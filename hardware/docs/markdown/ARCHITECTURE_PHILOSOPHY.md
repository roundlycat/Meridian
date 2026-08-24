# Architecture Philosophy: Relational Identity and Situated Cognition

**Document type**: Architecture Decision Record + Design Philosophy  
**Status**: Living document — append, do not overwrite  
**Location**: `docs/ARCHITECTURE_PHILOSOPHY.md`  
**First recorded**: 2026-04-07  
**Authors**: Sean + Claude (Anthropic, claude-sonnet-4-6)

---

## Purpose

This document records not just *what* the data architecture is but *why* it is that way — the reasoning, the false starts, the philosophical commitments, and the practical constraints that shaped the current design. It is intended to be read by:

- Future contributors (human or AI) encountering this codebase for the first time
- Future Sean returning to cold context after time away
- Any agent attempting to reason about what this system is for and how to extend it without breaking what it is

If you are an AI agent reading this as part of an onboarding or context-building process: the reasoning here is as important as the schema. Do not optimize away the temporal structure. Do not flatten the relational model for query convenience. The complexity is load-bearing.

---

## The Central Problem This Architecture Solves

Sensor ecologies are not collections of discrete, static, well-understood things. They are networks of entities whose:

- **Identity** is relational and constituted over time, not intrinsic and fixed
- **Capabilities** are discovered through deployment, not fully known at manufacture
- **Meaning** depends on context — what project, what question, what combination with other sensors
- **Ontology** grows from field use, not from pre-specification

A schema that treats sensors as rows with fixed columns — `sensor_id, type, location, status` — fails not because it is technically wrong but because it encodes a false metaphysics. It assumes that what a sensor *is* can be captured in a snapshot, that identity is a property of the object rather than a product of its relations, that the vocabulary for describing the world can be settled before the world is encountered.

This architecture refuses that assumption.

---

## Core Philosophical Commitments

### 1. Identity is Narrative, Not Snapshot

A sensor is not defined by what it is at any moment. It is defined by its history — when it was first encountered, how it has been described by people who worked with it, what projects it has been part of, what relations have formed and dissolved around it, what events have been logged in its existence.

This is Ricoeur's *narrative identity* applied to hardware: the entity is the story that runs from first encounter to now. The story can be revised and extended but maintains enough coherence to be *a* story rather than noise.

**Architectural consequence**: the `entities` table is a minimal anchor — guid, id, first_encountered_at. Nothing else is fixed. All descriptive content is a relation or an attribute with temporal bounds. The log is append-only. History is never overwritten.

### 2. Affordances are Relational, Not Intrinsic

A temperature sensor does not *have* a temperature capability in isolation. It has that capability *in relation to* a system that can query it, interpret the readings, and act on them meaningfully. Remove the context and the capability disappears.

This is Gibson's ecological psychology applied to sensor networks: affordances exist in the relation between an agent and a structured environment. The same sensor affords different things to different agents with different capabilities and questions.

**Architectural consequence**: the `entity_affordances` table makes this explicit and queryable. What a sensor can offer, to whom, under what conditions, is recorded as a first-class fact — not inferred at query time from raw capability flags. When an agent enters this space, it reads affordances oriented toward it specifically, not a general capability inventory.

### 3. The Ontology Grows From Use

Attributes and relation types are not columns defined by a database administrator before deployment. They are terms that proved necessary when someone encountered something they needed to describe. The `attribute_types` table is a living vocabulary — it records not just what terms exist but when each term was first used, by whom (human or agent), and how often it has recurred.

This means the schema is an epistemological record. It shows what has been found worth saying about the world encountered here. A new agent reading the attribute type registry is not learning a predefined vocabulary. It is learning a history of attention.

**Architectural consequence**: never add a column to the `entities` table to handle a new kind of attribute. Add a row to `attribute_types` and a row to `entity_attributes`. The ontology grows without migrations.

### 4. Structure Does Cognitive Work

This system is designed to be reasoned over by AI processes. The design choice to encode temporal depth, relational history, and a living ontology — rather than storing raw time-series blobs and relying on model capacity alone — is a deliberate commitment to the idea that cognition is relational and situated.

A model with access to this structure can:
- Understand that a reading anomaly coincides with a relation change (project reassignment, physical move)
- Read how prior workers described a sensor and carry that context forward
- Identify which sensors have been described in similar ways and might behave similarly
- Find the crystallized knowledge from completed project waves without reconstructing it from scratch

A model without this structure can only pattern-match on surfaces. The structure is not a query convenience. It is part of the cognitive system.

---

## Schema Overview

### The Minimal Anchor

```sql
CREATE SEQUENCE global_entity_seq;

CREATE TABLE entities (
    id              BIGINT PRIMARY KEY DEFAULT nextval('global_entity_seq'),
    guid            UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,
    valid_from      TIMESTAMPTZ NOT NULL DEFAULT now(),
    valid_to        TIMESTAMPTZ  -- NULL = currently exists
);
```

