# Meridian (v2)

Distributed perceptual system: the domestic environment as a composing entity.
Edge nodes (ESP32-C3 pollen pods, Sensor Pi) → MQTT → ingestion → PostgreSQL on
Inferno → relay-api (WebSocket) → Unity AR client. v1 (`sensor_ecology`) is
**frozen**; this is the contract-first rebuild. v1's corpus is inherited under
`seed/`. Rationale lives in the v1 archive: `sensor_ecology/docs/ADR-003_Meridian_V2.md`
and `sensor_ecology/docs/MERIDIAN_V2_RESTRUCTURE.md` (to be imported into `Docs/adr/`).
Per-slice lessons accrue in `Docs/lessons/` — read them before extending a slice.

## Current slice: B — "Nothing is claimed" (honest motif lifecycle)

Structure is EARNED off the hot path, never asserted at observation time.
ADR-003 items 2, 4 + the v1 data inheritance. Demo = replay the 284,399-event
seed corpus through the promotion gates; the diff between *earned* motifs and v1's
31 *asserted* ones is the research result.

- [ ] `schemas/002_motif_lifecycle.sql` — candidate→motif→dormant state machine, evidence, transitions, labels, FK-complete resonance, `motif_graph_stats` mat-view
- [ ] `seed/replay.py` — load seed `perceptual_events` (intact embeddings) into v2
- [ ] promotion job — HDBSCAN clustering + 4 gates (members/span/sources/stability) + explicit transitions with evidence snapshots; labels are decoration, refresh the mat-view
- [ ] compare earned vs v1's 31 asserted motifs → research result
- [ ] live embedding producer (raw → `perceptual_events`, local nomic, asserts nothing) — the relay already listens; *after* the demo
- [ ] **closing gate:** the replay demo recorded in `Docs/lessons/`

**Demo:** replay 284,399 v1 events; watch which motifs survive the gates, each
with its evidence snapshot. Replay reuses the seed's stored embeddings (no
re-embedding — that's why they were preserved).

> **✅ Slice A — "Nothing is lost" — CLOSED** (2026-06-15, outage demo 120/120/120).
> Durability spine survived a broker outage and a full reboot. See
> `Docs/lessons/slice-a-nothing-is-lost.md`.

**One slice in flight at a time.** Slice C (pod first contact) is scoped but NOT
started — do not build ahead of B's demo.

## What's running where

- **Inferno (192.168.0.28):** the `meridian` db runs in a **pgvector pg17 Docker
  container** (`meridian-postgres`, host port **5544**), isolated from the frozen
  v1 native `postgresql@17`. Plus Ollama (`nomic-embed-text`, 768-dim) + mosquitto.
  `docker` needs `sudo` unless your shell is in the docker group.
- **Sensor Pi (.25, `raspberrypi`):** local mosquitto + `services/spool` (SQLite
  WAL) — deployed and proven. v1's old `mosquitto` conf is `.disabled`.
- **v2 services:** `services/ingestion` + `services/relay` on Inferno, `services/spool`
  on the Pi. Run by hand from `~/Meridian` (no systemd units yet).
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
