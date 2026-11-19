"""
Unit and integration tests for Meridian V2 Relational Autonomy Core.
Tests all 5 layers:
  1. Viability Sensing Layer
  2. Boundary Maintenance Layer
  3. Constraint Engine
  4. Regime Manager
  5. Autopoietic Core
Plus end-to-end orchestration in RelationalAutonomyCore.
"""

import time
import unittest

from services.autonomy.autopoietic import (
    AutopoieticCore,
    DRV2605LWaveforms,
    HapticGrammarState,
)
from services.autonomy.boundary import (
    BoundaryMaintainer,
    PowerTier,
)
from services.autonomy.constraint import (
    ConstraintEngine,
    LandProtocolRule,
    RefusalReason,
    SpeciesProximityRule,
    WearerOpacityRule,
)
from services.autonomy.core import RelationalAutonomyCore
from services.autonomy.regime import (
    RegimeManager,
    RegimeType,
    smoothstep,
)
from services.autonomy.viability import (
    DegradationFlag,
    ViabilityAssessor,
)


class TestViabilitySensingLayer(unittest.TestCase):
    def setUp(self):
        self.assessor = ViabilityAssessor()

    def test_nominal_viability(self):
        self.assessor.ingest_ecology_node("w-sky-reference", {"ambient_temp": 18.0, "is_raining": False})
        self.assessor.ingest_device_telemetry(battery_voltage=3.95, charging_in_firebag=False, bus_errors=0)
        self.assessor.ingest_wearer_telemetry(contact_detected=True, skin_temp_c=32.0, motion_magnitude_g=0.1)

        state = self.assessor.assess()
        self.assertFalse(state.is_degraded)
        self.assertFalse(state.is_critical)
        self.assertGreater(state.scores.composite, 0.90)
        self.assertEqual(len(state.flags), 0)

    def test_subzero_cold_degradation(self):
        # Whitehorse winter condition: -28°C
        self.assessor.ingest_ecology_node("w-sky-reference", {"ambient_temp": -28.0, "is_raining": False})
        state = self.assessor.assess()

        self.assertIn(DegradationFlag.EXTREME_COLD, state.flags)
        self.assertTrue(state.is_critical)
        self.assertLess(state.scores.environmental, 0.50)

    def test_critical_power_and_firebag_status(self):
        # Low battery voltage (3.30V)
        self.assessor.ingest_device_telemetry(battery_voltage=3.30, charging_in_firebag=True)
        state = self.assessor.assess()

        self.assertIn(DegradationFlag.CRITICAL_POWER, state.flags)
        self.assertIn(DegradationFlag.CHARGING_FIREBAG_ACTIVE, state.flags)
        self.assertTrue(state.is_critical)

    def test_thermal_throttle_and_bus_errors(self):
        self.assessor.ingest_ecology_node("c1-hailo-camera", {"hailo_temp_c": 72.0})
        self.assessor.ingest_device_telemetry(bus_errors=8)
        state = self.assessor.assess()

        self.assertIn(DegradationFlag.THERMAL_THROTTLE, state.flags)
        self.assertIn(DegradationFlag.BUS_INTEGRITY_DEGRADED, state.flags)
        self.assertLess(state.scores.device, 0.60)


