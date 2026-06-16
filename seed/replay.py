"""
seed/replay.py — replay the v1 seed corpus into v2 (Slice B).

Loads seed/export/{agent_nodes,perceptual_events}.jsonl.gz into v2's `nodes` and
`perceptual_events`, REUSING the intact nomic-768 embeddings (no re-embedding —
that is exactly why they were preserved at freeze time). Idempotent: every insert
is `ON CONFLICT (id) DO NOTHING`, so a re-run tops up without duplicating. The
promotion job then earns motifs from these events; the diff against v1's 31
*asserted* motifs (`seed/export/motifs.jsonl.gz`, deliberately NOT loaded) is the
research result.

v1 → v2 mapping:
  agent_nodes.id (uuid)            → nodes.node_id (text)
  agent_nodes.node_type            → nodes.hw / form ; rest → nodes.manifest
  perceptual_events.agent_node_id  → perceptual_events.node_id (text)
  perceptual_events.event_start    → perceptual_events.event_time
  perceptual_events.event_label    → folded into feature_snapshot['_v1_event_label']
                                     (kept for the asserted-vs-earned comparison;
                                      the promotion job ignores everything but the embedding)

Run on Inferno (where the seed files + the meridian DB both live):
    DATABASE_URL=postgresql://meridian:...@localhost:5544/meridian \
        python seed/replay.py --export-dir seed/export
"""
from __future__ import annotations

import argparse
import asyncio
import datetime as dt
import gzip
import json
import logging
import os
import sys
import uuid

import asyncpg

# Make the repo root importable so we can reuse the services config loader,
# which parses meridian.env with Python (robust to passwords that break bash `source`).
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from services.common import load_config  # noqa: E402

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s: %(message)s")
log = logging.getLogger("replay")


def _dt(value):
    return dt.datetime.fromisoformat(value) if value else None


def _vector_literal(emb) -> str:
    # export stored the embedding as a JSON array of floats → pgvector text literal
    return "[" + ",".join(repr(float(x)) for x in emb) + "]"


def _read_jsonl_gz(path: str):
    with gzip.open(path, "rt", encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if line:
                yield json.loads(line)


async def load_nodes(conn, path: str) -> int:
    rows = []
    for r in _read_jsonl_gz(path):
        manifest = {
            "node_name": r.get("node_name"),
            "location_label": r.get("location_label"),
            "latitude": r.get("latitude"),
            "longitude": r.get("longitude"),
            **(r.get("metadata") or {}),
        }
        rows.append((
            str(r["id"]), r.get("node_type"), r.get("node_type"),
            json.dumps(manifest), _dt(r.get("registered_at")), _dt(r.get("last_heartbeat_at")),
        ))
    await conn.executemany(
        """
        INSERT INTO nodes (node_id, hw, form, manifest, first_seen_at, last_seen_at)
        VALUES ($1, $2, $3, $4::jsonb, $5, $6)
        ON CONFLICT (node_id) DO NOTHING
        """,
        rows,
    )
    log.info("nodes: %d loaded from %s", len(rows), os.path.basename(path))
    return len(rows)


EVENT_SQL = """
    INSERT INTO perceptual_events
        (id, node_id, domain, feature_snapshot, embedding, event_time, received_at)
    VALUES ($1, $2, $3, $4::jsonb, $5::vector, $6, $7)
    ON CONFLICT (id) DO NOTHING
"""


async def load_events(conn, path: str, batch_size: int, limit: int | None) -> int:
    seen = 0
    batch = []

    async def flush(rows):
        # Ensure FK targets exist even if an event references a node not in
        # agent_nodes (belt-and-suspenders; minimal node row, enriched if present).
        node_ids = list({r[1] for r in rows})
        await conn.execute(
            "INSERT INTO nodes (node_id) SELECT unnest($1::text[]) ON CONFLICT (node_id) DO NOTHING",
            node_ids,
        )
        await conn.executemany(EVENT_SQL, rows)

    for r in _read_jsonl_gz(path):
        snapshot = dict(r.get("feature_snapshot") or {})
        if r.get("event_label") is not None:
            snapshot["_v1_event_label"] = r["event_label"]
        event_time = _dt(r.get("event_start"))
        batch.append((
            uuid.UUID(str(r["id"])),
            str(r["agent_node_id"]) if r.get("agent_node_id") else None,
            r.get("domain"),
            json.dumps(snapshot),
            _vector_literal(r["embedding"]),
            event_time,
            event_time,                                  # received_at := event_start for replayed data
        ))
        seen += 1
        if len(batch) >= batch_size:
            await flush(batch)
            batch = []
            if seen % (batch_size * 25) == 0:
                log.info("  perceptual_events ... %d", seen)
        if limit is not None and seen >= limit:
            break
    if batch:
        await flush(batch)
    log.info("perceptual_events: %d processed from %s", seen, os.path.basename(path))
    return seen


async def main(export_dir: str, batch_size: int, limit: int | None) -> None:
    dsn = load_config().database_url        # reads meridian.env (or $DATABASE_URL override)
    conn = await asyncpg.connect(dsn)
    try:
        before = await conn.fetchval("SELECT count(*) FROM perceptual_events")
        await load_nodes(conn, os.path.join(export_dir, "agent_nodes.jsonl.gz"))
        await load_events(conn, os.path.join(export_dir, "perceptual_events.jsonl.gz"),
                          batch_size, limit)
        after = await conn.fetchval("SELECT count(*) FROM perceptual_events")
        log.info("DONE. perceptual_events: %d → %d (%d new). Next: run the promotion job.",
                 before, after, after - before)
    finally:
        await conn.close()


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description="Replay the v1 seed corpus into v2")
    ap.add_argument("--export-dir", default="seed/export")
    ap.add_argument("--batch", type=int, default=1000)
    ap.add_argument("--limit", type=int, default=None, help="stop after N events (smoke test)")
    args = ap.parse_args()
    asyncio.run(main(args.export_dir, args.batch, args.limit))
