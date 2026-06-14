# seed/ — v1 corpus inheritance

The one-time inheritance of sensor_ecology (v1) into Meridian v2. Step 2 of
`docs/MERIDIAN_V2_RESTRUCTURE.md`.

- **`export_corpus.py`** — produces `export/` from the v1 Postgres on Inferno.
- **`export/`** — the exported corpus (gzipped JSONL, one file per table) + `MANIFEST.json`.
- **`replay.py`** — (Slice B) replays the corpus through v2 ingestion + promotion.

## What's in the seed, and why

| File | Role |
|------|------|
| `agent_nodes.jsonl.gz` | perceptual node registry (FK target) |
| `sensor_readings.jsonl.gz` | canonical raw readings |
| `perceptual_events.jsonl.gz` | fused events **with intact 768-dim embeddings** |
| `motifs.jsonl.gz` | v1's **asserted** motifs — the "before" half of Slice B's asserted-vs-earned diff |
| `motif_label_map.jsonl.gz` | event_label → motif_id (migration completed 2026-06-12) |

**Excluded on purpose** (the lesson, not the data): `motif_resonance` and
`perceptual_motif_drift` (the corrupted resonance corpus + its derived drift),
and the legacy 384-dim `observations` / `emergent_patterns` / `agents` layer.
Mixing 384-dim and 768-dim embeddings is forbidden (v1 CLAUDE.md), and the
legacy layer is not part of the perceptual seed.

## Running the export (on Inferno)

The DB and a venv with `asyncpg` live on Inferno; run it there:

```bash
DATABASE_URL=postgresql://sean:ecology@localhost/sensor_ecology \
    /path/to/sensor_ecology/.venv/bin/python seed/export_corpus.py --out seed/export
```

It aborts if any `perceptual_events.embedding` is still NULL (re-run
`scripts/backfill_embeddings.py` first). Then verify — no DB needed:

```bash
python seed/export_corpus.py --verify --out seed/export
```

`MANIFEST.json` records per-file row counts and the sha256 of each file's
**uncompressed** JSONL content. Those counts/hashes are what `FROZEN.md` cites.

## Git policy

`MANIFEST.json` is committed (small, and the authoritative record). The bulk
`*.jsonl.gz` are git-ignored here — they can be large. Track them with
`git lfs track 'seed/export/*.jsonl.gz'` if you want them in the repo, or keep
them out-of-band; either way the manifest's hashes pin exactly what they must be.
