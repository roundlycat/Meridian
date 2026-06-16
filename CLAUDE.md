# Meridian (v2)

Distributed perceptual system: the domestic environment as a composing entity.
Edge nodes (ESP32-C3 pollen pods, Sensor Pi) → MQTT → ingestion → PostgreSQL on
Inferno → relay-api (WebSocket) → Unity AR client. v1 (`sensor_ecology`) is
**frozen**; this is the contract-first rebuild. v1's corpus is inherited under
`seed/`. Rationale lives in the v1 archive: `sensor_ecology/docs/ADR-003_Meridian_V2.md`
and `sensor_ecology/docs/MERIDIAN_V2_RESTRUCTURE.md` (to be imported into `Docs/adr/`).
Per-slice lessons accrue in `Docs/lessons/` — read them before extending a slice.

## Current slice: A — "Nothing is lost" (durability spine)

The spine that makes every other slice safe to retry blindly. ADR-003 items 1, 3, 6, 9.

- [x] `sensor_readings` `UNIQUE(node_id, seq)` + `INSERT … ON CONFLICT DO NOTHING` — proven
- [x] SQLite WAL spool on Sensor Pi (.25) — deployed, forwards upstream (spool forwards, not a bridge)
- [x] `pg_notify` trigger + single LISTEN loop in relay; SSE polling path gone — proven
- [x] single `meridian.env` + embedder-dim check at startup — proven
- [x] **closing gate:** outage demo **passed 120 / 120 / 120** (2026-06-15) — see `Docs/lessons/slice-a-nothing-is-lost.md`

**✅ Slice A is CLOSED.** The durability spine survived an induced broker outage
(and a full Inferno reboot) with zero loss and zero duplicates. **Next: Slice B —
"Nothing is claimed."** First move (per the lessons file): build the embedding
producer (raw events → `perceptual_events`, local nomic 768, asserting nothing) —
the piece the relay already listens for — then the promotion job's four gates,
then `seed/replay.py` over the 284,399-event corpus.

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
