"""
Meridian V2 — Boundary Maintenance Layer (Layer 2)
"No reaching in"

Maintains the physical, energetic, and informational membranes separating system from wearer.
Protects device coherence and wearer autonomy.

Boundaries:
  1. Physical boundary: chassis integrity, moisture ingress, mechanical shock.
  2. Energetic boundary: dynamic power budgeting based on ViabilityState.
  3. Informational boundary: strict refusal of interior modeling and affective inference.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass, field
from enum import Enum
from typing import Any, Dict, List, Set

from services.autonomy.viability import DegradationFlag, ViabilityState

log = logging.getLogger("autonomy.boundary")

# Prohibited keys representing attempts to model wearer interiority / psychological states
FORBIDDEN_INTERIOR_KEYS: Set[str] = {
    "intent",
    "intent_confidence",
    "mood",
    "emotion",
    "valence",
    "arousal",
    "affect",
    "stress",
    "stress_level",
    "cognitive_load",
    "attention_score",
    "fatigue_inferred",
    "psychological_state",
    "user_preference_prediction",
}


class PowerTier(str, Enum):
    FULL = "full"                      # Full vision (Hailo-8L), full dual-channel haptics
    CONSTRAINED = "constrained"        # Duty-cycle Hailo inferencing, reduce haptic servo rate
    MINIMAL_PRESERVATION = "minimal"   # Power off Hailo vision, disable servo, LRA only
    ISOLATED_CHARGING = "firebag"      # Battery charging in firebag; actuators disabled


@dataclass(frozen=True)
class EnergyBudget:
    tier: PowerTier
    hailo_vision_enabled: bool
    hailo_max_fps: float               # Frames per second cap
    servo_actuation_enabled: bool      # Channel 2 sliding mass enabled
    lra_max_intensity: int             # 0-255 cap on LRA pulse
    telemetry_interval_s: float        # Reporting period


@dataclass
class BoundaryState:
    timestamp: float
    energy_budget: EnergyBudget
    physical_integrity_ok: bool
    moisture_detected: bool
    shock_detected: bool
    informational_boundary_defenses: int   # Count of stripped interior inference attempts
    sanitized_wearer_metrics: Dict[str, Any] = field(default_factory=dict)
    active_breaches: List[str] = field(default_factory=list)


class BoundaryMaintainer:
    """
    Enforces physical limits, computes energetic budgets, and scrubs incoming
    data streams to strictly prohibit interior modeling of the wearer.
    """

    def __init__(self) -> None:
        self._total_inferences_stripped = 0

    def sanitize_wearer_telemetry(self, raw_payload: Dict[str, Any]) -> Dict[str, Any]:
        """
        Hard informational boundary enforcement.
        Strips any cognitive, affective, or psychological inferences.
        Preserves only objective physical surface boundary conditions.
        """
        sanitized: Dict[str, Any] = {}
        breach_keys: List[str] = []

        for k, v in raw_payload.items():
            k_lower = k.lower()
            if any(forbidden in k_lower for forbidden in FORBIDDEN_INTERIOR_KEYS):
                breach_keys.append(k)
                self._total_inferences_stripped += 1
            else:
                sanitized[k] = v

        if breach_keys:
            log.warning(
                "Informational boundary defense triggered! Stripped interior modeling fields: %s",
                breach_keys,
            )

        return sanitized

    def compute_energy_budget(self, viability: ViabilityState) -> EnergyBudget:
        """
        Determines the energetic tier without compromising system survivability.
        """
        # Firebag charging isolation
        if DegradationFlag.CHARGING_FIREBAG_ACTIVE in viability.flags:
            return EnergyBudget(
                tier=PowerTier.ISOLATED_CHARGING,
                hailo_vision_enabled=False,
                hailo_max_fps=0.0,
                servo_actuation_enabled=False,
                lra_max_intensity=0,
                telemetry_interval_s=30.0,
            )

        # Critical power or thermal overload -> Minimal preservation
        if (
            DegradationFlag.CRITICAL_POWER in viability.flags
            or DegradationFlag.THERMAL_CRITICAL in viability.flags
            or viability.scores.device < 0.35
        ):
            return EnergyBudget(
                tier=PowerTier.MINIMAL_PRESERVATION,
                hailo_vision_enabled=False,
                hailo_max_fps=0.0,
                servo_actuation_enabled=False,
                lra_max_intensity=90,  # Faint baseline tick
                telemetry_interval_s=15.0,
            )

        # Low power or thermal throttling -> Constrained
        if (
            DegradationFlag.LOW_POWER in viability.flags
            or DegradationFlag.THERMAL_THROTTLE in viability.flags
            or viability.scores.device < 0.70
        ):
            return EnergyBudget(
                tier=PowerTier.CONSTRAINED,
                hailo_vision_enabled=True,
                hailo_max_fps=0.1,  # 1 frame every 10 seconds
                servo_actuation_enabled=True,
                lra_max_intensity=180,
                telemetry_interval_s=10.0,
            )

        # Normal full operation
        return EnergyBudget(
            tier=PowerTier.FULL,
            hailo_vision_enabled=True,
            hailo_max_fps=1.0,
            servo_actuation_enabled=True,
            lra_max_intensity=255,
            telemetry_interval_s=5.0,
        )

    def evaluate(
        self,
        viability: ViabilityState,
        raw_wearer_payload: Dict[str, Any],
        moisture_sensor: bool = False,
    ) -> BoundaryState:
        """
        Evaluates physical, energetic, and informational boundaries.
        """
        sanitized = self.sanitize_wearer_telemetry(raw_wearer_payload)
        energy_budget = self.compute_energy_budget(viability)

        shock_detected = DegradationFlag.EXCESSIVE_SHOCK in viability.flags
        breaches: List[str] = []

        if moisture_sensor:
            breaches.append("Moisture ingress detected at wrist enclosure")
        if shock_detected:
            breaches.append("Mechanical shock exceeded 4.5g limit")

        physical_ok = len(breaches) == 0

        return BoundaryState(
            timestamp=viability.timestamp,
            energy_budget=energy_budget,
            physical_integrity_ok=physical_ok,
            moisture_detected=moisture_sensor,
            shock_detected=shock_detected,
            informational_boundary_defenses=self._total_inferences_stripped,
            sanitized_wearer_metrics=sanitized,
            active_breaches=breaches,
        )
