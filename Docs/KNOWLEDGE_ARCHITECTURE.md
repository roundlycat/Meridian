# Knowledge Architecture — Memory Palaces for AI Collaboration

*Initiated: May 11, 2026*
*Status: Design principle — applies across all Meridian sub-projects*

---

## The Problem This Solves

Every time a frontier AI model re-enters a complex project, it faces a reconstruction problem. The context is large, the conversation history is long, the relevant decisions are scattered across many sessions, and the model's training data is already months or years out of date. The standard response to this is to make the context window larger and hope the model attends to the right parts.

This is the wrong solution.

The right solution is to stop asking AI to recall and start building structures designed for **re-entry at the interpretation level** — pre-contextualized, pre-crystallized repositories of thinking that allow a model to begin contributing immediately without reconstructing what has already been worked out.

This document describes the design principles for those structures across the Meridian project ecosystem.

---

## The Core Distinction

### Recall vs. Interpretation

**Recall** is what a model does when it searches a large unstructured context for relevant information. It is expensive, unreliable, and scales badly. The larger the context, the more noise competes with signal. The model spends its resources on assembly rather than thinking.

**Interpretation** is what a model does when it encounters a well-structured artifact that has already done the assembly work. The crystallized thinking is present. The model's task is to extend it, apply it, question it — not to reconstruct it.

The goal of knowledge architecture in this project is to push as much as possible from the recall domain into the interpretation domain. Every document in this system should be designed to enable a capable model to re-enter at interpretation speed.

### The Stale Data Problem

Frontier models are trained on data that is months or years old by the time they are deployed, and continues aging during deployment. This is not a solvable problem — it is a structural feature of how large models work. No amount of faster training or more pervasive data collection changes the fundamental situation: most of the world's current state is not in the model's weights, and what is there is decontextualized.

The response is not to try to give the model more current data (though that helps at the margin). The response is to build **local contextualized repositories** that are maintained by the people closest to the work, designed for AI access, and represent the best available understanding of the local situation. The frontier model brings interpretive power. The local repository brings current, situated knowledge. Neither is sufficient alone.

---

## Design Principles

### 1. Crystallized Thinking Over Raw Logs

Raw conversation transcripts are poor re-entry documents. They contain the full path of reasoning including dead ends, corrections, and tangents. They require a model to do the same interpretive work the original conversation did.

Well-structured documents capture the *conclusions* of that reasoning with enough framing that the model understands why those conclusions were reached. The path is abbreviated. The destination is clear. The model picks up from there.

Every project document should be written as if handing it to a capable colleague who is joining the project today. What do they need to know? What decisions have been made and why? What is still open?

### 2. Explicit Re-Entry Sections

Every major document includes a **Knowledge Architecture Notes** section written specifically for AI re-entry. This section:

- States what the document is and is not
- Flags the most common misframings to avoid
- Points to companion documents
- Notes what has changed recently if relevant

This section is not for human readers primarily (though it should be legible to them). It is the interface between the document and a model encountering it cold.

### 3. The Semantic Frame Before the Data

Context without frame is noise. A temperature reading means nothing without knowing what temperature means in this environment. A motif score means nothing without knowing what the scoring system is optimising for.

Every data-bearing document should establish the interpretive frame before presenting the data. The frame is: what are we trying to understand, what do these measurements mean here, what would count as significant.

This mirrors the local ontology principle in the sensor ecology: the semantic map comes before the trace. The frame is the map. The data is the trace.

### 4. Layered Specificity

Documents are organised so that a model can stop reading at the appropriate level of specificity:

- **Top level**: what this is, why it matters, core design principles (readable in under a minute)
- **Mid level**: current status, key decisions, integration points (sufficient for most tasks)
- **Deep level**: implementation details, component specs, schema definitions (for specific technical work)

A model asked a high-level architectural question does not need to process component tolerances. A model asked to debug a specific integration does not need to re-read the philosophical grounding. Layered structure lets the model calibrate depth to task.

### 5. The Garden Is the Test

The garden ecology project is the test environment for these principles. It is a physical system with:
- Slow time (seasonal change, not millisecond sensor readings)
- Embodied memory (the substrate trace, the photogrammetry archive)
- Local ontology (what matters here, in this microclimate, earned over time)
- AI re-entry requirement (winter revisitation — the system must be legible to a model that was not present during the growing season)

