"""
Promotion job — earn motifs from evidence, off the hot path (ADR-003 §2, item 4).

Clusters the perceptual_events embeddings, applies four gates, and promotes only
clusters that EARN motif status — each transition recorded with the evidence
snapshot that justified it. Nothing is asserted; structure is measured.

Gates (thresholds from meridian.env):
  members    : >= PROMOTION_MIN_MEMBERS distinct events
  span       : evidence spans >= PROMOTION_MIN_SPAN_HOURS  (one afternoon can't be a motif)
  sources    : >= PROMOTION_MIN_SOURCES distinct nodes-or-domains
  stability  : centroid moved < PROMOTION_STABILITY_EPSILON (cosine) since last run
               — so a candidate must persist across two runs to promote. Time-delayed
               by design; on a static replay corpus, run TWICE (run 1 seeds candidates
               + their centroids, run 2 confirms stability and promotes).

Identity is content-derived (hash of the creation centroid) and re-runs match an
existing motif by nearest centroid, so the job converges instead of minting dupes.

Scale: 768-dim clustering runs on a sample of up to --cluster-sample events
(default 40000) for tractability; ALL events are then assigned to the nearest
cluster centroid within --assign-dist, and every gate is measured over the FULL
membership. The sample size is logged — no silent caps.

Run on Inferno (meridian db + the loaded corpus):
    python -m services.promotion
"""
from __future__ import annotations

import argparse
import asyncio
import hashlib
import json
import logging

import asyncpg
import numpy as np
from sklearn.cluster import HDBSCAN

from services.common import load_config

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s: %(message)s")
log = logging.getLogger("promotion")

MATCH_DIST = 0.10        # cosine distance within which a cluster == an existing motif
RNG_SEED = 42            # reproducible sampling → reproducible runs (helps the stability gate)


def _parse_vec(text: str) -> np.ndarray:
    return np.fromstring(text[1:-1], sep=",", dtype=np.float32)


def _normalize(m: np.ndarray) -> np.ndarray:
    n = np.linalg.norm(m, axis=1, keepdims=True)
    n[n == 0] = 1.0
    return m / n


def _content_key(centroid: np.ndarray) -> str:
    return hashlib.sha1(np.round(centroid, 2).tobytes()).hexdigest()[:16]


def _vec_literal(v: np.ndarray) -> str:
    return "[" + ",".join(repr(float(x)) for x in v) + "]"


async def _load_events(conn):
    n = await conn.fetchval("SELECT count(*) FROM perceptual_events WHERE embedding IS NOT NULL")
    vecs = np.empty((n, 768), dtype=np.float32)
    ids, nodes, domains, times = [], [], [], []
    i = 0
    async with conn.transaction():
        async for r in conn.cursor(
            "SELECT id, node_id, domain, event_time, embedding::text AS emb "
            "FROM perceptual_events WHERE embedding IS NOT NULL ORDER BY id",
            prefetch=2000,
        ):
            vecs[i] = _parse_vec(r["emb"])
            ids.append(r["id"]); nodes.append(r["node_id"])
            domains.append(r["domain"]); times.append(r["event_time"])
            i += 1
    log.info("loaded %d event embeddings", n)
    return ids, nodes, domains, times, _normalize(vecs)


def _cluster(vecs: np.ndarray, min_members: int, sample_cap: int):
    n = len(vecs)
    rng = np.random.default_rng(RNG_SEED)
    if n > sample_cap:
        sample_idx = rng.choice(n, sample_cap, replace=False)
        log.info("clustering on a %d-event sample of %d (tractability cap)", sample_cap, n)
    else:
        sample_idx = np.arange(n)
        log.info("clustering on all %d events", n)
    labels = HDBSCAN(min_cluster_size=min_members, metric="euclidean").fit_predict(vecs[sample_idx])

    centroids = []
    for lab in sorted(set(labels) - {-1}):
        c = vecs[sample_idx][labels == lab].mean(axis=0)
        centroids.append(c / (np.linalg.norm(c) or 1.0))
    log.info("HDBSCAN found %d clusters (%d sample points were noise)",
             len(centroids), int((labels == -1).sum()))
    return np.array(centroids, dtype=np.float32) if centroids else np.empty((0, 768), np.float32)


async def _existing_motifs(conn):
    rows = await conn.fetch("SELECT id, content_key, state, centroid::text AS c FROM motifs")
    return [{"id": r["id"], "content_key": r["content_key"], "state": r["state"],
             "centroid": _parse_vec(r["c"])} for r in rows]