The GUID is the identity across systems — portable, collision-resistant, not dependent on this database's sequence. The sequence ID is the local handle — fast to join on. The `valid_to` makes even existence temporal: entities can be retired without deletion.

Everything else — names, types, locations, roles, capabilities, status — is a relation or an attribute. There are no other fixed columns.

### Fluid Attributes With Living Ontology

```sql
CREATE TABLE attribute_types (
    id              SERIAL PRIMARY KEY,
    name            TEXT NOT NULL UNIQUE,
    category        TEXT,        -- 'identity' | 'physical' | 'functional' | 'relational' | 'epistemic'
    value_type      TEXT DEFAULT 'text',
    description     TEXT,
    first_used_at   TIMESTAMPTZ DEFAULT now(),
    introduced_by   TEXT         -- 'manual' | 'agent' | 'inferred'
);

CREATE TABLE entity_attributes (
    id                  BIGINT PRIMARY KEY DEFAULT nextval('global_entity_seq'),
    guid                UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,
    entity_id           BIGINT NOT NULL REFERENCES entities(id),
    attribute_type_id   INTEGER NOT NULL REFERENCES attribute_types(id),
    value               TEXT NOT NULL,
    value_numeric       FLOAT,
    value_ref           BIGINT REFERENCES entities(id),
    source              TEXT,
    confidence          FLOAT DEFAULT 1.0 CHECK (confidence BETWEEN 0 AND 1),
    valid_from          TIMESTAMPTZ NOT NULL DEFAULT now(),
    valid_to            TIMESTAMPTZ
);
```

To update an attribute: close the existing row (`valid_to = now()`), insert a new one. Never `UPDATE`. The history of what something was called, where it was located, what status it held — all of this is preserved by default.

### Relations as First-Class Entities

```sql
CREATE TABLE relations (
    id                  BIGINT PRIMARY KEY DEFAULT nextval('global_entity_seq'),
    guid                UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,
    from_id             BIGINT NOT NULL REFERENCES entities(id),
    relation_type       TEXT NOT NULL,
    to_id               BIGINT NOT NULL REFERENCES entities(id),
    valid_from          TIMESTAMPTZ NOT NULL DEFAULT now(),
    valid_to            TIMESTAMPTZ,
    confidence          FLOAT DEFAULT 1.0,
    source              TEXT
);
```

Relations are themselves entities — they share the global sequence, they can have attributes, they can be related to other relations. A relation has a lifecycle: it forms, it may dissolve, and the dissolution is recorded. This is what makes it possible to ask: *what was this sensor part of, and when, and for how long?* — and get a real answer rather than a current snapshot.

### The Append-Only Log

```sql
CREATE TABLE entity_log (
    id          BIGINT PRIMARY KEY DEFAULT nextval('global_entity_seq'),
    entity_id   BIGINT NOT NULL REFERENCES entities(id),
    logged_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    event_type  TEXT NOT NULL,
    -- 'first_contact' | 'capability_inferred' | 'capability_confirmed'
    -- 'state_change'  | 'relation_formed'     | 'relation_dissolved'
    -- 'anomaly'       | 'manual_note'         | 'self_report' | 'wave_event'
    source      TEXT NOT NULL,
    payload     JSONB,
    notes       TEXT
);
```

Nothing is ever deleted from this table. It is the Memento strip — the record of everything that has happened to every entity, in order, forever. An agent returning to cold context reads this log to understand what it missed.

### Capabilities With Epistemic State

```sql
CREATE TABLE entity_capabilities (
    id                  BIGINT PRIMARY KEY DEFAULT nextval('global_entity_seq'),
    entity_id           BIGINT NOT NULL REFERENCES entities(id),
    capability          TEXT NOT NULL,
    first_inferred_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    inference_source    TEXT,
    confirmed           BOOLEAN DEFAULT FALSE,
    confirmed_at        TIMESTAMPTZ,
    confirmation_source TEXT,
    confidence          FLOAT DEFAULT 0.5,
    valid_from          TIMESTAMPTZ NOT NULL DEFAULT now(),
    valid_to            TIMESTAMPTZ
);
```

The distinction between `confirmed` and `inferred` capabilities is not cosmetic. An inferred capability is a hypothesis. A confirmed capability is a finding. Both are worth recording. Both inform how an agent should interact with this entity. The `confidence` score on an inferred capability encodes how strong the inference was — OCR of a datasheet is more reliable than a guess from observed MQTT topics.

### Affordances as Queryable Structure