If a model can re-enter the garden project in January and make genuine sense of the May–November record without reconstructing from scratch, the knowledge architecture is working.

---

## Memory Palace Structure

The classical memory palace technique places information in imagined spatial locations so that traversal of the space retrieves the information. The principle is: **spatial and narrative structure aids retrieval** better than linear lists or flat databases.

Applied to AI-accessible repositories:

### Spatial Analogy: The Ecology as Place

The Meridian project is organised spatially rather than categorically. Documents live where their subject matter lives:

```
Meridian/
├── environments/
│   ├── garden/          — outdoor ecology, seasonal archive
│   └── interior/        — indoor nodes, established system
├── hardware/
│   ├── wrist_puck/      — embodied judgment node
│   ├── esp32_nodes/     — edge sensor nodes
│   └── passive_substrate/ — trace display hardware
├── inference/
│   ├── hailo/           — YOLOv8 pipeline
│   └── motif_scoring/   — pattern recognition
├── sound_field/         — acoustic grammar, MIDI pipeline
├── semantic_twin/       — conversation archive, pgvector
└── docs/
    ├── philosophy/      — conceptual grounding
    ├── architecture/    — system design
    └── knowledge/       — this document and companions
```

A model told "look at the garden in winter" navigates to `environments/garden/` and finds a structured record of the growing season. It does not need to search the full conversation archive.

### Narrative Analogy: Emplotted History

Each sub-project maintains a chronological record that is *emplotted* — not a raw log but a shaped narrative where events are meaningful in context. The `CHANGELOG.md` in each directory is not just a list of commits; it notes why decisions were made and what they resolved.

---

## Local Knowledge vs. Frontier Interpretation

The lamp-post data centre idea points at something real: **compute and memory located where the knowledge lives**, not centralised in a remote facility. The local node already has contextual knowledge the frontier model lacks. The right architecture uses each where it is strongest.

| Local Repository | Frontier Model |
|-----------------|----------------|
| Current sensor state | Pattern recognition across scales |
| Seasonal and historical record | Cross-domain analogical reasoning |
| Microclimate-specific ontology | General interpretive frameworks |
| Embodied trace memory | Linguistic and conceptual articulation |
| Low-latency, always available | High capability, intermittent access |

The local system does not need to explain itself to the frontier model from scratch on every interaction. The knowledge architecture document is the local system explaining itself *once*, in a form designed for re-entry.

### Grover's Algorithm Note

Grover's quantum search algorithm provides quadratic speedup for unstructured database search — finding a marked item in N entries requires O(√N) operations rather than O(N). This is precisely the problem of finding relevant context in a large unindexed conversation archive.

Practical quantum hardware for this use case is not near-term. But the problem it addresses is real and worth naming: the unstructured archive scales badly. The knowledge architecture approach sidesteps Grover's problem by *pre-structuring* the archive — reducing the search space through good organisation rather than faster search.

The semantic twin pipeline (sliding-window chunking, pgvector similarity search) is the current practical implementation of this principle.

---

## Implementation Checklist

For each major document in the Meridian ecosystem:

- [ ] Opens with a clear statement of what this is and is not
- [ ] Establishes the interpretive frame before presenting data or specs
- [ ] Has layered specificity (skim / read / deep dive)
- [ ] Includes a Knowledge Architecture Notes section for AI re-entry
- [ ] Points to companion documents
- [ ] Current status is visible without reading the whole document
- [ ] Key decisions include brief rationale, not just outcome
- [ ] Written as if handing to a capable colleague joining today

---

## Living Documents

These documents are not finished artifacts. They are living records that are updated as the project develops. The update discipline is:

- When a significant decision is made, add it to the relevant document *with rationale*
- When a design changes, note what changed and why, not just the new state
- When a document is used for AI re-entry and gaps are discovered, fill the gaps

The append-only principle applies: history is not overwritten. Outdated sections are marked as superseded rather than deleted. The record of how the project developed is part of the project.

---

*This document is itself an instance of the principle it describes.*
*Companion documents: `GARDEN_ECOLOGY.md`, `WRIST_PUCK.md`, `docs/philosophy/`*
*See also: `semantic_twin/` for the conversation archive implementation*
