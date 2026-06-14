"""
v1 Seed Corpus Export
=====================
One-time export of the sensor_ecology (v1) perceptual corpus into a portable,
verifiable seed for Meridian v2. This is step 2 of docs/MERIDIAN_V2_RESTRUCTURE.md
("Export the v1 corpus to seed/export/; write FROZEN.md; freeze v1").

What it exports
---------------
Seed corpus (raws + INTACT 768-dim embeddings — the durable truth Slice B replays):
    agent_nodes        perceptual node registry (FK target for events/readings)
    sensor_readings    canonical raw sensor readings
    perceptual_events  fused events WITH their nomic-embed-text (768-dim) embeddings

Comparison baseline (v1's *asserted* motifs — the "before" half of Slice B's
"asserted vs. earned" diff; NOT re-ingested as truth, kept for the research result):
    motifs             768-dim linguistic motif centroids
    motif_label_map    event_label -> motif_id mapping (the migration completed 2026-06-12)

Deliberately NOT exported (the lesson, not the data — ADR-003 / restructure plan):
    motif_resonance         corrupted resonance corpus (ingestion-time classification)
    perceptual_motif_drift  derived from the corrupted lineage
    observations / emergent_patterns / agents
                            legacy 384-dim MiniLM agent layer, superseded by the
                            768-dim perceptual layer. Mixing 384/768 is forbidden
                            (CLAUDE.md), and these are not part of the perceptual seed.

Output format
-------------
One gzipped JSON-Lines file per table in --out (default ./seed/export/), one JSON
object per row. pgvector columns are emitted as JSON arrays of floats. A MANIFEST.json
records, per file: row count + sha256 of the *uncompressed* JSONL bytes (stable across
gzip implementations / OSes), plus embedding model+dim, schema provenance, the
exclusion list with rationale, and the (password-stripped) source DB identity. The
manifest is what FROZEN.md cites and what `--verify` checks against.

Run on Inferno (where Postgres + the venv with asyncpg already live)
--------------------------------------------------------------------
    # from a checkout of the meridian repo on Inferno, using v1's venv:
    DATABASE_URL=postgresql://sean:ecology@localhost/sensor_ecology \
        /path/to/sensor_ecology/.venv/bin/python seed/export_corpus.py --out seed/export

    # verify a completed export against its manifest (no DB needed):
    python seed/export_corpus.py --verify --out seed/export

Idempotent: re-running overwrites the export directory cleanly and reproduces the
same uncompressed-content hashes for unchanged data.
"""

import argparse
import asyncio
import datetime as dt
import gzip
import hashlib
import json
import logging
import os
import uuid
from decimal import Decimal

import asyncpg

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s: %(message)s")
log = logging.getLogger(__name__)

DB_URL = os.environ.get("DATABASE_URL", "postgresql://sean:ecology@localhost/sensor_ecology")
EMBED_MODEL = os.environ.get("EMBED_MODEL", "nomic-embed-text")
EMBEDDING_DIM = 768
CURSOR_BATCH = 1000      # rows prefetched per server-side cursor round-trip
PROGRESS_EVERY = 50000   # log a progress line every N rows on streamed tables


# ---------------------------------------------------------------------------
# Table specs. `vector_cols` are pgvector columns selected as ::text and parsed
# to float arrays on write. `stream=True` uses a server-side cursor so we never
# hold a whole table in memory (perceptual_events is the big one).
# ---------------------------------------------------------------------------

TABLES = [
    {
        "name": "agent_nodes",
        "stream": False,
        "vector_cols": [],
        "query": """
            SELECT id, node_name, node_type, location_label,
                   latitude, longitude, registered_at, last_heartbeat_at, metadata
            FROM agent_nodes
            ORDER BY registered_at, id
        """,
    },
    {
        "name": "sensor_readings",
        "stream": True,
        "optional": True,   # 21M-row raw firehose; opt-in only (--include-raw-readings)
        "vector_cols": [],
        "query": """
            SELECT id, agent_node_id, domain, sensor_label, channel,
                   raw_value, unit, quality_flag, recorded_at
            FROM sensor_readings
            ORDER BY id
        """,
    },
    {
        "name": "perceptual_events",
        "stream": True,
        "vector_cols": ["embedding"],
        "query": """
            SELECT id, agent_node_id, domain, event_label, confidence,
                   source_reading_ids, feature_snapshot,
                   embedding::text AS embedding,
                   event_start, event_end, duration_ms,
                   is_cross_domain, domains_involved,
                   agent_power_mW  AS agent_power_mw,
                   agent_temp_c,
                   agent_cpu_load_pct,
                   metadata
            FROM perceptual_events
            ORDER BY event_start, id
        """,
    },
    {
        "name": "motifs",
        "stream": False,
        "vector_cols": ["centroid_embedding"],
        "query": """
            SELECT id, label, centroid_embedding::text AS centroid_embedding,
                   source_corpus, created_at, updated_at
            FROM motifs
            ORDER BY created_at, id
        """,
    },
    {
        "name": "motif_label_map",
        "stream": False,
        "vector_cols": [],
        "query": """
            SELECT event_label, motif_id
            FROM motif_label_map
            ORDER BY event_label
        """,
    },
]

