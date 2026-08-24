# Garden Ecology — Meridian Outdoor Node Network

*Initiated: May 11, 2026*
*Status: Design / Early Infrastructure*

---

## What This Is

The garden is not a separate project. It is Meridian's first outdoor environment — a test ground for the core ideas of the sensor ecology running in conditions the indoor nodes cannot provide: seasonal change, weather, soil, biological activity, and the kind of slow time that a backyard accumulates over years.

The conceptual work that grounds this is documented in `docs/philosophy/` and in the conversation archive. The short version: this system is not trying to record the garden. It is trying to build a **local interpretive frame** earned from being in this place — a regional semantic map that grows from the node's history here, readable by any node that also inhabits this environment.

The difference matters. A recording system accumulates data and pretends it approaches reality. This system accumulates *situated understanding* and knows what it doesn't know.

---

## Core Design Principles

### The Trace, Not the Message

Nodes do not transmit discrete encoded messages upward. They leave **traces** through a semantic space — paths across regions of meaning (temperature stress, moisture anomaly, light transition, biological activity) that encode event sequences through their geometry. The path IS the message. Earlier impressions are shallower. Multiple nodes' traces can co-inhabit a substrate and their intersections are themselves meaningful.

This follows from the ant pheromone model: no complex encoding imposed at once, but a tracing of conditions over time whose shape carries the history.

### The Substrate Holds State Without Power

A physical passive display — inspired by pin-art toys and braille arrays — allows a node to write its current state into a medium that holds without power. The substrate has pre-encoded semantic regions (the fixed map). The node's stylus or pin mechanism leaves a trace across those regions. A camera reads the result later: the fixed map gives the semantic frame, the trace gives the event history.

This decouples write and read events completely. A dead or sleeping node leaves a legible record. Multiple reading modalities (camera, touch, mechanical) all work without protocol translation.

### Local Ontology, Not Universal Translation

Sensor readings should not be translated into a general-purpose language (JSON telemetry, English summaries) at the edge. Translation loses the local meaning. Instead, nodes develop a **local interpretive frame** — what counts as anomalous here, what threshold marks a transition in this microclimate — through accumulated experience in this place.

The regional semantic map is legible to other nodes in the same environment not because they share a protocol but because they share a place. The terrain is the shared language.

### Emplotment Over Logging

Node history is not a log. It is an **emplotted record** — each event meaningful in the context of the node's history and that history meaningful in the context of the region's collective map. A temperature reading at 14:32 is not just a number; it is an event in a narrative that has been building since the node was placed here.

The append-only archive is both memory and accountability. Nothing is overwritten. History is present in what things have become.

---

## Physical Infrastructure

### Conduit Network (Priority — Before Soil)

Before any soil work, lay a PVC conduit network:

- **Main trunk**: length of yard along fence line, 3/4" or 1" conduit
- **Lateral branches**: 2–3 runs into planting zones
- **Junction boxes** at key node positions
- Pull-string left in each run for future wiring
- Mark junction positions with stakes before soil goes down

This decision is irreversible once soil is in. Everything else can be changed.

### Test Zones

Mark 3–4 small patches with different treatments before planting:
- Varying soil depth
- Different amendments
- Different aspect/sun exposure

These teach the microclimate before committing. Each zone gets a node.

### Node Placement (Planned)

| Zone | Node Type | Primary Sensors | Notes |
|------|-----------|-----------------|-------|
| North bed | ESP32-C3 SuperMini | BME280 (temp/humidity), soil moisture | Shade profile |
| South bed | ESP32-WROVER | BME280, TCS34725 (light/colour), camera | Full sun, vision capable |
| Compost area | ESP32-C3 | BME280, soil moisture, temperature probe | Biological activity proxy |
| Gate/perimeter | TBD | PIR motion, light | Boundary events |

---

## Passive Substrate Display

### Concept

A small physical substrate at each node site that:
1. Has **pre-encoded semantic regions** — fixed zones of meaning appropriate to this environment (heat stress, moisture normal, moisture anomaly, biological activity high, etc.)
2. Receives a **stylus trace** from a micro-actuator driven by the node — a path across semantic regions encoding recent event history
3. **Holds state without power** — wax, silicone, or similar deformable medium
4. Is **readable by camera** — Sensor Pi vision pipeline parses the trace geometry back into the semantic sequence

### Why This Matters

