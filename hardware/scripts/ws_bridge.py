"""
ws_bridge.py — Sensor Ecology WebSocket Bridge
================================================
Bridges MQTT telemetry → WebSocket for the AR web app.

Endpoints:
  GET  /ws/device/{device_id}   — stream telemetry for a specific device
  GET  /ws/bench                — stream all currently detected bench devices
  GET  /api/registry            — list all registered devices
  GET  /api/registry/{id}       — get a single device record
  GET  /api/registry/resolve    — resolve a Gemini CV label to a device_id
  GET  /health                  — service health check

Run:
  uvicorn ws_bridge:app --host 0.0.0.0 --port 8765 --reload

Environment variables (or set in systemd service):
  DATABASE_URL   postgresql://sean:ecology@192.168.0.28/sensor_ecology
  MQTT_HOST      192.168.0.25  (sensor Pi)
  MQTT_PORT      1883
"""

import asyncio
import json
import logging
import os
from contextlib import asynccontextmanager
from datetime import datetime, timezone
from typing import Optional

import asyncpg
import aiomqtt
from fastapi import FastAPI, WebSocket, WebSocketDisconnect, HTTPException
from fastapi.middleware.cors import CORSMiddleware

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

DATABASE_URL = os.environ.get(
    "DATABASE_URL",
    "postgresql://sean:ecology@192.168.0.28/sensor_ecology"
)
MQTT_HOST = os.environ.get("MQTT_HOST", "192.168.0.25")
MQTT_PORT = int(os.environ.get("MQTT_PORT", "1883"))

logging.basicConfig(level=logging.INFO,
                    format="%(asctime)s %(levelname)s %(name)s: %(message)s")
logger = logging.getLogger("ws_bridge")

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

# device_id → [WebSocket, ...]
_subscriptions: dict[str, list[WebSocket]] = {}

# bench topic → [WebSocket, ...]  (wildcard subscribers)
_bench_subscribers: list[WebSocket] = []

# device_id → latest telemetry payload
_latest: dict[str, dict] = {}

# db pool
_pool: Optional[asyncpg.Pool] = None

# topic → device_id cache (refreshed from registry)
_topic_map: dict[str, str] = {}

# device_id → thresholds cache
_threshold_cache: dict[str, dict] = {}


# ---------------------------------------------------------------------------
# Database helpers
# ---------------------------------------------------------------------------

async def get_pool() -> asyncpg.Pool:
    global _pool
    if _pool is None:
        _pool = await asyncpg.create_pool(
            DATABASE_URL,
            min_size=2,
            max_size=10,
            max_inactive_connection_lifetime=300
        )
    return _pool


async def load_registry_cache():
    """Load topic→device_id and threshold maps from device_registry."""
    global _topic_map, _threshold_cache
    pool = await get_pool()
    async with pool.acquire() as conn:
        rows = await conn.fetch(
            "SELECT id, mqtt_topics, thresholds FROM device_registry"
        )
    topic_map = {}
    threshold_cache = {}
    for row in rows:
        device_id = row["id"]
        topics = row["mqtt_topics"] or {}
        if isinstance(topics, str):
            topics = json.loads(topics)
        for topic in topics.values():
            if topic:
                topic_map[topic] = device_id
        thresholds = row["thresholds"] or {}
        if isinstance(thresholds, str):
            thresholds = json.loads(thresholds)
        threshold_cache[device_id] = thresholds

    _topic_map = topic_map
    _threshold_cache = threshold_cache
    logger.info("Registry cache loaded: %d topics, %d devices",
                len(_topic_map), len(_threshold_cache))


async def get_device(device_id: str) -> Optional[dict]:
    """Fetch a single device record from the registry."""
    pool = await get_pool()
    async with pool.acquire() as conn:
        row = await conn.fetchrow(
            "SELECT * FROM device_registry WHERE id = $1", device_id
        )
    if not row:
        return None
    d = dict(row)
    # Parse JSONB fields
    for field in ("mqtt_topics", "thresholds", "pinout"):
        if isinstance(d.get(field), str):
            d[field] = json.loads(d[field])
    d["created_at"] = d["created_at"].isoformat() if d.get("created_at") else None
    return d


async def resolve_cv_label(label: str) -> Optional[dict]:
    """Resolve a Gemini CV label to a device registry record."""
    pool = await get_pool()
    async with pool.acquire() as conn:
        row = await conn.fetchrow(
            "SELECT * FROM device_registry WHERE $1 = ANY(cv_labels)",
            label
        )
    if not row:
        return None
    d = dict(row)
    for field in ("mqtt_topics", "thresholds", "pinout"):
        if isinstance(d.get(field), str):
            d[field] = json.loads(d[field])
    d["created_at"] = d["created_at"].isoformat() if d.get("created_at") else None
    return d