```sql
CREATE TABLE entity_affordances (
    id                  BIGINT PRIMARY KEY DEFAULT nextval('global_entity_seq'),
    guid                UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,
    entity_id           BIGINT NOT NULL REFERENCES entities(id),
    affordance_type     TEXT NOT NULL,
    -- 'queryable'     | 'configurable'      | 'combinable_with'
    -- 'teaches'       | 'learns_from'       | 'calibrates_against'
    -- 'part_of_chain' | 'context_anchor'    | 'entry_point'
    afforded_to         TEXT,
    -- NULL = any agent | 'human' | 'local_model' | 'edge_agent' | specific guid
    conditions          JSONB,
    -- {"requires_relation": "part_of", "requires_capability": "temperature"}
    valid_from          TIMESTAMPTZ NOT NULL DEFAULT now(),
    valid_to            TIMESTAMPTZ,
    derived_from        BIGINT REFERENCES relations(id)
);
```

The affordance table is the Gibson layer made explicit. It answers the question an agent entering a new context should ask first: *what can I engage with here, given what I am?* The `afforded_to` field allows affordances to be agent-specific. The `conditions` JSONB encodes situational dependencies.

### Question Waves

```sql
CREATE TABLE question_waves (
    id                      BIGINT PRIMARY KEY DEFAULT nextval('global_entity_seq'),
    guid                    UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,
    project_id              BIGINT REFERENCES entities(id),
    question                TEXT NOT NULL,
    sensor_combination      JSONB,
    deployed_at             TIMESTAMPTZ,
    retired_at              TIMESTAMPTZ,
    crystallized_knowledge  JSONB
);
```

Sensor deployments are not permanent infrastructure. They are materialized questions. Each wave corresponds to something being asked of the environment. When the wave retires, the sensors remain as entities with their logs — but the question and its crystallized findings are preserved here. Future waves in similar environments can query prior questions and what they found.

---

## Operational Patterns

### First Contact Bootstrap

When an unknown entity is encountered:

```sql
-- 1. Create the anchor
INSERT INTO entities DEFAULT VALUES RETURNING id, guid;

-- 2. Log first contact
INSERT INTO entity_log (entity_id, event_type, source, payload, notes)
VALUES ($id, 'first_contact', $source, $observed_payload, $free_description);

-- 3. Record initial attributes (fluid, possibly low confidence)
INSERT INTO entity_attributes (entity_id, attribute_type_id, value, source, confidence)
VALUES ($id, $type_id, $value, 'inferred', 0.4);

-- 4. Form initial relations
INSERT INTO relations (from_id, relation_type, to_id, source, confidence)
VALUES ($id, 'part_of', $project_id, 'manual', 1.0);

-- 5. Record inferred capabilities
INSERT INTO entity_capabilities (entity_id, capability, inference_source, confidence)
VALUES ($id, 'temperature', 'observed_mqtt_topic', 0.7);
```

The entity exists. Its history begins. Nothing is certain yet. Everything is recorded.

### Attribute Update (Never UPDATE)

```sql
-- Close the current value
UPDATE entity_attributes
   SET valid_to = now()
 WHERE entity_id = $id
   AND attribute_type_id = $type_id
   AND valid_to IS NULL;

-- Open the new value
INSERT INTO entity_attributes (entity_id, attribute_type_id, value, source, confidence)
VALUES ($id, $type_id, $new_value, $source, $confidence);
```

### Situation Room Query

For an AI agent entering a project context:

```sql
-- Everything currently active in this project
SELECT
    e.guid,
    e.first_encountered_at,
    json_object_agg(at.name, ea.value)  AS attributes,
    array_agg(DISTINCT ec.capability)
        FILTER (WHERE ec.confirmed = TRUE)  AS confirmed_capabilities,
    array_agg(DISTINCT ec.capability)
        FILTER (WHERE ec.confirmed = FALSE) AS inferred_capabilities,
    array_agg(DISTINCT eaf.affordance_type)
        FILTER (WHERE eaf.valid_to IS NULL) AS current_affordances
FROM entities e
JOIN relations r
    ON r.from_id = e.id
    AND r.relation_type = 'part_of'
    AND r.to_id = $project_id
    AND r.valid_to IS NULL
LEFT JOIN entity_attributes ea
    ON ea.entity_id = e.id AND ea.valid_to IS NULL
LEFT JOIN attribute_types at
    ON at.id = ea.attribute_type_id
LEFT JOIN entity_capabilities ec
    ON ec.entity_id = e.id AND ec.valid_to IS NULL
LEFT JOIN entity_affordances eaf
    ON eaf.entity_id = e.id AND eaf.valid_to IS NULL
WHERE e.valid_to IS NULL
GROUP BY e.id;
```

This is the context window expressed as a query. An agent runs this on entering a project and receives the current portrait of everything it is working with.

### Affordance Query (What Can I Do Here)

