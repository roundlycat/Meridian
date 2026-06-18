"""
Embedding producer — raw sensor_readings → perceptual_events (ADR-003 §2).

Fuses raw readings into perceptual events, renders a FACTUAL description, embeds it
with local Ollama (nomic-embed-text, 768-dim), and writes a perceptual_event —
which fires the relay's pg_notify. It asserts NOTHING beyond the embedding: no
label, no resonance. The promotion job earns motifs later; this just records what
was perceived.

THE SLICE-B LESSON, ENCODED HERE: v1's environmental motifs could never be earned
because the embedded text was only raw values ("temperature X, humidity Y") — the
perceptual distinctions were labels painted on afterward by Gemini, never in the
signal. So render_text below describes the measured state in FACTUAL, banded terms
(deterministic functions of the values — "humidity high", "VOC elevated", "low
light") so distinctions can cluster, WITHOUT inventing interpretive narratives
("warm body present"). Bands are facts about the number; narratives are claims.

Idempotent: each event's id is uuid5(node|domain|window_start), so re-processing a
window is ON CONFLICT DO NOTHING.

PER-NODE TODO: SENSOR_DOMAIN and the bands below are the only things that depend on
which sensors a node carries — fill them in when the first node's spine is final.

Run on Inferno (meridian db + Ollama):
    python -m services.embedder --since '2026-06-01' --until '2026-06-18'   # backfill a range
    python -m services.embedder --loop                                       # process closed windows live
"""
from __future__ import annotations

import argparse
import asyncio
import datetime as dt
import json
import logging
import uuid

import aiohttp
import asyncpg

from services.common import load_config
from services.common.db import assert_embedding_dim

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s: %(message)s")
log = logging.getLogger("embedder")

NS = uuid.UUID("6d0f1c1e-0000-4000-8000-000000000002")   # stable namespace for event ids

# --- PER-NODE: map a sensor to its perceptual domain (Canonical Sensor Spine) ---
SENSOR_DOMAIN = {
    "bme688": "environmental_field", "sht35": "environmental_field",
    "tsl2591": "environmental_field", "as7341": "environmental_field",
    "sgp40": "environmental_field", "sgp40-voc": "environmental_field",
    "icm-42688-p": "embodied_state", "ina219": "embodied_state",
    "ina226": "embodied_state", "thermistor": "embodied_state",
    "piezo": "relational_contact", "vcnl4040": "relational_contact", "fsr": "relational_contact",
    "camera": "high_bandwidth", "thermal": "high_bandwidth", "microphone": "high_bandwidth",
}
DEFAULT_DOMAIN = "environmental_field"


def _band(value, edges, names):
    """Deterministic factual band for a value (a fact about the number, not a claim)."""
    if value is None:
        return None
    for edge, name in zip(edges, names):
        if value < edge:
            return name
    return names[-1]


def render_text(domain: str, channels: dict) -> str:
    """Factual, banded description. Distinctions come from the measured state itself."""
    def g(k):
        return channels.get(k)

    if domain == "environmental_field":
        parts = ["Environmental field reading."]
        if (t := g("temperature")) is not None:
            parts.append(f"Temperature {t:.1f}C ({_band(t,[16,22,26],['cold','cool','warm','hot'])}).")
        if (h := g("humidity")) is not None:
            parts.append(f"Humidity {h:.0f}% ({_band(h,[35,60],['dry','comfortable','humid'])}).")
        if (p := g("pressure")) is not None:
            parts.append(f"Pressure {p:.0f} hPa.")
        if (v := g("voc_index")) is not None:
            parts.append(f"VOC index {v:.0f} ({_band(v,[100,250],['clean','moderate','elevated'])}).")
        if (lx := g("lux")) is not None:
            parts.append(f"Light {lx:.0f} lux ({_band(lx,[5,50,300],['dark','dim','indoor','bright'])}).")
        return " ".join(parts)

    if domain == "embodied_state":
        parts = ["Embodied state reading."]
        if (pw := g("power_mw")) is not None:
            parts.append(f"Power draw {pw:.0f} mW ({_band(pw,[1500,4000],['idle','active','peak'])}).")
        if (bt := g("board_temp_c")) is not None:
            parts.append(f"Board temperature {bt:.1f}C ({_band(bt,[45,65],['cool','warm','hot'])}).")
        if (cpu := g("cpu_load_pct")) is not None:
            parts.append(f"CPU load {cpu:.0f}% ({_band(cpu,[30,70],['low','moderate','high'])}).")
        if (a := g("acceleration_magnitude")) is not None:
            parts.append(f"Acceleration {a:.2f} g ({_band(a,[1.05,1.3],['still','moving','impact'])}).")
        return " ".join(parts)

    if domain == "relational_contact":
        parts = ["Relational contact reading."]
        if (prox := g("proximity_raw")) is not None:
            parts.append(f"Proximity {prox:.0f} mm ({_band(prox,[50,200],['contact','near','far'])}).")
        if (pz := g("piezo_amplitude")) is not None:
            parts.append(f"Piezo amplitude {pz:.2f}.")
        return " ".join(parts)

    # high_bandwidth + fallback: describe channels factually
    parts = [f"{domain} reading."]
    for k, v in sorted(channels.items()):
        parts.append(f"{k} {v:.3g}." if isinstance(v, (int, float)) else f"{k} {v}.")
    return " ".join(parts)


