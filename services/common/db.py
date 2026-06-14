"""
Embedder-dimension startup gate (ADR-003 item 9).

The pgvector column's declared dimension MUST equal meridian.env EMBEDDING_DIM.
Services call `assert_embedding_dim()` at startup so the 768-vs-1536 class of
mismatch becomes a loud refusal to start, never silent data corruption — the
exact failure mode that wrecked v1's resonance corpus.

Run standalone as the dimension half of the health check:
    python -m services.common.db
"""
from __future__ import annotations

import asyncpg

from .config import Config, load_config


async def column_vector_dim(conn: asyncpg.Connection, table: str, column: str) -> int | None:
    """Declared dimension of a pgvector column, or None if absent / unspecified.

    pgvector stores the dimension directly in atttypmod (no VARHDRSZ offset),
    so atttypmod == the dimension for a `vector(N)` column; -1 means unbounded.
    """
    typmod = await conn.fetchval(
        """
        SELECT a.atttypmod
        FROM pg_attribute a
        JOIN pg_class     c ON c.oid = a.attrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'public'
          AND c.relname = $1
          AND a.attname = $2
          AND NOT a.attisdropped
        """,
        table, column,
    )
    if typmod is None or typmod < 0:
        return None
    return int(typmod)


async def assert_embedding_dim(
    conn: asyncpg.Connection,
    cfg: Config,
    table: str = "perceptual_events",
    column: str = "embedding",
) -> None:
    actual = await column_vector_dim(conn, table, column)
    host = cfg.database_url.rsplit("@", 1)[-1]
    if actual is None:
        raise RuntimeError(
            f"{table}.{column} not found or has no fixed dimension — has "
            f"schemas/ been applied to {host}? (run deploy/apply_migrations.sh)"
        )
    if actual != cfg.embedding_dim:
        raise RuntimeError(
            f"EMBEDDING_DIM mismatch: meridian.env says {cfg.embedding_dim}, but "
            f"{table}.{column} is vector({actual}). Refusing to start (ADR-003 item 9)."
        )


async def _main() -> None:
    cfg = load_config()
    conn = await asyncpg.connect(cfg.database_url)
    try:
        await assert_embedding_dim(conn, cfg)
        print(
            f"OK: perceptual_events.embedding is vector({cfg.embedding_dim}), "
            f"matches EMBEDDING_DIM."
        )
    finally:
        await conn.close()


if __name__ == "__main__":
    import asyncio

    asyncio.run(_main())
