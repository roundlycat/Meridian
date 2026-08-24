-- =============================================================================
-- Meridian v2 — DRAFT Slice: Parts / BOM / Inventory (evidence-aware)
--
-- STATUS: DRAFT. Not applied to any database. Not renamed into the real
-- schemas/ migration sequence. Written 2026-08-24 as a proposal to review
-- against the v1 design in hardware/sql/meridian_parts_schema.sql, which this
-- adapts rather than replaces — the relational shape there is sound and is
-- kept close to as-is. What changes:
--
--   1. parts_catalogue (OCR/photo scans) becomes EVIDENCE for a part, not a
--      parallel, disconnected table. A part can exist with zero, one, or many
--      supporting scans; confidence is visible instead of implied.
--   2. A part has a lifecycle state, mirroring the candidate -> motif -> dormant
--      pattern schemas/002_motif_lifecycle.sql already proved out for Slice B:
--      catalogued from one scan/hand-entry is not the same confidence as
--      confirmed against a datasheet or cross-referenced across multiple scans.
--      This is optional ceremony for a hand-typed BOM line (mark it
--      'confirmed' and move on) — it exists for when the OCR pipeline is
--      doing the typing instead of you.
--   3. mnp_gap_reports / mnp_proposals kept close to verbatim — this is
--      already a first draft of Slice C's negotiation mechanism and doesn't
--      need reinvention, just a home.
--
-- Does not touch perceptual_events, motifs, or anything Slice A/B owns.
-- Whether this should land as schemas/003_parts_inventory.sql alongside the
-- perceptual pipeline, or live in a separate "one slice in flight" lane
-- entirely, is a call for Sean — see HARDWARE_DB_AUDIT_2026-08-24.md §2.
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ------------------------------------------------------------
-- 1. PART SCANS (was: parts_catalogue)
-- Raw evidence: a photo of a component, OCR'd and embedded.
-- Zero or more scans can support a part. A scan can exist with no
-- part yet — that's the "I photographed something and haven't
-- catalogued it" state, which is the honest starting point.
-- ------------------------------------------------------------
CREATE TABLE part_scans (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    ingested_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    image_path      TEXT NOT NULL,
    image_filename  TEXT NOT NULL,
    ocr_raw         TEXT,
    ocr_results     TEXT,             -- parsed pin labels, ICs, etc.
    component_model TEXT,             -- best-guess identified chip/module
    summary         TEXT,             -- natural-language summary
    embedding       vector(1024),     -- bge-large-en-v1.5, matches parts_query.py
    tags            TEXT[],
    part_id         UUID              -- nullable FK, set once triaged onto a part
);

CREATE UNIQUE INDEX ON part_scans (image_filename);
CREATE INDEX part_scans_embedding_idx ON part_scans
    USING ivfflat (embedding vector_cosine_ops) WITH (lists = 50);

-- ------------------------------------------------------------
-- 2. PARTS CATALOG
-- The canonical record for a physical component. Lifecycle state is
-- informational, not a gate on usability — a hand-entered part can be
-- 'confirmed' on day one. It exists so scan-sourced parts carry visible
-- confidence instead of silently equal footing with a datasheet-checked one.
-- ------------------------------------------------------------
CREATE TYPE part_confidence AS ENUM ('candidate', 'confirmed', 'superseded');

