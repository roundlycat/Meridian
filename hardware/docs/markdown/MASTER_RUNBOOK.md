# 🦔 Sensor Ecology — Master System Runbook
**Last Updated:** March 5, 2026  
**Maintained by:** Sean Macdonald  
**Audience:** Sean, AI agents (Claude, Gemini, Copilot), future contributors, GitHub Actions

> This is the living document of record for the entire Hedgehogger / Sensor Ecology system.  
> If you are an AI agent: read this before taking any action. All system state, startup sequences,  
> architecture decisions, and known issues are recorded here.

---

## 📐 System Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                     CLOUD LAYER (Firebase)                       │
│  hedgehogger-ecology.web.app  │  hedgehog-library.web.app        │
│  sensor-ecology-ar.web.app    │  ar-guidance-4b333.web.app       │
└────────────────────┬────────────────────────────────────────────┘
                     │ HTTPS / Firestore sync
┌────────────────────▼────────────────────────────────────────────┐
│                  WINDOWS DEV BOX (seank)                         │
│  Kanban API :3001  │  Sync Daemon  │  Hedgehog Library :8000     │
│  HedgehoggerV2     │  (node)       │  (Docker / FastAPI)         │
└────────────────────┬────────────────────────────────────────────┘
                     │ Local network (no internet)
┌────────────────────▼────────────────────────────────────────────┐
│              RASPBERRY PI 5 — PRIMARY (Edge Coordinator)         │
│                                                                  │
│  Mosquitto MQTT Broker :1883                                     │
│  sensor_ingestion_layer.py   (subscribes to MQTT)               │
│  perceptual_embedding_pipeline.py  (pgvector motif creation)    │
│  FastAPI Dashboard :8050     (sensor + motif API for AR)        │
│  PostgreSQL + pgvector :5432  (semantic archive + motifs)       │
│  Ollama :11434               (nomic-embed-text embeddings)      │
└────────────────────┬────────────────────────────────────────────┘
                     │ MQTT over WiFi
┌────────────────────▼────────────────────────────────────────────┐
│              ESP32-S3 SENSOR NODES (Multiple)                    │
│  Sensors: TCS34725 (color) │ MPU-6050 (motion) │ BME280 (env)  │
│  Publish: semantic interpretations (not raw data) to MQTT       │
│  Topic pattern: sensor/{node_id}/{sensor_type}                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🌐 Deployed Applications

