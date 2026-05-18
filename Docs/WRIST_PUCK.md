# Wrist-Puck — Embodied Judgment Haptic Node

*Initiated: May 2026*
*Repo: `Meridian/hardware/wrist_puck`*
*Status: OpenSCAD enclosure in progress, pending Yukonstruct fabrication*

---

## What This Is

The wrist-puck is a wearable haptic node that translates the ecology's state into felt experience. Not a display. Not an alert system. A channel through which the system's current interpretation of its environment becomes *present in the body* of the person wearing it.

The distinction matters. Alerts are propositional — they say something. The wrist-puck operates below that level, in the register of what phenomenologists call pre-thematic awareness. You feel the ecology the way you feel weather — not as a set of propositions about atmospheric conditions but as a quality of the air, a heaviness, a particular kind of aliveness. The information arrives before you have decided to attend to it.

This is not a limitation. It is the design goal.

### The Branch That Holds

The project's philosophical grounding includes the concept of pre-linguistic felt judgment as an AI calibration channel — what has been called "the branch that holds." Before you can articulate why you trust or distrust a system's output, something in your body has already registered it. The wrist-puck is an attempt to give that registration a richer signal to work with. The ecology communicates its own uncertainty. The wearer absorbs that uncertainty haptically. The resulting felt sense informs how much cognitive weight to put on the system's interpretations.

This is a two-way calibration channel: the system learns from the environment, the wearer learns from the system, and the wearer's responses (attentiveness, investigation, dismissal) can feed back as signal.

---

## Haptic Grammar

The wrist-puck expresses a three-state grammar drawn from the ecology's motif scoring and anomaly detection:

### States

| State | Character | Haptic Expression |
|-------|-----------|-------------------|
| **Equilibrium** | System in expected range, no anomalies, motif patterns stable | Slow, low-amplitude LRA pulse. Barely perceptible. Background presence. |
| **Uncertainty** | Motif scores diverging, sensor readings at threshold, pattern ambiguous | Irregular LRA rhythm. Sliding mass begins slow lateral movement. Quality of unresolved tension. |
| **Anomaly** | Significant deviation, novel motif, threshold crossed | Sharp LRA burst. Sliding mass rapid traverse. Distinct, unmistakable, not alarming. |

The grammar is not binary (alert / no alert). It has texture. Equilibrium is present and felt, not silent. The transition from equilibrium through uncertainty to anomaly is continuous, not stepped. The wearer develops sensitivity to the gradient over time.

### Dual Channel

Two simultaneous haptic channels allow compound expression:

- **Channel 1 (LRA coin motor)**: Rapid, localised, frequency-variable. Expresses intensity and character.
- **Channel 2 (servo + sliding mass)**: Slow, directional, spatial. Expresses trajectory and duration.

A prolonged uncertainty that is resolving feels different from one that is intensifying. The combination of channels can express this distinction without requiring the wearer to look at anything.

---

## Hardware

### Enclosure

- **Form**: Cylinder, 68–76mm diameter, ~22mm tall
- **Wear**: Wrist or forearm mount (strap attachment points on enclosure)
- **Fabrication**: 3D print at Yukonstruct
- **File**: `wrist_puck_enclosure_1.scad`

### Components

| Component | Function | Notes |
|-----------|----------|-------|
| XIAO microcontroller | Main compute, BLE/WiFi | USB-C accessible through enclosure wall |
| DRV2605L | LRA motor driver | I2C, haptic waveform library |
| LRA 10mm coin motor | Channel 1 haptic | Press-fit into enclosure floor |
| SG51R micro servo | Channel 2 actuation | Drives sliding mass on linear rail |
| 30mm linear rail | Sliding mass track | Fitted inside cylinder |
| Sliding mass | Channel 2 haptic expression | Weight TBD, affects feel character |
| Battery compartment | Power | Capacity TBD — target full day wear |

### Geometry Constraints

The 76mm diameter ceiling is set by wearability. The 22mm height is set by the linear rail and servo stack. These are hard constraints. Component selection must fit within them.