CREATE TABLE parts (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name            TEXT NOT NULL,
    description     TEXT,
    category        TEXT NOT NULL,
    subcategory     TEXT,
    material_spec   TEXT,
    unit_type       TEXT NOT NULL,
    unit_cost_cad   NUMERIC(10,4),
    supplier_options TEXT[],
    interface_type  TEXT,             -- 'I2C','SPI','UART','I2S','analog','digital','power','connector'
    i2c_address     TEXT,
    voltage_v       NUMERIC(4,2),
    datasheet_url   TEXT,
    print_material  TEXT,
    print_mass_g    NUMERIC(6,1),
    embedding       vector(768),      -- nomic-embed-text, matches v2's perceptual embeddings
    confidence      part_confidence NOT NULL DEFAULT 'confirmed',
    notes           TEXT,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE part_scans
    ADD CONSTRAINT part_scans_part_fk
    FOREIGN KEY (part_id) REFERENCES parts(id) ON DELETE SET NULL;

CREATE INDEX ON parts USING GIN (supplier_options);
CREATE INDEX ON parts (category);
CREATE INDEX ON parts (interface_type);
CREATE INDEX ON parts (confidence);
CREATE INDEX ON parts USING ivfflat (embedding vector_cosine_ops) WITH (lists = 50);

-- Convenience view: a part with its supporting evidence count.
CREATE VIEW parts_with_evidence AS
SELECT
    p.*,
    COUNT(s.id) AS scan_count,
    MAX(s.ingested_at) AS last_scan_at
FROM parts p
LEFT JOIN part_scans s ON s.part_id = p.id
GROUP BY p.id;

-- ------------------------------------------------------------
-- 3. BOM SOURCES
-- ------------------------------------------------------------
CREATE TABLE bom_sources (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name            TEXT NOT NULL UNIQUE,
    description     TEXT,
    project_type    TEXT,             -- 'installation','field','research','infrastructure'
    currency        TEXT DEFAULT 'CAD',
    version         TEXT DEFAULT '1.0',
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Seed with the BOMs actually known to exist as of this draft — review before
-- running. Add rows here rather than inventing new project_type categories
-- that don't match anything in hardware/bom/ yet.
INSERT INTO bom_sources (name, description, project_type) VALUES
    ('Sensor Species Family',
     'Kinetic sculptural installation, Whitehorse YT. hardware/bom/Sensor Species Family — Full Bill of Materials.xlsx',
     'installation'),
    ('Morphogenesis',
     'Full build, filament, and CF upgrades. hardware/bom/Morphogenesis BOM — Full Build, Filament, CF Upgrades & Supplies.xlsx',
     'infrastructure'),
    ('Backbone LoRa',
     'Portenta / RPi5 / Jetson LoRa backbone. hardware/bom/Portenta–RPi5–Jetson LoRa Backbone BOM.xlsx — confirm this still reflects current backbone plans before importing.',
     'infrastructure'),
    ('Wrist-Puck',
     'Dual-channel haptic node. See wrist_puck_bom_v1_DRAFT.csv delivered alongside this schema — not yet imported.',
     'research');

-- ------------------------------------------------------------
-- 4. BOM LINE ITEMS
-- ------------------------------------------------------------
CREATE TABLE bom_line_items (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    bom_id          UUID NOT NULL REFERENCES bom_sources(id) ON DELETE CASCADE,
    part_id         UUID NOT NULL REFERENCES parts(id),
    source_item_no  INTEGER,
    qty_required    NUMERIC(10,2) NOT NULL,
    morphology      TEXT,
    priority        TEXT CHECK (priority IN ('critical','recommended','optional')),
    notes           TEXT,
    UNIQUE (bom_id, part_id, morphology)
);

CREATE INDEX ON bom_line_items (bom_id);
CREATE INDEX ON bom_line_items (part_id);

-- ------------------------------------------------------------
-- 5. INVENTORY
-- ------------------------------------------------------------
CREATE TABLE inventory (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    part_id         UUID NOT NULL REFERENCES parts(id) UNIQUE,
    qty_on_hand     NUMERIC(10,2) DEFAULT 0,
    qty_on_order    NUMERIC(10,2) DEFAULT 0,
    status          TEXT DEFAULT 'to_order'
                    CHECK (status IN ('in_stock','to_order','ordered','received','depleted')),
    order_source    TEXT,
    order_date      DATE,
    expected_date   DATE,
    location_note   TEXT,
    last_updated    TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX ON inventory (status);
CREATE INDEX ON inventory (part_id);

CREATE VIEW parts_with_inventory AS
SELECT
    p.id, p.name, p.category, p.subcategory,
    p.interface_type, p.i2c_address,
    p.unit_cost_cad, p.unit_type, p.confidence,
    COALESCE(i.qty_on_hand, 0) AS qty_on_hand,
    COALESCE(i.qty_on_order, 0) AS qty_on_order,
    COALESCE(i.status, 'to_order') AS inventory_status,
    i.order_source, i.location_note
FROM parts p
LEFT JOIN inventory i ON i.part_id = p.id;

-- ------------------------------------------------------------
-- 6. NODE CONFIGURATIONS
-- ------------------------------------------------------------
CREATE TABLE node_configurations (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name            TEXT NOT NULL,
    slug            TEXT NOT NULL UNIQUE,
    description     TEXT,
    node_family     TEXT,              -- 'garden_field','ssf_installation','meridian','wrist_haptics'
    enclosure_type  TEXT,
    deployment_context TEXT,
    controller      TEXT,
    comms_protocol  TEXT[],
    version         TEXT DEFAULT '0.1',
    is_active       BOOLEAN DEFAULT TRUE,
    notes           TEXT,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE node_parts (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    node_config_id  UUID NOT NULL REFERENCES node_configurations(id) ON DELETE CASCADE,
    part_id         UUID NOT NULL REFERENCES parts(id),
    qty             NUMERIC(6,2) DEFAULT 1,
    role            TEXT,
    bus_position    TEXT,
    is_required     BOOLEAN DEFAULT TRUE,
    notes           TEXT
);

CREATE INDEX ON node_parts (node_config_id);
CREATE INDEX ON node_parts (part_id);

CREATE VIEW node_bom AS
SELECT
    nc.name AS node_name,
    nc.slug,
    nc.deployment_context,
    p.name AS part_name,
    p.category,
    p.interface_type,
    p.i2c_address,
    np.qty,
    np.role,
    np.bus_position,
    np.is_required,
    COALESCE(i.qty_on_hand, 0) AS in_stock,
    COALESCE(i.status, 'to_order') AS stock_status,
    p.unit_cost_cad * np.qty AS line_cost_cad
FROM node_parts np
JOIN node_configurations nc ON nc.id = np.node_config_id
JOIN parts p ON p.id = np.part_id
LEFT JOIN inventory i ON i.part_id = p.id
ORDER BY nc.name, np.is_required DESC, np.role;

-- ------------------------------------------------------------
-- 7. DEPLOYED NODES
-- ------------------------------------------------------------
CREATE TABLE deployed_nodes (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    node_config_id  UUID REFERENCES node_configurations(id),
    label           TEXT NOT NULL UNIQUE,
    location_name   TEXT,
    scan_x          NUMERIC(8,4),
    scan_y          NUMERIC(8,4),
    scan_z          NUMERIC(8,4),
    scan_source     TEXT,
    mqtt_topic_prefix TEXT,
    deployed_at     TIMESTAMPTZ,
    is_active       BOOLEAN DEFAULT FALSE,
    last_seen       TIMESTAMPTZ,
    firmware_version TEXT,
    notes           TEXT
);

-- ------------------------------------------------------------
-- 8. MORPHOLOGY NEGOTIATION PROTOCOL (MNP) — Slice C groundwork
-- Kept close to hardware/sql/meridian_parts_schema.sql verbatim.
-- ------------------------------------------------------------
CREATE TABLE mnp_gap_reports (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    node_id         UUID REFERENCES deployed_nodes(id),
    node_label      TEXT,
    trigger_type    TEXT NOT NULL,     -- 'unstable_reading','mounting_failure','env_saturation','motif_drift','manual'
    description     TEXT NOT NULL,
    evidence        JSONB,
    severity        TEXT CHECK (severity IN ('low','medium','high','critical')),
    reported_at     TIMESTAMPTZ DEFAULT NOW(),
    status          TEXT DEFAULT 'open'
                    CHECK (status IN ('open','under_review','resolved','dismissed'))
);

CREATE TABLE mnp_proposals (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    gap_report_id   UUID REFERENCES mnp_gap_reports(id),
    proposed_config_id UUID REFERENCES node_configurations(id),
    title           TEXT NOT NULL,
    description     TEXT,
    justification   TEXT,
    proposed_by     TEXT DEFAULT 'system',
    requires_print  BOOLEAN DEFAULT FALSE,
    print_parts     UUID[],
    estimated_build_hours NUMERIC(4,1),
    status          TEXT DEFAULT 'pending'
                    CHECK (status IN ('pending','approved','modified','rejected','fabricating','installed')),
    steward_notes   TEXT,
    reviewed_at     TIMESTAMPTZ,
    installed_at    TIMESTAMPTZ,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX ON mnp_gap_reports (node_label);
CREATE INDEX ON mnp_gap_reports (status);
CREATE INDEX ON mnp_proposals (status);
CREATE INDEX ON mnp_proposals (gap_report_id);

-- ------------------------------------------------------------
-- 9. MIGRATION NOTE (unchanged intent from the v1 draft)
-- Populate from, in order:
--   1. v1 sensor_ecology's existing parts / bom_line_items / inventory /
--      node_configurations / node_parts (export -> review -> load, same
--      pattern as seed/export_corpus.py -> seed/replay.py for Slice B)
--   2. hardware/bom/*.xlsx not yet reflected in v1's db, if any
--   3. wrist_puck_bom_v1_DRAFT.csv (delivered alongside this file — net new,
--      no v1 equivalent exists)
-- Embeddings: nomic-embed-text via Ollama on Inferno, on
-- (name + description + material_spec), same convention as perceptual_events.
-- ------------------------------------------------------------