async def main(sample_cap: int, assign_dist: float) -> None:
    cfg = load_config()
    conn = await asyncpg.connect(cfg.database_url)
    try:
        ids, nodes, domains, times, vecs = await _load_events(conn)
        centroids = _cluster(vecs, cfg.promotion_min_members, sample_cap)
        if len(centroids) == 0:
            log.warning("no clusters formed; nothing to promote")
            return

        # Assign every event to its nearest cluster centroid within the distance cap.
        sims = vecs @ centroids.T                       # cosine (both normalized)
        best = sims.argmax(axis=1)
        best_sim = sims.max(axis=1)
        assigned = np.where(best_sim >= (1.0 - assign_dist), best, -1)
        log.info("assigned %d/%d events to a cluster (%d beyond --assign-dist=%.2f)",
                 int((assigned >= 0).sum()), len(ids), int((assigned < 0).sum()), assign_dist)

        existing = await _existing_motifs(conn)
        ex_centroids = (_normalize(np.array([m["centroid"] for m in existing], dtype=np.float32))
                        if existing else np.empty((0, 768), np.float32))
        matched_ids = set()
        promoted = candidates = 0

        for c in range(len(centroids)):
            members = np.where(assigned == c)[0]
            if len(members) < cfg.promotion_min_members:
                continue
            full_centroid = vecs[members].mean(axis=0)
            full_centroid /= (np.linalg.norm(full_centroid) or 1.0)

            node_set = {nodes[j] for j in members if nodes[j] is not None}
            domain_set = {domains[j] for j in members if domains[j] is not None}
            source_count = max(len(node_set), len(domain_set))
            mtimes = [times[j] for j in members if times[j] is not None]
            span_h = ((max(mtimes) - min(mtimes)).total_seconds() / 3600.0) if mtimes else 0.0

            members_ok = len(members) >= cfg.promotion_min_members
            span_ok = span_h >= cfg.promotion_min_span_hours
            sources_ok = source_count >= cfg.promotion_min_sources

            # Identity / stability: nearest existing motif within MATCH_DIST is "the same".
            match, drift = None, None
            if len(ex_centroids):
                d = 1.0 - ex_centroids @ full_centroid
                j = int(d.argmin())
                if d[j] <= MATCH_DIST:
                    match = existing[j]
                    drift = float(d[j])
            stability_ok = match is not None and drift < cfg.promotion_stability_epsilon

            gates_pass = members_ok and span_ok and sources_ok
            to_state = "motif" if (gates_pass and stability_ok) else "candidate"

            evidence = {
                "members": int(len(members)), "min_members": cfg.promotion_min_members,
                "span_hours": round(span_h, 1), "min_span_hours": cfg.promotion_min_span_hours,
                "sources": source_count, "min_sources": cfg.promotion_min_sources,
                "drift": (round(drift, 4) if drift is not None else None),
                "stability_epsilon": cfg.promotion_stability_epsilon,
                "gates": {"members": members_ok, "span": span_ok,
                          "sources": sources_ok, "stability": stability_ok},
            }

            async with conn.transaction():
                if match:
                    motif_id = match["id"]; from_state = match["state"]
                    matched_ids.add(motif_id)
                    await conn.execute(
                        "UPDATE motifs SET state=$2, centroid=$3::vector, member_count=$4, "
                        "source_count=$5, first_evidence_at=$6, last_evidence_at=$7, updated_at=now() "
                        "WHERE id=$1",
                        motif_id, to_state, _vec_literal(full_centroid), len(members),
                        source_count, (min(mtimes) if mtimes else None), (max(mtimes) if mtimes else None),
                    )
                else:
                    from_state = None
                    motif_id = await conn.fetchval(
                        "INSERT INTO motifs (content_key, state, centroid, member_count, source_count, "
                        "first_evidence_at, last_evidence_at) "
                        "VALUES ($1,$2,$3::vector,$4,$5,$6,$7) "
                        "ON CONFLICT (content_key) DO UPDATE SET state=EXCLUDED.state, "
                        "centroid=EXCLUDED.centroid, member_count=EXCLUDED.member_count, "
                        "source_count=EXCLUDED.source_count, updated_at=now() RETURNING id",
                        _content_key(full_centroid), to_state, _vec_literal(full_centroid),
                        len(members), source_count,
                        (min(mtimes) if mtimes else None), (max(mtimes) if mtimes else None),
                    )
                    matched_ids.add(motif_id)

                # Refresh membership (idempotent) and record the transition if state changed.
                await conn.execute("DELETE FROM motif_members WHERE motif_id=$1", motif_id)
                await conn.executemany(
                    "INSERT INTO motif_members (motif_id, perceptual_event_id) VALUES ($1,$2) "
                    "ON CONFLICT DO NOTHING",
                    [(motif_id, ids[j]) for j in members],
                )
                if from_state != to_state:
                    await conn.execute(
                        "INSERT INTO motif_transitions (motif_id, from_state, to_state, reason, evidence) "
                        "VALUES ($1,$2,$3,$4,$5::jsonb)",
                        motif_id, from_state, to_state,
                        ("gates_passed" if to_state == "motif" else "candidate_seeded"),
                        json.dumps(evidence),
                    )

            if to_state == "motif":
                promoted += 1
            else:
                candidates += 1

        # Demote any existing motif this run didn't see evidence for — never delete it.
        dormant = 0
        for m in existing:
            if m["id"] not in matched_ids and m["state"] != "dormant":
                async with conn.transaction():
                    await conn.execute("UPDATE motifs SET state='dormant', updated_at=now() WHERE id=$1", m["id"])
                    await conn.execute(
                        "INSERT INTO motif_transitions (motif_id, from_state, to_state, reason) "
                        "VALUES ($1,$2,'dormant','no_evidence_this_run')",
                        m["id"], m["state"],
                    )
                dormant += 1

        await conn.execute("REFRESH MATERIALIZED VIEW CONCURRENTLY motif_graph_stats")
        log.info("DONE. clusters=%d  promoted(motif)=%d  candidates=%d  demoted(dormant)=%d",
                 len(centroids), promoted, candidates, dormant)
        if promoted == 0:
            log.info("0 promoted — expected on the FIRST run (stability needs a 2nd run). Re-run to promote.")
    finally:
        await conn.close()


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description="Promotion job — earn motifs from evidence")
    ap.add_argument("--cluster-sample", type=int, default=40000,
                    help="max events to cluster directly (rest assigned to nearest); default 40000")
    ap.add_argument("--assign-dist", type=float, default=0.15,
                    help="max cosine distance to assign an event to a cluster; default 0.15")
    args = ap.parse_args()
    asyncio.run(main(args.cluster_sample, args.assign_dist))
