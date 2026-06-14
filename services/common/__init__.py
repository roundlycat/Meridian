"""Shared service code: single-source config + the embedder-dimension gate."""

from .config import Config, load_config
from .db import assert_embedding_dim, column_vector_dim

__all__ = ["Config", "load_config", "assert_embedding_dim", "column_vector_dim"]