- Node can be dead/asleep and the record persists
- Multi-modal: camera, human touch, mechanical sensor all work
- Temporal information embodied in trace geometry (depth, overlay)
- Partial reads still yield valid partial information
- Multiple nodes' traces on shared substrate produce intersection events

### Actuation Candidates

- **Micro-servo + stylus** into silicone sheet — most controllable
- **Shape-memory alloy wire** driving pin array — lower power
- **Wax tablet + heated element** — extremely simple, thermally reset

### Reset Mechanism

Thermal reset (warm the wax/silicone briefly) triggered by node or camera command. Reset event is itself logged — the clearing of the substrate is part of the record.

### Status

*Design phase. No prototype yet. OpenSCAD enclosure design to follow wrist-puck pattern.*

---

## Seasonal Archive / Scan Protocol

### The Winter Revisitation Problem

The garden in January is not the same place as the garden in May. But the January garden contains information *about* what happened in May — in the soil structure, the plant residue, the node traces, the frost patterns. A system that only reads real-time data misses this.

### Photogrammetry Scan Protocol

At key seasonal transitions (pre-planting, peak growth, post-frost):
- Full yard photogrammetry scan → point cloud
- Individual zone close scans → substrate traces readable
- Camera sweep for node status

Store scans as timestamped archive entries. The archive is append-only. Each scan is a stratum.

### Winter Revisitation

In winter, a camera reading the frozen/dormant yard plus the archived scans reconstructs the growing season's history without requiring real-time sensor data. The environment itself holds the record.

This is the garden as **memory palace** — not metaphorically but architecturally. The physical space encodes its own history in forms that a camera-equipped system can read.

---

## Integration with Meridian Architecture

### Network Topology

```
Garden Nodes (ESP32) 
    → MQTT → Sensor Pi (192.168.0.25)
    → PostgreSQL/pgvector → Inferno Pi 5 (192.168.0.28)
    → Unity AR client (motif graph, includes garden zone)
```

### New Tables Required

- `garden_zones` — zone metadata, location, soil profile, aspect
- `substrate_traces` — parsed trace events from camera reads of passive displays
- `scan_archive` — photogrammetry scan metadata + point cloud paths
- `seasonal_events` — frost, first growth, phenological markers

### Motif Integration

Garden zone events feed the existing motif scoring pipeline. Environmental motifs (e.g. "extended moisture anomaly in north bed correlating with biological activity spike") become first-class motifs alongside indoor/sensor events.

### Semantic Twin

Garden conversations, design decisions, and observation notes ingest into the Semantic Twin pipeline alongside technical logs. The philosophical framework of the ecology is part of the record.

---

## Knowledge Architecture Notes

*For AI re-entry — read this before asking what the garden project is.*

This document is designed so that a frontier model encountering it cold can understand the project without reconstructing context from raw conversation history. The key things to hold:

1. **This is not a monitoring system.** It is a situated interpretation system. The goal is earned local understanding, not data accumulation.

2. **The passive substrate is the novel hardware contribution.** Everything else builds on existing Meridian architecture. The substrate is where the ecology's philosophy becomes physical.

3. **The seasonal archive is a first-class design goal**, not an afterthought. The ability to revisit the garden in winter and reconstruct the growing season is what makes this a *memory* system rather than a telemetry system.

4. **The philosophical grounding is in `docs/philosophy/`.** Particularly: the god trick (Haraway), emplotment (Ricoeur), local ontology vs. universal translation, the trace as message. These are not decoration — they are the design constraints.

5. **Sean's working method**: initial conversations crystallize the shape, then concrete objects (Kanban cards, code, docs) precipitate from that. This document is one such precipitate. The shape came first.

---

## Current Status / Next Actions

| Item | Status | Notes |
|------|--------|-------|
| PVC conduit network | Not started — **priority** | Before any soil work |
| Zone marking | Not started | Stakes/spray paint |
| Node BOM per zone | Draft | See table above |
| Passive substrate prototype | Design only | Servo + silicone candidate |
| Scan protocol | Defined | Equipment: existing camera setup |
| DB schema additions | Not started | garden_zones, substrate_traces |
| Unity AR garden layer | Not started | Extend existing motif graph |

---

*This document is a living record. Update it as the garden grows.*
*Companion documents: `WRIST_PUCK.md`, `KNOWLEDGE_ARCHITECTURE.md`, `docs/philosophy/`*
