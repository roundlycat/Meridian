"""
Ingestion service — idempotent MQTT → Postgres writer (ADR-003 §1, item 1).

The durability endpoint: at-least-once delivery everywhere, exactly-once EFFECT
here. Edge nodes (and the Sensor Pi spool) may republish freely; UNIQUE(node_id,
seq) + ON CONFLICT DO NOTHING make every retry a no-op. Edge clocks are not
trusted — event_time is reconstructed from the boot epoch, so a spool drained
after an Inferno outage lands with honest timestamps instead of all bunched at
drain time.

This service is also the CONTRACT the firmware must meet (contract-first; the
ESP32 firmware doesn't exist yet). Wire format on the MQTT broker:

  meridian/field/{node_id}/manifest   (retained)  -> upserts `nodes`
      {"schema_ver":1,"hw":"esp32-c3","form":"pollen-pod","sensors":[...], ...}

  meridian/field/{node_id}/readings              -> sensor_readings (one or many)
      {"boot_id":"<nonce>","seq":12345,"millis_since_boot":840321,
       "sensor":"sgp40-voc","channel":"voc_index","value":123.4,"unit":"ppb"}
      (a JSON object, or a JSON array of them for batches drained from the spool)

  meridian/field/{node_id}/status     (last will) -> liveness only (logged)

Run (from the repo root, venv with asyncpg + aiomqtt>=2):
    python -m services.ingestion
Config comes from meridian.env (see services/common/config.py search order).
"""
from __future__ import annotations

import asyncio
import datetime as dt
import json
import logging

import aiomqtt
import asyncpg

from services.common import load_config

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s: %(message)s")
log = logging.getLogger("ingestion")

TOPIC_FILTERS = [
    "meridian/field/+/manifest",
    "meridian/field/+/readings",
    "meridian/field/+/status",
]
RECONNECT_BACKOFF_S = 5


def _node_id_from_topic(topic: str) -> str | None:
    # meridian/field/{node_id}/<kind>
    parts = topic.split("/")
    if len(parts) == 4 and parts[0] == "meridian" and parts[1] == "field":
        return parts[2]
    return None


async def _upsert_node_from_manifest(conn, node_id: str, manifest: dict) -> None:
    await conn.execute(
        """
        INSERT INTO nodes (node_id, hw, form, manifest, last_seen_at)
        VALUES ($1, $2, $3, $4, now())
        ON CONFLICT (node_id) DO UPDATE
            SET hw = EXCLUDED.hw,
                form = EXCLUDED.form,
                manifest = EXCLUDED.manifest,
                last_seen_at = now()
        """,
        node_id, manifest.get("hw"), manifest.get("form"), json.dumps(manifest),
    )
    log.info("manifest: upserted node %s (%s/%s)", node_id, manifest.get("hw"), manifest.get("form"))


async def _ensure_node(conn, node_id: str) -> None:
    # Readings can arrive before a manifest; make sure the FK target exists.
    await conn.execute(
        """
        INSERT INTO nodes (node_id, last_seen_at) VALUES ($1, now())
        ON CONFLICT (node_id) DO UPDATE SET last_seen_at = now()
        """,
        node_id,
    )


async def _boot_session(conn, node_id: str, boot_id: str, millis_since_boot: int | None):
    """Resolve (or create) the boot session, returning (id, boot_epoch).

    On first sight of a boot we estimate boot_epoch = now() - millis_since_boot,
    i.e. the wall-clock instant the node powered on (ADR-003 §1, time handling).
    """
    epoch_expr = "now()" if millis_since_boot is None else \
        "now() - make_interval(secs => $3::double precision / 1000.0)"
    args = [node_id, boot_id]
    if millis_since_boot is not None:
        args.append(millis_since_boot)
    await conn.execute(
        f"""
        INSERT INTO boot_sessions (node_id, boot_id, boot_epoch)
        VALUES ($1, $2, {epoch_expr})
        ON CONFLICT (node_id, boot_id) DO NOTHING
        """,
        *args,
    )
    row = await conn.fetchrow(
        "SELECT id, boot_epoch FROM boot_sessions WHERE node_id = $1 AND boot_id = $2",
        node_id, boot_id,
    )
    return row["id"], row["boot_epoch"]


async def _insert_reading(conn, node_id: str, r: dict) -> bool:
    """Insert one reading idempotently. Returns True if a NEW row was written."""
    seq = r["seq"]
    boot_id = r.get("boot_id")
    millis = r.get("millis_since_boot")

    boot_session_id, boot_epoch = (None, None)
    if boot_id is not None:
        boot_session_id, boot_epoch = await _boot_session(conn, node_id, boot_id, millis)

    event_time = None
    if boot_epoch is not None and millis is not None:
        event_time = boot_epoch + dt.timedelta(milliseconds=millis)

    status = await conn.execute(
        """
        INSERT INTO sensor_readings
            (node_id, seq, boot_session_id, millis_since_boot,
             sensor, channel, value, unit, event_time, payload)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
        ON CONFLICT (node_id, seq) DO NOTHING
        """,
        node_id, seq, boot_session_id, millis,
        r.get("sensor"), r.get("channel"), r.get("value"), r.get("unit"),
        event_time, json.dumps(r.get("payload", {})),
    )
    # asyncpg returns 'INSERT 0 1' when a row was inserted, 'INSERT 0 0' on conflict.
    return status.endswith(" 1")


async def _handle(conn, topic: str, payload: bytes) -> None:
    node_id = _node_id_from_topic(topic)
    if node_id is None:
        log.warning("ignoring unrecognized topic: %s", topic)
        return
    kind = topic.rsplit("/", 1)[-1]

    if kind == "status":
        log.info("status: %s -> %s", node_id, payload.decode("utf-8", "replace"))
        return

    try:
        data = json.loads(payload)
    except json.JSONDecodeError as e:
        log.warning("bad JSON on %s: %s", topic, e)
        return

    if kind == "manifest":
        await _upsert_node_from_manifest(conn, node_id, data)
        return

    if kind == "readings":
        readings = data if isinstance(data, list) else [data]
        await _ensure_node(conn, node_id)
        written = 0
        async with conn.transaction():
            for r in readings:
                try:
                    if await _insert_reading(conn, node_id, r):
                        written += 1
                except KeyError as e:
                    log.warning("reading from %s missing field %s; skipped", node_id, e)
        log.info("readings: %s -> %d new / %d received", node_id, written, len(readings))


async def _run_once(cfg) -> None:
    pool = await asyncpg.create_pool(cfg.database_url, min_size=1, max_size=4)
    try:
        async with aiomqtt.Client(hostname=cfg.mqtt_host, port=cfg.mqtt_port) as client:
            for f in TOPIC_FILTERS:
                await client.subscribe(f, qos=1)
            log.info("subscribed on %s:%s to %s", cfg.mqtt_host, cfg.mqtt_port, TOPIC_FILTERS)
            async for message in client.messages:
                async with pool.acquire() as conn:
                    await _handle(conn, message.topic.value, message.payload)
    finally:
        await pool.close()


async def main() -> None:
    cfg = load_config()
    log.info("ingestion starting (db=%s)", cfg.database_url.rsplit("@", 1)[-1])
    while True:
        try:
            await _run_once(cfg)
        except aiomqtt.MqttError as e:
            log.warning("MQTT connection lost (%s); reconnecting in %ds", e, RECONNECT_BACKOFF_S)
            await asyncio.sleep(RECONNECT_BACKOFF_S)


if __name__ == "__main__":
    asyncio.run(main())
