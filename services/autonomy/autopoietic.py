"""
Meridian V2 — Autopoietic Core (Layer 5)
"Deposited, not commanded"

Maintains system viability while respecting wearer autonomy and opacity.
Outputs are not imperative instructions ("Turn left!", "Alert!"), but stigmergic
environmental deposits left in the sensory field for the wearer to inhabit or ignore.

Modulates:
  • Wrist-Puck Haptics: Three-state grammar (Equilibrium / Uncertainty / Anomaly),
    dual-channel (LRA coin motor + servo sliding mass on linear rail).
  • AR Overlays: Spatial, world-anchored deposits (not heads-up HUD popups).
  • Self-Repair: Gracefully absorbs bus degradations and sensor outages without override.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass, field
from enum import Enum
from typing import Any, Dict, Optional

from services.autonomy.boundary import BoundaryState, PowerTier
from services.autonomy.constraint import RefusalState
from services.autonomy.regime import RegimeState, RegimeType
from services.autonomy.viability import DegradationFlag, ViabilityState

log = logging.getLogger("autonomy.autopoietic")


class HapticGrammarState(str, Enum):
    EQUILIBRIUM = "equilibrium"      # Stable pattern, slow gentle low-amplitude pulse
    UNCERTAINTY = "uncertainty"      # Diverging scores, irregular rhythm, slow sliding drift
    ANOMALY = "anomaly"              # Distinct threshold crossing, traverse sweep
    QUIESCENCE = "quiescence"        # Zero emission; opacity respected or system sleeping


# DRV2605L Waveform Library Presets (Standard TI Library)
class DRV2605LWaveforms:
    STRONG_CLICK = 1
    SHARP_TICK = 10
    SOFT_BUMP = 11
    DOUBLE_CLICK = 12
    TRIPLE_CLICK = 13
    SOFT_FUZZ = 14
    TRANSITION_HUM = 15
    ALERT_PULSE = 47
    SMOOTH_HUM = 118


@dataclass
class HapticDeposit:
    state: HapticGrammarState
    lra_intensity: int              # 0 - 255
    lra_waveform_id: int            # DRV2605L waveform index
    servo_target_position: float    # 0.0 (home/left) to 1.0 (far/right), 0.5 (center)
    servo_speed: float              # 0.0 (static) to 1.0 (maximum safe slew)
    pulse_interval_ms: int          # Period between periodic haptic pulses
    duration_ms: int                # Active actuation window
    is_suppressed: bool = False     # True if muted by refusal or opacity
    rationale: str = ""


@dataclass
class ARDeposit:
    anchor_type: str                # e.g. "environmental_motif", "boundary_horizon", "quiescent"
    spatial_zone: str               # e.g. "b1-bed-north", "canopy-periphery", "sky-baseline"
    luminance: float                # 0.0 (invisible) to 1.0 (full visual presence)
    persistence_seconds: float
    metadata: Dict[str, Any] = field(default_factory=dict)
    is_suppressed: bool = False


@dataclass
class AutopoieticDeposits:
    timestamp: float
    regime: RegimeType
    haptic: HapticDeposit
    ar: ARDeposit
    system_coherence: Dict[str, Any] = field(default_factory=dict)


class AutopoieticCore:
    """
    Transforms system state, ecological regimes, and constraints into non-directive
    deposits that respect wearer autonomy and maintain self-repair.
    """

    def __init__(self) -> None:
        self._servo_current_pos: float = 0.5

    def synthesize_haptic_deposit(
        self,
        grammar_state: HapticGrammarState,
        regime: RegimeState,
        viability: ViabilityState,
        boundary: BoundaryState,
        refusal: RefusalState,
    ) -> HapticDeposit:
        # 1. Wearer Opacity / Refusal: Hard suppression
        if refusal.haptics_inhibited or not viability.telemetry_snapshot.get("wearer_contact", True):
            return HapticDeposit(
                state=HapticGrammarState.QUIESCENCE,
                lra_intensity=0,
                lra_waveform_id=0,
                servo_target_position=0.5,
                servo_speed=0.0,
                pulse_interval_ms=0,
                duration_ms=0,
                is_suppressed=True,
                rationale="Wearer opacity or contact withdrawal respected unconditionally",
            )

        # 2. Firebag Charging / Hardware Protection
        if boundary.energy_budget.tier == PowerTier.ISOLATED_CHARGING:
            return HapticDeposit(
                state=HapticGrammarState.QUIESCENCE,
                lra_intensity=0,
                lra_waveform_id=0,
                servo_target_position=0.5,
                servo_speed=0.0,
                pulse_interval_ms=0,
                duration_ms=0,
                is_suppressed=True,
                rationale="Battery charging in protective firebag — actuators isolated",
            )

        # Base parameters depending on 3-state grammar
        if grammar_state == HapticGrammarState.ANOMALY:
            base_intensity = 210
            waveform = DRV2605LWaveforms.STRONG_CLICK
            target_pos = 0.85 if self._servo_current_pos < 0.5 else 0.15
            servo_speed = 0.70
            interval_ms = 4000
            duration_ms = 350
        elif grammar_state == HapticGrammarState.UNCERTAINTY:
            base_intensity = 140
            waveform = DRV2605LWaveforms.SOFT_FUZZ
            target_pos = 0.65 if self._servo_current_pos <= 0.5 else 0.35
            servo_speed = 0.25
            interval_ms = 7000
            duration_ms = 220
        else:  # EQUILIBRIUM
            base_intensity = 75
            waveform = DRV2605LWaveforms.SOFT_BUMP
            target_pos = 0.50
            servo_speed = 0.08
            interval_ms = 12000
            duration_ms = 120

        # Modulation by Active Regime
        reg = regime.active_regime
        active_weight = regime.blend_weight

        if reg == RegimeType.SURVIVAL:
            # Minimal survival heartbeat, servo disabled to prevent current spike
            intensity = min(60, boundary.energy_budget.lra_max_intensity)
            waveform = DRV2605LWaveforms.SHARP_TICK
            target_pos = 0.5
            servo_speed = 0.0
            interval_ms = 15000
            duration_ms = 80
            rationale = "Survival heartbeat: minimal current draw to preserve rail continuance"

        elif reg == RegimeType.QUIET:
            # Quiet mode: soften LRA to whisper floor, minimize gear train speed
            intensity = int(base_intensity * (1.0 - 0.55 * active_weight))
            intensity = min(intensity, boundary.energy_budget.lra_max_intensity)
            servo_speed = servo_speed * (1.0 - 0.70 * active_weight)
            interval_ms = int(interval_ms * 1.5)
            rationale = "Ecological quiet: attenuated amplitude and silent servo drift"

        elif reg == RegimeType.NIGHT:
            # Diurnal night: slow, long-period respiration rhythm
            intensity = int(base_intensity * (1.0 - 0.40 * active_weight))
            intensity = min(intensity, boundary.energy_budget.lra_max_intensity)
            waveform = DRV2605LWaveforms.TRANSITION_HUM
            target_pos = 0.50
            servo_speed = 0.05
            interval_ms = 20000
            rationale = "Night diurnal cycle: slow breathing rhythm, grounded baseline"

        elif reg == RegimeType.TREATY:
            # Treaty mode: calm resting baseline
            intensity = min(65, boundary.energy_budget.lra_max_intensity)
            waveform = DRV2605LWaveforms.SMOOTH_HUM
            target_pos = 0.50
            servo_speed = 0.05
            interval_ms = 14000
            rationale = "Treaty mode: non-intrusive harmonic presence"

        else:  # EXPLORATION
            intensity = min(base_intensity, boundary.energy_budget.lra_max_intensity)
            if not boundary.energy_budget.servo_actuation_enabled:
                servo_speed = 0.0
            rationale = f"Exploration regime: organic {grammar_state.value} presence"

        self._servo_current_pos = target_pos

        return HapticDeposit(
            state=grammar_state,
            lra_intensity=intensity,
            lra_waveform_id=waveform,
            servo_target_position=round(target_pos, 2),
            servo_speed=round(servo_speed, 2),
            pulse_interval_ms=interval_ms,
            duration_ms=duration_ms,
            is_suppressed=False,
            rationale=rationale,
        )

    def synthesize_ar_deposit(
        self,
        regime: RegimeState,
        refusal: RefusalState,
        ecology_context: Dict[str, Any],
    ) -> ARDeposit:
        # If recording or AR is inhibited (e.g. Treaty protocol or domestic privacy)
        if refusal.ar_overlays_inhibited or refusal.recording_prohibited:
            return ARDeposit(
                anchor_type="quiescent",
                spatial_zone="none",
                luminance=0.0,
                persistence_seconds=0.0,
                metadata={"status": "AR deposits suspended under land protocol/privacy"},
                is_suppressed=True,
            )

        reg = regime.active_regime
        luminance = 0.75
        if reg == RegimeType.QUIET:
            luminance = 0.25
        elif reg == RegimeType.NIGHT:
            luminance = 0.15
        elif reg == RegimeType.SURVIVAL:
            luminance = 0.05

        return ARDeposit(
            anchor_type="environmental_horizon",
            spatial_zone=ecology_context.get("dominant_zone", "garden-open"),
            luminance=round(luminance, 2),
            persistence_seconds=30.0,
            metadata={
                "regime": reg.value,
                "motif_count": ecology_context.get("active_motifs", 0),
                "stigmergic_character": "ambient_trace",
            },
            is_suppressed=False,
        )

    def generate_deposits(
        self,
        timestamp: float,
        grammar_state: HapticGrammarState,
        regime: RegimeState,
        viability: ViabilityState,
        boundary: BoundaryState,
        refusal: RefusalState,
        ecology_context: Dict[str, Any],
    ) -> AutopoieticDeposits:
        haptic = self.synthesize_haptic_deposit(
            grammar_state=grammar_state,
            regime=regime,
            viability=viability,
            boundary=boundary,
            refusal=refusal,
        )
        ar = self.synthesize_ar_deposit(
            regime=regime,
            refusal=refusal,
            ecology_context=ecology_context,
        )

        # Self-repair: record system integrity and adaptive fallbacks
        coherence = {
            "bus_degraded": DegradationFlag.BUS_INTEGRITY_DEGRADED in viability.flags,
            "power_rail_tier": boundary.energy_budget.tier.value,
            "refusals_honored": len(refusal.active_refusals),
            "haptic_actuator_state": haptic.state.value,
            "servo_position": haptic.servo_target_position,
        }

        return AutopoieticDeposits(
            timestamp=timestamp,
            regime=regime.active_regime,
            haptic=haptic,
            ar=ar,
            system_coherence=coherence,
        )