async def embed(session: aiohttp.ClientSession, cfg, text: str):
    async with session.post(cfg.ollama_embed_url, json={"model": cfg.embed_model, "prompt": text}) as r:
        r.raise_for_status()
        vec = (await r.json())["embedding"]
    if len(vec) != cfg.embedding_dim:
        raise ValueError(f"embedder returned {len(vec)} dims, expected {cfg.embedding_dim}")
    return "[" + ",".join(repr(float(x)) for x in vec) + "]"


WINDOW_SQL = """
    SELECT node_id,
           date_bin($1::interval, event_time, TIMESTAMPTZ 'epoch') AS w,
           sensor, channel, avg(value) AS v
    FROM sensor_readings
    WHERE event_time >= $2 AND event_time < $3 AND channel IS NOT NULL
    GROUP BY node_id, w, sensor, channel
    ORDER BY w
"""


async def process_range(conn, session, cfg, window: str, since, until) -> int:
    rows = await conn.fetch(WINDOW_SQL, window, since, until)
    # group rows -> {(node, domain, window): {channel: value}}
    groups: dict = {}
    for r in rows:
        domain = SENSOR_DOMAIN.get((r["sensor"] or "").lower(), DEFAULT_DOMAIN)
        key = (r["node_id"], domain, r["w"])
        groups.setdefault(key, {})[r["channel"]] = float(r["v"]) if r["v"] is not None else None

    written = 0
    for (node_id, domain, w), channels in groups.items():
        event_id = uuid.uuid5(NS, f"{node_id}|{domain}|{w.isoformat()}")
        text = render_text(domain, channels)
        snapshot = {"channels": channels, "window_start": w.isoformat(), "render": text}
        try:
            emb = await embed(session, cfg, text)
        except Exception as e:
            log.warning("embed failed for %s/%s @ %s: %s", node_id, domain, w, e)
            continue
        status = await conn.execute(
            """
            INSERT INTO perceptual_events (id, node_id, domain, feature_snapshot, embedding, event_time)
            VALUES ($1, $2, $3, $4::jsonb, $5::vector, $6)
            ON CONFLICT (id) DO NOTHING
            """,
            event_id, node_id, domain, json.dumps(snapshot), emb, w,
        )
        if status.endswith(" 1"):
            written += 1
    log.info("range %s..%s: %d windows, %d new perceptual_events", since, until, len(groups), written)
    return written


async def main(window_s: int, since, until, loop: bool) -> None:
    cfg = load_config()
    conn = await asyncpg.connect(cfg.database_url)
    await assert_embedding_dim(conn, cfg)        # refuse to start on a dim mismatch (ADR item 9)
    window = f"{window_s} seconds"
    try:
        async with aiohttp.ClientSession() as session:
            if loop:
                log.info("loop mode: processing each closed %ds window", window_s)
                while True:
                    now = await conn.fetchval("SELECT now()")
                    win_end = now - dt.timedelta(seconds=window_s)
                    win_start = win_end - dt.timedelta(seconds=window_s)
                    await process_range(conn, session, cfg, window, win_start, win_end)
                    await asyncio.sleep(window_s)
            else:
                await process_range(conn, session, cfg, window, since, until)
    finally:
        await conn.close()


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description="Embedding producer: readings -> perceptual_events")
    ap.add_argument("--window", type=int, default=60, help="fusion window in seconds (default 60)")
    ap.add_argument("--since", help="backfill start (ISO, e.g. 2026-06-01)")
    ap.add_argument("--until", help="backfill end (ISO)")
    ap.add_argument("--loop", action="store_true", help="run continuously over closed windows")
    args = ap.parse_args()
    if not args.loop and not (args.since and args.until):
        ap.error("provide --loop, or both --since and --until for a backfill range")
    s = dt.datetime.fromisoformat(args.since) if args.since else None
    u = dt.datetime.fromisoformat(args.until) if args.until else None
    asyncio.run(main(args.window, s, u, args.loop))
