# Adaption Labs — Public Sector Grant Proposal
## Draft — Sean Kimmerly, Government ICT Advisor, Whitehorse, Yukon

---

## Applicant

**Name:** Sean Kimmerly
**Role:** Independent Researcher and Government ICT Advisor
**Location:** Whitehorse, Yukon, Canada
**Sector:** Territorial government ICT / civic technology

---

## Organizational Context

I work as an ICT advisor to the Yukon territorial government and as an independent
researcher building distributed sensing and AI infrastructure for northern and remote
conditions. My advisory work includes enterprise asset management systems, semantic
infrastructure, and technology strategy for a jurisdiction that spans 483,000 km²
with a population of approximately 45,000 people — served by a single territorial
government expected to deliver complex public services across Indigenous language
communities, vast geographic distances, and intermittent connectivity.

The AAAS asset management system I built for the government (versions 1–3), which
integrates temporal tables, RFID, spatial data, and live environmental feeds, was
identified in a government peer review as the most advanced among comparable Canadian
jurisdictions. That work established the pattern I continue to develop: infrastructure
that works under real northern conditions rather than ideal ones.

---

## The Problem

Public sector AI deployment in northern and remote jurisdictions faces a structural
mismatch. Most AI systems are designed for abundant infrastructure: reliable
high-bandwidth connectivity, cloud-resident compute, large homogenous datasets, and
stable deployment environments. None of these conditions reliably exist in Yukon.

The specific challenges:

**Connectivity:** Large portions of the territory operate on intermittent satellite or
microwave links. AI systems that depend on continuous cloud connectivity fail silently
or not at all in these conditions.

**Language and cultural diversity:** Yukon has fourteen distinct First Nations, each
with treaty relationships, governance structures, and in many cases living languages.
AI systems preconfigured on southern Canadian or American data arrive with assumptions
that do not hold.

**Institutional scale:** A territorial government delivering the full range of public
services — health, education, infrastructure, emergency management, environmental
monitoring — with the staffing levels of a mid-sized municipality. The margin for
error is thin and the overhead of maintaining complex AI infrastructure is real.

**Knowledge decay:** The most valuable institutional knowledge in small northern
governments is held by individuals, not systems. It is lost when people leave.
AI systems that freeze at deployment cannot absorb the continuous learning that
actually happens in these institutions.

The result is that public sector AI in jurisdictions like Yukon tends toward one of
two failure modes: expensive enterprise deployments that require southern technical
support and don't adapt to local conditions, or no deployment at all.

---

## Proposed Work

I am developing **Meridian** — a distributed sensor ecology and adaptive knowledge
infrastructure designed explicitly for northern and remote conditions. The system
currently comprises:

- **ESP32 sensor nodes** deployed across a residential site in Whitehorse, publishing
  environmental telemetry (temperature, soil moisture, light, CO2, presence detection,
  computer vision) via MQTT over a store-and-forward architecture that handles
  intermittent connectivity without data loss
- **Local inference pipeline** using a Hailo-8L neural processing unit for on-device
  YOLOv8s object detection — no cloud dependency for inference
- **PostgreSQL/pgvector** semantic store on local hardware (Raspberry Pi infrastructure)
  for continuous embedding of sensor events and motif detection
- **Unity AR interface** for situated, embodied interaction with the sensor ecology's
  accumulated knowledge
- **Synthetic simulation environment** for developing and testing the pipeline against
  realistic northern environmental conditions before full hardware deployment

Meridian is a working prototype, not a concept. It is running now.

The architecture embeds specific principles that align with Adaption's stated mission:

**Continuous learning over static deployment.** The system ingests sensor events
continuously into a semantic store, updating its model of the environment in real
time rather than at periodic retraining cycles.

**Edge-first, cloud-optional.** Inference and storage run on local hardware. Cloud
connectivity is used when available but never assumed. This is the store-and-forward
principle applied to AI infrastructure.

**Place-specific rather than preconfigured.** The system learns the specific rhythms,
anomalies, and patterns of its deployment site. A system trained on southern Canadian
or American data would not know that ravens are a significant presence event in a
Whitehorse yard, or that soil moisture dynamics in permafrost-adjacent ground behave
differently than temperate baselines.

**Access to the Adaption platform would allow me to:**

1. Extend the Meridian adaptive data pipeline to a public sector pilot — specifically
   environmental monitoring and asset tracking for a Yukon government use case,
   building on the AAAS infrastructure already in production
2. Test the integration of Adaption's continuous learning architecture with
   edge-deployed sensor ecology data under real northern connectivity conditions
3. Develop a replicable pattern for adaptive AI deployment in small, remote,
   resource-constrained public sector environments — documented and open for
   other northern jurisdictions to adopt
4. Explore adaptive AI for Indigenous language and knowledge contexts in Yukon,
   in consultation with First Nations partners, where preconfigured models
   consistently underperform

---

## Why This Matters Beyond Yukon

The conditions Meridian is designed for — intermittent connectivity, small institutions,
linguistic and cultural diversity, high stakes, thin margins — are not unique to Yukon.
They describe most of the public sector outside major urban centres globally.

The pattern of work being developed here is explicitly designed to be forkable:
documented, open, and adapted to specific conditions rather than exported wholesale.
If it works in Whitehorse it works, with modification, in northern Manitoba, in
rural Saskatchewan, in remote Indigenous communities across the country, and in
analogous conditions internationally.

Adaption's framing — that intelligence should not arrive preconfigured, that AI
should evolve alongside the people and problems it serves — describes exactly what
this work is trying to demonstrate is possible without abundant resources.

---

## Track Record

- AAAS enterprise asset management system (Yukon government): temporal tables,
  RFID integration, ArcGIS spatial data, live weather feeds — peer-reviewed as most
  advanced among comparable Canadian jurisdictions
- Meridian sensor ecology: ESP32 nodes, MQTT, PostgreSQL/pgvector, Hailo-8L inference,
  Unity AR motif graph — in active development, published to GitHub
- 6+ years as developer and technical analyst, self-taught, working across distributed
  systems, semantic infrastructure, IoT/edge computing, and AR development
- Government ICT advisory across enterprise asset ontology, store-and-forward
  architectures, and distributed systems suited to northern contexts

---

## What I Am Asking For

Access to the Adaption platform to extend and validate the Meridian adaptive data
architecture in a public sector context — with the goal of producing a documented,
replicable pattern for continuous-learning AI deployment under northern and remote
conditions.

This is not a request for AI to solve a problem I cannot define. The problem is
defined. The infrastructure is running. The ask is the platform access and the
connection to Adaption's adaptive data research that would let this work reach
further than it can on self-funded hardware alone.

---

*Contact and technical documentation available on request.*
*Meridian project: github.com/[username]/meridian*
