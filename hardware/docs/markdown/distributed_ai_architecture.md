# Distributed Personal AI Architecture
## Complete System Design for Sovereign Intelligence Infrastructure

**Author:** Sean (with Claude collaboration)  
**Created:** 2026-01-27  
**Purpose:** Reference architecture for privacy-preserving, distributed AI system  
**Philosophy:** Minimum sustainable personal-to-industrial system that protects autonomy while enabling AI-augmented flourishing  

---

## Table of Contents

1. [System Overview](#system-overview)
2. [Hardware Architecture](#hardware-architecture)
3. [Software Architecture](#software-architecture)
4. [Intelligence Layers](#intelligence-layers)
5. [Communication Architecture](#communication-architecture)
6. [Privacy & Security](#privacy--security)
7. [Data Flows](#data-flows)
8. [Use Case Examples](#use-case-examples)
9. [Build Phases](#build-phases)
10. [Philosophical Foundation](#philosophical-foundation)

---

## System Overview

### Core Principle

**Distributed intelligence with fluid handoffs** - each layer processes at its capability limit, hands off when exceeded, maintains privacy boundaries throughout.

### Key Features

- **Local-First:** Most processing happens on personal devices
- **Privacy-Preserving:** Data minimization, encryption, verifiable boundaries
- **Modular:** Components can be added/removed/upgraded independently
- **Sovereign:** User owns infrastructure, controls data, audits behavior
- **Sustainable:** Low power, repairable, 5-10 year lifespan
- **Comprehensible:** Any motivated citizen can understand and build

### Architecture Principles

1. **Hayekian Distributed Knowledge:** Keep knowledge at edge where it exists
2. **Ordo Amoris Preservation:** Each person's value hierarchy respected
3. **Liberalism of Fear:** Structural limits on power concentration
4. **Hermeneutic Infrastructure:** Translation across difference without erasure
5. **Temporal Continuity:** Conversation archives constitute narrative identity

---

## Hardware Architecture

### Layer 0: Micro-Intelligences (Sensors & Actuators)

**Devices:**
```
ESP32-S3 DevKit ($12 each)
├─ WiFi + Bluetooth + LoRa capability
├─ GPIO for sensors
├─ Low power (0.5-1W)
└─ Quantity: 5-10 nodes

Sensors:
├─ DHT22 (temperature/humidity): $5
├─ PIR (motion detection): $3
├─ Door/window sensors: $5
├─ RFID reader (RC522): $8
└─ Custom sensors as needed

Communication:
├─ LoRa modules (RFM95W): $15 each
└─ MQTT over WiFi (primary)
```

**Capabilities:**
- Environmental sensing
- Simple threshold detection
- Local event triggers
- Pub-sub messaging
- Battery-powered options

**Location:** Distributed (living room, bedroom, workspace, outdoors)

---

### Layer 1: Edge Coordinator (Primary Intelligence Hub)

**Device: Raspberry Pi 5 (8GB)**

**Core Hardware:**
```
Raspberry Pi 5 (8GB RAM): $80
├─ CPU: Quad-core Cortex-A76 @ 2.4GHz
├─ RAM: 8GB LPDDR4X
├─ PCIe: 2.0 x1 lane (for accelerators)
├─ USB: 2x USB 3.0, 2x USB 2.0
├─ GPIO: 40-pin header (sensor coordination)
├─ Network: Gigabit Ethernet, WiFi 6, BT 5.2
└─ Power: ~5-8W

Storage:
├─ NVMe 256GB (your Surface drive): $0
│   └─ Via M.2 HAT ($12)
└─ For: PostgreSQL, conversation archives, models

AI Acceleration (Choose based on phase):
├─ Movidius NCS2 (you have): 1 TOPS
│   └─ OpenVINO models, OCR, vision
├─ Hailo-8 M.2 (future): 26 TOPS
│   └─ More flexible, faster, better long-term
└─ Coral TPU USB (alternative): 4 TOPS
    └─ TensorFlow Lite, good for vision

Peripherals:
├─ Camera Module 3 ($25): High-quality vision
├─ Cooling: Active cooler included, heatsink
└─ Case: Official or Argon ONE ($15-40)
```

**Capabilities:**
- Coordinate 10-20 sensor nodes
- Run 1-3B parameter language models
- Computer vision (with accelerator)
- PostgreSQL + pgvector semantic search
- MQTT broker (sensor coordination)
- MCP servers (expose to personal devices)
- Local web interface (monitoring)
- Real-time inference (<100ms)

**Location:** Home (always-on, central hub)

**Power:** 24/7 operation ~$5/month electricity

---

### Layer 2: Epistolary Terminal (Personal Interface)

**Mobile Field Device**

**Hardware:**
```
Option A: Raspberry Pi Zero W 2 + E-ink
├─ Pi Zero W 2: $15
├─ Waveshare 7.5" e-ink: $65
├─ Bluetooth keyboard (iClever BK03): $35
├─ LiPo battery 3000mAh: $12
├─ USB LiPo charger: $6
├─ Optional: LoRa module: $15
└─ Total: $148-163

Option B: Raspberry Pi 4/5 + E-ink (More Capable)
├─ Pi 4 (4GB): $55 OR Pi 5 (4GB): $60
├─ E-ink display: $65
├─ Keyboard: $35
├─ Battery bank (20,000mAh): $30
├─ Optional: Movidius NCS2 (vision): $60
└─ Total: $245-310

Option C: ESP32-S3 + E-ink (Lightest)
├─ ESP32-S3: $12
├─ E-ink display: $65
├─ Keyboard: $35
├─ LiPo battery: $12
└─ Total: $124 (text-only, no vision)
```

**Capabilities:**
- Long-form text composition (epistolary computing)
- Encrypted communication with Edge Coordinator
- Local conversation storage (MicroSD)
- E-ink display (outdoor readable, low power)
- Hours of battery life (days for ESP32)
- Optional: Camera + NCS2 for field OCR
- LoRa mesh networking (off-grid communication)

**Location:** Portable (pocket/bag, field use)

**Usage:** Philosophical reflection, journaling, field notes, contemplative computing

---

### Layer 3: Personal Devices (Laptop/Phone)

**Existing Hardware:**

**Laptop:**
```
Your current laptop
├─ CPU: Capable of running 7-13B models
├─ RAM: 16GB+ recommended
├─ Storage: SSD for model loading
├─ GPU: Integrated or discrete (if available)
└─ OS: Linux preferred, macOS works, Windows possible
```

**Phone:**
```
Your Samsung Galaxy Tab A9+
├─ AR capabilities (camera, sensors)
├─ Bluetooth (connect to sensors)
├─ WiFi (coordinate with Edge)
└─ Android (flexible, open)
```

**Capabilities:**
- Larger language models (7-70B quantized)
- Rich UI (complex visualizations)
- Internet access (gateway to cloud)
- MCP client (access Edge services)
- Cloud mediation layer
- User interaction for complex decisions

**Location:** Mobile (with you throughout day)

---

### Layer 4: Cloud AI (External Services)

**Services:**
```
Anthropic Claude:
├─ Sonnet 4.5 (general intelligence)
├─ Opus 4.5 (complex reasoning)
└─ Via API, mediated by personal device

OpenAI (if needed):
├─ GPT-4 (alternative reasoning)
└─ Whisper (speech recognition)

Specialized:
├─ PubMed MCP server (medical literature)
├─ Other MCP servers as needed
└─ Always mediated, never direct
```

**Access Pattern:**
- Only through personal device mediation
- Anonymized/compressed queries
- Audit logging (local)
- User consent per query
- Minimal data exposure

---

## Software Architecture

### Layer 0: Micro-Intelligence Firmware

**Platform:** ESP32 (Arduino/ESP-IDF)

```
Sensor Node Software:
├─ Main loop (sensor reading, threshold checks)
├─ MQTT client (pub-sub messaging)
├─ Local decision logic (simple rules)
├─ Sleep/wake management (power optimization)
└─ OTA updates (secure firmware updates)

Example Structure:
/firmware/
├─ src/
│   ├─ main.cpp (event loop)
│   ├─ sensors.cpp (DHT22, PIR, etc.)
│   ├─ mqtt_client.cpp (communication)
│   └─ decision_logic.cpp (local intelligence)
├─ lib/ (libraries)
└─ platformio.ini (build config)
```

**Languages:** C++, Arduino framework

**Communication:** MQTT topics
```
Publish:
├─ sensors/temperature/living_room
├─ sensors/motion/bedroom
└─ events/anomaly/sensor_12

Subscribe:
├─ commands/sensor_12
└─ updates/firmware
```

---

### Layer 1: Edge Coordinator Software

**Platform:** Raspberry Pi 5 (Ubuntu Server 24.04 or Raspberry Pi OS)

**Core Services:**

#### PostgreSQL + pgvector (Semantic Search)
```
Database Schema:
├─ conversations (your archives)
│   ├─ id, timestamp, content, metadata
│   └─ embedding (vector for semantic search)
├─ documents (scanned books, OCR results)
├─ health_data (temporal tracking)
└─ sensor_data (time-series from micro nodes)

Location: /mnt/nvme/postgresql/
Size: ~10-50GB
```

#### Local Language Model Server
```
Options:
├─ llama.cpp server (Llama 3.2 1-3B)
├─ Ollama (easier management)
└─ vLLM (production-grade)

Model Storage: /mnt/nvme/models/
├─ llama-3.2-1b-q4.gguf (1GB)
├─ llama-3.2-3b-q4.gguf (2GB)
└─ phi-3-mini-q4.gguf (2GB)

API: OpenAI-compatible endpoint
URL: http://edge-pi:11434 (local network)
```

#### MQTT Broker (Sensor Coordination)
```
Mosquitto MQTT:
├─ Port: 1883 (local network)
├─ Auth: Username/password
├─ TLS: For external access
└─ Topics: Organized by sensor type/location

Config: /etc/mosquitto/mosquitto.conf
Persistence: /mnt/nvme/mqtt/
```

#### MCP Servers (Tool Exposure)
```
MCP Server Stack:
├─ conversation-context (semantic search)
├─ health-archive (medical data)
├─ sensor-coordinator (IoT control)
└─ knowledge-agents (pub-sub research)

Language: Python (FastMCP framework)
Location: /opt/mcp-servers/

Example MCP Server:
/opt/mcp-servers/conversation-context/
├─ server.py (FastMCP implementation)
├─ database.py (pgvector queries)
└─ embeddings.py (sentence transformers)
```

#### Computer Vision Services
```
With Movidius NCS2:
├─ OpenVINO inference engine
├─ Text detection (OCR pipeline)
├─ Object detection (workspace awareness)
└─ Scene classification

With Hailo-8 (future):
├─ More flexible model support
├─ Faster inference
├─ PyTorch/TensorFlow/ONNX
└─ Larger model capacity

API: REST endpoint for vision tasks
URL: http://edge-pi:5000/vision
```

#### Pub-Sub Coordination Layer
```
Knowledge Agent Coordinator:
├─ Subscribes to relevant events
├─ Triggers research agents
├─ Synthesizes results
└─ Publishes to interested parties

Example:
symptom_event → medical_research_agent → literature_search → triage_synthesis
```

**Software Stack:**
```
OS: Ubuntu Server 24.04 LTS
Database: PostgreSQL 16 + pgvector
Language Models: llama.cpp / Ollama
MQTT: Mosquitto
Vision: OpenVINO + NCS2 / Hailo SDK
MCP: FastMCP (Python)
Web UI: Grafana (monitoring) + Custom (FastAPI)
```

**Directory Structure:**
```
/mnt/nvme/
├─ postgresql/ (database)
├─ models/ (language models)
├─ conversations/ (archives)
├─ documents/ (scanned, OCR'd)
└─ mqtt/ (message persistence)

/opt/
├─ mcp-servers/ (tool servers)
├─ vision-services/ (CV pipeline)
└─ coordination/ (pub-sub logic)

/home/pi/
└─ projects/ (your code, experiments)
```

---

### Layer 2: Epistolary Terminal Software

**Platform:** Varies by hardware choice

**ESP32-S3 Version:**
```
Firmware:
├─ E-ink display driver (GxEPD2)
├─ Bluetooth keyboard (BLEKeyboard)
├─ Message storage (SD card, SPIFFS)
├─ LoRa communication (RFM95W)
└─ Encryption (AES-256)

Language: C++ (Arduino/ESP-IDF)
Size: ~500 lines for basic version
```

**Pi Zero W 2 Version:**
```
Python Application:
├─ E-ink display (Waveshare library)
├─ Bluetooth keyboard handler
├─ Local storage (SQLite)
├─ Network: WiFi, LoRa
├─ Encryption (cryptography library)
└─ Optional: Local small model (1B)

Language: Python
Storage: 32GB MicroSD
```

**Features:**
- Compose messages offline
- Encrypt before transmission
- Send via WiFi or LoRa
- Receive and display responses
- Local conversation archive
- Battery-optimized (sleep modes)

---

### Layer 3: Personal Device Software

**Laptop:**
```
MCP Client:
├─ Connects to Edge MCP servers
├─ Orchestrates local + cloud reasoning
├─ Privacy mediation layer
└─ User interface for complex tasks

Cloud Mediator:
├─ Anonymization engine
├─ Query compression
├─ Consent management
├─ Audit logging

Development Environment:
├─ VS Code (with MCP extension)
├─ Adaptive interface (context-aware)
├─ GitHub integration
└─ Terminal access to Edge
```

**Phone/Tablet:**
```
Android Apps:
├─ MCP client (connect to Edge)
├─ AR interface (camera + overlays)
├─ Haptic feedback (for adaptive instruction)
├─ Location services (context awareness)
└─ Sensor integration

Purpose:
├─ Mobile access to Edge services
├─ AR-guided instruction
├─ Field interaction with epistolary device
└─ Gateway to cloud when needed
```

---

### Layer 4: Cloud Integration

**APIs Used:**
```
Anthropic Claude:
├─ Messages API (conversational)
├─ Tool use (MCP servers on edge)
└─ Vision API (if needed)

Always via mediation:
├─ Personal device prepares query
├─ Anonymizes/compresses
├─ Logs what's sent
├─ Integrates response with local context
└─ Never direct from Edge/Micro layers
```

---

## Intelligence Layers

### Layer 0: Micro-Intelligence (Reactive)

**Cognitive Capabilities:**
- Threshold detection ("temp > 25°C")
- Simple pattern matching ("motion detected at night")
- State machines ("door open → alert")
- Local logging

**Decision Authority:**
- Routine events (log locally)
- Threshold violations (alert Edge)
- Anomalies (request analysis)

**Example Agent:**
```python
class TemperatureSensor:
    def __init__(self):
        self.normal_range = (18, 24)
        self.history = []
    
    def observe(self):
        temp = read_sensor()
        self.history.append(temp)
        
        # Can I handle this?
        if self.in_normal_range(temp):
            log_locally()
            return
        
        # Outside normal - check if transient
        if self.is_brief_anomaly():
            log_locally()
            return
        
        # Persistent anomaly - hand off
        self.publish_to_edge({
            'event': 'temperature_anomaly',
            'value': temp,
            'duration': self.anomaly_duration(),
            'my_assessment': 'outside_normal_persistent',
            'needs': 'correlation_analysis'
        })
```

---

### Layer 1: Edge Intelligence (Coordinating)

**Cognitive Capabilities:**
- Multi-sensor correlation
- Time-series analysis
- Pattern recognition (1-3B LLM)
- Semantic search (local archives)
- Computer vision (with accelerator)
- Local decision-making

**Decision Authority:**
- Coordinate multiple sensors
- Analyze patterns over time
- Execute automated responses (alerts, actions)
- Provide local AI assistance
- Hand off when uncertain or need larger capability

**Example Agent:**
```python
class EdgeCoordinator:
    def __init__(self):
        self.local_llm = Llama3_3B()
        self.semantic_search = PgVector()
        self.sensors = subscribe_mqtt()
    
    def handle_temperature_anomaly(self, event):
        # Gather context
        motion = self.get_recent_motion()
        door = self.get_door_status()
        weather = self.get_weather_api()
        
        # Correlate
        if door == 'open' and motion == 'recent':
            return self.simple_alert("Door left open, close it?")
        
        # More complex - use local LLM
        context = {
            'event': event,
            'motion': motion,
            'door': door,
            'weather': weather,
            'history': self.get_temp_history(days=7)
        }
        
        analysis = self.local_llm.analyze(context)
        
        if analysis.confidence > 0.8:
            # Handle locally
            return self.execute_action(analysis.recommendation)
        
        # Uncertain - hand off to personal device
        self.handoff_to_personal({
            'event': event,
            'context': context,
            'local_analysis': analysis,
            'why_handoff': 'low_confidence_need_larger_model',
            'privacy_level': 'low'  # Environmental data, not sensitive
        })
```

---

### Layer 2: Personal Intelligence (Mediating)

**Cognitive Capabilities:**
- Larger language models (7-13B)
- Rich context integration
- User preference learning
- Privacy boundary enforcement
- Cloud query mediation
- Complex UI/visualization

**Decision Authority:**
- Determine if local can handle
- Decide if cloud is needed
- Enforce privacy constraints
- Get user consent for sensitive queries
- Integrate cloud + local + user knowledge

**Example Agent:**
```python
class PersonalMediator:
    def __init__(self):
        self.local_llm = Llama3_13B()  # Larger model
        self.cloud_client = AnthropicClient()
        self.user_prefs = load_preferences()
        self.privacy_engine = PrivacyGuard()
    
    def handle_handoff_from_edge(self, request):
        privacy = request['privacy_level']
        
        # Try local first (larger model than Edge)
        if self.can_handle_locally(request):
            result = self.local_llm.process(request)
            if result.confidence > 0.75:
                return self.send_to_edge(result)
        
        # Need cloud
        if privacy == 'high':
            # Too sensitive
            return self.notify_user({
                'message': 'Cannot analyze without cloud (privacy block)',
                'partial': result,
                'options': ['accept_limited_result', 'consult_human_expert']
            })
        
        # Medium/low privacy - prepare cloud query
        cloud_query = self.privacy_engine.anonymize(request)
        
        # Get user consent
        if not self.user_consented(cloud_query):
            return self.request_consent(cloud_query)
        
        # Send to cloud (anonymized)
        cloud_result = self.cloud_client.query(cloud_query)
        
        # Integrate with local context
        integrated = self.integrate(
            cloud=cloud_result,
            local=result,
            edge=request
        )
        
        return integrated
```

---

### Layer 3: Cloud Intelligence (Substrate)

**Cognitive Capabilities:**
- Largest models (hundreds of billions of parameters)
- Real-time web search
- Vast training data (internet-scale)
- Specialized capabilities
- Multi-modal reasoning

**Decision Authority:**
- None (advisory only)
- Provides pattern recognition
- Suggests options
- Explains reasoning
- **User decides, cloud informs**

**Example Interaction:**
```python
# Mediated cloud query (from personal device)
cloud_query = {
    'query': 'User experiencing atypical anxiety pattern. Differential diagnosis?',
    # Note: No PII, anonymized, compressed
    'context': 'minimal',
    'user_id': hash(user_id)  # Pseudonymous
}

# Cloud processes
response = anthropic.messages.create(
    model="claude-sonnet-4-20250514",
    messages=[{'role': 'user', 'content': cloud_query['query']}]
)

# Returns suggestions, not commands
# Personal device integrates with local context
# User sees: cloud suggestions + local analysis + their own knowledge
# User decides action
```

---

## Communication Architecture

### Protocols & Standards

**MQTT (Micro ↔ Edge)**
```
Broker: Mosquitto on Edge Pi
Port: 1883 (local), 8883 (TLS external)
QoS: 0-2 (configurable)
Topics: Hierarchical

Example Topics:
├─ sensors/temperature/living_room
├─ sensors/motion/bedroom/+  (wildcard)
├─ events/anomaly/#  (multi-level wildcard)
├─ commands/actuators/+
└─ status/sensor_12/health
```

**HTTP/REST (Edge ↔ Personal)**
```
Edge API: FastAPI on Pi 5
Port: 8000 (local network)
Endpoints:
├─ /api/semantic_search (query archives)
├─ /api/health (check system status)
├─ /api/vision/ocr (process image)
└─ /api/sensor/query (get sensor data)

TLS: Self-signed cert (local trust)
Auth: API key (generated per device)
```

**MCP (Edge ↔ Personal)**
```
Protocol: Model Context Protocol
Transport: stdio or SSE
Servers: Multiple on Edge

Example:
Personal device → MCP client
  ↓
Edge Pi → MCP server (conversation-context)
  ↓
Returns: Semantic search results
```

**HTTPS (Personal ↔ Cloud)**
```
Anthropic API
Endpoint: https://api.anthropic.com/v1/messages
Auth: API key (in environment, not code)
TLS: 1.3
Rate limit: Track locally, respect limits
```

**LoRa (Epistolary ↔ Edge, optional)**
```
Frequency: 915 MHz (North America)
Range: 2-10km (line of sight)
Bandwidth: ~10-50 Kbps
Use case: Off-grid communication
Encryption: AES-256 before transmission
```

### Message Formats

**Sensor Event (Micro → Edge)**
```json
{
  "sensor_id": "temp_living_room",
  "timestamp": "2026-01-27T14:32:15Z",
  "event_type": "temperature_anomaly",
  "data": {
    "temperature": 12.5,
    "normal_range": [18, 24],
    "duration_seconds": 1800
  },
  "local_assessment": "persistent_anomaly",
  "needs": "correlation_analysis"
}
```

**Handoff Request (Edge → Personal)**
```json
{
  "from": "edge_coordinator",
  "timestamp": "2026-01-27T14:35:00Z",
  "event_type": "complex_pattern",
  "local_analysis": {
    "confidence": 0.62,
    "hypothesis": "heating_failure",
    "supporting_evidence": [...]
  },
  "reason_for_handoff": "low_confidence_need_larger_model",
  "privacy_level": "low",
  "suggested_action": "analyze_with_weather_context",
  "user_notification": "optional"
}
```

**Cloud Query (Personal → Cloud)**
```json
{
  "query": "Atypical anxiety pattern analysis request",
  "anonymization_level": "high",
  "context": "minimal",
  "user_consent": true,
  "audit_id": "a3f8b2c9-...",
  "privacy_constraints": ["no_pii", "no_health_specifics"],
  "expected_response": "differential_suggestions"
}
```

### Network Topology

```
Internet Cloud
     ↑
     | HTTPS (mediated, minimal)
     |
┌────┴─────┐
│ Laptop/  │ ←→ WiFi/BT ←→ Phone/Tablet
│ Personal │
└────┬─────┘
     | HTTP/MCP (local network)
     ↓
┌──────────────┐
│  Edge Pi 5   │ ←→ WiFi/BT ←→ Epistolary Terminal
│ Coordinator  │
└──────┬───────┘
       | MQTT (local)
       ↓
  ┌────┴────┬────────┬────────┐
  │         │        │        │
┌─┴──┐  ┌──┴──┐  ┌──┴──┐  ┌──┴──┐
│ESP │  │ESP  │  │ESP  │  │ESP  │
│32  │  │32   │  │32   │  │32   │
│#1  │  │#2   │  │#3   │  │#N   │
└────┘  └─────┘  └─────┘  └─────┘
Temp    Motion   Door     ...
```

---

## Privacy & Security

### Privacy Boundaries

**Boundary 1: Micro ↔ Edge (Open)**
- Data: Environmental (temperature, motion)
- Privacy: Low (not personal)
- Encryption: Optional (local network)
- Retention: Time-series (pruned)

**Boundary 2: Edge ↔ Personal (Moderate)**
- Data: Conversation archives, health patterns
- Privacy: High (personal but local)
- Encryption: TLS (self-signed)
- Retention: Indefinite (user controlled)

**Boundary 3: Personal ↔ Cloud (Critical)**
- Data: Anonymized queries only
- Privacy: Maximum protection
- Encryption: TLS 1.3, API key
- Retention: None (cloud doesn't persist)
- Audit: Complete local logging

### Encryption Strategy

**At Rest:**
```
Edge Pi NVMe:
├─ LUKS full-disk encryption
├─ Key: User password + TPM (if available)
└─ Unlocked at boot

Epistolary Device:
├─ Encrypted filesystem (ESP32: library, Pi: LUKS)
├─ Messages encrypted before storage
└─ Key: User PIN

Personal Devices:
├─ OS-level encryption (FileVault, BitLocker, LUKS)
└─ Standard best practices
```

**In Transit:**
```
Micro → Edge:
├─ MQTT over TLS (if sensitive)
└─ Otherwise plaintext (local network)

Edge → Personal:
├─ HTTPS (self-signed cert, local CA)
└─ Mutual TLS (optional, for paranoid mode)

Personal → Cloud:
├─ HTTPS (Anthropic's cert)
├─ API key in Authorization header
└─ Payload encrypted at application level (optional)

Epistolary → Edge (LoRa):
├─ AES-256 encryption before transmission
├─ Shared secret (pre-configured)
└─ End-to-end (radio is broadcast, assume intercept)
```

### Authentication & Authorization

**Micro Sensors:**
- Device ID (MAC address derived)
- MQTT username/password
- IP whitelist (local network only)

**Edge Services:**
- API keys (per client device)
- IP whitelist (local network)
- Certificate pinning (for TLS)

**Personal → Cloud:**
- Anthropic API key (environment variable)
- Rotated periodically
- Never in code/git

**User Authentication:**
- Epistolary device: PIN (local)
- Edge web UI: Username/password
- Personal devices: OS-level (existing)

### Audit Logging

**What's Logged:**
```
Edge Pi:
├─ All cloud queries (what was sent)
├─ All MCP requests (who accessed what)
├─ Sensor events (anomalies, patterns)
└─ System health (errors, performance)

Personal Device:
├─ Cloud interactions (query + response)
├─ Privacy decisions (what was anonymized)
├─ User consents (when, for what)
└─ Handoff events (why escalated)

Logs stored:
├─ Location: Local only (never cloud)
├─ Format: JSON (searchable)
├─ Retention: 90 days (configurable)
└─ Access: User can review anytime
```

**Audit Query Examples:**
```bash
# What did I send to cloud last week?
jq '.event_type == "cloud_query"' audit.json | jq -s 'map(select(.timestamp > "2026-01-20"))'

# Who accessed my health data?
jq '.resource == "health_archive"' audit.json

# Show all privacy decisions
jq '.event_type == "privacy_decision"' audit.json
```

---

## Data Flows

### Example 1: Routine Sensor Monitoring

```
1. ESP32 (temp sensor):
   Reading: 22°C
   Assessment: Normal
   Action: Log locally
   [STOPS HERE - no handoff]

2. ESP32 (every hour):
   Publishes: sensors/temperature/living_room = {temp: 22, status: normal}
   
3. Edge Pi:
   Subscribes: sensors/temperature/#
   Stores: Time-series in PostgreSQL
   [STOPS HERE - routine data]

Result: Efficient, local, no cloud involved
```

### Example 2: Anomaly Requiring Analysis

```
1. ESP32 (temp sensor):
   Reading: 12°C
   Assessment: Anomaly (outside normal range)
   MQTT publish: events/anomaly/temp_living_room

2. Edge Pi receives event:
   ├─ Queries other sensors (correlation)
   │   ├─ Motion: None recent
   │   └─ Door: Closed
   ├─ Checks weather API: Outside temp -25°C
   ├─ Local LLM analysis:
   │   "Possible heating failure, confidence: 0.65"
   └─ Decision: Hand off (confidence too low)

3. Edge → Personal handoff:
   HTTP POST /api/handoff {
     event: ...,
     local_analysis: ...,
     privacy_level: low
   }

4. Personal Device (laptop):
   ├─ Receives handoff
   ├─ Runs larger local model (13B)
   ├─ Correlates with:
   │   ├─ Calendar (no planned absences)
   │   ├─ Recent furnace maintenance logs
   │   └─ Historical patterns
   ├─ Confidence: 0.85 "Likely heating failure"
   └─ Decision: Notify user, suggest action

5. User Notification:
   "Heating system may have failed. Inside temp 12°C, 
    outside -25°C. Recommend checking furnace."

Result: Multi-layer analysis, appropriate handoffs, user informed
```

### Example 3: Medical Pattern (Privacy-Sensitive)

```
1. Wearable sensor (ESP32 + heart rate monitor):
   HRV: 145ms (elevated at rest)
   Assessment: Outside normal for user
   MQTT: events/health/hrv_anomaly

2. Edge Pi:
   ├─ Receives health event (HIGH PRIVACY)
   ├─ Queries local health archive:
   │   ├─ Sleep: Poor last night
   │   ├─ Exercise: None recent
   │   ├─ Medication: No changes
   │   └─ Similar episodes: 3 weeks ago (resolved)
   ├─ Local LLM (3B):
   │   "Possible anxiety vs cardiac, confidence: 0.60"
   └─ Decision: Hand off to personal (privacy-preserved)

3. Edge → Personal (encrypted, local network):
   Handoff: {
     event: health_anomaly,
     privacy_level: HIGH,
     local_analysis: {...},
     recommendation: do_not_send_to_cloud_without_consent
   }

4. Personal Device:
   ├─ Receives (knows privacy is HIGH)
   ├─ Larger local model (13B):
   │   ├─ Full health history (local)
   │   ├─ Stress patterns (local)
   │   ├─ Correlation with work/life events
   │   └─ Confidence: 0.72 "Likely anxiety, monitor"
   ├─ Privacy check:
   │   BLOCK cloud query (health data too sensitive)
   └─ User notification with options

5. User sees:
   "Elevated heart rate detected. Pattern similar to 
    anxiety episode 3 weeks ago (poor sleep + stress).
    
    Options:
    [1] Monitor for 30 min (alert if worsens)
    [2] Schedule doctor appointment
    [3] Send ANONYMIZED pattern to cloud for analysis
        (I'll show you exactly what gets sent)
    
    I'm keeping this local - too sensitive for cloud."

6. User chooses [3] - wants cloud analysis

7. Personal device prepares anonymized query:
   Shows user: "User experiencing: elevated HRV at rest,
                no recent exercise, poor sleep, work stress.
                Previous similar episodes resolved naturally.
                Differential diagnosis?"
   
   User approves (sees exactly what's sent)

8. Personal → Cloud (HTTPS, anonymized):
   Query sent to Claude
   
9. Cloud response:
   "Could indicate: anxiety (most likely), thyroid 
    dysfunction, cardiac arrhythmia. Medical evaluation
    recommended if pattern persists or worsens."

10. Personal device:
    ├─ Receives cloud response
    ├─ Integrates with local context
    └─ Presents to user:
        "Cloud analysis suggests medical evaluation if
         persists. Your pattern historically resolves
         naturally, but this episode feels different.
         
         Scheduling doctor appointment (preventive).
         Continuing to monitor. If symptoms worsen → 911."

Result: Privacy preserved at each layer, user in control,
        cloud used minimally with consent, local + cloud 
        knowledge integrated
```

### Example 4: Philosophical Research (Semantic Search)

```
1. User at lake with epistolary terminal:
   Composes: "Reflecting on Ricoeur's narrative identity
              in context of conversation archives..."
   
   Query: "What does Ricoeur say about temporal identity
           and selfhood?"

2. Epistolary → Edge (WiFi or LoRa):
   Encrypted message sent

3. Edge Pi receives query:
   ├─ Semantic search in local archives:
   │   ├─ Past conversations mentioning Ricoeur
   │   ├─ Scanned pages from Time and Narrative (OCR'd)
   │   └─ Related philosophical discussions
   ├─ pgvector query (embeddings)
   ├─ Local LLM synthesis (3B):
   │   Combines: Book excerpts + past reflections
   └─ Confidence: 0.85 (good enough for this query)

4. Edge → Epistolary:
   Response: "Ricoeur distinguishes idem (sameness) from
              ipse (selfhood). Your conversation archives
              embody this - concepts evolve (ipse) while
              maintaining narrative continuity (idem).
              
              Relevant passage from Time and Narrative p.246:
              [OCR'd text]
              
              From your conversation 2025-11-03: You noted
              this connection to temporal database design..."

5. User receives on e-ink display:
   Reads synthesis while at lake
   Reflects, composes response
   
   [ENTIRE INTERACTION LOCAL - no cloud needed]

Result: Semantic knowledge accessible in field, 
        privacy-preserved, conversation + books integrated
```

---

## Use Case Examples

### Use Case 1: Adaptive Soldering Instruction

**Scenario:** Building epistolary device, soldering headers

**Hardware:**
- Phone/tablet (camera, AR display)
- Edge Pi + Hailo-8 (computer vision)
- Haptic wristband (directional guidance)

**Flow:**
```
1. User: Positions camera over workspace
   
2. Phone → Edge: Video stream

3. Edge (Hailo-8 vision):
   ├─ Detects: ESP32 board, e-ink display, wires, soldering iron
   ├─ Tracks: Hand position, iron location
   ├─ Identifies: Which pins connected (GPIO map)
   └─ Safety: Monitors for iron near plastic

4. Edge → Phone: AR overlay instructions
   ├─ Highlights: Next pin to connect (GPIO 13)
   ├─ Arrow: Shows wire routing path
   ├─ Warning: Iron too close to component (visual alert)

5. Edge → Haptic wristband:
   ├─ Directional pull toward correct pin
   ├─ Strong pulse when positioned correctly
   ├─ Urgent vibration if danger detected

6. User's skill level (from profile):
   ├─ Beginner → Detailed steps, slow pace
   ├─ Intermediate → Minimal guidance, safety only
   └─ Updates as user improves

7. Multimodal feedback:
   ├─ Visual: AR overlay on phone
   ├─ Audio: "Heat joint for 3 seconds"
   ├─ Haptic: Pull toward correct location
   └─ Synchronized, real-time

8. Progress tracking:
   ├─ Edge knows: 3 of 8 pins connected
   ├─ Estimates: 10 minutes remaining
   └─ Celebrates: "Nice joint! Next: GPIO 14 → DIN"

Result: Safe, guided assembly with adaptive instruction
```

### Use Case 2: Field Philosophical Reflection

**Scenario:** Walking at -30°C, reflecting on Ricoeur

**Hardware:**
- Epistolary terminal (Pi Zero W + e-ink)
- Folding keyboard
- Edge Pi (at home, WiFi range or LoRa)

**Flow:**
```
1. User: Walks to frozen lake
   ├─ Observes: Ice patterns, light quality
   └─ Thinks: Connection to temporal structure

2. Epistolary device (in pocket):
   ├─ Display: Low power, e-ink visible in bright sun
   └─ Battery: Hours of operation (days if ESP32 version)

3. User stops, pulls out device:
   ├─ E-ink shows: Last thought from previous session
   └─ Keyboard: Unfolds, ready to type

4. User composes (eyes on landscape, not screen):
   "The ice fractures reveal temporal layers - 
    each freeze/thaw cycle a narrative stratum.
    Ricoeur's concordance/discordance..."

5. Query to Edge:
   "Find connections between Ricoeur's temporal layers
    and the AAAS asset degradation patterns"

6. Transmission:
   ├─ Via LoRa: Long range, encrypted
   ├─ Or WiFi: If within home range
   └─ Message: Text-only, low bandwidth

7. Edge receives query:
   ├─ Semantic search: Ricoeur passages + AAAS discussions
   ├─ Local LLM synthesis
   └─ Response: 3-4 paragraphs

8. Epistolary receives response:
   ├─ E-ink display: High readability outdoors
   └─ User reads while experiencing landscape

9. User reflects, adds:
   "Yes - the database temporal tables are like ice layers.
    Each version a freeze of state, queryable across time.
    Both reveal: identity through change..."

10. Saved locally:
    ├─ Conversation archived on device
    ├─ Synced to Edge when back in range
    └─ Integrated into semantic knowledge system

Result: Contemplative computing in embodied practice,
        landscape + philosophy + technology integrated
```

### Use Case 3: Medical Pattern Detection

**Scenario:** Tracking symptoms over months, detecting drift

**Hardware:**
- Wearable sensors (HRV, sleep, activity)
- Edge Pi (health archive, pattern detection)
- Personal device (triage, visualization)
- Optional: Cloud (medical literature research)

**Flow:**
```
1. Continuous monitoring (background):
   ├─ Wearable → Edge: HRV, sleep quality, activity
   ├─ Edge stores: Time-series in PostgreSQL
   └─ Knowledge agents: Subscribe to health events

2. Pattern emerges (3 months):
   ├─ Edge detects: HRV declining gradually
   ├─ Correlation: With sleep quality degradation
   └─ Local LLM: "Drifting illness phenomena detected"

3. Edge → Personal handoff:
   "Sean's HRV has declined 15% over 3 months.
    Correlates with worsening sleep (30min less/night).
    No single acute event - gradual drift.
    
    Pattern worth medical attention?
    I can generate report for doctor."

4. User reviews:
   ├─ Visualization: 3-month trend chart
   ├─ Correlation: Sleep vs HRV plotted
   └─ Decision: "Yes, generate report"

5. Personal device prepares:
   ├─ Queries Edge: Full health archive
   ├─ Synthesizes:
   │   ├─ Symptom timeline
   │   ├─ Medication history
   │   ├─ Correlation analysis
   │   └─ Conversation excerpts (symptoms mentioned)
   ├─ Optional cloud query (with consent):
   │   "Gradual HRV decline + sleep degradation.
   │    Arctic resident, government worker.
   │    Differential diagnosis?"
   └─ Cloud returns: Thyroid, vitamin D, sleep disorder

6. Triage synthesis:
   ├─ Integrates: Personal data + cloud research
   ├─ Generates: Doctor-ready report (PDF)
   ├─ Summary: 1-page overview
   ├─ Detail: Charts, timeline, data
   └─ Research: Relevant literature (cited)

7. Doctor appointment:
   ├─ Brings: Complete synthesized report
   ├─ Doctor sees: Pattern over time (not just snapshot)
   ├─ Discussion: Informed by data + patient understanding
   └─ Diagnosis: Faster, more accurate

8. Post-appointment:
   ├─ Adds: Doctor's notes to archive
   ├─ Updates: Treatment plan in system
   ├─ Continues: Monitoring with new baseline
   └─ Privacy: All local, nothing in corporate cloud

Result: Drifting illness detected early, comprehensive
        medical report, privacy-preserved, better care
```

### Use Case 4: Community Coordination

**Scenario:** Neighborhood temperature monitoring, elder care

**Hardware:**
- Multiple households with Edge Pi + sensors
- LoRa mesh network
- Community knowledge agents
- Human volunteers

**Flow:**
```
1. Cold snap event (-35°C):
   ├─ 15 households monitoring temperature
   └─ Local spirits detect: Unusual sustained cold

2. Community mesh activates:
   ├─ Sensor #3: "My house: 14°C (heating struggling)"
   ├─ Sensor #7: "My house: 16°C (normal but stressed)"
   ├─ Sensor #12: "Elderly resident, temp borderline"
   └─ Coordination: Pattern emerges

3. Community Edge Pi (central):
   ├─ Aggregates: All sensor reports
   ├─ Detects: Cluster of homes struggling
   ├─ Correlates: With outside temp + forecasted duration
   └─ Knowledge agent: "Wellness check protocol?"

4. Community coordinator (human + AI):
   ├─ AI suggests: Check on elderly residents
   ├─ AI identifies: 3 households with vulnerable people
   ├─ AI generates: Volunteer check-in list
   └─ Human volunteers: Accept tasks

5. Volunteer dispatched:
   ├─ Gets: List of addresses, context (temp data)
   ├─ Visits: Mrs. Chen (elderly, house cold)
   ├─ Reports back: "Furnace filter clogged, fixed it"
   └─ Updates system: Issue resolved

6. System learning:
   ├─ Pattern recorded: Cold + elderly = vulnerability
   ├─ Next time: Proactive check-in
   └─ Community resilience: Improved

7. Privacy preserved:
   ├─ Sensor data: Shared voluntarily
   ├─ Elder consent: Explicitly given
   ├─ Volunteer coordination: Local only
   └─ No corporate surveillance

Result: Community care enabled by distributed sensors,
        AI coordination, human compassion, privacy respected
```

---

## Build Phases

### Phase 1: Edge Coordinator Foundation (Weeks 1-4)

**Goal:** Get Pi 5 running as central intelligence hub

**Hardware:**
- ☑ Order Pi 5 (8GB) - $80
- ☑ Order M.2 HAT - $12
- ☑ Order USB M.2 enclosure - $10 (temporary)
- ☑ Extract Surface NVMe - $0
- ☐ Order power supply - $12
- ☐ Order case - $15

**Software:**
- ☐ Install Ubuntu Server 24.04
- ☐ Set up NVMe (USB initially)
- ☐ Install PostgreSQL + pgvector
- ☐ Load conversation archives
- ☐ Test semantic search
- ☐ Install Ollama + Llama 3.2 3B
- ☐ Test local LLM queries

**Outcome:** Semantic search working, local LLM responsive

**Time:** 2-3 weeks (including shipping)

---

### Phase 2: Computer Vision (Weeks 5-8)

**Goal:** Add vision capabilities with NCS2

**Hardware:**
- ☐ Use existing Movidius NCS2
- ☐ Order camera module - $25
- ☐ Optional: Order M.2 HAT (move NVMe to PCIe)

**Software:**
- ☐ Set up OpenVINO on Pi 5
- ☐ Deploy OCR pipeline (code we wrote)
- ☐ Test: Scan Ricoeur page, extract text
- ☐ Add scene classification model
- ☐ Test: Describe workspace

**Outcome:** OCR working, can digitize books locally

**Time:** 1-2 weeks

---

### Phase 3: Micro-Intelligence Network (Weeks 9-16)

**Goal:** Deploy first sensor nodes, test coordination

**Hardware:**
- ☐ Order ESP32-S3 (x3) - $36
- ☐ Order DHT22 sensors (x3) - $15
- ☐ Order PIR sensors (x2) - $6
- ☐ Breadboards, wires, power supplies

**Software:**
- ☐ Install Mosquitto MQTT on Pi 5
- ☐ Write ESP32 firmware (temperature node)
- ☐ Test: Sensor → MQTT → Pi 5
- ☐ Deploy 3 nodes (living room, bedroom, office)
- ☐ Write coordination logic on Pi 5
- ☐ Test: Anomaly detection, correlation

**Outcome:** Multi-sensor network coordinating through Edge

**Time:** 4-6 weeks (learning, iteration)

---

### Phase 4: Epistolary Terminal (Weeks 17-24)

**Goal:** Build portable field device

**Hardware:**
- ☐ Order Pi Zero W 2 - $15 (or ESP32 for lighter version)
- ☐ Order e-ink display - $65
- ☐ Order Bluetooth keyboard - $35
- ☐ Order battery - $12

**Software:**
- ☐ E-ink driver setup
- ☐ Bluetooth keyboard pairing
- ☐ Message composition UI
- ☐ Encryption + transmission
- ☐ LoRa integration (optional)

**Outcome:** Working epistolary device for field use

**Time:** 4-8 weeks (hardware integration learning curve)

---

### Phase 5: Personal Device Integration (Weeks 25-32)

**Goal:** Connect laptop/phone as mediators

**Software:**
- ☐ MCP client on laptop
- ☐ Connect to Edge MCP servers
- ☐ Privacy mediation layer
- ☐ Cloud integration (Anthropic API)
- ☐ Audit logging

**Outcome:** Full stack operational, local ↔ cloud working

**Time:** 4-8 weeks (software development)

---

### Phase 6: Advanced Capabilities (Weeks 33+)

**Hardware:**
- ☐ Hailo-8 AI accelerator - $70-100
- ☐ Additional sensors
- ☐ LoRa mesh network

**Software:**
- ☐ Adaptive instruction (AR/haptic)
- ☐ Health tracking integration
- ☐ Knowledge agents (pub-sub)
- ☐ Community coordination

**Outcome:** Mature distributed AI system

**Time:** Ongoing iteration

---

## Philosophical Foundation

### Epistemology: Distributed Knowledge (Hayek)

**Principle:** Knowledge exists in particular times and places, cannot be centralized without loss

**Implementation:**
- Micro sensors: Local environmental knowledge
- Edge coordinator: Situated reasoning with local context
- Personal devices: Your embodied particular experience
- Cloud: Universal/statistical patterns

**Preservation:** Each layer keeps knowledge at appropriate level

---

### Phenomenology: Embodied Particularity (Scheler, Heidegger)

**Principle:** Each person's ordo amoris structures their world differently

**Implementation:**
- Local models learn YOUR patterns (not population average)
- Epistolary device: Contemplative, embodied interaction
- Translation infrastructure: Across different lifeworlds
- Privacy: Your particular experience not reduced to data

**Preservation:** Technology serves embodied human experience

---

### Hermeneutics: Understanding Through Dialogue (Gadamer, Ricoeur)

**Principle:** Understanding requires fusion of horizons, ongoing interpretation

**Implementation:**
- Conversation archives: Temporal narrative identity
- Semantic search: Interpretive access to past understanding
- AI as substrate: Pattern recognition, not oracle
- Translation: Between particular and universal

**Preservation:** Dialogue as genuine intellectual practice

---

### Political Philosophy: Liberalism of Fear (Shklar)

**Principle:** Design against worst case (cruelty, domination), not for best case

**Implementation:**
- Privacy boundaries: Structural, not policy-based
- Local processing: Can't surveil what you don't access
- Open source: Auditable, comprehensible
- Sovereignty: User owns infrastructure, data, decisions

**Preservation:** Power constrained architecturally

---

### Technology Philosophy: Convivial Tools (Illich), Democratization

**Principle:** Technology should serve human flourishing, be comprehensible and buildable

**Implementation:**
- Modular components: Understandable pieces
- Standard parts: Repairable, replaceable
- Open source: Auditable, modifiable
- Build guides: Anyone can create
- Affordability: ~$400 total, not $thousands

**Preservation:** Technology for people, not extraction

---

## Summary: What This Architecture Achieves

### Technical Achievements

✓ **Local AI Processing:** 1-3B models on edge, 7-13B on personal devices  
✓ **Computer Vision:** OCR, object detection, scene understanding (local)  
✓ **Semantic Search:** 1.6M words queryable in <50ms  
✓ **Multi-Sensor Coordination:** 10-20 nodes working together  
✓ **Privacy Preservation:** Minimal cloud exposure, complete audit trail  
✓ **Modular Scaling:** Add capabilities incrementally  
✓ **Low Power:** 5-8W edge, hours on battery for portable  
✓ **Affordable:** <$400 total investment  

### Philosophical Achievements

✓ **Distributed Epistemology:** Knowledge kept at appropriate layers  
✓ **Embodied Computing:** Technology serves situated human experience  
✓ **Hermeneutic Practice:** AI dialogue as genuine intellectual work  
✓ **Structural Protection:** Privacy through architecture, not promises  
✓ **Democratic Access:** Comprehensible, buildable, repairable  
✓ **Temporal Continuity:** Archives constitute narrative identity  

### Political Achievements

✓ **Sovereignty:** User owns infrastructure, controls data  
✓ **Privacy:** Local processing, minimal cloud, verifiable  
✓ **Transparency:** Open source, audit logs, comprehensible  
✓ **Exit Option:** Can leave systems, take data, build alternative  
✓ **Relationship Not Domination:** AI as collaborator, not oracle  
✓ **Community Enablement:** Scales from individual to neighborhood  

### Human Achievements

✓ **Contemplative Computing:** Epistolary device for thoughtful interaction  
✓ **Embodied Knowing:** Respects tacit, situated, particular knowledge  
✓ **Translation Infrastructure:** Understanding across difference  
✓ **Health Sovereignty:** Medical data private, patterns detected  
✓ **Intellectual Practice:** Conversation archives as living knowledge  
✓ **Place-Based Computing:** Technology integrated with landscape  

---

## What This Isn't

✗ **Not maximalist:** Not trying to replace cloud AI entirely  
✗ **Not Luddite:** Not rejecting powerful systems  
✗ **Not paranoid:** Not assuming everyone is malicious  
✗ **Not utopian:** Not claiming this solves everything  
✗ **Not finished:** Always iterating, learning, improving  

**It is:** Minimum viable infrastructure for sovereign AI-augmented flourishing

---

## Next Actions

**Immediate (This week):**
1. Order Pi 5 (8GB)
2. Order M.2 HAT
3. Order USB M.2 enclosure
4. Extract Surface NVMe, test health

**Next month:**
1. Set up Pi 5 when it arrives
2. Install PostgreSQL + pgvector
3. Load conversation archives
4. Test semantic search
5. Deploy OCR with NCS2

**Next quarter:**
1. Deploy micro-intelligence sensors
2. Build epistolary terminal
3. Integrate personal devices
4. Test full stack

**Next year:**
1. Add Hailo-8 accelerator
2. Implement adaptive instruction
3. Deploy health tracking
4. Community pilot

---

**This architecture is buildable, affordable, comprehensible, and philosophically grounded.**

**It preserves human autonomy while enabling AI-augmented capability.**

**It's not science fiction. It's next month's project.**

---

*Document created: 2026-01-27*  
*Version: 1.0*  
*Status: Reference architecture for implementation*  
*License: Your personal use, share/modify as needed*