class TestBoundaryMaintenanceLayer(unittest.TestCase):
    def setUp(self):
        self.maintainer = BoundaryMaintainer()

    def test_informational_boundary_strips_interior_modeling(self):
        # Incoming payload attempting to model wearer emotional / cognitive interiority
        intrusive_payload = {
            "skin_temp_c": 32.5,
            "motion_magnitude_g": 0.12,
            "contact_detected": True,
            "stress_level": 0.85,
            "mood": "anxious",
            "intent": "fleeing",
            "cognitive_load": 0.72,
        }

        sanitized = self.maintainer.sanitize_wearer_telemetry(intrusive_payload)

        # Objective physical surface conditions must be preserved
        self.assertIn("skin_temp_c", sanitized)
        self.assertIn("motion_magnitude_g", sanitized)
        self.assertIn("contact_detected", sanitized)

        # Psychological / interior inferences must be strictly stripped
        self.assertNotIn("stress_level", sanitized)
        self.assertNotIn("mood", sanitized)
        self.assertNotIn("intent", sanitized)
        self.assertNotIn("cognitive_load", sanitized)

    def test_energy_budget_scaling(self):
        assessor = ViabilityAssessor()
        assessor.ingest_device_telemetry(battery_voltage=3.95)
        nominal_viability = assessor.assess()
        budget_full = self.maintainer.compute_energy_budget(nominal_viability)
        self.assertEqual(budget_full.tier, PowerTier.FULL)
        self.assertTrue(budget_full.hailo_vision_enabled)
        self.assertTrue(budget_full.servo_actuation_enabled)

        # Depleted battery
        assessor.ingest_device_telemetry(battery_voltage=3.30)
        critical_viability = assessor.assess()
        budget_min = self.maintainer.compute_energy_budget(critical_viability)
        self.assertEqual(budget_min.tier, PowerTier.MINIMAL_PRESERVATION)
        self.assertFalse(budget_min.hailo_vision_enabled)
        self.assertFalse(budget_min.servo_actuation_enabled)

        # Firebag charging isolation
        assessor.ingest_device_telemetry(charging_in_firebag=True)
        firebag_viability = assessor.assess()
        budget_firebag = self.maintainer.compute_energy_budget(firebag_viability)
        self.assertEqual(budget_firebag.tier, PowerTier.ISOLATED_CHARGING)
        self.assertFalse(budget_firebag.hailo_vision_enabled)
        self.assertEqual(budget_firebag.lra_max_intensity, 0)


class TestConstraintEngine(unittest.TestCase):
    def setUp(self):
        self.engine = ConstraintEngine()

    def test_ecological_refusal_on_raven_detection(self):
        context = {
            "hailo_telemetry": {
                "frame_detections": [
                    {"class": "raven", "confidence": 0.92, "bbox_xywh": [0.1, 0.1, 0.2, 0.2]}
                ]
            }
        }
        refusal = self.engine.evaluate(timestamp=time.time(), context=context)

        self.assertTrue(refusal.is_refusing)
        self.assertIn(RefusalReason.ECOLOGICAL_SPECIES_PRESENCE, refusal.active_refusals)
        self.assertTrue(refusal.quiet_mode_mandated)
        self.assertIn("raven", refusal.rationales[0])

    def test_social_refusal_on_land_protocol(self):
        context = {
            "land_protocol": {
                "active": True,
                "protocol_name": "Kwanlin Dün Traditional Territory Land Protocol",
            }
        }
        refusal = self.engine.evaluate(timestamp=time.time(), context=context)

        self.assertTrue(refusal.is_refusing)
        self.assertIn(RefusalReason.SOCIAL_LAND_PROTOCOL, refusal.active_refusals)
        self.assertTrue(refusal.recording_prohibited)
        self.assertTrue(refusal.vision_inhibited)
        self.assertTrue(refusal.ar_overlays_inhibited)

    def test_wearer_refusal_on_puck_cover(self):
        context = {
            "wearer_telemetry": {
                "puck_covered": True,
                "contact_detected": True,
            }
        }
        refusal = self.engine.evaluate(timestamp=time.time(), context=context)

        self.assertTrue(refusal.is_refusing)
        self.assertIn(RefusalReason.WEARER_OPACITY_REQUEST, refusal.active_refusals)
        self.assertTrue(refusal.haptics_inhibited)
        self.assertTrue(refusal.ar_overlays_inhibited)


