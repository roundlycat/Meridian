-- ============================================================
-- Meridian Ecology — Parts & BOM Database Schema
-- Target: PostgreSQL 17 + pgvector on Inferno (192.168.0.28)
-- Purpose: Unified parts catalog, multi-BOM tracking,
--          inventory state, node configuration, MNP support
-- ============================================================

CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ------------------------------------------------------------
-- 1. PARTS CATALOG
-- The canonical record for any physical component.
-- One row per unique part regardless of which BOM it appears in.
-- ------------------------------------------------------------
CREATE TABLE parts (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name            TEXT NOT NULL,
    description     TEXT,
    category        TEXT NOT NULL,          -- e.g. 'Electronics – Sensors', '3D Printed Parts'
    subcategory     TEXT,                   -- e.g. 'Fasteners', 'Power'
    material_spec   TEXT,                   -- e.g. 'BME688 I2C breakout', 'PETG 1.75mm'
    unit_type       TEXT NOT NULL,          -- 'ea', 'spool', 'reel', 'kit', 'm', etc.
    unit_cost_cad   NUMERIC(10,4),
    supplier_options TEXT[],                -- array of supplier names
    -- Electronics-specific fields (null for non-electronic parts)
    interface_type  TEXT,                   -- 'I2C', 'SPI', 'UART', 'I2S', 'analog', 'digital', 'power'
    i2c_address     TEXT,                   -- e.g. '0x76', '0x29' — null if not I2C
    voltage_v       NUMERIC(4,2),           -- operating voltage
    datasheet_url   TEXT,
    -- Fabrication-specific fields
    print_material  TEXT,                   -- e.g. 'PETG', 'TPU 95A' — null if not printed
    print_mass_g    NUMERIC(6,1),           -- estimated print mass in grams
    -- Semantic embedding for MNP similarity search
    embedding       vector(768),
    notes           TEXT,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX ON parts USING GIN (supplier_options);
CREATE INDEX ON parts (category);
CREATE INDEX ON parts (interface_type);
CREATE INDEX ON parts USING ivfflat (embedding vector_cosine_ops) WITH (lists = 50);

-- ------------------------------------------------------------
-- 2. BOM SOURCES
-- Each distinct bill of materials document or project context.
-- ------------------------------------------------------------
CREATE TABLE bom_sources (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name            TEXT NOT NULL UNIQUE,   -- e.g. 'Sensor Species Family', 'Garden Field Nodes'
    description     TEXT,
    project_type    TEXT,                   -- 'installation', 'field', 'research', 'infrastructure'
    currency        TEXT DEFAULT 'CAD',
    version         TEXT DEFAULT '1.0',
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Seed the two known BOMs
INSERT INTO bom_sources (name, description, project_type) VALUES
    ('Sensor Species Family',
     'Kinetic sculptural installation — Whitehorse YT. 20 primary components across four morphological types.',
     'installation'),
    ('Garden Field Nodes',
     'Outdoor sensor ecology deployment — garden plot, Whitehorse YT. Initial autonomy testing phase.',
     'field'),
    ('Meridian Core Infrastructure',
     'Indoor research ecology — Inferno Pi5, Sensor Pi, edge nodes, AR layer.',
     'research');

-- ------------------------------------------------------------
-- 3. BOM LINE ITEMS
-- A part''s appearance in a specific BOM with project-context metadata.
-- Same part can appear in multiple BOMs with different quantities.
-- ------------------------------------------------------------
CREATE TABLE bom_line_items (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    bom_id          UUID NOT NULL REFERENCES bom_sources(id) ON DELETE CASCADE,
    part_id         UUID NOT NULL REFERENCES parts(id),
    source_item_no  INTEGER,                -- original item # from source BOM document
    qty_required    NUMERIC(10,2) NOT NULL,
    morphology      TEXT,                   -- e.g. 'Pollen Pod', 'Garland Links', 'E1 Central'
    priority        TEXT CHECK (priority IN ('critical','recommended','optional')),
    notes           TEXT,
    UNIQUE (bom_id, part_id, morphology)    -- same part can appear for different morphologies
);

CREATE INDEX ON bom_line_items (bom_id);
CREATE INDEX ON bom_line_items (part_id);

-- ------------------------------------------------------------
-- 4. INVENTORY
-- Actual stock state, independent of BOM requirements.
-- This is what MNP proposals consult before recommending fabrication.
-- ------------------------------------------------------------
CREATE TABLE inventory (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    part_id         UUID NOT NULL REFERENCES parts(id) UNIQUE,
    qty_on_hand     NUMERIC(10,2) DEFAULT 0,
    qty_on_order    NUMERIC(10,2) DEFAULT 0,
    status          TEXT DEFAULT 'to_order'
                    CHECK (status IN ('in_stock','to_order','ordered','received','depleted')),
    order_source    TEXT,                   -- where it was/will be ordered from
    order_date      DATE,
    expected_date   DATE,
    location_note   TEXT,                   -- e.g. 'bench drawer 3', 'drybox'
    last_updated    TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX ON inventory (status);
CREATE INDEX ON inventory (part_id);

-- Convenience view: parts with current inventory state
CREATE VIEW parts_with_inventory AS
SELECT
    p.id, p.name, p.category, p.subcategory,
    p.interface_type, p.i2c_address,
    p.unit_cost_cad, p.unit_type,
    COALESCE(i.qty_on_hand, 0) AS qty_on_hand,
    COALESCE(i.qty_on_order, 0) AS qty_on_order,
    COALESCE(i.status, 'to_order') AS inventory_status,
    i.order_source, i.location_note
FROM parts p
LEFT JOIN inventory i ON i.part_id = p.id;

-- ------------------------------------------------------------
-- 5. NODE CONFIGURATIONS
-- A named, versioned recipe for a physical sensor node.
-- E1, B1, B2, W, P, Hub, Pollen Pod v1, etc.
-- ------------------------------------------------------------
CREATE TABLE node_configurations (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name            TEXT NOT NULL,          -- 'E1 Central', 'B1 Bed North', 'Pollen Pod v1'
    slug            TEXT NOT NULL UNIQUE,   -- 'e1-central', 'pollen-pod-v1'
    description     TEXT,
    node_family     TEXT,                   -- 'garden_field', 'ssf_installation', 'meridian'
    enclosure_type  TEXT,                   -- 'pollen_pod', 'puck_outdoor', 'perch_pod', 'bare'
    deployment_context TEXT,               -- 'outdoor_exposed', 'indoor_gallery', 'shed'
    controller      TEXT,                   -- 'pico_w', 'qt_py_rp2040', 'pi_5', 'portenta_x8'
    comms_protocol  TEXT[],                 -- ['mqtt','wifi'], ['lorawan'], ['uart_uplink']
    version         TEXT DEFAULT '0.1',
    is_active       BOOLEAN DEFAULT TRUE,
    notes           TEXT,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Parts within a node configuration
CREATE TABLE node_parts (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    node_config_id  UUID NOT NULL REFERENCES node_configurations(id) ON DELETE CASCADE,
    part_id         UUID NOT NULL REFERENCES parts(id),
    qty             NUMERIC(6,2) DEFAULT 1,
    role            TEXT,                   -- 'primary_sensor', 'controller', 'power',
                                            -- 'comms', 'connector', 'enclosure', 'lighting'
    bus_position    TEXT,                   -- 'i2c_primary', 'uart_1', 'i2s', 'gpio_4'
    is_required     BOOLEAN DEFAULT TRUE,
    notes           TEXT
);

CREATE INDEX ON node_parts (node_config_id);
CREATE INDEX ON node_parts (part_id);

-- Convenience view: full bill of parts for a node config
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
-- 6. DEPLOYED NODES
-- Physical instances of a node configuration deployed in the field.
-- ------------------------------------------------------------
CREATE TABLE deployed_nodes (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    node_config_id  UUID REFERENCES node_configurations(id),
    label           TEXT NOT NULL UNIQUE,   -- 'E1', 'B1', 'pollen-pod-03'
    location_name   TEXT,                   -- 'garden centre', 'north bed', 'workshop wall'
    -- Spatial reference from Scaniverse/Polycam scans
    scan_x          NUMERIC(8,4),           -- position in scan coordinate space (meters)
    scan_y          NUMERIC(8,4),
    scan_z          NUMERIC(8,4),
    scan_source     TEXT,                   -- 'scaniverse_2026-05-13', 'polycam_2026-05-13'
    -- MQTT
    mqtt_topic_prefix TEXT,                 -- e.g. 'meridian/garden/e1'
    -- Status
    deployed_at     TIMESTAMPTZ,
    is_active       BOOLEAN DEFAULT FALSE,
    last_seen       TIMESTAMPTZ,
    firmware_version TEXT,
    notes           TEXT
);

-- ------------------------------------------------------------
-- 7. MORPHOLOGY NEGOTIATION PROTOCOL (MNP)
-- Gap reports from nodes and the proposals that respond to them.
-- ------------------------------------------------------------
CREATE TABLE mnp_gap_reports (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    node_id         UUID REFERENCES deployed_nodes(id),
    node_label      TEXT,                   -- denormalized for querying when node_id unknown
    trigger_type    TEXT NOT NULL,          -- 'unstable_reading', 'mounting_failure',
                                            -- 'env_saturation', 'motif_drift', 'manual'
    description     TEXT NOT NULL,
    evidence        JSONB,                  -- sensor readings, error rates, context at time of report
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
    justification   TEXT,                   -- why this proposal addresses the gap
    proposed_by     TEXT DEFAULT 'system',  -- 'system', 'claude', 'gemini', 'human'
    -- Fabrication details
    requires_print  BOOLEAN DEFAULT FALSE,
    print_parts     UUID[],                 -- array of part IDs needing fabrication
    estimated_build_hours NUMERIC(4,1),
    -- Human stewardship
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
-- 8. USEFUL QUERIES (as comments for reference)
-- ------------------------------------------------------------

-- What can I build right now for E1?
-- SELECT part_name, role, in_stock, stock_status
-- FROM node_bom WHERE slug = 'e1-central' AND is_required = TRUE;

-- What sensors share an I2C bus without address conflict?
-- SELECT name, i2c_address, interface_type FROM parts
-- WHERE interface_type = 'I2C' AND i2c_address IS NOT NULL
-- ORDER BY i2c_address;

-- What's the total cost of the SSF BOM, critical items only?
-- SELECT SUM(p.unit_cost_cad * b.qty_required)
-- FROM bom_line_items b
-- JOIN parts p ON p.id = b.part_id
-- JOIN bom_sources s ON s.id = b.bom_id
-- WHERE s.name = 'Sensor Species Family' AND b.priority = 'critical';

-- What parts in the SSF BOM are already in stock?
-- SELECT p.name, i.qty_on_hand, i.location_note
-- FROM bom_line_items b
-- JOIN parts p ON p.id = b.part_id
-- JOIN bom_sources s ON s.id = b.bom_id
-- JOIN inventory i ON i.part_id = p.id
-- WHERE s.name = 'Sensor Species Family' AND i.status = 'in_stock';

-- Find semantically similar parts to a given sensor (MNP substitution)
-- SELECT name, category, 1 - (embedding <=> query_embedding) AS similarity
-- FROM parts WHERE embedding IS NOT NULL
-- ORDER BY embedding <=> query_embedding LIMIT 5;

-- ============================================================
-- MIGRATION NOTE
-- Populate parts + bom_line_items by importing from:
--   1. Sensor_Species_Family___Full_Bill_of_Materials.xlsx (106 items)
--   2. Garden field nodes BOM (in progress)
--   3. Meridian core parts inventory (manual + from existing notes)
-- Embeddings: run nomic-embed-text on (name + description + material_spec)
--             via Ollama on Inferno after initial import
-- ============================================================