async def get_recent_observations(device_id: str, limit: int = 5) -> list[dict]:
    """Fetch recent observations for a device."""
    pool = await get_pool()
    async with pool.acquire() as conn:
        rows = await conn.fetch(
            """SELECT level, message, source, observed_at
               FROM device_observations
               WHERE device_id = $1
               ORDER BY observed_at DESC
               LIMIT $2""",
            device_id, limit
        )
    return [
        {**dict(r), "observed_at": r["observed_at"].isoformat()}
        for r in rows
    ]


async def write_observation(device_id: str, level: str,
                             message: str, source: str):
    """Persist an anomaly observation."""
    pool = await get_pool()
    async with pool.acquire() as conn:
        await conn.execute(
            """INSERT INTO device_observations (device_id, level, message, source)
               VALUES ($1, $2, $3, $4)""",
            device_id, level, message, source
        )


# ---------------------------------------------------------------------------
# Anomaly enrichment
# ---------------------------------------------------------------------------

def enrich_with_anomalies(device_id: str, payload: dict) -> dict:
    """
    Compare payload values against device thresholds.
    Attaches an 'anomalies' list to the payload.
    """
    thresholds = _threshold_cache.get(device_id, {})
    anomalies = []

    for metric, value in payload.items():
        if not isinstance(value, (int, float)):
            continue
        t = thresholds.get(metric, {})
        if not t:
            continue

        if "critical" in t and value >= t["critical"]:
            anomalies.append({
                "metric": metric,
                "level": "critical",
                "value": value,
                "threshold": t["critical"],
                "message": f"{metric} critically high: {value}"
            })
        elif "warn" in t and value >= t["warn"]:
            anomalies.append({
                "metric": metric,
                "level": "warn",
                "value": value,
                "threshold": t["warn"],
                "message": f"{metric} elevated: {value}"
            })
        elif "warn_low" in t and value < t["warn_low"]:
            anomalies.append({
                "metric": metric,
                "level": "warn",
                "value": value,
                "threshold": t["warn_low"],
                "message": f"{metric} unexpectedly low: {value}"
            })

    return {**payload, "anomalies": anomalies}


# ---------------------------------------------------------------------------
# Broadcast helpers
# ---------------------------------------------------------------------------

async def broadcast_to_device(device_id: str, message: dict):
    """Send a message to all WebSocket subscribers for a device."""
    subscribers = _subscriptions.get(device_id, [])
    dead = []
    for ws in subscribers:
        try:
            await ws.send_json(message)
        except Exception:
            dead.append(ws)
    for ws in dead:
        subscribers.remove(ws)


async def broadcast_to_bench(message: dict):
    """Send a message to all bench wildcard subscribers."""
    dead = []
    for ws in _bench_subscribers:
        try:
            await ws.send_json(message)
        except Exception:
            dead.append(ws)
    for ws in dead:
        _bench_subscribers.remove(ws)


# ---------------------------------------------------------------------------
# MQTT relay task
# ---------------------------------------------------------------------------

async def mqtt_relay():
    """
    Subscribe to all sensor topics and relay to WebSocket subscribers.
    Reconnects automatically on disconnect.
    """
    while True:
        try:
            async with aiomqtt.Client(
                hostname=MQTT_HOST,
                port=MQTT_PORT,
                keepalive=60
            ) as client:
                logger.info("MQTT connected to %s:%d", MQTT_HOST, MQTT_PORT)

                # Subscribe to all sensor and bench topics
                await client.subscribe("sensors/#")
                await client.subscribe("bench/detected_components")
                await client.subscribe("thermal/#")

                async for message in client.messages:
                    topic = str(message.topic)
                    try:
                        payload = json.loads(message.payload.decode())
                    except (json.JSONDecodeError, UnicodeDecodeError):
                        continue

                    # Bench detection events → bench subscribers
                    if topic == "bench/detected_components":
                        await broadcast_to_bench({
                            "type": "bench_scan",
                            "topic": topic,
                            "data": payload,
                            "timestamp": datetime.now(timezone.utc).isoformat()
                        })
                        continue

                    # Resolve topic to device_id
                    device_id = _topic_map.get(topic)
                    if not device_id:
                        continue

                    # Enrich with anomaly detection
                    enriched = enrich_with_anomalies(device_id, payload)
                    _latest[device_id] = enriched

                    # Persist critical anomalies
                    for anomaly in enriched.get("anomalies", []):
                        if anomaly["level"] == "critical":
                            asyncio.create_task(write_observation(
                                device_id,
                                "critical",
                                anomaly["message"],
                                "threshold"
                            ))

                    msg = {
                        "type": "telemetry",
                        "device_id": device_id,
                        "topic": topic,
                        "data": enriched,
                        "timestamp": datetime.now(timezone.utc).isoformat()
                    }

                    await broadcast_to_device(device_id, msg)
                    await broadcast_to_bench(msg)

        except aiomqtt.MqttError as e:
            logger.warning("MQTT error: %s — reconnecting in 5s", e)
            await asyncio.sleep(5)
        except Exception as e:
            logger.error("MQTT relay error: %s — reconnecting in 10s", e)
            await asyncio.sleep(10)


