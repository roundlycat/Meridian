-- ============================================================
-- Semantic Twin Query Library
-- Inferno :: PostgreSQL + pgvector
-- Organized as composable, versioned SQL blocks
-- ============================================================
-- Convention: prefix with section letter + number
--   A = Foundation / utility
--   B = Similarity / proximity
--   C = Cross-source connections
--   D = Temporal / drift
--   E = Cluster / topology
-- ============================================================


-- ============================================================
-- A. FOUNDATION
-- ============================================================

-- A1: What sources and projects are in the corpus?
SELECT
    source,
    project,
    COUNT(*)        AS chunk_count,
    MIN(date)       AS earliest,
    MAX(date)       AS latest
FROM semantic_chunks
GROUP BY source, project
ORDER BY source, chunk_count DESC;


-- A2: Volume by month across all sources
SELECT
    to_char(date::date, 'YYYY-MM') AS month,
    source,
    COUNT(*)                        AS chunks
FROM semantic_chunks
GROUP BY month, source
ORDER BY month, source;


-- A3: Quick inspect — most recent chunks from each source
SELECT DISTINCT ON (source)
    source, project, date, left(text, 120) AS preview
FROM semantic_chunks
ORDER BY source, date DESC;


-- ============================================================
-- B. SIMILARITY — finding nearest neighbours
-- ============================================================

-- B1: Find the N chunks most similar to a given chunk by id
--     Replace :target_id with your chunk id
WITH target AS (
    SELECT embedding FROM semantic_chunks WHERE id = :target_id
)
SELECT
    sc.id,
    sc.source,
    sc.project,
    sc.date,
    1 - (sc.embedding <=> t.embedding) AS cosine_similarity,
    left(sc.text, 150)                  AS preview
FROM semantic_chunks sc, target t
WHERE sc.id != :target_id
ORDER BY sc.embedding <=> t.embedding
LIMIT 15;


-- B2: Find chunks most similar to a free-text probe
--     Requires embedding the probe externally; paste vector literal here
--     e.g. '[0.012, -0.034, ...]'::vector
WITH probe AS (
    SELECT :probe_vector::vector AS embedding
)
SELECT
    sc.id,
    sc.source,
    sc.project,
    sc.date,
    1 - (sc.embedding <=> p.embedding) AS cosine_similarity,
    left(sc.text, 200)                  AS preview
FROM semantic_chunks sc, probe p
ORDER BY sc.embedding <=> p.embedding
LIMIT 20;


-- B3: Same as B2 but filtered to a single source
--     Useful for: "what did Claude say near this idea?"
--     Set :source to 'claude', 'copilot', 'gemini', 'claude-code', 'antigravity'
WITH probe AS (
    SELECT :probe_vector::vector AS embedding
)
SELECT
    sc.id,
    sc.project,
    sc.date,
    1 - (sc.embedding <=> p.embedding) AS cosine_similarity,
    left(sc.text, 200)                  AS preview
FROM semantic_chunks sc, probe p
WHERE sc.source = :source
ORDER BY sc.embedding <=> p.embedding
LIMIT 15;


-- ============================================================
-- C. CROSS-SOURCE CONNECTIONS
-- ============================================================

-- C1: For every chunk in source A, find its nearest neighbour in source B
--     Shows where conversations across systems converged on the same territory
--     Adjust :source_a and :source_b as needed
SELECT
    a.id            AS a_id,
    a.source        AS a_source,
    a.date          AS a_date,
    b.id            AS b_id,
    b.source        AS b_source,
    b.date          AS b_date,
    1 - (a.embedding <=> b.embedding) AS similarity,
    left(a.text, 100) AS a_preview,
    left(b.text, 100) AS b_preview
FROM semantic_chunks a
CROSS JOIN LATERAL (
    SELECT *
    FROM semantic_chunks b
    WHERE b.source = :source_b
    ORDER BY a.embedding <=> b.embedding
    LIMIT 1
) b
WHERE a.source = :source_a
  AND 1 - (a.embedding <=> b.embedding) > 0.75   -- similarity threshold
ORDER BY similarity DESC
LIMIT 50;


-- C2: High-similarity pairs across ALL source combinations
--     The full connection map — slow on large corpora, run with LIMIT
SELECT
    a.source    AS source_a,
    b.source    AS source_b,
    a.date      AS date_a,
    b.date      AS date_b,
    1 - (a.embedding <=> b.embedding) AS similarity,
    left(a.text, 80) AS preview_a,
    left(b.text, 80) AS preview_b
FROM semantic_chunks a
JOIN semantic_chunks b
    ON a.id < b.id                              -- avoid duplicates
    AND a.source != b.source                    -- cross-source only
    AND 1 - (a.embedding <=> b.embedding) > 0.80
ORDER BY similarity DESC
LIMIT 100;


-- C3: Connection density between source pairs
--     How strongly are two sources semantically coupled?
--     (average of top-1 similarities, source A -> source B)
WITH nearest AS (
    SELECT
        a.source                            AS src_a,
        b.source                            AS src_b,
        1 - (a.embedding <=> b.embedding)   AS sim
    FROM semantic_chunks a
    CROSS JOIN LATERAL (
        SELECT source, embedding
        FROM semantic_chunks b2
        WHERE b2.source != a.source
        ORDER BY a.embedding <=> b2.embedding
        LIMIT 1
    ) b
)
SELECT
    src_a,
    src_b,
    ROUND(AVG(sim)::numeric, 4)  AS avg_top1_similarity,
    COUNT(*)                      AS sample_size
