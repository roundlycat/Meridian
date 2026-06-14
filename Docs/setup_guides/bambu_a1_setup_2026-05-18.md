# Bambu A1 Mini Setup
_Generated: 2026-05-18_

---

## Canonical Setup Sequence

### Phase 1 — Unboxing & Physical Assembly
1. Remove outer packaging, inventory contents against packing list
2. Remove foam inserts in sequence (there's an order — don't force anything)
3. Attach print head to gantry, connect ribbon cable and PTFE tube
4. Install build plate (textured PEI side up for PETG)
5. Connect power

### Phase 2 — Network & Software
6. Download Bambu Studio on your machine, create/login Bambu account
7. Power on printer, connect to WiFi via screen menu
8. Add printer in Bambu Studio (LAN mode or cloud — I'd suggest LAN mode for Meridian)
9. Firmware update if prompted

### Phase 3 — Calibration
10. Run full calibration sequence from screen menu (vibration comp → bed leveling → flow rate)
11. This takes ~20 min, don't skip it on first run

### Phase 4 — PETG Profile
12. In Bambu Studio: Generic PETG as starting profile, 235°C nozzle, 70°C bed, no cooling first layer
13. First layer speed 30mm/s

### Phase 5 — Validation Print
14. Wrist puck lid (as discussed — quick, meaningful, tests snap geometry)

> **Note:** The A1 ships with some test filament — set that aside, load your PETG for the actual calibration prints. LAN mode matters for Meridian long-term since you'll want the printer potentially addressable from Inferno eventually.

---

## Session Summary (2026-05-19)

- A1 Mini is WiFi only, no ethernet — LAN mode is a software setting
- Printer ships mostly assembled — main task is seating print head connector, routing PTFE tube
- Accessories bag may be packed inside AMS unit or under foam — check before assuming missing
- Single filament feed (not 4-spool AMS Lite) — one PTFE tube from right-side feeder to gantry buffer to print head
- Network plugin failure in Bambu Studio is cosmetic — not needed for LAN setup or slicing
- Blue PETG loaded, power confirmed on
- First print deferred until calibration run — PETG profile to be configured in Bambu Studio