EXCLUSIONS = {
    "sensor_readings": "21M-row raw sensor firehose; not needed for replay (per-event raws live "
                       "in perceptual_events.feature_snapshot). Opt in with --include-raw-readings "
                       "to archive it separately.",
    "motif_resonance": "corrupted resonance corpus (ingestion-time classification) — the lesson, not the data",
    "perceptual_motif_drift": "derived from the corrupted resonance lineage",
    "observations": "legacy 384-dim MiniLM agent layer, superseded by the 768-dim perceptual layer",
    "emergent_patterns": "legacy 384-dim agent layer",
    "agents": "legacy agent registry, superseded by agent_nodes",
}


def parse_vector(text):
    """pgvector '[0.1,-0.2,...]'::text -> list[float], or None."""
    if text is None:
        return None
    inner = text.strip().lstrip("[").rstrip("]").strip()
    if not inner:
        return []
    return [float(x) for x in inner.split(",")]


def json_default(obj):
    if isinstance(obj, (dt.datetime, dt.date, dt.time)):
        return obj.isoformat()
    if isinstance(obj, uuid.UUID):
        return str(obj)
    if isinstance(obj, Decimal):
        return float(obj)
    if isinstance(obj, (bytes, bytearray)):
        return obj.hex()
    raise TypeError(f"not JSON-serializable: {type(obj)!r}")


def sanitize_db_url(url: str) -> str:
    """Strip any password from the DSN for the manifest."""
    if "@" not in url:
        return url
    scheme, rest = url.split("://", 1) if "://" in url else ("", url)
    creds, host = rest.split("@", 1)
    user = creds.split(":", 1)[0]
    prefix = f"{scheme}://" if scheme else ""
    return f"{prefix}{user}:***@{host}"


async def export_table(conn, spec, out_dir):
    name = spec["name"]
    path = os.path.join(out_dir, f"{name}.jsonl.gz")
    vector_cols = spec["vector_cols"]
    hasher = hashlib.sha256()
    rows = 0

    # gzip mtime=0 so the container is reproducible run-to-run (the hash is over
    # the uncompressed content regardless, but this keeps the .gz stable too).
    with gzip.GzipFile(path, "wb", mtime=0) as gz:
        async def emit(record):
            nonlocal rows
            d = dict(record)
            for col in vector_cols:
                d[col] = parse_vector(d.get(col))
            line = json.dumps(d, default=json_default, separators=(",", ":"),
                              ensure_ascii=False) + "\n"
            data = line.encode("utf-8")
            hasher.update(data)   # hash of uncompressed JSONL — stable & verifiable
            gz.write(data)
            rows += 1
            if spec["stream"] and rows % PROGRESS_EVERY == 0:
                log.info("  %s ... %d rows", name, rows)

        if spec["stream"]:
            async with conn.transaction():
                async for record in conn.cursor(spec["query"], prefetch=CURSOR_BATCH):
                    await emit(record)
        else:
            for record in await conn.fetch(spec["query"]):
                await emit(record)

    sha = hasher.hexdigest()
    log.info("exported %-18s %8d rows  sha256=%s  -> %s", name, rows, sha[:12], path)
    return {"file": f"{name}.jsonl.gz", "rows": rows, "sha256": sha}