FROM nearest
GROUP BY src_a, src_b
ORDER BY avg_top1_similarity DESC;


-- ============================================================
-- D. TEMPORAL / DRIFT
-- ============================================================

-- D1: Average embedding centroid per month per source
--     Use this to track conceptual drift over time
--     (centroid is the mean vector — requires pgvector avg() or manual)
SELECT
    source,
    to_char(date::date, 'YYYY-MM') AS month,
    COUNT(*)                        AS chunk_count,
    AVG(embedding)                  AS centroid   -- pgvector supports avg()
FROM semantic_chunks
GROUP BY source, month
ORDER BY source, month;


-- D2: Semantic distance between consecutive monthly centroids
--     How much did the conversation shift month to month?
WITH monthly_centroids AS (
    SELECT
        source,
        to_char(date::date, 'YYYY-MM') AS month,
        AVG(embedding)                  AS centroid
    FROM semantic_chunks
    GROUP BY source, month
),
lagged AS (
    SELECT
        source,
        month,
        centroid,
        LAG(centroid) OVER (PARTITION BY source ORDER BY month) AS prev_centroid
    FROM monthly_centroids
)
SELECT
    source,
    month,
    ROUND((1 - (centroid <=> prev_centroid))::numeric, 4) AS continuity,
    ROUND((centroid <=> prev_centroid)::numeric, 4)       AS drift
FROM lagged
WHERE prev_centroid IS NOT NULL
ORDER BY source, month;


-- D3: Find the chunk most representative of a given month
--     Closest to that month's centroid = "modal thought" of the period
WITH monthly_centroid AS (
    SELECT AVG(embedding) AS centroid
    FROM semantic_chunks
    WHERE source = :source
      AND to_char(date::date, 'YYYY-MM') = :month  -- e.g. '2026-03'
)
SELECT
    sc.id,
    sc.date,
    sc.project,
    1 - (sc.embedding <=> mc.centroid) AS centrality,
    left(sc.text, 250)                  AS text
FROM semantic_chunks sc, monthly_centroid mc
WHERE sc.source = :source
  AND to_char(sc.date::date, 'YYYY-MM') = :month
ORDER BY sc.embedding <=> mc.centroid
LIMIT 5;


-- ============================================================
-- E. CLUSTER / TOPOLOGY
-- ============================================================

-- E1: K-means style bucket assignment using project labels
--     Quick topology view without external clustering
SELECT
    project,
    source,
    COUNT(*)                                    AS size,
    AVG(embedding)                              AS centroid
FROM semantic_chunks
GROUP BY project, source
ORDER BY size DESC;


-- E2: Find chunks that are "bridges" — high similarity to multiple sources
--     These are the conceptual crossroads in the corpus
WITH cross_sim AS (
    SELECT
        a.id,
        a.source,
        a.text,
        COUNT(DISTINCT b.source)               AS distinct_sources_reached,
        AVG(1 - (a.embedding <=> b.embedding)) AS avg_cross_similarity
    FROM semantic_chunks a
    JOIN semantic_chunks b
        ON b.source != a.source
       AND 1 - (a.embedding <=> b.embedding) > 0.72
    GROUP BY a.id, a.source, a.text
)
SELECT
    id,
    source,
    distinct_sources_reached,
    ROUND(avg_cross_similarity::numeric, 4) AS avg_cross_sim,
    left(text, 200)                          AS preview
FROM cross_sim
WHERE distinct_sources_reached >= 2
ORDER BY distinct_sources_reached DESC, avg_cross_similarity DESC
LIMIT 30;


-- E3: "Orphan" chunks — low similarity to everything else
--     Outliers, one-off thoughts, potentially interesting anomalies
WITH avg_sim AS (
    SELECT
        a.id,
        a.source,
        AVG(1 - (a.embedding <=> b.embedding)) AS mean_similarity_to_corpus
    FROM semantic_chunks a
    JOIN semantic_chunks b ON a.id != b.id
    GROUP BY a.id, a.source
)
SELECT
    sc.id,
    sc.source,
    sc.date,
    ROUND(avg_sim.mean_similarity_to_corpus::numeric, 4) AS mean_sim,
    left(sc.text, 200) AS preview
FROM semantic_chunks sc
JOIN avg_sim ON sc.id = avg_sim.id
ORDER BY avg_sim.mean_similarity_to_corpus ASC
LIMIT 20;


-- ============================================================
-- NOTES
-- ============================================================
-- :probe_vector   — embed your query text externally (Python/Node),
--                   paste as '[f1, f2, ...]'::vector
-- :target_id      — chunk id (sha256 prefix from converter output)
-- :source         — 'claude' | 'copilot' | 'gemini' | 'claude-code' | 'antigravity'
-- :month          — 'YYYY-MM' string
-- :source_a / :source_b — any source pair for cross-source queries
--
-- Recommended index (if not already present):
--   CREATE INDEX ON semantic_chunks USING ivfflat (embedding vector_cosine_ops)
--   WITH (lists = 100);
-- ============================================================
