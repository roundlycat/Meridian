"""
Meridian V2 — Regime Manager (Layer 4)
"Continuance instead of rupture"

Selects the globally viable system mode while maintaining continuity over abrupt breaks.
Transitions between modes are eased and textured rather than stepped.

Regimes:
  • EXPLORATION: Open perceptual inquiry, balanced ambient cues, full sensory grounding.
  • QUIET: Minimal emissions, acoustic silence, softened visual and haptic presence.
  • SURVIVAL: Extreme cold, power deficit, or bus degradation; shedding peripheral loads.
  • TREATY: Land protocols active, non-recording enforced, sacred/treaty bounds honored.
  • NIGHT: Diurnal downshift based on ambient lux, resting cadence, prolonged intervals.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass
from enum import Enum
from typing import Any, Dict, Optional

from services.autonomy.boundary import BoundaryState, PowerTier
from services.autonomy.constraint import RefusalReason, RefusalState
from services.autonomy.viability import DegradationFlag, ViabilityState

log = logging.getLogger("autonomy.regime")


class RegimeType(str, Enum):
    EXPLORATION = "exploration"
    QUIET = "quiet"
    SURVIVAL = "survival"
    TREATY = "treaty"
    NIGHT = "night"


@dataclass
class RegimeState:
    active_regime: RegimeType
    previous_regime: Optional[RegimeType]
    transition_progress: float       # 0.0 (just initiated) to 1.0 (settled)
    blend_weight: float              # Eased progress via smoothstep
    entered_at: float
    transition_duration_s: float
    reason: str

    @property
    def is_transitioning(self) -> bool:
        return self.transition_progress < 1.0


def smoothstep(edge0: float, edge1: float, x: float) -> float:
    """Hermite interpolation for organic, non-rupturing transitions."""
    t = max(0.0, min(1.0, (x - edge0) / (edge1 - edge0)))
    return t * t * (3.0 - 2.0 * t)


class RegimeManager:
    """
    Evaluates system viability, boundaries, refusals, and diurnal/ecological context
    to sustain the appropriate operating regime with smooth, non-jarring transitions.
    """

    DEFAULT_TRANSITION_SECONDS = 15.0

    def __init__(self, transition_duration_s: float = DEFAULT_TRANSITION_SECONDS) -> None:
        self.transition_duration_s = transition_duration_s
        self._current_regime: RegimeType = RegimeType.EXPLORATION
        self._previous_regime: Optional[RegimeType] = None
        self._transition_start_time: float = 0.0
        self._reason: str = "Initial system bring-up"

    def determine_target_regime(
        self,
        viability: ViabilityState,
        boundary: BoundaryState,
        refusal: RefusalState,
        macro_env: Dict[str, Any],
    ) -> tuple[RegimeType, str]:
        """
        Calculates the appropriate regime based on relational priorities:
        Survival > Treaty/Protocol > Ecological Quiet > Diurnal Night > Exploration.
        """
        # 1. Survival: Hardware preservation or human cold risk overrides normal operation
        if (
            viability.is_critical
            or boundary.energy_budget.tier == PowerTier.MINIMAL_PRESERVATION
            or DegradationFlag.EXTREME_COLD in viability.flags
            or DegradationFlag.CRITICAL_POWER in viability.flags
        ):
            return (
                RegimeType.SURVIVAL,
                "Critical viability condition (sub-zero freeze, power deficit, or rail drop)",
            )

        # 2. Treaty / Protocol: Social refusal and land boundaries take precedence
        if (
            refusal.recording_prohibited
            or RefusalReason.SOCIAL_LAND_PROTOCOL in refusal.active_refusals
            or RefusalReason.SOCIAL_PRIVACY_BOUNDARY in refusal.active_refusals
        ):
            return (
                RegimeType.TREATY,
                "Land protocol / treaty territory active — honoring relational boundary",
            )

        # 3. Quiet: Ecological refusal (sensitive species nearby) or quiet mandate
        if refusal.quiet_mode_mandated:
            return (
                RegimeType.QUIET,
                "Sensitive species proximity / habitat quiet mandated by constraint engine",
            )

        # 4. Night: Diurnal downshift (lux < 5.0 or simulated night hour)
        sim_hour = macro_env.get("sim_hour")
        ambient_lux = macro_env.get("lux", 100.0)
        is_night = (ambient_lux < 3.0) or (sim_hour is not None and (sim_hour >= 22.0 or sim_hour <= 5.0))

        if is_night:
            return (
                RegimeType.NIGHT,
                "Diurnal downshift — low ambient illumination / resting cycle",
            )

        # 5. Exploration: Default ambient inquiry
        return (
            RegimeType.EXPLORATION,
            "Baseline ambient inquiry — all boundaries coherent and open",
        )

    def update(
        self,
        timestamp: float,
        viability: ViabilityState,
        boundary: BoundaryState,
        refusal: RefusalState,
        macro_env: Dict[str, Any],
    ) -> RegimeState:
        target_regime, reason = self.determine_target_regime(
            viability, boundary, refusal, macro_env
        )

        if target_regime != self._current_regime:
            log.info(
                "Regime shift initiated: %s -> %s (Reason: %s)",
                self._current_regime.value,
                target_regime.value,
                reason,
            )
            self._previous_regime = self._current_regime
            self._current_regime = target_regime
            self._transition_start_time = timestamp
            self._reason = reason

        elapsed = timestamp - self._transition_start_time
        if self._previous_regime is None or elapsed >= self.transition_duration_s:
            progress = 1.0
            weight = 1.0
        else:
            progress = max(0.0, min(1.0, elapsed / self.transition_duration_s))
            weight = smoothstep(0.0, 1.0, progress)

        return RegimeState(
            active_regime=self._current_regime,
            previous_regime=self._previous_regime,
            transition_progress=round(progress, 3),
            blend_weight=round(weight, 3),
            entered_at=self._transition_start_time,
            transition_duration_s=self.transition_duration_s,
            reason=self._reason,
        )
