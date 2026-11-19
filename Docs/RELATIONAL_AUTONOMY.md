# Meridian V2 — Relational Autonomy Core Architecture

```
                           ┌────────────────────────────────────┐
                           │        ECOLOGICAL WORLD             │
                           │  (species, season, land protocols)  │
                           └────────────────────────────────────┘
                                         ▲
                                         │  ecological constraints
                                         │
┌──────────────────────────────────────────────────────────────────────────────┐
│                     MERIDIAN V2 — RELATIONAL AUTONOMY CORE                   │
│                                                                              │
│   ┌──────────────────────────────────────────────────────────────────────┐   │
│   │  1. VIABILITY SENSING LAYER                                          │   │
│   │  (the archive the body cannot hear)                                  │   │
│   │                                                                      │   │
│   │  • environment: cold, humidity, terrain                              │   │
│   │  • device: power rails, thermal, bus integrity                        │   │
│   │  • wearer: motion, skin temp                                         │   │
│   │                                                                      │   │
│   │  → produces: viability score + silent degradation flags              │   │
│   └──────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│   ┌──────────────────────────────────────────────────────────────────────┐   │
│   │  2. BOUNDARY MAINTENANCE LAYER                                       │   │
│   │  (no reaching in)                                                    │   │
│   │                                                                      │   │
│   │  • physical boundary: chassis, moisture, shock                       │   │
│   │  • energetic boundary: power budgeting                               │   │
│   │  • informational boundary: no inference, no interior modeling        │   │
│   │                                                                      │   │
│   │  → protects wearer autonomy + device coherence                       │   │
│   └──────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│   ┌──────────────────────────────────────────────────────────────────────┐   │
│   │  3. CONSTRAINT ENGINE                                                │   │
│   │  (refusal as a first-class state)                                    │   │
│   │                                                                      │   │
│   │  • ecological refusal: species nearby → quiet mode                   │   │
│   │  • social refusal: land protocols → no recording                     │   │
│   │  • wearer refusal: opacity respected, no inference                   │   │
│   │                                                                      │   │
│   │  → filters all actions through ethical + ecological constraints      │   │
│   └──────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│   ┌──────────────────────────────────────────────────────────────────────┐   │
│   │  4. REGIME MANAGER                                                   │   │
│   │  (continuance instead of rupture)                                    │   │
│   │                                                                      │   │
│   │  • exploration mode                                                  │   │
│   │  • quiet mode                                                        │   │
│   │  • survival mode                                                     │   │
│   │  • treaty mode                                                       │   │
│   │  • night mode                                                        │   │
│   │                                                                      │   │
│   │  → selects globally viable mode with soft transitions                │   │
│   └──────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│   ┌──────────────────────────────────────────────────────────────────────┐   │
│   │  5. AUTOPOIETIC CORE                                                 │   │
│   │  (deposited, not commanded)                                          │   │
│   │                                                                      │   │
│   │  • self-repair without override                                      │   │
│   │  • stigmergic communication (trail markers, not commands)            │   │
│   │  • AR overlays as environmental deposits                             │   │
│   │  • haptics as non-directive cues                                     │   │
│   │                                                                      │   │
│   │  → maintains system viability while respecting wearer autonomy       │   │
│   └──────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
                                         │
                                         │  deposits, not commands
                                         ▼
                           ┌────────────────────────────────────┐
                           │        WEARER EXPERIENCE            │
                           │  (continuance, autonomy, opacity)   │
                           └────────────────────────────────────┘
```

## Directory Structure

All components are located under `services/autonomy/`:

- `services/autonomy/viability.py`: **Layer 1 — Viability Sensing Layer**. Calculates environmental, device, and wearer viability scores and sets degradation flags (`SUBZERO_COLD`, `LOW_POWER`, `THERMAL_THROTTLE`, `BUS_INTEGRITY_DEGRADED`).
- `services/autonomy/boundary.py`: **Layer 2 — Boundary Maintenance Layer**. Enforces energetic power budgeting (`FULL`, `CONSTRAINED`, `MINIMAL_PRESERVATION`, `ISOLATED_CHARGING`) and informational boundaries (strictly strips any attempts at interior modeling, mood, intent, or stress inferences).
- `services/autonomy/constraint.py`: **Layer 3 — Constraint Engine**. Treats refusal as an ontological first-class state. Evaluates ecological refusals (species presence / ravens), social refusals (land protocols / traditional territories), and wearer opacity.
- `services/autonomy/regime.py`: **Layer 4 — Regime Manager**. Manages operating modes (`EXPLORATION`, `QUIET`, `SURVIVAL`, `TREATY`, `NIGHT`) with Hermite smoothstep continuous transitions ("continuance instead of rupture").
- `services/autonomy/autopoietic.py`: **Layer 5 — Autopoietic Core**. Generates non-directive stigmergic deposits rather than alerts or commands. Implements the 3-state wrist-puck haptic grammar (`EQUILIBRIUM`, `UNCERTAINTY`, `ANOMALY`) across dual channels (LRA coin motor waveform + servo sliding mass) and spatial AR deposits.
- `services/autonomy/core.py`: **Orchestrator**. Unifies the 5 layers in a single synchronous/asynchronous `tick()`.
- `services/autonomy/__main__.py`: **Daemon Service**. Subscribes to MQTT topics (`garden/ecology/#`, `wearer/ecology/#`, `meridian/device/health`, `meridian/protocols/land`) and publishes deposits to `meridian/autonomy/deposits/haptic`, `meridian/autonomy/deposits/ar`, and `meridian/autonomy/state`.

## Verification & Execution

- **Unit Tests**:
  ```bash
  python -m unittest tests/test_autonomy.py
  ```
- **Interactive Simulation**:
  ```bash
  python scripts/simulate_autonomy.py
  ```
- **Service Run**:
  ```bash
  python -m services.autonomy
  ```
