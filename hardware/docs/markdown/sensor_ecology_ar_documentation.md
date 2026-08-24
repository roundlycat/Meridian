# Sensor Ecology AR System — Build Documentation
**Date:** Sunday, March 8, 2026  
**Status:** Fully operational

---

## What Was Built

A live AR guidance system that reads physical sensor ecology state and overlays it on camera view. Three AI systems collaborate: Gemini Vision (component identification), Llama3.2 (ecological narrative and diagnostic language), and the sensor ecology ingestion pipeline (perceptual event classification). The result is a system that can identify hardware on a workbench, retrieve its live telemetry, detect anomalies against registered thresholds, and generate grounded diagnostic guidance — all rendered as a camera overlay on a tablet.

---

## Architecture

```
Sensor Pi (192.168.0.25)
  ├── Mosquitto MQTT broker :1883
  ├── sensor-ingestion.service → perceptual_embedding_pipeline.py
  │     └── writes perceptual_events → Inferno PostgreSQL
  ├── sensor-dashboard.service → FastAPI :8000
  │     └── /api/stats/ecology — live domain states
  └── Ollama :11434 (OLLAMA_HOST=0.0.0.0)
        └── llama3.2:latest — ecological narrative + diagnostics

Inferno (192.168.0.28)
  ├── PostgreSQL :5432 — canonical sensor_ecology database
  │     ├── perceptual_events (26,000+ rows, live)
  │     ├── device_registry (8 devices)
  │     └── device_observations
  ├── sensor-ecology-dashboard.service :9500
  ├── relay-api.service :8765 — Unity AR relay
  └── ws_bridge :8766 — WebSocket/MQTT bridge (new)

Firebase (ar-guidance-4b333.web.app)
  └── AR Guidance app v16+
        ├── Gemini Vision API — component identification
        ├── Live ecology fetch → raspberrypi.local:8000/api/stats/ecology
        ├── WebSocket → 192.168.0.28:8766/ws/device/{id}
        └── Diagnose → 192.168.0.28:8766/api/device/{id}/diagnose
```

---

## Services & Ports

| Host | Port | Service | Notes |
|------|------|---------|-------|
| raspberrypi | 1883 | Mosquitto MQTT | Sensor Pi broker |
| raspberrypi | 8000 | sensor-dashboard | FastAPI, ecology API |
| raspberrypi | 11434 | Ollama | llama3.2, nomic-embed-text |
| Inferno | 5432 | PostgreSQL | Canonical DB |
| Inferno | 8766 | ws_bridge | New — WebSocket/MQTT bridge |
| Inferno | 8765 | relay-api | Unity AR relay (existing) |
| Inferno | 9500 | sensor-ecology-dashboard | Main dashboard |

---

## Root Cause Found & Fixed

**Symptom:** `/api/stats/ecology` returning March 3–7 data. `perceptual_events` frozen at 26,717 rows.

**Cause chain:**
1. Pipeline writes to Inferno PostgreSQL via network (`ecology` password)
2. Service crash-loop on March 6 23:00 due to `InvalidPasswordError`
3. Dashboard unit file hardcoded `DB_DSN=postgresql://sean:ecology@localhost/sensor_ecology`
4. Dashboard reading local PostgreSQL which only had test rows
5. Systemd `Environment=` line overrides `.env` file — `.env` edits had no effect

**Fixes applied:**
```bash
# 1. Dashboard now points at Inferno
# /etc/systemd/system/sensor-dashboard.service.d/override.conf
[Service]
Environment=DB_DSN=postgresql://sean:ecology@192.168.0.28/sensor_ecology

# 2. Ollama exposed on network
# /etc/systemd/system/ollama.service.d/override.conf  
[Service]
Environment=OLLAMA_HOST=0.0.0.0:11434
```

---

## Device Registry

Table `device_registry` on Inferno PostgreSQL (`sensor_ecology` database).

| id | display_name | device_type | cv_labels |
|----|-------------|-------------|-----------|
| raspberry-pi-node-1 | Sensor Hub Pi | raspberry-pi-5 | Raspberry Pi, Main Board, Pi 5… |
| esp32-node-1 | ESP32 DevKit Node 1 | esp32-s3 | ESP32, ESP32 Development Board… |
| bme280-sensor-1 | BME280 Environmental Sensor | bme280 | BME280… |
| camera-module-1 | Pi Camera Module | camera | Camera Module, Pi Camera… |
| breadboard-1 | Half-size Breadboard | breadboard | Breadboard… |
| sensor-hub-1 | Multi-channel Sensor Hub | breakout-board | Sensor Hub, Jumper Wire Breakout Board… |
| display-1 | LCD/OLED Display Panel | display | LCD/OLED Display Panel… |
| mlx90640-thermal-1 | MLX90640 Thermal Camera | mlx90640 | Thermal Camera, IR Camera… |

**Key query — resolve Gemini CV label to device:**
```sql
SELECT * FROM device_registry WHERE $1 = ANY(cv_labels);
```

