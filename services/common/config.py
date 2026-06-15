"""
Single-source configuration (ADR-003 §0).

Every Meridian service reads configuration from ONE file. Search order:
    1. $MERIDIAN_ENV                      (explicit override)
    2. /etc/meridian/meridian.env         (the deployed location)
    3. <repo>/deploy/meridian.env         (local dev convenience)
The first file found wins. Real process environment variables override file
values, which keeps tests and one-off invocations honest without editing files.

No third-party dependency: the env-file parser is a few lines so this module
imports cleanly anywhere asyncpg already runs.
"""
from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path

# Keys a service may set/override via the real environment.
_KNOWN_KEYS = (
    "DATABASE_URL", "EMBED_MODEL", "EMBEDDING_DIM", "OLLAMA_EMBED_URL",
    "MQTT_HOST", "MQTT_PORT", "RELAY_HOST", "RELAY_PORT", "NOTIFY_CHANNEL",
    "RAW_RETENTION_DAYS",
    "SPOOL_LOCAL_MQTT_HOST", "SPOOL_LOCAL_MQTT_PORT", "SPOOL_DB_PATH",
)


def _candidate_paths() -> list[Path]:
    cands: list[str | None] = [
        os.environ.get("MERIDIAN_ENV"),
        "/etc/meridian/meridian.env",
        str(Path(__file__).resolve().parents[2] / "deploy" / "meridian.env"),
    ]
    return [Path(c) for c in cands if c]


def _parse_env_file(path: Path) -> dict[str, str]:
    out: dict[str, str] = {}
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, val = line.partition("=")
        out[key.strip()] = val.strip()
    return out


def _load_raw() -> dict[str, str]:
    merged: dict[str, str] = {}
    for path in _candidate_paths():
        if path.is_file():
            merged.update(_parse_env_file(path))
            break
    for key in _KNOWN_KEYS:                       # process env overrides the file
        if key in os.environ:
            merged[key] = os.environ[key]
    return merged


@dataclass(frozen=True)
class Config:
    database_url: str
    embed_model: str
    embedding_dim: int
    ollama_embed_url: str
    mqtt_host: str
    mqtt_port: int
    relay_host: str
    relay_port: int
    notify_channel: str
    raw_retention_days: int
    # Spool tier (Sensor Pi). Subscribes to the LOCAL broker, forwards UPSTREAM
    # to the central broker (mqtt_host/mqtt_port above).
    spool_local_mqtt_host: str
    spool_local_mqtt_port: int
    spool_db_path: str


def load_config() -> Config:
    raw = _load_raw()

    def required(key: str) -> str:
        try:
            return raw[key]
        except KeyError:
            raise KeyError(
                f"missing required config key {key!r}; set it in meridian.env "
                f"(searched: {[str(p) for p in _candidate_paths()]})"
            ) from None

    return Config(
        database_url=required("DATABASE_URL"),
        embed_model=raw.get("EMBED_MODEL", "nomic-embed-text"),
        embedding_dim=int(raw.get("EMBEDDING_DIM", "768")),
        ollama_embed_url=raw.get("OLLAMA_EMBED_URL", "http://localhost:11434/api/embeddings"),
        mqtt_host=raw.get("MQTT_HOST", "localhost"),
        mqtt_port=int(raw.get("MQTT_PORT", "1883")),
        relay_host=raw.get("RELAY_HOST", "0.0.0.0"),
        relay_port=int(raw.get("RELAY_PORT", "8765")),
        notify_channel=raw.get("NOTIFY_CHANNEL", "perceptual_events"),
        raw_retention_days=int(raw.get("RAW_RETENTION_DAYS", "90")),
        spool_local_mqtt_host=raw.get("SPOOL_LOCAL_MQTT_HOST", "localhost"),
        spool_local_mqtt_port=int(raw.get("SPOOL_LOCAL_MQTT_PORT", "1883")),
        spool_db_path=raw.get("SPOOL_DB_PATH", "/var/lib/meridian/spool.db"),
    )