async def run_export(out_dir: str, include_raw: bool) -> None:
    os.makedirs(out_dir, exist_ok=True)
    conn = await asyncpg.connect(DB_URL)
    # decode JSONB to Python objects so feature_snapshot/metadata nest as real JSON
    await conn.set_type_codec(
        "jsonb", encoder=json.dumps, decoder=json.loads, schema="pg_catalog",
    )
    await conn.set_type_codec(
        "json", encoder=json.dumps, decoder=json.loads, schema="pg_catalog",
    )

    started = dt.datetime.now(dt.timezone.utc)
    db_name = await conn.fetchval("SELECT current_database()")
    files = []
    try:
        # Sanity gate: refuse to produce a seed with NULL embeddings — that would
        # silently break v2 replay. v1's obligation was zero NULLs (memory 2026-06-12).
        null_emb = await conn.fetchval(
            "SELECT count(*) FROM perceptual_events WHERE embedding IS NULL"
        )
        if null_emb:
            raise SystemExit(
                f"ABORT: {null_emb} perceptual_events still have NULL embeddings. "
                f"Re-run scripts/backfill_embeddings.py on Inferno before exporting."
            )

        for spec in TABLES:
            if spec.get("optional") and not include_raw:
                log.info("skipping %s (optional raw firehose; pass --include-raw-readings to export)",
                         spec["name"])
                continue
            files.append(await export_table(conn, spec, out_dir))
    finally:
        await conn.close()

    finished = dt.datetime.now(dt.timezone.utc)
    manifest = {
        "export_kind": "sensor_ecology_v1_seed_corpus",
        "schema_version": "schemas/004_motif_label_map.sql (motif_label_map migration applied)",
        "embedding_model": EMBED_MODEL,
        "embedding_dim": EMBEDDING_DIM,
        "source_db": sanitize_db_url(DB_URL),
        "source_db_name": db_name,
        "exported_started_utc": started.isoformat(),
        "exported_finished_utc": finished.isoformat(),
        "files": files,
        "total_rows": sum(f["rows"] for f in files),
        "raw_readings_included": include_raw,
        "excluded_tables": EXCLUSIONS,
        "hash_note": "sha256 is computed over the UNCOMPRESSED JSONL bytes of each file",
        "vector_encoding": "pgvector columns emitted as JSON arrays of floats",
    }
    manifest_path = os.path.join(out_dir, "MANIFEST.json")
    with open(manifest_path, "w", encoding="utf-8") as fh:
        json.dump(manifest, fh, indent=2)
    log.info("wrote manifest: %s (%d files, %d total rows)",
             manifest_path, len(files), manifest["total_rows"])
    log.info("DONE. Next: verify with --verify, then write FROZEN.md citing these counts.")


def run_verify(out_dir: str) -> None:
    manifest_path = os.path.join(out_dir, "MANIFEST.json")
    with open(manifest_path, encoding="utf-8") as fh:
        manifest = json.load(fh)

    ok = True
    for entry in manifest["files"]:
        path = os.path.join(out_dir, entry["file"])
        if not os.path.exists(path):
            log.error("MISSING %s", entry["file"]); ok = False; continue
        hasher = hashlib.sha256()
        rows = 0
        with gzip.GzipFile(path, "rb") as gz:
            for line in gz:
                hasher.update(line)
                rows += 1
        sha = hasher.hexdigest()
        rows_ok = rows == entry["rows"]
        sha_ok = sha == entry["sha256"]
        if rows_ok and sha_ok:
            log.info("OK   %-18s %8d rows  sha256=%s", entry["file"], rows, sha[:12])
        else:
            ok = False
            log.error("FAIL %-18s rows %d/%d  sha %s/%s",
                      entry["file"], rows, entry["rows"], sha[:12], entry["sha256"][:12])
    if ok:
        log.info("VERIFY PASSED: %d files match manifest", len(manifest["files"]))
    else:
        raise SystemExit("VERIFY FAILED — export does not match manifest")


def main() -> None:
    ap = argparse.ArgumentParser(description="Export / verify the v1 seed corpus")
    ap.add_argument("--out", default="seed/export", help="output directory (default: seed/export)")
    ap.add_argument("--verify", action="store_true",
                    help="verify an existing export against its MANIFEST.json (no DB)")
    ap.add_argument("--include-raw-readings", action="store_true",
                    help="also export the 21M-row sensor_readings firehose (slow, multi-GB; "
                         "not needed for Slice B replay)")
    args = ap.parse_args()
    if args.verify:
        run_verify(args.out)
    else:
        asyncio.run(run_export(args.out, args.include_raw_readings))


if __name__ == "__main__":
    main()
