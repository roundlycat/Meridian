# Spatially-Grounded Contextual Intelligence
## A Research Statement — Draft 0.1

*Sean Kissick — Whitehorse, Yukon — May 2026*

---

### The Problem

Most information systems treat data as portable and context-free. A record exists in a database; a user queries it; it arrives on a screen. The spatial, temporal, and relational context in which that record was created — the place, the moment, the decision it accompanied — is stripped away in storage and absent at retrieval.

This works adequately for many purposes. It fails when the person who needs the information is standing *in* the situation the data describes, making a time-pressured decision in a physical environment with a specific role and a specific need. The nurse checking a medication log, the grader operator approaching a known frost-heave zone, the repair crew inspecting infrastructure with an unknown failure history — these people need not just data, but the *right* data, *located* in space, *navigable* through time, and *filtered* for relevance by role and context.

No current system does all of this together. Parts exist separately. The combination does not.

---

### The Proposed Architecture

The work described here develops an integrated system with three core properties:

**1. Spatial anchoring**
Information lives at the physical thing it describes. A maintenance note attaches to the pipe junction. A decision record attaches to the medication cabinet. A road condition history attaches to kilometre 340 of a highway. Navigation to the information is navigation to the place — in augmented reality, this means the data appears when you are present.

**2. Temporal navigability**
The space carries its own history. A timeline scrubber allows a user to move forward and backward through accumulated records, decisions, repairs, sensor readings, and events. The space becomes narratively intelligible — it has a before and after, a sequence of causally connected moments. This is not a log viewer overlaid on a map; it is the space itself rendered as a temporal object.

**3. Role-contextual relevance filtering**
The decisive novel element. It is not sufficient to restrict access by role. The system must determine, for this person in this place at this moment, which of the available information streams is causally relevant to their current situation. Weather data is irrelevant inside a building *except* when a causal pathway connects it to the present moment: a lightning storm caused a brownout that caused a medication fridge temperature excursion. The AI layer identifies that pathway and surfaces the weather event in the nurse's view. The same event is invisible to the grader operator unless it affected road conditions.

This relevance filtering operates across data sources, across time, and across spatial scales. It requires a semantic layer capable of representing causal relationships between heterogeneous data types.

---

### The Building Blocks — Already in Production

This is not a theoretical proposal. The component systems exist and are operational.

**The AAAS Asset Management System** is a production asset management platform developed for a Canadian government jurisdiction, described as among the most advanced in comparable Canadian jurisdictions. It manages physical asset records, inspection histories, maintenance decisions, and lifecycle data. It is the asset graph that the spatial layer will render.

**The Meridian Sensor Ecology** is a distributed sensor network combining ESP32 and Raspberry Pi edge nodes, a PostgreSQL/pgvector database with semantic embedding, a Unity AR motif graph visualization, and a generative interpretive layer. Sensor readings are embedded and stored as vectors; motifs emerge from pattern clustering; the ecology develops an interpretive vocabulary over time. The philosophical framework is autopoietic — the ecology is treated as a developing entity whose interpretive vocabulary reflects lived experience rather than static authorship.

**The Semantic Twin** is a pgvector-based archive of the research process itself — conversations, decisions, and architectural reasoning across multiple AI collaborators (Claude, Gemini, Copilot). It implements sliding-window chunking and multi-source ingestion. It demonstrates that the same vector-proximity architecture that drives motif formation in the ecology can preserve and retrieve the reasoning behind decisions — the *why* alongside the *what*.

**The AR deployment layer** targets Meta Quest 3 with Unity as the development environment, combining colour passthrough mixed reality with spatial anchoring. Proof-of-concept work with ArcGIS-style temporal overlay has validated the time-navigation model. The current phase integrates mesh scanning (photogrammetry), blueprint overlays, and live sensor data into a single navigable scene.

---

### The Research Questions

1. **Relevance inference**: Can an AI layer reliably determine cross-domain causal relevance in real time — identifying, for instance, that a weather event is relevant to a medication record but not to a road maintenance record — without false positives that create noise or false negatives that suppress critical information?

2. **Temporal coherence in spatial AR**: What interaction models allow a user to navigate time within a spatially-anchored AR environment without losing orientation in physical space? How does the temporal scrubber interact with presence?

3. **Edge-viable semantic processing**: The system must function at the edge — in remote highway infrastructure, in buildings without reliable connectivity. What is the minimum viable semantic layer for relevance filtering that can operate on edge hardware (ESP32, Raspberry Pi, Meta Quest on-device)?

4. **Structural data transmission**: Can purposeful acoustic transmission through in-situ infrastructure (PVC conduit, pipe networks, structural members) serve as a low-bandwidth, no-radio data bus for sensor nodes? Under what conditions does direct-contact vibration encoding provide reliable transmission without electromagnetic emission?

5. **Role vocabulary and contextual identity**: How should roles be represented to support relevance filtering that goes beyond access control? A role is not just a permission set — it is a situational context that determines which causal chains are actionable for this person.

---

### Why the Combination Is the Contribution

Each component, taken separately, has precedents. Vector databases exist. AR spatial anchoring exists. Temporal GIS exists. Role-based access control exists. Sensor ecologies exist.

The contribution is in the integration: a system where the semantic embedding layer that drives sensor motif formation in a garden ecology is *the same architecture* as the relevance filter for a hospital medication record or a highway infrastructure inspection. The philosophical framework — treating the space as a developing narrative entity with an evolving interpretive vocabulary — is not decorative. It is the design principle that makes the components coherent rather than merely assembled.

The immediate prototype is a backyard garden in Whitehorse, Yukon: a 243 × 434 cm space with a shed, two raised beds, a PVC conduit infrastructure layer, and a single soil moisture sensor feeding into a live ecology. The grader operator on the Alaska Highway and the nurse in a northern health centre are the same system at a larger scale, with a richer asset graph and a more complex role vocabulary.

---

### Current Status and Near-Term Work

- Meridian sensor ecology: operational, motif graph active, AR layer in development
- AAAS system: production deployment, v3
- Semantic Twin: operational, 377 conversations archived
- Garden prototype: site-planned, PVC infrastructure layer in preparation, first sensor deployment imminent
- AR/Unity layer: mesh scanning and blueprint overlay in progress
- Acoustic transmission experiment: scoped, pending hardware assembly
- A1 3D printer: commissioned (filament pending), first use case: weatherproof edge sensor cases

---

### A Note on Method

This work has been developed through sustained AI-collaborative research — an 18-month practice of structured dialogue with Claude, Gemini, and Copilot as distinct intellectual partners, each contributing differently to architectural coherence, generative momentum, and code development. The Semantic Twin is both a tool within the system and a record of the system's own development. The research method and the research subject are, in this sense, continuous.

---

*This document is a working draft. Corrections and expansions welcome.*
