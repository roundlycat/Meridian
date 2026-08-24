#!/usr/bin/env python3
"""
Parts Catalogue Query Tool
==========================
Semantic search over the local parts catalogue.

Usage:
    python3 parts_query.py "IR obstacle sensor"
    python3 parts_query.py "voltage comparator with potentiometer"
    python3 parts_query.py --list
"""

import sys
import psycopg2
from sentence_transformers import SentenceTransformer

DB_DSN = (
    "host=localhost "
    "dbname=sensor_ecology "
    "user=sean "
    "password=ecology"
)

EMBED_MODEL = "BAAI/bge-large-en-v1.5"
TOP_K       = 5

embedder = SentenceTransformer(EMBED_MODEL)


def search(query: str, top_k: int = TOP_K):
    vec = embedder.encode(query, normalize_embeddings=True).tolist()
    conn = psycopg2.connect(DB_DSN)
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT
                    id,
                    image_filename,
                    component_model,
                    summary,
                    ingested_at,
                    1 - (embedding <=> %s::vector) AS similarity
                FROM parts_catalogue
                ORDER BY embedding <=> %s::vector
                LIMIT %s
                """,
                (vec, vec, top_k)
            )
            rows = cur.fetchall()
    finally:
        conn.close()
    return rows


def list_all():
    conn = psycopg2.connect(DB_DSN)
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT id, image_filename, component_model, ingested_at
                FROM parts_catalogue
                ORDER BY ingested_at DESC
                """
            )
            return cur.fetchall()
    finally:
        conn.close()


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: parts_query.py <search terms>  |  parts_query.py --list")
        sys.exit(1)

    if sys.argv[1] == "--list":
        rows = list_all()
        print(f"\n{'ID':<5} {'Ingested':<22} {'Filename':<45} Component")
        print("─" * 100)
        for r in rows:
            print(f"{r[0]:<5} {str(r[3])[:19]:<22} {r[1]:<45} {(r[2] or 'unparsed')[:50]}")
        print(f"\n{len(rows)} parts in catalogue")
    else:
        query = " ".join(sys.argv[1:])
        print(f"\nSearching for: {query}\n")
        results = search(query)
        for i, (pid, fname, model, summary, ts, sim) in enumerate(results, 1):
            print(f"[{i}] similarity={sim:.3f}  id={pid}")
            print(f"    File     : {fname}")
            print(f"    Component: {model or 'unparsed'}")
            print(f"    Summary  : {(summary or '')[:120]}")
            print()
