# Slice B — "Nothing is claimed" (honest motif lifecycle)

**Status:** research result established (asserted-vs-earned run, 2026-06-17);
coarsening + lessons in progress.
**ADR-003 items:** 2 (honest motif lifecycle), 4 (promotion job + graph stats) + the v1 data inheritance.

> Written for the next session and for future Sean. What was predicted, what
> happened, the headline result, and the next question.

---

## What was predicted

ADR-003 §2 claimed v1's motifs were corrupted because it **asserted resonance at
ingestion time** — classifying events into motifs as they arrived, on thin
evidence. v2 inverts it: ingestion asserts nothing; a promotion job earns motifs
off the hot path through gates, recording each with its evidence. Replaying the
284k-event corpus through that lifecycle and diffing *earned* vs v1's 31 *asserted*
motifs would quantify the corruption.

## What we built

- `schemas/002_motif_lifecycle.sql` — candidate→motif→dormant state machine,
  `motif_members` (evidence), `motif_transitions` (with evidence snapshots),
  `motif_labels` (decoration), FK-complete `motif_resonance`, `motif_graph_stats`.
- `seed/replay.py` — loaded all 284,400 events (reusing stored embeddings).
- `services/promotion` — HDBSCAN clustering (sampled for tractability, full
  membership by nearest-centroid), the gates, content-derived identity,
  transitions, dormancy, materialized-view refresh.
- `seed/compare_motifs.py` — the asserted-vs-earned report.

## The headline result (the research deliverable)

**v1 asserted 31 motifs. Under real evidence: 5 supported, 26 hallucinated.**

The 5 grounded motifs are *all the agent sensing itself* — `thermal_stress`,
`thermal_recovery`, `idle`, `ambient thermal field`, `thermal motion` (the Pi's
own thermal/CPU/embodied state), matched at cosine distance 0.08–0.10.

The 26 hallucinations fail in two distinct ways, and **the more poetic the name,
the less real it was:**
- **Environmental-perception motifs** (`warm body present`, `dim warm light`,
  `footsteps`, `cold front`, `presence approaching/departing`), d ≈ 0.25–0.30 —
  Gemini-applied *linguistic labels on a generic, undifferentiated sensor
  embedding*. The embedded text was only `"Environmental field event:
  temperature/humidity/pressure …"` — it never encoded "warm body" or
  "footsteps," so those categories had no cluster to stand on.
- **Abstract motifs** (`cognitive-anchor`, `self-attunement`,
  `epistemic-repository`, `focal-hush`, `liminal-cognoscence` …), d ≈ 0.40–0.54 —
  pure conversation-corpus artifacts with *zero* physical grounding, yet rendered
  on the live HUD as perceptual motifs.

This is the mechanism of the v1 inaccuracy, named and measured: the perceptual
field only ever supported the agent's **self-sensing** plus a single generic
environmental baseline. Everything richer was painted on.

## What surprised us (the real lessons)

1. **The gate set in the ADR was the wrong evidence model for this field.** The
   first run with ADR's `≥2 sources` gate promoted exactly ONE motif — a 143k-event
   incoherent blob — and rejected every coherent recurring state. Investigation
   showed why: 4 active nodes but **type-siloed** (avg 1.01 sources/cluster), so
   cross-source corroboration is structurally impossible. **Deviation:** we
   replaced the spatial `sources` gate with a **temporal `recurrence` gate**
   (evidence on ≥ N distinct days). `members + recurrence + stability` are the hard
   gates now; `span`/`sources` are kept in the evidence snapshot as informational.
   With recurrence, 148/162 clusters earned through — the lifecycle came alive.
2. **Hallucination is invisible until you require evidence.** v1's 26 invented
   motifs looked exactly as real as the 5 grounded ones on the HUD. Only the
   candidate-first lifecycle, refusing to assert, made the difference legible.
3. **Embedding-text fidelity bounds what can ever be a motif.** Categories not
   present in the text that gets embedded can never form clusters — no downstream
   cleverness recovers them. If we want environmental *perception* motifs in v2,
   the embedding text must encode the perceptual distinctions (the embedding
   producer's job), not a label slapped on afterward.
4. **Clustering grain ≠ gate floor.** HDBSCAN `min_cluster_size` was conflated with
   the members gate, over-fragmenting the environmental baseline into ~140
   near-identical "sensor_reading" motifs (148 earned, only 4 real labels). Now a
   separate `--min-cluster-size` knob coarsens it.
5. **High-dim HDBSCAN is the cost center.** 40k×768 ran ~21 min; 12k returns in
   seconds with the same structure. For full-corpus fidelity later: PCA→~50 dims.

## Deferred / known-not-done

- **Coarsen the earned set** (raise `--min-cluster-size`) so the motif graph is a
  legible handful, not 148 baseline fragments. (Headline 5/31 result is unaffected.)
- **Live embedding producer** — raw events → `perceptual_events` with local nomic,
  asserting nothing; the piece the relay already listens for. And critically, its
  embedding text should encode real perceptual distinctions (lesson 3) so future
  environmental motifs can actually be earned, not hallucinated.
- **Labelling** of earned motifs (lazy, local-first) — decoration, deferred.
- `apply_migrations.sh` still has no migration-tracking; new migrations applied by hand.

## The next question

For the rebuild's research thesis, Slice B already answers it: AI-scaffolded,
candidate-first architecture turns 31 asserted motifs into "5 real, 26 invented,"
with the mechanism legible. The forward question is **whether a v2 embedding
producer that encodes perceptual distinctions can let genuine environmental motifs
earn their way in** — i.e. give the field something true to say beyond its own
temperature. That, and Slice C (pollen-pod first contact), are next.
