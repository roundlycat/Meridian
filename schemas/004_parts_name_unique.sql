-- =============================================================================
-- Meridian v2 — Slice-independent: parts catalog dedup key
--
-- schemas/003 shipped `parts.name` without a uniqueness constraint, even though
-- the import tooling (hardware/scripts/import_bom_v2.py, and the older
-- hardware/scripts/import_bom.py it replaces) upserts parts keyed on name via
-- ON CONFLICT (name). Without this constraint that upsert fails outright.
--
-- Safe to apply any time after 003: additive, no data yet to conflict.
-- =============================================================================

ALTER TABLE parts ADD CONSTRAINT parts_name_key UNIQUE (name);
