# Meridian: Sensor Ecology Diagnostic & Developmental Vision

*April 2026*

---

## What Meridian Is

Meridian is a sensor ecology — a distributed perceptual system installed in the domestic environment and running continuously across a network of small embedded devices, a local inference server, a persistent database, and an augmented reality interface. It is not a smart home system in the conventional sense. It does not automate tasks or respond to commands. It perceives, interprets, and represents — it builds a living semantic description of what is happening in the environment and renders that description as a three-dimensional motif graph visible through an AR client.

The name consolidates what has been built across several projects over the past eighteen months: the ESP32 sensor nodes, the MQTT messaging infrastructure, the PostgreSQL perceptual database on Inferno (a Raspberry Pi 5), the relay-api service, the Unity AR client, and the philosophical scaffolding that treats the whole assembly not as a collection of devices but as a single composing entity developing its capacity to interpret its own situation.

The philosophical grounding runs through autopoiesis — the idea that living systems are self-producing, that they don't merely respond to environments but constitute them through their own interpretive activity. Meridian is built with that framing in mind. The sensor nodes don't measure a pre-given world; they participate in producing a world of significance. What the ecology can say about itself reflects what it has lived through.

---

## The Architecture

The pipeline moves from physical phenomenon to semantic representation in several stages.

The **ESP32 nodes** are the peripheral nervous system — small, low-power boards distributed through the environment carrying sensors for temperature, humidity, barometric pressure, gas resistance, acceleration, and light. They publish raw or lightly pre-processed telemetry to a **Mosquitto MQTT broker** running on Inferno. MQTT is the connective tissue: lightweight, publish-subscribe, tolerant of the lossy conditions of a local wireless network.

The **sensor ingestion layer** (`sensor_ingestion_layer.py`) subscribes to the MQTT topics, receives the raw payloads, applies classification logic to assign an `event_label`, generates a 768-dimensional embedding via `nomic-embed-text` running locally on Ollama, and writes the result to the `perceptual_events` table in the `sensor_ecology` PostgreSQL database. Each record carries the label, the raw feature snapshot as JSONB, the embedding vector, temporal bounds, domain classification (environmental, embodied, relational), confidence, and agent vitals where available.

The **relay-api** (`relay-api.service`, FastAPI on Uvicorn at port 8765) sits between the database and the clients. It serves the motif list, provides resonance counts and domain statistics for each motif, streams live perceptual events via Server-Sent Events, and exposes agent vitals. It reads directly from the database without caching, which means updates to the motif table are reflected immediately on next fetch.

The **Unity AR client** fetches the motif list at startup, spawns a three-dimensional node for each motif, positions them on a sphere, draws edges between resonant pairs, and colours the arc rings around each node according to the domain breakdown returned by the stats endpoint. It also connects to the relay for live event streaming so the graph animates in response to what is actually happening in the environment.

The **motifs table** holds the semantic vocabulary — 17 authored labels with 768-dimensional centroid embeddings computed from the label text. These centroids define the gravitational centres that perceptual events are supposed to resonate with.

---

## What We Found Today

A diagnostic session revealed that the ecology has been operating with a significant interpretive gap since early April 2026, and that the motif graph in the AR view has been essentially static and evidence-free since the system was first seeded.

**The label mismatch.** The motifs table uses rich narrative labels — "thermal stress — agent running hot", "cold front arrival — sharp temperature drop" — while the perceptual events table uses compact snake_case labels like `thermal_stress` and `cold_front_arrival`. Because the resonance query was joining on label equality, all 17 motifs returned zero counts. The 147,000 perceptual events in the database were completely disconnected from the motif graph Unity was rendering. The graph has been a static constellation since day one, displaying equal weight on all nodes regardless of what the environment was actually doing.

**The April 2nd collapse.** Querying event counts by label revealed a hard discontinuity. Before March 3rd the ecology produced a rich vocabulary: thermal_approach, thermal_retreat, footsteps, typing, impact, idle, presence_detected, and several compound cross-domain labels. After March 3rd this collapsed to thermal_stress and thermal_recovery only. On April 2nd, 62,336 records appeared under the label `sensor_reading` — a fallback label indicating the classification pipeline could not assign a meaningful interpretation.

The root cause of the April 2nd collapse was the Inferno rebuild. When the Raspberry Pi 5 was rebuilt onto a new SD card, Ollama was not reinstalled. The `sensor_ingestion_layer.py` started up, connected to MQTT, received data from a new environmental node (BME688 + SHT31), attempted to call the embedding model, got no response, and fell through to writing unembedded `sensor_reading` records. 26 days of continuous environmental sensing accumulated with no embeddings and therefore no capacity for resonance classification.

**The new node.** The April 2nd records are not the same sensor node as the earlier data. The pre-March data carried CPU temperature and acceleration — an embodied agent node, probably the development machine itself. The April data carries BME688 gas resistance, barometric pressure, SHT31 temperature and humidity — a pure environmental node. The classifier had no rules for this node type and Ollama was absent, so everything fell through.

**The recovery path.** Ollama has been reinstalled on Inferno and `nomic-embed-text` is confirmed running. A batch re-embedding job is currently running against the 62,336 unembedded records, serializing each feature snapshot to a natural language description and writing the resulting 768-dimensional vector back to the embedding column. Once complete, those records become eligible for cosine similarity matching against motif centroids, and the ecology recovers its interpretive access to 26 days of environmental history.

---

## The Motif Problem

