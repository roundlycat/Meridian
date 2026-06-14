"""
Relay service — Postgres LISTEN/NOTIFY → WebSocket fan-out (ADR-003 §1, item 3).

Replaces v1's SSE polling. Holds ONE Postgres LISTEN connection on the
'perceptual_events' channel (fed by the AFTER INSERT trigger in schemas/001).
Each NOTIFY carries an event id only; the relay fetches the row and fans it out
to every connected WebSocket client. Load now scales with event rate, not with
client count × poll frequency.

Wire envelope keeps v1 ws_bridge's shape ({"type", "data"}), so the Unity AR
client points at this relay unchanged:
    {"type": "perceptual_event",
     "data": {id, node_id, domain, feature_snapshot, event_time, received_at}}
The embedding is deliberately omitted — it is motif-space internal and large;
the client never needed it (same "carry the id, not the payload" instinct that
keeps NOTIFY payloads to an id).

Run (repo root, venv with asyncpg + websockets):
    python -m services.relay
"""
from __future__ import annotations

import asyncio
import datetime as dt
import json
import logging
import uuid

import asyncpg
import websockets

from services.common import load_config

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s: %(message)s")
log = logging.getLogger("relay")

FETCH_SQL = """
    SELECT id, node_id, domain, feature_snapshot, event_time, received_at
    FROM perceptual_events
    WHERE id = $1
"""

clients: set = set()


def _json_default(o):
    if isinstance(o, (dt.datetime, dt.date)):
        return o.isoformat()
    if isinstance(o, uuid.UUID):
        return str(o)
    raise TypeError(f"not JSON-serializable: {type(o)!r}")


async def _init_conn(conn: asyncpg.Connection) -> None:
    # decode jsonb (feature_snapshot) to a real dict, not a string
    await conn.set_type_codec(
        "jsonb", encoder=json.dumps, decoder=json.loads, schema="pg_catalog",
    )


async def ws_handler(websocket, path=None):  # path arg kept for websockets<11 compat
    clients.add(websocket)
    log.info("client connected (%s); %d total", getattr(websocket, "remote_address", "?"), len(clients))
    try:
        async for _ in websocket:   # no inbound protocol; just hold the connection open
            pass
    except websockets.ConnectionClosed:
        pass
    finally:
        clients.discard(websocket)
        log.info("client disconnected; %d total", len(clients))


async def broadcast(message: str) -> None:
    if not clients:
        return
    targets = list(clients)
    results = await asyncio.gather(*(c.send(message) for c in targets), return_exceptions=True)
    for c, r in zip(targets, results):
        if isinstance(r, Exception):
            clients.discard(c)


async def fanout_worker(pool: asyncpg.Pool, queue: asyncio.Queue) -> None:
    while True:
        event_id = await queue.get()
        try:
            async with pool.acquire() as conn:
                row = await conn.fetchrow(FETCH_SQL, uuid.UUID(event_id))
            if row is None:
                log.warning("notified event %s not found", event_id)
                continue
            msg = json.dumps({"type": "perceptual_event", "data": dict(row)}, default=_json_default)
            await broadcast(msg)
            log.info("fanned out event %s to %d client(s)", event_id, len(clients))
        except Exception as e:                       # never let one bad event kill the loop
            log.warning("fanout failed for %s: %s", event_id, e)


async def main() -> None:
    cfg = load_config()
    queue: asyncio.Queue = asyncio.Queue()

    pool = await asyncpg.create_pool(cfg.database_url, min_size=1, max_size=4, init=_init_conn)
    # Dedicated long-lived connection for LISTEN (not from the pool, which recycles).
    listen_conn = await asyncpg.connect(cfg.database_url)

    def on_notify(connection, pid, channel, payload):   # sync callback, runs in the loop
        queue.put_nowait(payload)

    await listen_conn.add_listener(cfg.notify_channel, on_notify)
    log.info("LISTEN %s on %s", cfg.notify_channel, cfg.database_url.rsplit("@", 1)[-1])

    asyncio.create_task(fanout_worker(pool, queue))
    async with websockets.serve(ws_handler, cfg.relay_host, cfg.relay_port):
        log.info("relay WebSocket up on ws://%s:%d", cfg.relay_host, cfg.relay_port)
        await asyncio.Future()   # run forever


if __name__ == "__main__":
    asyncio.run(main())
