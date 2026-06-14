-- =============================================================================
-- Meridian v2 — Slice A: durability spine
-- ADR-003 §1 (idempotent ingestion, boot-epoch time) + §1's LISTEN/NOTIFY (item 3)
-- + the schema half of item 9 (the embedding dim here MUST equal meridian.env
--   EMBEDDING_DIM; services validate the two match at startup).
--
-- schemas/ is the single source of schema truth. Migrations are applied in
-- filename order. This file is greenfield — it does NOT migrate v1; v1's corpus
-- arrives via seed/replay.py (Slice B).
--
-- Naming: plural tables, singular NOTIFY channel — ADR-003 is internally
-- inconsistent (item 1 "sensor_readings", §2 trigger "perceptual_event"); we
-- standardize on plural table names + channel 'perceptual_events'.
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS vector;

-- ---------------------------------------------------------------------------
-- Nodes. Identity is content-derived (efuse MAC), never assigned (ADR-003 §3).
-- Trust state (OBSERVED → TRUSTED probation) lands in Slice C; here a node is
-- just an identity + its retained manifest.
-- ---------------------------------------------------------------------------
CREATE TABLE nodes (
    node_id        TEXT PRIMARY KEY,                 -- e.g. 'pod-a4c138...'
    hw             TEXT,                             -- 'esp32-c3', 'sensor-pi'
    form           TEXT,                             -- 'pollen-pod', 'sensor-pi'
    manifest       JSONB NOT NULL DEFAULT '{}',      -- retained MQTT birth cert (Slice C)
    first_seen_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_seen_at   TIMESTAMPTZ
);

-- ---------------------------------------------------------------------------
-- Boot sessions. Edge nodes do not trust their clocks (ADR-003 §1, time
-- handling). On the first packet of a boot we stamp wall-clock; event_time is
-- then reconstructed as first_seen_at + millis_since_boot. One row per boot.
-- ---------------------------------------------------------------------------
CREATE TABLE boot_sessions (
    id             BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    node_id        TEXT NOT NULL REFERENCES nodes(node_id),
    boot_id        TEXT NOT NULL,                    -- node-local boot nonce
    first_seen_at  TIMESTAMPTZ NOT NULL DEFAULT now(),  -- wall clock at first packet of this boot
    boot_epoch     TIMESTAMPTZ,                      -- estimated instant the node booted:
                                                     -- first_seen_at - (first millis_since_boot).
                                                     -- event_time = boot_epoch + millis_since_boot.
    UNIQUE (node_id, boot_id)
);

-- ---------------------------------------------------------------------------
-- Raw readings. At-least-once delivery everywhere, exactly-once EFFECT here:
-- UNIQUE(node_id, seq) + ON CONFLICT DO NOTHING is the single constraint that
-- makes the whole spool design safe to retry blindly (ADR-003 §1.3).
-- ---------------------------------------------------------------------------
CREATE TABLE sensor_readings (
    id                 BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    node_id            TEXT NOT NULL REFERENCES nodes(node_id),
    seq                BIGINT NOT NULL,              -- monotonic per node, from firmware
    boot_session_id    BIGINT REFERENCES boot_sessions(id),
    millis_since_boot  BIGINT,                       -- node uptime at sample time
    sensor             TEXT NOT NULL,                -- 'sgp40-voc', etc.
    channel            TEXT,
    value              DOUBLE PRECISION,
    unit               TEXT,
    received_at        TIMESTAMPTZ NOT NULL DEFAULT now(),  -- authoritative arrival
    event_time         TIMESTAMPTZ,                  -- reconstructed (see boot_sessions)
    provenance         TEXT NOT NULL DEFAULT 'unverified',  -- Slice C promotes to trusted
    payload            JSONB NOT NULL DEFAULT '{}',
    UNIQUE (node_id, seq)
);
CREATE INDEX idx_sensor_readings_node_time ON sensor_readings (node_id, received_at DESC);

-- ---------------------------------------------------------------------------
-- Perceptual events. Ingestion asserts NOTHING beyond the embedding (ADR-003
-- §2): no label, no resonance, no motif FK. Those arrive in Slice B. The
-- embedding column dimension is the contract the startup check enforces.
-- ---------------------------------------------------------------------------
CREATE TABLE perceptual_events (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    node_id           TEXT REFERENCES nodes(node_id),
    domain            TEXT,
    feature_snapshot  JSONB NOT NULL DEFAULT '{}',
    embedding         vector(768) NOT NULL,          -- == meridian.env EMBEDDING_DIM
    event_time        TIMESTAMPTZ,
    received_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_perceptual_events_time ON perceptual_events (received_at DESC);

-- ---------------------------------------------------------------------------
-- LISTEN/NOTIFY replaces SSE polling (item 3). The payload is the event ID
-- ONLY — Postgres NOTIFY has an 8 kB limit and we refuse two sources of truth.
-- relay-api holds one LISTEN connection and fetches the row, then fans out over
-- the existing ws-bridge WebSocket path. Load scales with event rate, not
-- client count × poll frequency.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION notify_perceptual_event() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    PERFORM pg_notify('perceptual_events', NEW.id::text);
    RETURN NEW;
END;
$$;

CREATE TRIGGER perceptual_events_notify
    AFTER INSERT ON perceptual_events
    FOR EACH ROW EXECUTE FUNCTION notify_perceptual_event();
