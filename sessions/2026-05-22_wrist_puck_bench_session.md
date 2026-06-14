# Session: 2026-05-22
*Afternoon — Wrist-Puck (v1.0) Bench Testing & Calibration*
*Participants: Sean, Antigravity*

---

## How this session began

Following up on the AR Guidance dashboard development, we moved to formalize a repeatable testing protocol for the hardware nodes. This session focuses specifically on the **Wrist-Puck v1.0** node. 

The physical components (ESP32-C3, DRV2605L, 10mm coin LRA, SG51R servo, jumper wires) are laid out on the bench. We do not have the LiPo batteries yet, so all tests are conducted on **Bench Power** (USB 5V). 

We also confirmed the transition from Yukonstruct to the in-house **Bambu Lab A1 Mini** for fabrication.

## Key developments

### Structured Commissioning Protocol
Extracted the 35-item testing checklist from the *Haptic Pucks and Pollen Pods (May 2026)* reference document into a standalone `node_commissioning_protocol.md`. This protocol strips out the battery-specific checks for today's run and provides a repeatable sequence covering Pre-Power, Power-On, Calibration, Wi-Fi, Motif, Safety, and Enclosure fit checks.

### Kanban Integration
The commissioning checklist has been directly pushed to the Hedgehogger Kanban board as a reusable template, allowing Sean to check off steps directly from his phone while hands are occupied at the bench.

## Current Bench Status
- ESP32-C3 connected to PC via USB-C.
- DRV2605L wired for I2C (SDA=GPIO6, SCL=GPIO7, 3.3V power).
- SG51R servo wired for PWM (GPIO5, 5V power).
- Bambu A1 Mini ready for `wrist_puck_enclosure_1.scad` (PLA/PETG, 0.2mm, 20% infill).

## Threads to carry forward

- [ ] Complete the physical wiring pre-power checks.
- [ ] Flash the base Wrist-Puck firmware (Arduino IDE 2.x, XIAO_ESP32C3, ArduinoJson v7, ESP32Servo, Wire).
- [ ] Test the AR Guidance overlay to verify the node appears with high confidence and correctly reflects its active state.
- [ ] Print the enclosure and verify fit tolerances (specifically the linear rail for the sliding mass).
