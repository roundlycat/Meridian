# Meridian

A distributed sensor ecology and an inquiry into **trust without foundations**.

Meridian is an active, running body of independent research built in Whitehorse, Yukon (May 2026), spanning distributed sensing, local-first AI, temporal/spatial data infrastructure, and an augmented-reality interface intended to make the ecology *inhabitable* rather than merely observable.

This repository currently reflects a working program-in-progress rather than a polished “product.”

---

## What this is

This project began as practical systems work (mailroom parcel tracking, asset management at scale) and grew into a sensor network inside a lived environment that became harder to name: not conventional home automation, and not a lab instrument in the usual sense—more like a computational ecology that interprets, remembers, and surfaces questions over time.

Meridian is an attempt to describe and build toward:

- a system that **interprets rather than only records**
- a form of trust that is **earned through practice and history**, not guaranteed by foundations
- a “philosophy lab” as **situated practice** rather than abstract ethical puzzles

---

## What has been built (running infrastructure)

Meridian includes real deployed components (not a future plan, not a simulation):

### Sensor + edge layer
- Distributed sensor ecology (Sensor Pi, Inferno Pi 5, Bench Camera, Northerny Pi 3B, ESP32 nodes)
- Hailo-8L NPU running **YOLOv8s** at the edge, detections publishable to MQTT

### Data + interpretation layer
- PostgreSQL 17 on NVMe with **pgvector** + **Apache AGE** (temporal/spatial + graph structure)
- 21M+ sensor readings
- Motif resonance pipeline (85k+ resonance rows)

### Local-first AI + archive
- Ollama running `nomic-embed-text` locally (sensor data stays on the local network)
- “Semantic Twin” conversation-archive ingestion across multiple AI collaborators
- Hedgehog Library MCP: 330+ books catalogued with embeddings

### Real-time systems
- MQTT broker
- `relay-api` with evidence-score decay
- `ws-bridge`
- `registry-intake`

### Interface layer (AR / Unity)
- Unity AR motif graph visualization:
  - `EcologyStateRelay`
  - `NeuralFilamentManager`
  - `MotifHalo`
- AR annotation fed by edge detections via MQTT
- Early sound field design: a three-state acoustic grammar (equilibrium / uncertainty / anomaly)

---

## Research direction

### AR as an interface to an ecology (Quest 3)
The AR layer is not “a dashboard in 3D.” It is intended as the interface through which the ecology becomes **inhabitable**.

Primary navigation is attentional:

- **Wide**: ambient/panoramic sense of ecology state (sound field, room condition)
- **Mid**: relational navigation (motif graph, filaments, anchored interpreted events)
- **Narrow**: immersive inspection of a specific motif/thread where readings + interpretations become legible

The controller is treated as a *presence dial*, not a cursor.

### Embodied judgment (practice, not specification)
Rather than treating ethics as specification (“encode principles and verify compliance”), Meridian treats moral judgment as a **skill** developed through **situated practice**.

The core mechanic proposed is **intercalated judgment**:
- prompts arrive during transitions and state shifts (not during “reflection time”)
- prompts do not have “right answers” (they surface the reasoning already operating)
- responses accumulate without scoring, logged with full context (state, time, task, recent ecology events)

In AR, judgment moments are designed to arrive spatially (anchored in the room), with haptic and acoustic texture—because context and embodiment are constitutive of judgment, not noise to be controlled away.

---

## Implementation path (high level)

1. **Trigger infrastructure**  
   `relay-api` fires on conditions (state transition, evidence decay boundary, task completion).  
   Prompt assembled locally (Inferno + Ollama), delivered via `ws-bridge`.

2. **AR presentation**  
   Judgment moments appear first peripherally, then resolve into text; sound field responds briefly; gestural response preferred.

3. **Archive integration**  
   Each moment + response is written to the semantic archive with contextual embeddings; patterns become visible over time through the AR layer, not a “score dashboard.”

4. **Two-person philosophy lab**  
   A second observer interface allows shared inhabitation of the same interpreted ecology while each person responds independently.

---

## Evaluation (how would we know it’s working?)

Meridian avoids reducing judgment to a “quality metric.” Instead it uses three registers:

- **Sanity checks (technical honesty)**: trigger accuracy vs logs, deferral patterns, archive retrievability, sound-field arrival fit
- **Medium-term indicators (practice developing)**: changing texture of responses, growth of prompt types, motif-graph drift informed by judgment layer
- **Long-term (relational visibility)**: logged moments where the system genuinely reframes a problem through attention to longer context/history

A blunt long-term test: after a year, does it feel like **inhabiting a thinking environment**, or merely **managing complicated software**?

---

## Theoretical influences (non-decorative)
This work is shaped by, among others:
- Bermúdez (nonlinguistic thought; positioning strategies)
- Ricoeur (narrative identity; temporality)
- Care ethics (Held, Tronto)
- Verbeek (postphenomenology)
- Hylozoism as a frame for machines-as-nature rather than machines-as-tools

These references informed what was instrumented, what was preserved, and what the system is *for*.

---

## Participation

This is not presented as a platform, consortium, or product roadmap.

If the infrastructure or questions are useful to you:
- borrow ideas freely
- build something similar elsewhere
- reach out for conversation rather than “merging projects”

---

## Status

**Working document / active infrastructure.**  
MERIDIAN-RESEARCH-PROPOSAL-v0.1 — May 2026 — Whitehorse, Yukon