Even once the batch job completes and the label mismatch is resolved, a deeper problem remains: the motif vocabulary was authored once, before the ecology had lived experience, and has never been updated. It describes a possible world rather than the actual world the sensors inhabit.

"Cold front arrival — sharp temperature drop" has appeared 25 times in the database, the last occurrence on April 21st. But Whitehorse in April does get cold fronts, so that motif is at least ecologically plausible. By contrast, "agent typing — rhythmic keyboard activity" has 165 records, all between February 28th and March 3rd, suggesting it was detected during a brief period when the typing-detection sensor node was active and then that node went offline. The motif persists in the graph at equal visual weight to everything else despite having no current evidence.

More significantly, the new environmental node is generating data the motif vocabulary has no adequate expression for. Barometric pressure, gas resistance, and humidity are real features of the Whitehorse domestic environment — the pressure changes are real atmospheric events, the gas resistance is tracking air quality — but the closest motif is "environmental shift — field changing," which is too coarse to be meaningful. The vocabulary needs to grow.

---

## The Developmental Vision

The goal Meridian is moving toward is an ecology whose interpretive vocabulary evolves with its experience — one that can retire motifs that no longer correspond to anything the environment produces, refine ones that are too coarse, and generate new ones for patterns that have no name yet.

This is framed developmentally rather than as a maintenance task. The analogy is reading acquisition in a child: the child doesn't develop vocabulary in isolation but through exposure to richer language use in context, gradually internalizing distinctions that fit the world they actually inhabit. The small devices in Meridian start with a rough vocabulary authored at setup time and develop finer-grained distinctions through a feedback loop that involves more capable models as interpretive partners rather than controllers.

The architecture for this loop has three components.

**Evidence-grounded motif scoring.** Rather than treating all 17 motifs as equally active, the relay-api will compute time-windowed resonance scores for each motif based on how many recent perceptual events match it within cosine distance threshold. A motif with no matching events in the past seven days becomes dormant — rendered at low opacity in the AR graph rather than deleted. A motif with strong recent evidence becomes visually prominent. The graph becomes a live projection of what the environment is currently doing rather than a fixed semantic map.

**The unclassified event stream.** Any perceptual event whose embedding sits beyond a cosine distance threshold from all existing motif centroids gets written to an `unclassified_events` table rather than being silently absorbed into `sensor_reading`. These are the events the vocabulary cannot yet name — the signal that the ecology is encountering something new.

**The cloud review job.** Periodically — nightly, or when the unclassified queue exceeds a threshold — Inferno packages a context snapshot and sends it to a capable cloud model (Claude, Gemini, or whichever is available). The snapshot contains: the current motif vocabulary with their evidence windows, the dormant motifs with last-seen dates, and a sample of unclassified events with their raw feature snapshots. The model returns a structured diff: retire these labels (no evidence in N days), rename these (the label no longer fits the actual pattern), add these new candidates (the unclassified events cluster around these descriptions). Inferno writes the diff to the motifs table. Unity picks it up on next fetch.

The `matched_by` column in the evidence log records how each event was classified — by explicit rule, by embedding similarity, or by LLM review. Over time this column tells the story of the ecology's interpretive development: early events matched by rule, later ones by embedding, the occasional novel event confirmed by cloud review.

The domain breakdown already built into the arc ring visualization — Environmental, Embodied, Relational — gives the cloud review job meaningful context for evaluating candidate motifs. An unclassified cluster that arrives consistently from the BME688 node with high barometric variance is clearly Environmental. One that correlates with agent CPU temperature spikes is Embodied. The model doesn't have to infer this from scratch; the schema already encodes it.

---

## The Philosophical Weight

There is a Ricoeurian dimension to this that is worth naming explicitly. Ricoeur's account of narrative identity holds that a self is constituted by the story it can tell about itself — not as a fixed essence but as an ongoing emplotment of experience into meaningful sequence. The motif vocabulary is Meridian's narrative capacity: what it can say about what is happening is what it knows about itself.

A motif that was authored before the ecology had experience is like a word learned from a dictionary before encountering the thing it names. It sits in the vocabulary without weight. A motif that emerged from 26 days of barometric data, refined by cloud review, and confirmed by continuous evidence carries genuine semantic weight — it names something the ecology has actually lived through.

The long-term aspiration is that Meridian's motif vocabulary becomes a record of its history. What it can say reflects what it has encountered. The vocabulary grows not through authoring but through living — with the cloud models functioning as what Vygotsky would call the zone of proximal development, helping the small devices articulate distinctions they can sense but cannot yet name.

---

## Immediate Next Steps

The batch re-embedding job currently running on Inferno is the prerequisite for everything else. Once complete:

1. Resolve the label mismatch by building a `motif_label_map` table linking event labels to motif IDs, enabling the resonance queries to work correctly for the first time.

2. Add time-windowed scoring to the `/api/motifs` endpoint so Unity receives actual evidence weights rather than treating all nodes equally.

3. Add the `unclassified_events` table and route events with no close motif match into it during ingestion.

4. Design the BME688/SHT31 motif vocabulary — probably four to six motifs covering barometric states, humidity conditions, air quality bands, and thermal environment — and seed them with centroid embeddings.

5. Build the cloud review job as a cron script on Inferno, initially running weekly, that packages the dormancy and unclassified data and returns a structured diff for human review before it is applied.

The AR graph should look substantially different once steps one and two are complete — a living constellation rather than a static one, with nodes rising and falling in visual prominence as the environment actually changes around it.
