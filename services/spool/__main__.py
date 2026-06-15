"""
Spool service — Sensor Pi (.25) edge durability tier (ADR-003 §1, tier 2).

Runs on the Sensor Pi. Edge nodes (and local Hailo inference) publish to the Pi's
LOCAL mosquitto. The spool:
  1. subscribes to everything under meridian/field/# on the local broker,
  2. journals each message to a SQLite WAL spool on disk (durable, survives reboot),
  3. forwards each message UPSTREAM to Inferno's broker, marking it forwarded only
     after the upstream broker confirms delivery (QoS 1).

When Inferno or the network is down, messages accumulate unforwarded in SQLite and
drain automatically on reconnect — nothing is lost. The on-disk journal is also the
queryable witness the power-pull demo compares against ("did Inferno end up with
exactly what the edge emitted?").

Blind re-forwarding is safe: every reading carries (node_id, seq) and Inferno
ingestion does ON CONFLICT DO NOTHING, so at-least-once forwarding from the spool
yields exactly-once effect in Postgres.

Design note: this deliberately deviates from ADR-003's "mosquitto bridge + spool"
by having the spool forward (the bridge's job). SQLite with explicit ack-tracking
is inspectable and disk-bounded, which the demo needs and a bridge's opaque queue
can't give. The Pi's mosquitto is then just a plain local broker.

Run on the Pi (venv with aiomqtt; sqlite3 is stdlib):
    python -m services.spool
"""
from __future__ import annotations

import asyncio
import datetime as dt
import logging
import os
import sqlite3

import aiomqtt

from services.common import load_config

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s: %(message)s")
log = logging.getLogger("spool")

TOPIC_FILTER = "meridian/field/#"
RECONNECT_BACKOFF_S = 5
DRAIN_BATCH = 200
DRAIN_IDLE_SLEEP_S = 0.5

SCHEMA = """
CREATE TABLE IF NOT EXISTS spool (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    topic         TEXT NOT NULL,
    payload       BLOB NOT NULL,
    qos           INTEGER NOT NULL DEFAULT 1,
    received_at   TEXT NOT NULL,            -- ISO-8601 UTC
    forwarded_at  TEXT                      -- NULL until confirmed upstream
);
CREATE INDEX IF NOT EXISTS idx_spool_unforwarded
    ON spool (id) WHERE forwarded_at IS NULL;
"""


def _utcnow() -> str:
    return dt.datetime.now(dt.timezone.utc).isoformat()


def _open_db(path: str) -> sqlite3.Connection:
    parent = os.path.dirname(path)
    if parent:
        os.makedirs(parent, exist_ok=True)
    conn = sqlite3.connect(path, check_same_thread=False)
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA synchronous=NORMAL")
    conn.executescript(SCHEMA)
    conn.commit()
    return conn


class Spool:
    def __init__(self, db: sqlite3.Connection):
        self._db = db
        self._lock = asyncio.Lock()
        self._nudge = asyncio.Event()

    async def append(self, topic: str, payload: bytes, qos: int) -> None:
        async with self._lock:
            await asyncio.to_thread(
                self._db.execute,
                "INSERT INTO spool (topic, payload, qos, received_at) VALUES (?, ?, ?, ?)",
                (topic, payload, qos, _utcnow()),
            )
            await asyncio.to_thread(self._db.commit)
        self._nudge.set()

    async def next_batch(self, limit: int) -> list[tuple]:
        async with self._lock:
            cur = await asyncio.to_thread(
                self._db.execute,
                "SELECT id, topic, payload, qos FROM spool "
                "WHERE forwarded_at IS NULL ORDER BY id LIMIT ?",
                (limit,),
            )
            return await asyncio.to_thread(cur.fetchall)

    async def mark_forwarded(self, row_id: int) -> None:
        async with self._lock:
            await asyncio.to_thread(
                self._db.execute,
                "UPDATE spool SET forwarded_at = ? WHERE id = ?",
                (_utcnow(), row_id),
            )
            await asyncio.to_thread(self._db.commit)

    async def pending(self) -> int:
        async with self._lock:
            cur = await asyncio.to_thread(
                self._db.execute, "SELECT count(*) FROM spool WHERE forwarded_at IS NULL"
            )
            return (await asyncio.to_thread(cur.fetchone))[0]


async def local_subscriber(cfg, spool: Spool) -> None:
    """Capture everything the Pi hears into the spool (durable first, always)."""
    while True:
        try:
            async with aiomqtt.Client(
                hostname=cfg.spool_local_mqtt_host, port=cfg.spool_local_mqtt_port
            ) as client:
                await client.subscribe(TOPIC_FILTER, qos=1)
                log.info("subscribed (local) %s:%s %s",
                         cfg.spool_local_mqtt_host, cfg.spool_local_mqtt_port, TOPIC_FILTER)
                async for m in client.messages:
                    await spool.append(m.topic.value, bytes(m.payload), 1)
        except aiomqtt.MqttError as e:
            log.warning("local broker lost (%s); retry in %ds", e, RECONNECT_BACKOFF_S)
            await asyncio.sleep(RECONNECT_BACKOFF_S)


async def upstream_forwarder(cfg, spool: Spool) -> None:
    """Drain unforwarded rows to Inferno's broker, marking each only on confirm."""
    while True:
        try:
            async with aiomqtt.Client(hostname=cfg.mqtt_host, port=cfg.mqtt_port) as client:
                log.info("connected (upstream) %s:%s; draining spool", cfg.mqtt_host, cfg.mqtt_port)
                while True:
                    batch = await spool.next_batch(DRAIN_BATCH)
                    if not batch:
                        spool._nudge.clear()
                        try:
                            await asyncio.wait_for(spool._nudge.wait(), timeout=DRAIN_IDLE_SLEEP_S)
                        except asyncio.TimeoutError:
                            pass
                        continue
                    for row_id, topic, payload, qos in batch:
                        await client.publish(topic, payload, qos=qos)  # awaits PUBACK at qos 1
                        await spool.mark_forwarded(row_id)
                    log.info("forwarded %d (still pending: %d)", len(batch), await spool.pending())
        except aiomqtt.MqttError as e:
            log.warning("upstream lost (%s); %d pending; retry in %ds",
                        e, await spool.pending(), RECONNECT_BACKOFF_S)
            await asyncio.sleep(RECONNECT_BACKOFF_S)


async def main() -> None:
    cfg = load_config()
    db = _open_db(cfg.spool_db_path)
    spool = Spool(db)
    log.info("spool starting: db=%s, local=%s:%s, upstream=%s:%s, pending=%d",
             cfg.spool_db_path, cfg.spool_local_mqtt_host, cfg.spool_local_mqtt_port,
             cfg.mqtt_host, cfg.mqtt_port, await spool.pending())
    try:
        await asyncio.gather(
            local_subscriber(cfg, spool),
            upstream_forwarder(cfg, spool),
        )
    finally:
        db.close()


if __name__ == "__main__":
    asyncio.run(main())