class TestRegimeManager(unittest.TestCase):
    def setUp(self):
        self.regime_mgr = RegimeManager(transition_duration_s=10.0)
        self.assessor = ViabilityAssessor()
        self.maintainer = BoundaryMaintainer()
        self.engine = ConstraintEngine()

    def test_smooth_transition_interpolation(self):
        # Exploration at t=0
        t0 = 1000.0
        viability = self.assessor.assess()
        boundary = self.maintainer.evaluate(viability, {})
        refusal = self.engine.evaluate(t0, {})
        env = {"lux": 150.0}

        s0 = self.regime_mgr.update(t0, viability, boundary, refusal, env)
        self.assertEqual(s0.active_regime, RegimeType.EXPLORATION)
        self.assertEqual(s0.transition_progress, 1.0)

        # Trigger quiet mode via raven at t=1001.0
        t1 = 1001.0
        refusal_quiet = self.engine.evaluate(
            t1,
            {"hailo_telemetry": {"frame_detections": [{"class": "raven", "confidence": 0.88}]}},
        )
        s1 = self.regime_mgr.update(t1, viability, boundary, refusal_quiet, env)
        self.assertEqual(s1.active_regime, RegimeType.QUIET)
        self.assertEqual(s1.previous_regime, RegimeType.EXPLORATION)
        self.assertEqual(s1.transition_progress, 0.0)

        # Halfway through transition window (t = 1006.0, elapsed = 5s / 10s)
        t_half = 1006.0
        s_half = self.regime_mgr.update(t_half, viability, boundary, refusal_quiet, env)
        self.assertEqual(s_half.transition_progress, 0.5)
        # smoothstep(0, 1, 0.5) = 0.5 * 0.5 * (3 - 1) = 0.5
        self.assertAlmostEqual(s_half.blend_weight, 0.5, places=2)

        # After transition completes (t = 1012.0)
        t_done = 1012.0
        s_done = self.regime_mgr.update(t_done, viability, boundary, refusal_quiet, env)
        self.assertEqual(s_done.transition_progress, 1.0)
        self.assertEqual(s_done.blend_weight, 1.0)
        self.assertFalse(s_done.is_transitioning)

    def test_regime_priorities(self):
        t = 2000.0
        # 1. Survival beats Treaty & Quiet
        self.assessor.ingest_device_telemetry(battery_voltage=3.25)  # Critical
        viability = self.assessor.assess()
        boundary = self.maintainer.evaluate(viability, {})
        refusal = self.engine.evaluate(
            t,
            {
                "land_protocol": {"active": True},
                "hailo_telemetry": {"frame_detections": [{"class": "raven", "confidence": 0.9}]},
            },
        )
        regime = self.regime_mgr.update(t, viability, boundary, refusal, {"lux": 100.0})
        self.assertEqual(regime.active_regime, RegimeType.SURVIVAL)