# ---------------------------------------------------------------------------
# App lifecycle
# ---------------------------------------------------------------------------

@asynccontextmanager
async def lifespan(app: FastAPI):
    await get_pool()
    await load_registry_cache()
    asyncio.create_task(mqtt_relay())

    # Refresh registry cache every 5 minutes
    async def refresh_loop():
        while True:
            await asyncio.sleep(300)
            await load_registry_cache()
    asyncio.create_task(refresh_loop())

    logger.info("ws_bridge started")
    yield
    if _pool:
        await _pool.close()
    logger.info("ws_bridge stopped")


# ---------------------------------------------------------------------------
# FastAPI app
# ---------------------------------------------------------------------------

app = FastAPI(title="Sensor Ecology WebSocket Bridge", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],   # tighten for production
    allow_methods=["*"],
    allow_headers=["*"],
)


# ---------------------------------------------------------------------------
# WebSocket endpoints
# ---------------------------------------------------------------------------

@app.websocket("/ws/device/{device_id}")
async def device_stream(websocket: WebSocket, device_id: str):
    """
    Stream live telemetry for a specific device.
    Sends device_info immediately on connect, then telemetry as it arrives.
    """
    device = await get_device(device_id)
    if not device:
        await websocket.close(code=4004, reason=f"Device {device_id} not found")
        return

    await websocket.accept()
    _subscriptions.setdefault(device_id, []).append(websocket)
    logger.info("WS client connected to device: %s", device_id)

    try:
        # Send device info + latest telemetry immediately
        await websocket.send_json({
            "type": "device_info",
            "device": device,
            "latest": _latest.get(device_id),
            "recent_observations": await get_recent_observations(device_id)
        })

        # Keep alive — client can send pings
        while True:
            data = await websocket.receive_text()
            if data == "ping":
                await websocket.send_json({"type": "pong"})

    except WebSocketDisconnect:
        logger.info("WS client disconnected from device: %s", device_id)
    finally:
        subs = _subscriptions.get(device_id, [])
        if websocket in subs:
            subs.remove(websocket)


@app.websocket("/ws/bench")
async def bench_stream(websocket: WebSocket):
    """
    Stream all bench activity — component detections and all device telemetry.
    Used by the AR app for the global ecology view.
    """
    await websocket.accept()
    _bench_subscribers.append(websocket)
    logger.info("WS client connected to bench stream")

    try:
        await websocket.send_json({
            "type": "bench_state",
            "active_devices": list(_latest.keys()),
            "latest": _latest
        })

        while True:
            data = await websocket.receive_text()
            if data == "ping":
                await websocket.send_json({"type": "pong"})

    except WebSocketDisconnect:
        logger.info("WS client disconnected from bench stream")
    finally:
        if websocket in _bench_subscribers:
            _bench_subscribers.remove(websocket)


# ---------------------------------------------------------------------------
# REST endpoints
# ---------------------------------------------------------------------------

@app.get("/health")
async def health():
    return {
        "status": "ok",
        "mqtt_host": MQTT_HOST,
        "active_devices": list(_latest.keys()),
        "subscriber_count": sum(len(v) for v in _subscriptions.values()),
        "bench_subscribers": len(_bench_subscribers)
    }


@app.get("/api/registry")
async def list_registry():
    pool = await get_pool()
    async with pool.acquire() as conn:
        rows = await conn.fetch(
            "SELECT id, display_name, device_type, location, cv_labels "
            "FROM device_registry ORDER BY device_type"
        )
    return [dict(r) for r in rows]


@app.get("/api/registry/resolve")
async def resolve_label(label: str):
    """
    Resolve a Gemini CV label to a device registry record.
    Called by AR app after Gemini identifies a component.

    Example: GET /api/registry/resolve?label=ESP32+Development+Board
    """
    device = await resolve_cv_label(label)
    if not device:
        return {"device_id": None, "matched": False, "label": label}
    return {"device_id": device["id"], "matched": True, "device": device}


@app.get("/api/registry/{device_id}")
async def get_registry_entry(device_id: str):
    device = await get_device(device_id)
    if not device:
        raise HTTPException(status_code=404, detail=f"Device {device_id} not found")
    device["latest_telemetry"] = _latest.get(device_id)
    device["recent_observations"] = await get_recent_observations(device_id)
    return device


@app.post("/api/registry/{device_id}/observe")
async def post_observation(device_id: str, body: dict):
    """
    Manually record an observation for a device.
    Used by Gemini when it detects a visual anomaly (loose wire, missing component, etc.)
    """
    device = await get_device(device_id)
    if not device:
        raise HTTPException(status_code=404, detail=f"Device {device_id} not found")
    await write_observation(
        device_id,
        body.get("level", "info"),
        body.get("message", ""),
        body.get("source", "gemini")
    )
    return {"status": "recorded"}


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8765)