Current enclosure at 76mm is the larger end of the range — validate comfort before committing. The 68mm version may be preferable for smaller wrists but requires tighter component packing.

---

## Firmware

### Communication

XIAO receives haptic commands via BLE from the ecology's interpretation layer (Inferno Pi → Sensor Pi → BLE broadcast or direct connection). Commands specify:

- State (equilibrium / uncertainty / anomaly)
- Intensity (0–255)
- Duration
- Channel weights (LRA vs servo proportion)

### Haptic Waveform Library

DRV2605L has onboard waveform library (123 preset effects). Initial implementation uses library waveforms for LRA. Custom waveforms via streaming mode are a later refinement.

The three-state grammar maps to waveform families:
- Equilibrium: soft pulse waveforms, long interval
- Uncertainty: irregular click/buzz patterns, variable interval
- Anomaly: sharp impact waveforms, short duration, high amplitude

### Sliding Mass Control

Servo position commands from XIAO. Speed of traverse expresses urgency. Direction of traverse (if bilateral motion is implemented) could express directionality of anomaly source — which zone, which sensor axis.

---

## Integration with Meridian

### Signal Path

```
Sensor nodes → MQTT → Sensor Pi
    → Motif scoring pipeline → Inferno Pi
    → Interpretation layer → haptic command
    → BLE → Wrist-Puck XIAO → DRV2605L + SG51R
```

### Haptic Events as Motif Input

The wearer's interaction with the wrist-puck (if instrumented — removal, covering, deliberate stillness) can feed back as signal into the ecology. The boundary between observer and system is not hard.

### Unity AR Integration

The wrist-puck state is visible in the Unity AR motif graph as a node — the embodied human interpreter represented alongside the sensor nodes. Its haptic state at any moment is part of the ecology's record.

---

## Relation to Sound Field

The generative sound field (three-state acoustic grammar, Python MIDI → Reaktor/Cubase → surround) expresses the same grammar through a different sensory channel. The wrist-puck and the sound field are not redundant — they are complementary modalities:

- Sound field: ambient, spatial, background awareness, affects the room
- Wrist-puck: personal, private, body-present, travels with the wearer

A state change registered haptically while away from the sound environment is not lost. The wearer carries the ecology's current interpretation on their wrist.

---

## Current Status / Next Actions

| Item | Status | Notes |
|------|--------|-------|
| OpenSCAD enclosure v1 | In progress | `wrist_puck_enclosure_1.scad` |
| Component validation | Pending | Verify fit within geometry constraints |
| Yukonstruct print | Pending enclosure validation | |
| XIAO firmware skeleton | Not started | BLE receive + DRV2605L basic |
| DRV2605L waveform mapping | Not started | Map three states to waveform families |
| Servo sliding mass test | Not started | Characterise feel at different speeds |
| BLE integration with Inferno | Not started | Haptic command protocol |
| Wear testing | Not started | Comfort at 76mm vs 68mm |

---

## Knowledge Architecture Notes

*For AI re-entry.*

1. **This is not an alert device.** The design goal is pre-thematic, sub-propositional communication of system state. Alerts are a degenerate case. Hold the phenomenological framing or the design decisions won't make sense.

2. **The three-state grammar is the core constraint.** All hardware and firmware decisions serve it. Do not add states without strong reason — the value is in the wearer developing sensitivity to a simple, textured grammar over time.

3. **Dual channel is intentional.** LRA alone would be sufficient for alerts. The sliding mass adds the temporal/directional dimension that makes the grammar rich enough to be genuinely informative without being propositional.

4. **The sound field is a sibling project**, not a dependency. They share the grammar but operate independently.

5. **Sean's background in sound design** (Cubase, motorised fader control surfaces) directly informs the haptic grammar design. The feel of the wrist-puck is being designed with the same attention to texture and dynamics that goes into audio work.

---

*Companion documents: `GARDEN_ECOLOGY.md`, `KNOWLEDGE_ARCHITECTURE.md`, `docs/philosophy/`*
*See also: `Meridian/sound_field/` for the acoustic grammar sibling project*
