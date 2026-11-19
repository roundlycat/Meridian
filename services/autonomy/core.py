"""
Meridian V2 — Relational Autonomy Core Orchestrator
Ties together the 5 layers:
  1. Viability Sensing Layer      (the archive the body cannot hear)
  2. Boundary Maintenance Layer   (no reaching in)
  3. Constraint Engine            (refusal as a first-class state)
  4. Regime Manager               (continuance instead of rupture)
  5. Autopoietic Core             (deposited, not commanded)
"""

from __future__ import annotations

import logging
import time
from typing import Any, Dict, Optional

from services.autonomy.autopoietic import (
    AutopoieticCore,
    AutopoieticDeposits,
    HapticGrammarState,
)
from services.autonomy.boundary import BoundaryMaintainer, BoundaryState
from services.autonomy.constraint import ConstraintEngine, RefusalState
from services.autonomy.regime import RegimeManager, RegimeState
from services.autonomy.viability import ViabilityAssessor, ViabilityState

log = logging.getLogger("autonomy.core")


class RelationalAutonomyCore:
    """
    Coordinates data flow strictly through the 5 cybernetic and ecological layers.
    Operates synchronously or within an async event loop.
    """

    def __init__(self, transition_duration_s: float = 15.0) -> None:
        self.viability = ViabilityAssessor()
        self.boundary = BoundaryMaintainer()
        self.constraints = ConstraintEngine()
        self.regime = RegimeManager(transition_duration_s=transition_duration_s)
        self.autopoietic = AutopoieticCore()

        # Cached live state buffers
        self._latest_wearer_payload: Dict[str, Any] = {}
        self._latest_hailo_telemetry: Dict[str, Any] = {}
        self._active_land_protocol: Dict[str, Any] = {"active": False}
        self._macro_env: Dict[str, Any] = {}
        self._privacy_zone_active: bool = False
        self._moisture_alert: bool = False

        # Ecology / motif scoring indicator
        self._is_anomaly: bool = False
        self._is_uncertain: bool = False

    def ingest_ecology_telemetry(self, slug: str, metrics: Dict[str, Any]) -> None:
        """Receives readings from outdoor/indoor environmental nodes."""
        self.viability.ingest_ecology_node(slug, metrics)

        if slug == "w-sky-reference":
            self._macro_env["ambient_temp"] = metrics.get("ambient_temp")
            self._macro_env["lux"] = metrics.get("lux")
            self._macro_env["is_raining"] = metrics.get("is_raining")
        elif slug == "c1-hailo-camera":
            self._latest_hailo_telemetry = metrics
        elif slug == "e1-central":
            self._macro_env["co2_ppm"] = metrics.get("co2_ppm")
            self._macro_env["acoustic_db"] = metrics.get("acoustic_db")

    def ingest_wearer_telemetry(self, payload: Dict[str, Any]) -> None:
        """
        Receives telemetry from the wrist-puck or wearer sensors.
        Informational boundary strictly strips any interior modeling at the intake gateway.
        """
        sanitized = self.boundary.sanitize_wearer_telemetry(payload)
        self._latest_wearer_payload = sanitized

        # Update physical surface metrics in viability assessor
        contact = sanitized.get("contact_detected")
        skin_temp = sanitized.get("skin_temp_c")
        accel = sanitized.get("motion_magnitude_g")

        self.viability.ingest_wearer_telemetry(
            contact_detected=contact,
            skin_temp_c=skin_temp,
            motion_magnitude_g=accel,
        )

    def ingest_device_health(
        self,
        battery_voltage: Optional[float] = None,
        charging_in_firebag: Optional[bool] = None,
        bus_errors: Optional[int] = None,
        moisture_detected: Optional[bool] = None,
    ) -> None:
        """Updates hardware rail, bus, and safety enclosure states."""
        self.viability.ingest_device_telemetry(
            battery_voltage=battery_voltage,
            charging_in_firebag=charging_in_firebag,
            bus_errors=bus_errors,
        )
        if moisture_detected is not None:
            self._moisture_alert = moisture_detected

    def set_land_protocol(self, active: bool, protocol_name: str = "") -> None:
        """Sets social / traditional land protocol state."""
        self._active_land_protocol = {
            "active": active,
            "protocol_name": protocol_name,
        }

    def set_privacy_zone(self, active: bool) -> None:
        """Sets domestic privacy boundary."""
        self._privacy_zone_active = active

    def set_anomaly_state(self, is_anomaly: bool, is_uncertain: bool = False) -> None:
        """Sets current ecological interpretation (anomaly vs uncertainty vs equilibrium)."""
        self._is_anomaly = is_anomaly
        self._is_uncertain = is_uncertain

    def _resolve_grammar_state(self) -> HapticGrammarState:
        if self._is_anomaly:
            return HapticGrammarState.ANOMALY
        if self._is_uncertain:
            return HapticGrammarState.UNCERTAINTY
        return HapticGrammarState.EQUILIBRIUM

    def tick(self, timestamp: Optional[float] = None) -> AutopoieticDeposits:
        """
        Executes one full cycle through the 5 layers.
        Returns the resulting non-directive deposits.
        """
        ts = timestamp if timestamp is not None else time.time()

        # ── Layer 1: Viability Sensing Layer ───────────────────────────
        viability: ViabilityState = self.viability.assess()

        # ── Layer 2: Boundary Maintenance Layer ────────────────────────
        boundary: BoundaryState = self.boundary.evaluate(
            viability=viability,
            raw_wearer_payload=self._latest_wearer_payload,
            moisture_sensor=self._moisture_alert,
        )

        # ── Layer 3: Constraint Engine ─────────────────────────────────
        rule_context = {
            "hailo_telemetry": self._latest_hailo_telemetry,
            "land_protocol": self._active_land_protocol,
            "wearer_telemetry": boundary.sanitized_wearer_metrics,
            "macro_env": self._macro_env,
            "privacy_zone_active": self._privacy_zone_active,
        }
        refusal: RefusalState = self.constraints.evaluate(timestamp=ts, context=rule_context)

        # ── Layer 4: Regime Manager ────────────────────────────────────
        regime: RegimeState = self.regime.update(
            timestamp=ts,
            viability=viability,
            boundary=boundary,
            refusal=refusal,
            macro_env=self._macro_env,
        )

        # ── Layer 5: Autopoietic Core ──────────────────────────────────
        grammar_state = self._resolve_grammar_state()
        deposits: AutopoieticDeposits = self.autopoietic.generate_deposits(
            timestamp=ts,
            grammar_state=grammar_state,
            regime=regime,
            viability=viability,
            boundary=boundary,
            refusal=refusal,
            ecology_context=self._macro_env,
        )

        return deposits