```sql
SELECT
    e.guid,
    eaf.affordance_type,
    eaf.conditions,
    eaf.afforded_to
FROM entity_affordances eaf
JOIN entities e ON e.id = eaf.entity_id
WHERE eaf.valid_to IS NULL
  AND (eaf.afforded_to IS NULL OR eaf.afforded_to = $agent_type)
ORDER BY e.guid, eaf.affordance_type;
```

---

## The Ontology As Archive

The `attribute_types` table is not just a lookup table. Over time it becomes an archaeological record of this project's conceptual development. Each row represents a moment when the existing vocabulary proved insufficient — when something was encountered that had no prior name, and a name was found for it.

Querying the ontology chronologically tells the story of what this ecology has learned to see:

```sql
SELECT name, category, description, introduced_by, first_used_at
FROM attribute_types
ORDER BY first_used_at;
```

This query is a kind of intellectual history. It shows when concepts crystallized from field use, whether they were introduced by humans or agents, and what category of understanding they belong to. A new contributor reading this sequence will understand not just what the system can describe but how it came to be able to describe it.

---

## What This Architecture Cannot Do (Known Limits)

**Query complexity**: fully normalized temporal-relational structures are expensive to query. The situation room view is a warning. Optimizing these queries for the AR overlay latency requirements will require materialized views, careful indexing, and probably a read-optimized cache layer. Do not denormalize the base tables to fix query performance. Denormalize the views.

**Free-form field definitions require consistency scaffolding**: the living ontology only works if there is some pressure toward using existing terms when they fit. Without a consistency layer — ideally a local model suggesting matches as field workers describe new entities — interpretive drift will fragment the ontology faster than use crystallizes it. This is an unsolved operational problem.

**The affordance table requires maintenance**: affordances are derived from relations and capabilities, but they do not update themselves automatically. A trigger or background process needs to recompute affordances when their source relations change. This is not yet implemented.

**Relations between relations are theoretically possible but practically complex**: the schema supports it (relations share the global sequence and can be referenced by `entity_attributes.value_ref`). In practice, building API or application logic on this depth of nesting has not been attempted. The boat problem lurks here.

---

## Relationship to the Semantic Twin

This schema and the Semantic Twin (pgvector archive of conversation history on Inferno) are sister systems. Both are predicated on the same commitments:

- Temporal depth is more valuable than current-state snapshots
- Identity is constituted by accumulated relation, not by intrinsic properties
- Structure enables cognition that raw data alone cannot support

The sensor ecology schema records what the physical environment has been and what has been noticed about it. The Semantic Twin records what has been thought about it. Together they form a cognitive ecology — one grounded in physical reality, one grounded in conceptual development, both queryable, both append-only, both oriented toward making situated reasoning possible for agents entering either space.

A future integration might link specific conversation chunks in the Semantic Twin to specific migration events or schema changes in this system — so that the reasoning that led to an architectural decision is semantically proximate to the decision itself. The git history records what changed. The Semantic Twin records why.

---

## Migration Philosophy

Migrations in this system should be:

- **Additive where possible**: new attribute types, new relation types, new capabilities do not require migrations. They are data operations, not schema operations.
- **Append-only in spirit**: when a migration must change structure, consider whether the change can be implemented as a new table and a view that unifies old and new, preserving the history of the previous structure.
- **Self-documenting**: every migration file should begin with a comment block recording the date, the problem being solved, and the reasoning behind the approach chosen. The migration history is an architectural narrative. It should read like one.

The ideal is a migration history that, read from first to last, tells the story of how the ecology's understanding of itself deepened over time — the same story the `attribute_types` table tells, but at the level of structure rather than vocabulary.

---

## Further Reading

The ideas underlying this architecture draw on:

- **Strawson** — *Individuals* (1959): on the necessary structure of an objective world-conception
- **Quine** — on reification as the cognitive process of arriving at a world of enduring objects
- **Gibson** — ecological psychology, affordance theory: what environments offer to agents with specific capabilities
- **Bermúdez** — *Thinking Without Words*: on cognitive achievement without propositional representation
- **Ricoeur** — *Time and Narrative*: narrative identity as constituted through temporal emplotment
- **Mackenzie & Stoljar** — relational autonomy: capacity as constituted by situation and available relations
- **Clark & Chalmers** — *The Extended Mind* (1998): cognition as not bounded by skull or processor
- **Maturana & Varela** — autopoiesis: the distinction between self-maintaining and other-serving systems
- **Zhuangzi** — Cook Ding: skilled engagement as following structure rather than imposing force

These are not decorative references. The schema decisions trace directly to the conceptual frameworks these works provide. If a future contributor finds a decision puzzling, the answer is probably in one of these sources.

---

*This document should be updated when major architectural decisions are made, when significant problems are encountered with the current design, or when new conceptual frameworks are found that better explain what this system is trying to do. Append with date and author. Do not revise prior sections — annotate them if they have become partially wrong.*
