# Slice A — "Nothing is lost" (durability spine)

**Status:** core built and proven; demo result recorded below.
**Built:** 2026-06-14 → 2026-06-15.
**ADR-003 items:** 1 (idempotent ingestion), 3 (LISTEN/NOTIFY relay), 6 (Pi spool), 9 (single config + dim gate).

> This file is written for the next session (and for future Sean), per the
> restructure plan's Decision 3: what was predicted, what actually happened, and
> what question to carry into the next slice.

---

## What was predicted

ADR-003 §1 claimed a tiered spool — ESP32 ring buffer → Pi SQLite/mosquitto →
idempotent Inferno ingestion — would make Inferno outages "delayed, not lost,"
with **exactly-once effect** at the database from `UNIQUE(node_id, seq)` +
`ON CONFLICT DO NOTHING`. Event delivery would move from SSE polling to a single
`LISTEN/NOTIFY` connection. All config would live in one `meridian.env`, with the
embedder dimension validated at startup so the 768-vs-other mismatch becomes a
loud failure, not silent corruption.

## What we built

- `schemas/001_durability_spine.sql` — `nodes`, `boot_sessions` (with `boot_epoch`),
  `sensor_readings` (`UNIQUE(node_id,seq)`), `perceptual_events` + an `AFTER INSERT`
  `pg_notify('perceptual_events', id)` trigger.
- `services/common` — single-file config loader + `assert_embedding_dim` (the
  startup gate).
- `services/ingestion` — aiomqtt → Postgres, idempotent writes, boot-epoch
  `event_time` reconstruction, **durable MQTT session**.
- `services/relay` — one `LISTEN` connection → WebSocket fan-out, keeping v1
  `ws_bridge`'s `{type,data}` envelope (Unity unchanged). SSE polling deleted.
- `services/spool` — Sensor Pi tier: local subscribe → SQLite WAL journal →
  forward upstream, mark-on-confirm.
- `deploy/` — `docker-compose.yml` (pgvector pg17 on Inferno, isolated from frozen
  v1), `apply_migrations.sh`, `mosquitto-pi.conf`, `meridian.env.example`.

Each was proven against the real stack (idempotency: a duplicate `seq` dropped,
original value preserved; relay: insert → NOTIFY → WebSocket with embedding
omitted; dim gate: `vector(768)` matches).

## The demo (the slice's falsifiable test)

Simulate an edge node publishing N readings into the Pi's local broker; pull
Inferno mid-stream for several minutes; on recovery, the spool drains and the
counts must agree.

```
Pi   : sqlite spool   total = ____   forwarded = ____
Inferno: sensor_readings(node='sim-pod') = ____
```
**Result:** <!-- fill in actual numbers after the run; expected 120/120/120 -->
Pass = all three equal across an induced outage. <!-- update Status line above once recorded -->

---

## What surprised us (the real lessons)

1. **`stop` is not `freeze`.** v1's ingestion services (`esp32-bridge`,
   `registry-intake`) were stopped for the corpus export but only *stopped*, not
   *disabled* — they auto-restarted across a reboot and quietly resumed writing.
   Freezing a service means `disable --now`, **and** checking for a sibling
   `.timer` (`epistemic-exchange.timer` would have re-launched its service even
   after the service was disabled). Verify with `is-enabled`, not just `is-active`.

2. **Migration files are not the live schema.** The live `motifs` table had
   drifted from `schemas/001` (no `source_corpus`; extra `score/last_seen/active`).
   The export aborted until we read the *actual* columns from `information_schema`.
   Lesson: against a long-lived DB, introspect; never assume the migrations
   describe what's really there.

3. **Broker-ack ≠ delivery.** The spool marks a reading forwarded on the upstream
   broker's QoS-1 PUBACK — but a PUBACK only means the *broker* took it. If the
   consumer is mid-reconnect with a clean session, the broker drops it and the
   spool wrongly believes it delivered. The guarantee only holds with a **durable
   subscription** (ingestion: fixed identifier + `clean_session=False`) **plus**
   broker `persistence=true` **plus** idempotent writes. All three, or it leaks.

4. **We deviated from ADR-003 on purpose.** ADR said "mosquitto bridge + spool."
   We had the **spool forward** instead — a SQLite journal with explicit
   ack-tracking is inspectable and disk-bounded, which the demo needs as a
   *countable* witness and a bridge's opaque queue can't give. The Pi's mosquitto
   is then a plain local broker. Revisit if a second edge aggregator appears.

5. **DB-free edges shape the packaging.** `services/common/__init__` eagerly
   imported the dim gate (→ `asyncpg`), which broke the deliberately DB-free Pi
   spool. Shared `__init__` files must not pull in heavy/optional deps; import
   them where used.

6. **Shared hardware carries v1 ghosts.** The Sensor Pi still had v1's
   `mosquitto` conf (a second `listener 1883`, plus a `9001` websockets listener
   Unity used in v1). Freezing v1 isn't only about Inferno's systemd units — edge
   hosts carry config too. (Disabled, not deleted: `sensor_ecology.conf.disabled`.)

## Deferred / known-not-done

- **ESP32 firmware** — the wire contract is *defined* by `services/ingestion`
  (manifest/readings/status topics) but no firmware emits it yet; we tested with
  `mosquitto_pub`.
- **No systemd units for v2 services** — they run by hand. Productionizing
  (units + `/etc/meridian/meridian.env`) is deploy hardening, not slice work.
- **Spool retention/vacuum** — forwarded rows accumulate forever; a prune of
  `WHERE forwarded_at IS NOT NULL` past some age is needed before long running.
- **No ACLs** — broker is anonymous (one trusted home; ADR §4 deferred).
- `motif_resonance` FK and the materialized view (ADR item 2/4) belong to Slice B.

---

## The next question → Slice B, "Nothing is claimed"

The spine guarantees the *raw* record survives. Slice B asks whether the
*interpretations* are honest: replay the v1 seed corpus (`seed/export/`, 284,399
events) through ingestion + the promotion job's four gates, and see **which
motifs earn their way through** versus v1's 31 *asserted* motifs. The diff between
asserted and earned is the research result the Meridian proposal is waiting on.

Open design question to resolve first: ingestion currently writes raw
`sensor_readings`; Slice B needs the **embedding step** that turns events into
`perceptual_events` (the producer the relay already listens for). That producer —
local-first nomic embedding, asserting nothing — is where Slice A's relay meets
Slice B's lifecycle. Start there.
