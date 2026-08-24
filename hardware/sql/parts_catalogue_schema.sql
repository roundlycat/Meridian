-- Sensor Ecology — Parts Catalogue
-- Run once on Inferno: psql -U <user> -d <your_db> -f parts_catalogue_schema.sql

CREATE EXTENSION IF NOT EXISTS vector;

CREATE TABLE IF NOT EXISTS parts_catalogue (
    id              SERIAL PRIMARY KEY,
    ingested_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- File provenance
    image_path      TEXT NOT NULL,          -- absolute path to original image
    image_filename  TEXT NOT NULL,

    -- Raw OCR text (full dark panel)
    ocr_raw         TEXT,

    -- Parsed sections from the scan app output
    ocr_results     TEXT,                   -- section 1: pin labels, ICs, etc.
    component_model TEXT,                   -- section 2: identified chip / module
    summary         TEXT,                   -- section 3: natural language summary

    -- Semantic embedding of summary + component_model (bge-large: 1024 dims)
    embedding       vector(1024),

    -- Optional tags added later
    tags            TEXT[]
);

-- Semantic similarity search index
CREATE INDEX IF NOT EXISTS parts_catalogue_embedding_idx
    ON parts_catalogue
    USING ivfflat (embedding vector_cosine_ops)
    WITH (lists = 50);

-- Fast lookup by filename (idempotency check)
CREATE UNIQUE INDEX IF NOT EXISTS parts_catalogue_filename_idx
    ON parts_catalogue (image_filename);
