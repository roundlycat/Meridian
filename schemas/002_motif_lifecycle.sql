-- =============================================================================
-- Meridian v2 — Slice B: the honest motif lifecycle (ADR-003 §2, items 2 + 4)
--
-- Ingestion (Slice A) asserts NOTHING beyond the embedding. Here, structure is
-- EARNED off the hot path by the promotion job and recorded as explicit
-- transitions with the evidence that justified them. A motif's identity is
-- content-derived (a stable hash of its medoid region, ADR §5.1), so re-running
-- promotion converges instead of minting duplicates.
--
-- This is v2's OWN motif table — distinct from v1's 31 *asserted* motifs, which
-- stay in seed/export/motifs.jsonl.gz as the comparison baseline and are NOT
-- loaded here. The diff between earned and asserted is the slice's research result.
-- =============================================================================

CREATE TYPE motif_state AS ENUM ('candidate', 'motif', 'dormant');

-- Named attractors in the shared 768-dim space.
CREATE TABLE motifs (
    id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    content_key        TEXT UNIQUE NOT NULL,          -- stable hash of the medoid region
    state              motif_state NOT NULL DEFAULT 'candidate',
    centroid           vector(768) NOT NULL,
    member_count       INTEGER NOT NULL DEFAULT 0,
    source_count       INTEGER NOT NULL DEFAULT 0,    -- distinct nodes/domains in evidence
    first_evidence_at  TIMESTAMPTZ,                   -- earliest member event_time
    last_evidence_at   TIMESTAMPTZ,                   -- latest member event_time
    created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_motifs_state    ON motifs (state);
CREATE INDEX idx_motifs_centroid ON motifs USING hnsw (centroid vector_cosine_ops);

-- Membership IS the evidence: which perceptual_events support which motif.
CREATE TABLE motif_members (
    motif_id            UUID NOT NULL REFERENCES motifs(id) ON DELETE CASCADE,
    perceptual_event_id UUID NOT NULL REFERENCES perceptual_events(id) ON DELETE CASCADE,
    added_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (motif_id, perceptual_event_id)
);
CREATE INDEX idx_motif_members_event ON motif_members (perceptual_event_id);

-- Explicit, audited transitions. Demotion to dormant NEVER deletes evidence;
-- the snapshot records the gate values that justified the move.
CREATE TABLE motif_transitions (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    motif_id        UUID NOT NULL REFERENCES motifs(id) ON DELETE CASCADE,
    from_state      motif_state,                      -- NULL on first appearance
    to_state        motif_state NOT NULL,
    reason          TEXT NOT NULL,                    -- 'gates_passed', 'no_evidence_30d', ...
    evidence        JSONB NOT NULL DEFAULT '{}',      -- the gate values at transition time
    transitioned_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_motif_transitions_motif ON motif_transitions (motif_id, transitioned_at DESC);

-- Labels are DECORATION, not evidence (ADR §2): provenance-stamped, regenerable.
-- Only promoted motifs get labelled; a missing label never affects the lifecycle.
CREATE TABLE motif_labels (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    motif_id    UUID NOT NULL REFERENCES motifs(id) ON DELETE CASCADE,
    label       TEXT NOT NULL,
    labeller    TEXT NOT NULL,                        -- 'ollama:llama3', 'gemini', 'human'
    model       TEXT,
    labelled_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_motif_labels_motif ON motif_labels (motif_id, labelled_at DESC);

-- Resonance is computed at QUERY time (ADR §2: asking beats pre-computing). This
-- table is only an optional log of observed resonances — and unlike v1, the
-- motif_id FK is present with ON DELETE CASCADE (item 2's missing-FK fix).
CREATE TABLE motif_resonance (
    id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    motif_id            UUID NOT NULL REFERENCES motifs(id) ON DELETE CASCADE,
    perceptual_event_id UUID REFERENCES perceptual_events(id) ON DELETE CASCADE,
    cosine_distance     DOUBLE PRECISION NOT NULL,
    observed_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_motif_resonance_motif ON motif_resonance (motif_id, observed_at DESC);

-- Graph statistics as a materialized view, refreshed CONCURRENTLY by the
-- promotion job (item 4). AR client + dashboard READ this; they never aggregate
-- live. The unique index is what makes REFRESH ... CONCURRENTLY possible.
CREATE MATERIALIZED VIEW motif_graph_stats AS
SELECT
    m.id,
    m.content_key,
    m.state,
    m.member_count,
    m.source_count,
    m.first_evidence_at,
    m.last_evidence_at,
    (SELECT l.label FROM motif_labels l
     WHERE l.motif_id = m.id ORDER BY l.labelled_at DESC LIMIT 1) AS label
FROM motifs m
WHERE m.state = 'motif';
CREATE UNIQUE INDEX idx_motif_graph_stats_id ON motif_graph_stats (id);