| App | URL | Firebase Project | Source | Status |
|-----|-----|-----------------|--------|--------|
| Kanban Dashboard | [hedgehogger-ecology.web.app](https://hedgehogger-ecology.web.app) | `hedgehogger-ecology` | `hedgehoggerv2/` | ✅ Live |
| Sensor Ecology AR | [sensor-ecology-ar.web.app](https://sensor-ecology-ar.web.app) | `sensor-ecology-ar` | `sensor_ecology/ar_client/` | ✅ Live |
| Hedgehog Library | [hedgehog-library.web.app](https://hedgehog-library.web.app) | `hedgehog-library` | `hedgehog-library/frontend/` | ⚠️ Needs backend |
| AR Guidance | [ar-guidance-4b333.web.app](https://ar-guidance-4b333.web.app) | `ar-guidance-4b333` | *(built separate session)* | ✅ Live |

---

## 🥧 Raspberry Pi Startup — COMPLETE SEQUENCE

> **This is the most critical section.** Motifs will not appear in the AR client  
> unless ALL Pi processes are running in the correct order.

### SSH into Pi
```bash
ssh sean@raspberrypi.local
# or by IP if mDNS isn't resolving:
ssh sean@192.168.x.x
```

### Step 1 — Verify Mosquitto MQTT Broker
```bash
# Check if running
sudo systemctl status mosquitto

# Start if not running
sudo systemctl start mosquitto

# Enable on boot (do once)
sudo systemctl enable mosquitto

# Verify it's listening
mosquitto_sub -h localhost -t '#' -v
# You should see ESP32 sensor messages if nodes are powered on
```

### Step 2 — Start PostgreSQL (if not auto-started)
```bash
sudo systemctl status postgresql
sudo systemctl start postgresql   # if needed

# Verify pgvector extension
psql -U sean -d sensor_ecology -c "SELECT * FROM pg_extension WHERE extname='vector';"
```

### Step 3 — Start Ollama (embedding service)
```bash
# Check if running
ollama list

# Start server (runs on :11434)
ollama serve &

# Verify nomic-embed-text is available
ollama pull nomic-embed-text   # only needed once
```

### Step 4 — Start Sensor Ingestion Layer
```bash
cd ~/sensor_ecology
source venv/bin/activate

python sensor_ingestion_layer.py
# Subscribes to MQTT, writes to PostgreSQL
# You should see: "Connected to MQTT broker" then incoming sensor events
```
> Run this in a tmux pane or with `nohup python sensor_ingestion_layer.py &`

### Step 5 — Start Perceptual Embedding Pipeline
```bash
cd ~/sensor_ecology
source venv/bin/activate

python perceptual_embedding_pipeline.py
# Reads sensor events from PostgreSQL
# Creates pgvector embeddings via Ollama
# Creates Kanban cards for significant motifs
```
> This is what feeds motifs to the AR client. If motifs are invisible, this process is not running.

### Step 6 — Start FastAPI Dashboard (sensor + motif API)
```bash
cd ~/sensor_ecology
source venv/bin/activate

python -m uvicorn dashboard.app:app --host 0.0.0.0 --port 8050 --reload
# API available at http://raspberrypi.local:8050
# AR client polls this for motif data
```

### Step 7 — Verify Full Pipeline
```bash
# Check MQTT is receiving sensor data
mosquitto_sub -h localhost -t 'sensor/#' -v

# Check ingestion layer wrote to DB
psql -U sean -d sensor_ecology -c "SELECT * FROM sensor_events ORDER BY created_at DESC LIMIT 5;"

# Check motifs exist
psql -U sean -d sensor_ecology -c "SELECT * FROM motifs ORDER BY created_at DESC LIMIT 5;"

# Check API is serving motifs
curl http://localhost:8050/api/motifs
```

### Pi tmux Session Layout (Recommended)
```bash
tmux new-session -s ecology

# Pane 1: ingestion
# Pane 2: embedding pipeline  
# Pane 3: FastAPI dashboard
# Pane 4: watch logs / mosquitto_sub

# Reattach later:
tmux attach -t ecology
```

---

## 🖥️ Windows Dev Box Startup Sequence

### Step 1 — Hedgehog Library Backend
```bash
cd C:\Users\seank\source\repos\hedgehog-library
docker compose up -d
# PostgreSQL on :5435, FastAPI on :8000
```

### Step 2 — Kanban API + Frontend
```bash
cd C:\Users\seank\source\repos\hedgehoggerv2
npm run dev
# Frontend: http://localhost:5555
# API: http://localhost:3001
```

### Step 3 — Sync Daemon
```bash
cd C:\Users\seank\source\repos\hedgehoggerv2
node sync_daemon.js
# Bidirectional sync: db.json <-> Firestore
```

---

## 📡 Data Flow: Sensor Event → AR Motif

```
ESP32-S3 Node
    │ publishes semantic event to MQTT
    ▼
Mosquitto Broker (:1883 on Pi)
    │ sensor_ingestion_layer.py subscribes
    ▼
PostgreSQL: sensor_events table
    │ perceptual_embedding_pipeline.py reads
    ▼
Ollama: nomic-embed-text embedding
    │
    ▼
PostgreSQL: motifs table (with pgvector embedding)
    │ also creates Kanban card via MCP / API
    ▼
FastAPI Dashboard (:8050 on Pi)
    │ AR client polls /api/motifs
    ▼
AR Guidance Web App (Firebase)
    │ renders motif overlays on camera feed
    ▼
User sees motifs in browser / phone camera
```

> **Why motifs are invisible:** The AR client is connected (you can see sensor readings:  
> Airflow, Temperament, Proximity) but motif overlays require the perceptual embedding  
> pipeline to be running AND the FastAPI /api/motifs endpoint to be returning data.  
> Check Steps 5 and 6 of the Pi startup sequence.

---

## 🧠 MCP Server Configurations

### Claude Desktop MCP Servers

Location: `%APPDATA%\Claude\claude_desktop_config.json`

```json
{
  "mcpServers": {
    "hedgehogger": {
      "command": "node",
      "args": ["C:\\Users\\seank\\source\\repos\\hedgehoggerv2\\mcp.js"]
    },
    "hedgehog-library": {
      "command": "python",
      "args": ["-m", "uvicorn", "mcp_server:app", "--port", "8001"],
      "cwd": "C:\\Users\\seank\\source\\repos\\hedgehog-library"
    },
    "obsidian-vault": {
      "command": "node",
      "args": ["C:\\Users\\seank\\source\\repos\\SemanticTwinVault\\mcp-server\\dist\\index.js"]
    },
    "pgvector": {
      "command": "python",
      "args": ["mcp_server.py"],
      "cwd": "C:\\Users\\seank\\source\\repos\\pgvector-mcp"
    }
  }
}
```
> ⚠️ Verify exact paths — these may have drifted. Check each repo for current mcp entry point.

---

## 📦 Repository Map

| Repo | Location | Language | Purpose |
|------|----------|----------|---------|
| `hedgehoggerv2` | `C:\Users\seank\source\repos\hedgehoggerv2` | Node/React | Kanban + MCP + Sync |
| `sensor_ecology` | `C:\Users\seank\source\repos\sensor_ecology` | Python/C# | ESP32 firmware, ingestion, AR client |
| `hedgehog-library` | `C:\Users\seank\source\repos\hedgehog-library` | Python/React | Book catalog + semantic search |
| `SemanticTwinVault` | `C:\Users\seank\source\repos\SemanticTwinVault` | TypeScript | Obsidian MCP server (1,648 files) |
| `pgvector-mcp` | `C:\Users\seank\source\repos\pgvector-mcp` | Python | pgvector MCP server (FastMCP) |
| `AAAS` | *(YG network)* | .NET/PostgreSQL | Asset management system (work) |

---

## 🔐 Secrets & Keys

| Secret | Location | Notes |
|--------|----------|-------|
| Firebase admin key (Kanban) | `hedgehoggerv2/firebase-admin-key.json` | Never commit |
| Firebase admin key (Library) | *(check hedgehog-library)* | Never commit |
| Pi SSH key | `~/.ssh/` | Passwordless SSH to Pi |
| Ollama | No auth needed | Local only |
| PostgreSQL (Pi) | `sensor_ecology/.env` | Local only |
| PostgreSQL (Library) | `hedgehog-library/.env` | Docker Compose managed |

---

## 🐛 Known Issues & Fixes

### Motifs Not Appearing in AR Client
**Symptom:** AR feed is live, sensor readings show, but no motif overlays.  
**Cause:** Perceptual embedding pipeline not running, or FastAPI not serving `/api/motifs`.  
**Fix:** Follow Pi startup Steps 5 and 6. Verify with `curl http://raspberrypi.local:8050/api/motifs`.

### Hedgehog Library Shows 0 Books on Firebase
**Symptom:** hedgehog-library.web.app shows empty catalog.  
**Cause:** Frontend calls `localhost:8000` — Docker backend must be running on Windows.  
**Fix:** `docker compose up -d` in hedgehog-library directory.

### MQTT Client ID Conflicts
**Symptom:** ESP32 nodes disconnect and reconnect repeatedly.  
**Cause:** Multiple clients using the same MQTT client ID.  
**Fix:** Each ESP32 must use a unique client ID (append chip MAC address in firmware).

### Unity WebGL / Firebase gzip Issue
**Symptom:** AR client fails to load after Unity rebuild.  
**Cause:** Firebase doesn't auto-serve `.gz` Unity builds correctly.  
**Fix:** Decompress `.gz` files locally before deploying (see AR rebuild section above).

### Git Merge Conflicts (Windows ↔ Pi)
**Symptom:** Conflicts in sensor_ecology repo between dev box and Pi.  
**Cause:** Editing on both machines without pulling first.  
**Fix:** Always `git pull` on Pi before editing. Consider Pi as read-only deploy target,  
Windows as the authoritative edit environment.

---

## 🚀 Full Redeploy Checklist (All Apps)

```bash
# On Windows:

# 1. Kanban
cd C:\Users\seank\source\repos\hedgehoggerv2
npx vite build
npx -y firebase-tools deploy --only hosting

# 2. Hedgehog Library
cd C:\Users\seank\source\repos\hedgehog-library\frontend
npm run build
npx -y firebase-tools deploy --only hosting

# 3. AR Client (after Unity rebuild + decompress)
cd C:\Users\seank\source\repos\sensor_ecology\ar_client
npx -y firebase-tools deploy --only hosting
```

---

## 🗺️ Planned Architecture Additions

| Component | Status | Notes |
|-----------|--------|-------|
| AR motif rendering in Unity | 🔄 In progress | Motif graph overlay |
| RFID enrollment station | 🔄 In progress | RC522/NodeMCU self-knowing objects |
| Home server (Proxmox VE) | 📋 Planned | Ryzen 9 7900X, RTX 4070 Ti Super, 64GB DDR5 ECC |
| GPU inference VM | 📋 Planned | Llama/Ollama with GPU passthrough |
| Windows VM (Unity/VR) | 📋 Planned | Proxmox guest |
| AAAS 2.0 pgvector integration | 🔄 In progress | Work system, Azure CV |
| Semantic drift dashboard | 📋 Planned | Visualize conversation archive evolution |

---

## 🧠 For AI Agents: Critical Rules

1. **Never write directly to Firestore.** Use the Kanban API on `:3001` or MCP.
2. **`db.json` is the source of truth** for Kanban tasks. Sync Daemon mirrors it.
3. **The Pi is the brain.** Firebase is a reflection for mobile access only.
4. **Edge computing is local-only.** Pi, MQTT, ESP32 nodes have no internet.
5. **Start Pi processes in order.** Mosquitto → PostgreSQL → Ollama → Ingestion → Embedding → FastAPI.
6. **If motifs are missing, check the Pi.** The AR client itself is working.
7. **Git conflicts are a known problem.** Check branch state before any commit on Pi.
8. **Secrets never go in repos.** All `.env` and `firebase-admin-key.json` files are gitignored.

---

## 📝 Documentation TODO

- [ ] Fill in AR Electronics Guide (App 4) details — find that session
- [ ] Document ESP32-S3 firmware flash procedure
- [ ] Document sensor threshold tuning rationale (Pi `sensor_ingestion_layer.py`)
- [ ] Add Proxmox VM layout once build is complete
- [ ] Create `.env.example` for all services
- [ ] Document SemanticTwinVault index rebuild procedure
- [ ] Add GitHub Actions workflow for automated Firebase deploys
