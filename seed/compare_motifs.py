"""
seed/compare_motifs.py — the asserted-vs-earned diff (Slice B research deliverable).

Puts v1's *asserted* motifs (seed/export/motifs.jsonl.gz — the 31 v1 claimed at
ingestion time, with their nomic-768 centroids) side by side with v2's *earned*
motifs (the promotion job's output: clusters that recur across many days and hold
stable). For each asserted motif it asks: does a real perceptual cluster actually
sit near where v1 said one was?

  SUPPORTED   : an earned motif lies within --support-dist (cosine) of the asserted
                centroid → v1's claim has perceptual evidence.
  UNSUPPORTED : no earned motif nearby → v1 asserted a resonance the evidence does
                not back. These are the HUD hallucinations, named.
  NOVEL       : an earned motif with no asserted motif nearby → a recurring pattern
                v1 never named.

This is purely a report — it writes nothing.

Run on Inferno (meridian db + the seed files):
    python seed/compare_motifs.py
"""
from __future__ import annotations

import argparse
import gzip
import json
import logging
import os
import sys

import asyncpg
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from services.common import load_config  # noqa: E402

logging.basicConfig(level=logging.INFO, format="%(message)s")
log = logging.getLogger("compare")


def _normalize(m: np.ndarray) -> np.ndarray:
    n = np.linalg.norm(m, axis=1, keepdims=True)
    n[n == 0] = 1.0
    return m / n


def _parse_vec(text: str) -> np.ndarray:
    return np.fromstring(text[1:-1], sep=",", dtype=np.float32)


def _load_asserted(path: str):
    labels, vecs = [], []
    with gzip.open(path, "rt", encoding="utf-8") as fh:
        for line in fh:
            r = json.loads(line)
            emb = r.get("centroid_embedding")
            if not emb:
                continue
            labels.append(r.get("label") or "(unlabelled)")
            vecs.append(np.asarray(emb, dtype=np.float32))
    return labels, _normalize(np.array(vecs, dtype=np.float32))


async def _load_earned(conn):
    rows = await conn.fetch(
        """
        SELECT m.id, m.member_count, m.centroid::text AS c,
               mode() WITHIN GROUP (ORDER BY pe.feature_snapshot->>'_v1_event_label') AS top_label
        FROM motifs m
        JOIN motif_members mm ON mm.motif_id = m.id
        JOIN perceptual_events pe ON pe.id = mm.perceptual_event_id
        WHERE m.state = 'motif'
        GROUP BY m.id, m.member_count, m.centroid
        ORDER BY m.member_count DESC
        """
    )
    labels = [r["top_label"] or "(none)" for r in rows]
    counts = [r["member_count"] for r in rows]
    vecs = _normalize(np.array([_parse_vec(r["c"]) for r in rows], dtype=np.float32))
    return labels, counts, vecs


async def main(support_dist: float, export_dir: str) -> None:
    cfg = load_config()
    a_labels, a_vecs = _load_asserted(os.path.join(export_dir, "motifs.jsonl.gz"))
    conn = await asyncpg.connect(cfg.database_url)
    try:
        e_labels, e_counts, e_vecs = await _load_earned(conn)
    finally:
        await conn.close()

    log.info("\n=== asserted-vs-earned (support distance < %.2f cosine) ===", support_dist)
    log.info("v1 asserted motifs: %d    v2 earned motifs: %d\n", len(a_labels), len(e_labels))

    # asserted → nearest earned
    supported = unsupported = 0
    log.info("--- v1's asserted motifs: does the evidence back them? ---")
    dist_ae = 1.0 - a_vecs @ e_vecs.T if len(e_vecs) else np.ones((len(a_vecs), 1))
    for i, lab in enumerate(a_labels):
        j = int(dist_ae[i].argmin())
        d = float(dist_ae[i][j])
        if d < support_dist:
            supported += 1
            log.info("  SUPPORTED    %-22s  ~ earned '%s' (d=%.3f)", lab, e_labels[j], d)
        else:
            unsupported += 1
            log.info("  UNSUPPORTED  %-22s  (nearest earned d=%.3f) — no recurring evidence", lab, d)

    # earned → nearest asserted (novelty)
    novel = 0
    dist_ea = 1.0 - e_vecs @ a_vecs.T
    novel_rows = []
    for i in range(len(e_labels)):
        d = float(dist_ea[i].min())
        if d >= support_dist:
            novel += 1
            novel_rows.append((e_counts[i], e_labels[i], d))

    log.info("\n--- v2's earned motifs v1 never named (top 15 by evidence) ---")
    for cnt, lab, d in sorted(novel_rows, reverse=True)[:15]:
        log.info("  NOVEL  %-22s  %7d events  (nearest asserted d=%.3f)", lab, cnt, d)

    distinct_earned_labels = len(set(e_labels))
    log.info("\n=== SUMMARY ===")
    log.info("v1 asserted 31-ish; of %d with centroids: %d SUPPORTED, %d UNSUPPORTED (hallucinated)",
             len(a_labels), supported, unsupported)
    log.info("v2 earned %d motifs across %d distinct dominant v1-labels; %d NOVEL (v1 missed)",
             len(e_labels), distinct_earned_labels, novel)
    if distinct_earned_labels < len(e_labels) / 3:
        log.info("NOTE: %d earned motifs but only %d distinct labels — likely finer-grained "
                 "sub-clusters of fewer real states; raise HDBSCAN min_cluster_size or merge "
                 "nearby motifs to coarsen.", len(e_labels), distinct_earned_labels)


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description="Compare v1 asserted vs v2 earned motifs")
    ap.add_argument("--support-dist", type=float, default=0.20,
                    help="max cosine distance for an asserted motif to count as evidence-backed")
    ap.add_argument("--export-dir", default="seed/export")
    args = ap.parse_args()
    import asyncio
    asyncio.run(main(args.support_dist, args.export_dir))
