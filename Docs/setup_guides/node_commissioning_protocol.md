# Node Commissioning Protocol: Wrist-Puck Haptic Node (v1.0)
_Generated: 2026-05-22_

This protocol is derived from Section 2.6 of the *Haptic Pucks and Pollen Pods — Complete Variant Reference*.
**Note:** This variant is for **Bench Power** testing (LiPo steps removed).

---

## Pre-Power Checks (4 items)
1. Confirm all wiring connections match pin assignment table — no bare wire contacts touching enclosure or each other.
2. Verify I2C pull-up resistors present (on DRV board or on perfboard) — 4.7 kΩ SDA and SCL to 3.3 V.
3. Confirm LRA is press-fit flush, face down, with no adhesive bridging the LRA terminals.
4. Confirm sliding mass moves freely in rail slot through full servo sweep range — no binding.

## Power-On Checks (5 items)
5. Connect USB-C (Bench Power) — confirm XIAO power LED illuminates, no smoke or heat.
6. Open Serial Monitor at 115200 baud — confirm firmware boot messages, no crash loop.
7. Confirm DRV2605L detected at I2C address 0x5A in serial output.
8. *(Skipped: Battery voltage reading plausible on ADC GPIO2).*
9. Confirm no hardware watchdog resets during boot sequence.

## Calibration Checks (5 items)
10. Run DRV2605L auto-calibration routine — confirm success flag returned via serial.
11. Confirm LRA resonant frequency detected within range for C10-100 (~175 Hz).
12. Sweep servo 750–2250 µs — confirm full travel without binding or stall.
13. Confirm center position (1500 µs) returns mass to geometric center of rail slot.
14. Play DRV2605L effect 47 manually — confirm LRA vibration felt through enclosure surface.

## Wi-Fi Checks (3 items)
15. Confirm SSID and password correct, 2.4 GHz band (not 5 GHz — ESP32-C3 does not support 5 GHz).
16. Confirm IP address assigned and printed to serial — note for UDP sender configuration.
17. Confirm UDP listener active on port 9000 — send test ping from sender host.

## UDP Motif Tests (6 items)
18. Send "rough_bump" motif — confirm LRA effect 47 fires, servo moves to 1100 µs, LRA effect 52 fires, servo returns center.
19. Send "weight_left" motif — confirm servo moves to 800 µs, low RTP amplitude felt, LRA stops, servo returns center.
20. Send "heartbeat" motif (repeat:3) — confirm double pulse × 3 repetitions with servo position shift.
21. Send malformed JSON — confirm firmware discards gracefully without crash.
22. Send motif with unknown id — confirm firmware executes steps normally (id is for logging only).
23. Send motif with repeat:10 and 4 steps — confirm all 40 step executions complete without watchdog reset.

## Safety Checks (2 items)
24. Confirm idle timeout — after 5 seconds of no motifs received, servo auto-centers.
25. Confirm hardware watchdog — introduce >8 s blocking delay in test firmware; confirm reset and recovery.
26. *(Skipped: Low battery alert).*
27. *(Skipped: LiPo thermal check).*

## Enclosure Fit Checks (6 items)
*(To be performed once Bambu A1 Mini prints are complete)*
28. Confirm lid snaps flush with no component interference inside.
29. Confirm USB-C port accessible through wall cutout with connector — no forced angle.
30. Confirm LRA window provides audible/tactile transmission — vibration felt clearly on lid exterior.
31. Confirm strap slots accept 22 mm NATO strap without forcing.
32. Confirm enclosure does not flex or creak under normal wrist-worn loading.
33. Confirm no wires pinched in lid seam — inspect perimeter with light before final close.
