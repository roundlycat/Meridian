# Meridian (v2)

Distributed perceptual system: the domestic environment as a composing entity.
Edge nodes (ESP32-C3 pollen pods, Sensor Pi) → MQTT → ingestion → PostgreSQL on
Inferno → relay-api (WebSocket) → Unity AR client. v1 (`sensor_ecology`) is
**frozen**; this is the contract-first rebuild. v1's corpus is inherited under
`seed/`. Rationale lives in the v1 archive: `sensor_ecology/docs/ADR-003_Meridian_V2.md`
and `docs/MERIDIAN_V2_RESTRUCTURE.md` (to be imported into `docs/adr/`).

## Current slice: A — "Nothing is lost" (durability spine)

The spine that makes every other slice safe to retry blindly. ADR-003 items 1, 3, 6, 9.

- [ ] `sensor_readings` `UNIQUE(node_id, seq)` + `INSERT … ON CONFLICT DO NOTHING`
- [ ] SQLite WAL spool + mosquitto bridge on Sensor Pi (.25)
- [ ] `pg_notify` trigger + single LISTEN loop in relay; SSE polling path deleted
- [ ] all config in `/etc/meridian/meridian.env`; embedder-dim check at startup

**Demo — the slice is done when this passes, not when the code is pretty:**
pull Inferno's power mid-stream for 10 minutes. After recovery, row counts match
what the edge nodes emitted. v1 could not pass this; v2 must.

**One slice in flight at a time.** Slices B (honest motif lifecycle) and C (pod
first contact) are scoped but NOT started — do not build ahead of the demo.

## What's running where

- **Inferno (192.168.0.28):** PostgreSQL 17 (`meridian` db), Ollama
  (`nomic-embed-text`, 768-dim), mosquitto. Shared infra; v1 used the same boxes.
- **Sensor Pi (.25):** local mosquitto + SQLite spool — Slice A target, not built yet.
- **v2 services:** none deployed yet. Slice A's ingestion + relay are the first.
- **Unity AR client:** unchanged from v1 — speaks the same ws-bridge WebSocket
  contract, repointed at v2's relay. Not rewritten (garden-phase work).

## Health check

Once Slice A lands: `bash deploy/health.sh` (db reachable + embedder dim matches
the schema's `vector(N)` + recent rows present). Until then, verify shared infra:
`pg_isready -h 192.168.0.28 && curl -s 192.168.0.28:11434/api/version`

## Do not

- Do not restart v1 ingestion (`esp32-bridge`, `registry-intake` on the old
  stack). v1 is frozen; restarting moves the frozen seed count.
- Do not mix embedding dimensions — everything is 768-dim nomic. The startup
  dimension check exists to make a mismatch fail loudly, not silently corrupt.
- Do not add configuration as literals; it goes in `meridian.env`, nowhere else.
- Do not start Slice B/C work while Slice A's demo is unproven.

> Update this file at the end of any session that changes system state.