---

## WebSocket Bridge (`ws_bridge.py`)

**Location:** `/home/sean/sensor_ecology/ws_bridge.py` on Inferno  
**Run:** `uvicorn ws_bridge:app --host 0.0.0.0 --port 8766`

### Endpoints

| Method | Path | Purpose |
|--------|------|---------|
| GET | /health | Service health check |
| GET | /api/registry | List all devices |
| GET | /api/registry/resolve?label= | Resolve Gemini CV label → device |
| GET | /api/registry/{id} | Device detail + latest telemetry |
| POST | /api/registry/{id}/observe | Record manual observation |
| POST | /api/device/{id}/diagnose | Generate Llama3.2 diagnostic |
| WS | /ws/device/{id} | Live telemetry stream for one device |
| WS | /ws/bench | All bench activity stream |

### Diagnose endpoint
Fetches device profile from registry, formats a prompt with live anomalies, POSTs to Llama3.2 at `http://192.168.0.25:11434/api/generate`. Returns structured diagnostic steps for AR display. Timeout: 120 seconds.

### Key configuration
```python
DATABASE_URL = "postgresql://sean:ecology@192.168.0.28/sensor_ecology"
MQTT_HOST    = "192.168.0.25"
MQTT_PORT    = 1883
# Llama endpoint: http://192.168.0.25:11434/api/generate
```

---

## AR App — Live Data Mapping

**URL:** https://ar-guidance-4b333.web.app  
**Current version:** v16+

| AR Slot | Data source | Field |
|---------|-------------|-------|
| Primary Vitals | `environmental_field` domain | `agent_temp_c` → displayed as °C |
| Embodied State | `embodied_state` domain | `event_label` → capitalised |
| Resonance | Any domain | `latest_resonance.narrative_sentence` → 3-line clamp, tap to expand |
| Ecology bar colour | All domains | Red if any domain stale >30s |
| Component cards | Gemini Vision API | CV labels, confidence, location, UUID |
| Diagnosis pane | ws_bridge /diagnose | Llama3.2 response, shown on anomaly |

**Confidence gate:** 40% — filters non-electronics from card display.

---

## Ecological Domains

| Domain | Meaning | Example labels |
|--------|---------|----------------|
| `environmental_field` | Light, temperature, atmosphere | `dim_warm`, `dark`, `bright` |
| `embodied_state` | Node power/activity state | `idle`, `active`, `thermal_stress` |
| `high_bandwidth` | Thermal/motion events | `thermal_shift`, `thermal_stress` |

---

## Wide-to-Narrow Focus Protocol

**Unity motif graph (wide):** Spatial map of all nodes, motif patterns over time, which nodes are active/stressed. Macro ecological awareness.

**AR web app (narrow):** Physical identification of specific device, live telemetry, resonance narrative, wiring guidance, Llama3.2 diagnostic. Micro inspection and care.

**Trigger:** CV identifies a node → `/api/registry/resolve` → WebSocket stream opens → anomaly detection → diagnose if threshold crossed. One HTTP call bridges macro awareness to physical care.

---

## Llama3.2 Narrator

**Model:** `llama3.2:latest` (3.2B Q4_K_M)  
**Host:** Sensor Pi, `http://192.168.0.25:11434`  
**Uses:**
1. **Ecological narrative** — ambient poetic state descriptions ("warm presence approaching", "thermal recovery — agent cooling down") generated by the sensor ingestion pipeline
2. **Diagnostic guidance** — step-by-step repair instructions triggered by anomalies in the AR app

Both uses share the same model, different prompts, different registers. The continuity is intentional — the same narrator moves between poetic ecological awareness and practical technical guidance.

---

## Known Issues & Future Work

- Llama3.2 diagnostic responses can hallucinate non-existent CLI commands. Fix: ground the prompt with actual `pinout` and `thresholds` JSONB from device registry.
- `ws_bridge.py` needs a systemd service file on Inferno for auto-restart on reboot.
- `mqtt_connected` status in `/health` shows "unknown" — minor, MQTT is working.
- Unity motif graph WebSocket integration to ws_bridge not yet wired.
- Motion-gating for ESP-CAM to reduce Gemini API calls (planned).

---

## File Locations

| File | Host | Path |
|------|------|------|
| ws_bridge.py | Inferno | /home/sean/sensor_ecology/ws_bridge.py |
| sensor_ingestion_layer.py | Sensor Pi | /home/sean/sensor_ecology/sensor_ingestion_layer.py |
| perceptual_embedding_pipeline.py | Sensor Pi | /home/sean/sensor_ecology/perceptual_embedding_pipeline.py |
| dashboard .env | Sensor Pi | /home/sean/sensor_ecology/dashboard/.env |
| systemd override (dashboard) | Sensor Pi | /etc/systemd/system/sensor-dashboard.service.d/override.conf |
| systemd override (ollama) | Sensor Pi | /etc/systemd/system/ollama.service.d/override.conf |
