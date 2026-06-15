"""Shared service code: single-source config (+ the dim gate, imported on demand).

NOTE: db.py (the embedder-dimension gate) is deliberately NOT imported here — it
pulls in asyncpg, which DB-free edge services (the Pi spool) must not require.
Services that need it import explicitly: `from services.common.db import assert_embedding_dim`.
"""

from .config import Config, load_config

__all__ = ["Config", "load_config"]
