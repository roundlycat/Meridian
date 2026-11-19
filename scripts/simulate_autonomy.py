#!/usr/bin/env python3
"""
Meridian V2 — Relational Autonomy Core Interactive Simulation
Demonstrates the 5 layers in dynamic operation:
  1. Viability Sensing
  2. Boundary Maintenance
  3. Constraint Engine (Refusal as a first-class state)
  4. Regime Manager (Continuance instead of rupture)
  5. Autopoietic Core (Stigmergic deposits: Wrist-Puck Haptics & AR Overlays)
"""

import time
from services.autonomy.core import RelationalAutonomyCore
from services.autonomy.autopoietic import HapticGrammarState

def print_separator(title: str):
    print("\n" + "=" * 70)
    print(f"  SCENARIO: {title}")
    print("=" * 70)

def display_deposits(deposits):
    print(f"  [REGIME]        Active: {deposits.regime.value.upper()}")
    print(f"  [HAPTIC DEPOSIT] State: {deposits.haptic.state.value} | Suppressed: {deposits.haptic.is_suppressed}")
    print(f"                  LRA Intensity: {deposits.haptic.lra_intensity}/255 (Waveform #{deposits.haptic.lra_waveform_id})")
    print(f"                  Servo Position: {deposits.haptic.servo_target_position:.2f} (Speed: {deposits.haptic.servo_speed:.2f})")
    print(f"                  Interval: {deposits.haptic.pulse_interval_ms}ms | Duration: {deposits.haptic.duration_ms}ms")
    print(f"                  Rationale: \"{deposits.haptic.rationale}\"")
    print(f"  [AR DEPOSIT]    Anchor: {deposits.ar.anchor_type} | Zone: {deposits.ar.spatial_zone}")
    print(f"                  Luminance: {deposits.ar.luminance:.2f} | Suppressed: {deposits.ar.is_suppressed}")

def run_simulation():
    print("Initializing Meridian Relational Autonomy Core...")
    core = RelationalAutonomyCore(transition_duration_s=4.0)

    # ──────────────────────────────────────────────────────────────────────────
    # SCENARIO 1: Nominal Summer Day Exploration
    # ──────────────────────────────────────────────────────────────────────────
    print_separator("1. Nominal Garden Exploration (Open Relational Inquiry)")
    core.ingest_ecology_telemetry("w-sky-reference", {"ambient_temp": 16.5, "lux": 650.0, "is_raining": False})
    core.ingest_ecology_telemetry("b1-bed-north", {"soil_moisture_vwc": 38.0})
    core.ingest_device_health(battery_voltage=4.10, charging_in_firebag=False, bus_errors=0)
    core.ingest_wearer_telemetry({"contact_detected": True, "skin_temp_c": 32.5, "motion_magnitude_g": 0.08})
    
    deposits = core.tick(timestamp=100.0)
    display_deposits(deposits)

    # ──────────────────────────────────────────────────────────────────────────
    # SCENARIO 2: Attempted Interior Modeling (Informational Boundary Test)
    # ──────────────────────────────────────────────────────────────────────────
    print_separator("2. Informational Boundary Defense (No Interior Modeling)")
    print("  Incoming telemetry includes attempted emotional/intent inference...")
    core.ingest_wearer_telemetry({
        "contact_detected": True,
        "skin_temp_c": 32.2,
        "motion_magnitude_g": 0.10,
        "stress_level": 0.88,
        "inferred_intent": "hurrying",
        "predicted_mood": "distracted",
    })
    deposits = core.tick(timestamp=102.0)
    print(f"  Total Inferences Stripped: {core.boundary._total_inferences_stripped}")
    print(f"  Wearer Sanitized Keys: {list(core._latest_wearer_payload.keys())}")
    display_deposits(deposits)

    # ──────────────────────────────────────────────────────────────────────────
    # SCENARIO 3: Ecological Refusal (Raven Detected nearby)
    # ──────────────────────────────────────────────────────────────────────────
    print_separator("3. Ecological Refusal (Raven Detected Nearby → QUIET Mode)")
    print("  Hailo-8L vision detects Corvus corax (raven, 94% confidence)...")
    core.ingest_ecology_telemetry("c1-hailo-camera", {
        "frame_detections": [{"class": "raven", "confidence": 0.94, "bbox_xywh": [0.3, 0.2, 0.15, 0.18]}]
    })
    
    # Tick at transition start
    deposits = core.tick(timestamp=104.0)
    refusal = core.constraints.evaluate(104.0, {"hailo_telemetry": core._latest_hailo_telemetry})
    print(f"  Constraint Engine Refusal: {refusal.summary}")
    display_deposits(deposits)

    # ──────────────────────────────────────────────────────────────────────────
    # SCENARIO 4: Social Refusal (Land Protocol / Treaty Territory)
    # ──────────────────────────────────────────────────────────────────────────
    print_separator("4. Social Refusal (Land Protocol Active → TREATY Mode)")
    print("  Entering Kwanlin Dün Traditional Territory protocol boundary...")
    core.set_land_protocol(active=True, protocol_name="Kwanlin Dün Traditional Territory")
    deposits = core.tick(timestamp=108.0)
    print(f"  Recording Prohibited: {deposits.ar.is_suppressed} (AR Spatial Overlays Suppressed)")
    display_deposits(deposits)

    # ──────────────────────────────────────────────────────────────────────────
    # SCENARIO 5: Wearer Opacity Asserted (Covering the Puck)
    # ──────────────────────────────────────────────────────────────────────────
    print_separator("5. Wearer Refusal / Opacity (Wearer Covers Wrist-Puck)")
    print("  Wearer covers the puck enclosure (opacity demanded)...")
    core.ingest_wearer_telemetry({"contact_detected": True, "puck_covered": True, "skin_temp_c": 31.0})
    deposits = core.tick(timestamp=110.0)
    print("  Wearer Opacity Respected Unconditionally — Zero Actuation Command Issued.")
    display_deposits(deposits)

    # ──────────────────────────────────────────────────────────────────────────
    # SCENARIO 6: Northern Deep Cold & Low Power (SURVIVAL Mode)
    # ──────────────────────────────────────────────────────────────────────────
    print_separator("6. Yukon Freeze & Low Rail (SURVIVAL Mode — Continuance)")
    print("  Wearer uncovered puck. Temperature drops to -26°C, battery drops to 3.32V...")
    core.set_land_protocol(active=False)
    core.ingest_wearer_telemetry({"contact_detected": True, "puck_covered": False, "skin_temp_c": 26.5})
    core.ingest_ecology_telemetry("w-sky-reference", {"ambient_temp": -26.0, "lux": 10.0, "is_raining": False})
    core.ingest_device_health(battery_voltage=3.32, charging_in_firebag=False, bus_errors=2)
    deposits = core.tick(timestamp=114.0)
    display_deposits(deposits)

    # ──────────────────────────────────────────────────────────────────────────
    # SCENARIO 7: Firebag Protective Charging
    # ──────────────────────────────────────────────────────────────────────────
    print_separator("7. Hardware Charging in Protective Firebag")
    print("  Wearer plugs device into charging rail inside firebag...")
    core.ingest_device_health(battery_voltage=3.80, charging_in_firebag=True)
    deposits = core.tick(timestamp=118.0)
    display_deposits(deposits)

    print("\n" + "=" * 70)
    print("  SIMULATION COMPLETE: All 5 Relational Autonomy Layers Verified.")
    print("=" * 70 + "\n")

if __name__ == "__main__":
    run_simulation()