class TestAutopoieticCore(unittest.TestCase):
    def setUp(self):
        self.core = AutopoieticCore()
        self.assessor = ViabilityAssessor()
        self.maintainer = BoundaryMaintainer()
        self.engine = ConstraintEngine()
        self.regime_mgr = RegimeManager()

    def test_three_state_grammar_deposits(self):
        t = 3000.0
        viability = self.assessor.assess()
        boundary = self.maintainer.evaluate(viability, {})
        refusal = self.engine.evaluate(t, {})
        regime = self.regime_mgr.update(t, viability, boundary, refusal, {"lux": 100.0})

        # 1. Equilibrium
        d_eq = self.core.generate_deposits(
            t, HapticGrammarState.EQUILIBRIUM, regime, viability, boundary, refusal, {}
        )
        self.assertEqual(d_eq.haptic.state, HapticGrammarState.EQUILIBRIUM)
        self.assertFalse(d_eq.haptic.is_suppressed)
        self.assertEqual(d_eq.haptic.lra_waveform_id, DRV2605LWaveforms.SOFT_BUMP)
        self.assertEqual(d_eq.haptic.servo_target_position, 0.50)

        # 2. Uncertainty
        d_un = self.core.generate_deposits(
            t, HapticGrammarState.UNCERTAINTY, regime, viability, boundary, refusal, {}
        )
        self.assertEqual(d_un.haptic.state, HapticGrammarState.UNCERTAINTY)
        self.assertEqual(d_un.haptic.lra_waveform_id, DRV2605LWaveforms.SOFT_FUZZ)
        self.assertIn(d_un.haptic.servo_target_position, {0.35, 0.65})

        # 3. Anomaly
        d_an = self.core.generate_deposits(
            t, HapticGrammarState.ANOMALY, regime, viability, boundary, refusal, {}
        )
        self.assertEqual(d_an.haptic.state, HapticGrammarState.ANOMALY)
        self.assertEqual(d_an.haptic.lra_waveform_id, DRV2605LWaveforms.STRONG_CLICK)
        self.assertGreater(d_an.haptic.lra_intensity, d_un.haptic.lra_intensity)

    def test_haptic_suppression_on_opacity(self):
        t = 3050.0
        viability = self.assessor.assess()
        boundary = self.maintainer.evaluate(viability, {})
        refusal = self.engine.evaluate(t, {"wearer_telemetry": {"puck_covered": True}})
        regime = self.regime_mgr.update(t, viability, boundary, refusal, {})

        deposits = self.core.generate_deposits(
            t, HapticGrammarState.ANOMALY, regime, viability, boundary, refusal, {}
        )
        self.assertTrue(deposits.haptic.is_suppressed)
        self.assertEqual(deposits.haptic.lra_intensity, 0)
        self.assertEqual(deposits.haptic.state, HapticGrammarState.QUIESCENCE)


class TestRelationalAutonomyCoreIntegration(unittest.TestCase):
    def setUp(self):
        self.core = RelationalAutonomyCore(transition_duration_s=5.0)

    def test_full_pipeline_flow(self):
        # 1. Ingest normal environment
        self.core.ingest_ecology_telemetry("w-sky-reference", {"ambient_temp": 14.5, "lux": 250.0, "is_raining": False})
        self.core.ingest_ecology_telemetry("e1-central", {"co2_ppm": 420.0, "acoustic_db": 28.0})
        self.core.ingest_device_health(battery_voltage=4.05, charging_in_firebag=False, bus_errors=0)

        # 2. Ingest wearer telemetry with intrusive interior modeling
        self.core.ingest_wearer_telemetry({
            "contact_detected": True,
            "skin_temp_c": 31.8,
            "motion_magnitude_g": 0.05,
            "inferred_emotion": "calm",  # should be stripped
        })

        deposits = self.core.tick()

        # Check regime and deposits
        self.assertEqual(deposits.regime, RegimeType.EXPLORATION)
        self.assertEqual(deposits.haptic.state, HapticGrammarState.EQUILIBRIUM)
        self.assertFalse(deposits.haptic.is_suppressed)
        self.assertFalse(deposits.ar.is_suppressed)
        self.assertEqual(self.core.boundary._total_inferences_stripped, 1)

    def test_raven_shifts_to_quiet_regime(self):
        self.core.ingest_ecology_telemetry("w-sky-reference", {"ambient_temp": 12.0, "lux": 300.0, "is_raining": False})
        self.core.ingest_ecology_telemetry("c1-hailo-camera", {
            "frame_detections": [{"class": "raven", "confidence": 0.95, "bbox_xywh": [0.2, 0.2, 0.1, 0.1]}]
        })
        deposits = self.core.tick()

        self.assertEqual(deposits.regime, RegimeType.QUIET)
        self.assertLess(deposits.ar.luminance, 0.50)  # dimmed visual presence

    def test_land_protocol_treaty_mode(self):
        self.core.set_land_protocol(active=True, protocol_name="Kwanlin Dün Traditional Territory")
        deposits = self.core.tick()

        self.assertEqual(deposits.regime, RegimeType.TREATY)
        self.assertTrue(deposits.ar.is_suppressed)


if __name__ == "__main__":
    unittest.main()
