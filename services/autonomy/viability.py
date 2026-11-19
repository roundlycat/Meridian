"""
Meridian V2 — Viability Sensing Layer (Layer 1)
"The archive the body cannot hear"

Continuously senses and synthesizes non-apparent, ambient, device, and biological
boundary metrics that human sensory awareness does not track natively as a unified archive.

Senses:
  • Environment: sub-zero cold, humidity, barometric storm trends, rain intensity.
  • Device: power rails, battery voltage/SoC, thermal load, bus/packet integrity.
  • Wearer: physical surface contact, accelerometer gross motion, contact temperature.

Produces:
  • ViabilityScore (domain scores + composite geometric mean).
  • DegradationFlags (silent degradation markers before catastrophic failure).
"""

from __future__ import annotations

import math
import time
from dataclasses import dataclass, field
from enum import Enum
from typing import Any, Dict, List, Optional, Set


class DegradationFlag(str, Enum):
    # Environmental flags
    SUBZERO_COLD = "env:subzero_cold"
    EXTREME_COLD = "env:extreme_cold"
    STORM_PRESSURE_DROP = "env:storm_pressure_drop"
    HEAVY_PRECIPITATION = "env:heavy_precipitation"

    # Device & Energetic flags
    LOW_POWER = "dev:low_power"
    CRITICAL_POWER = "dev:critical_power"
    POWER_RAIL_DROOP = "dev:power_rail_droop"
    CHARGING_FIREBAG_ACTIVE = "dev:charging_firebag_active"
    THERMAL_THROTTLE = "dev:thermal_throttle"
    THERMAL_CRITICAL = "dev:thermal_critical"
    BUS_INTEGRITY_DEGRADED = "dev:bus_integrity_degraded"
    NODE_OFFLINE = "dev:node_offline"

    # Wearer physical boundary flags (Strictly non-inferential)
    CONTACT_LOST = "wearer:contact_lost"
    RAPID_CHILL = "wearer:rapid_chill"
    EXCESSIVE_SHOCK = "wearer:excessive_shock"


@dataclass(frozen=True)
class ViabilityScore:
    environmental: float  # 0.0 (lethal/untenable) to 1.0 (optimal)
    device: float         # 0.0 (depleted/failed) to 1.0 (fully coherent)
    wearer: float         # 0.0 (contact lost/distressed) to 1.0 (viable contact)
    composite: float      # Weighted or geometric assessment of total viability


@dataclass
class ViabilityState:
    timestamp: float
    scores: ViabilityScore
    flags: Set[DegradationFlag] = field(default_factory=set)
    telemetry_snapshot: Dict[str, Any] = field(default_factory=dict)

    @property
    def is_degraded(self) -> bool:
        return len(self.flags) > 0 or self.scores.composite < 0.70

    @property
    def is_critical(self) -> bool:
        critical_flags = {
            DegradationFlag.CRITICAL_POWER,
            DegradationFlag.THERMAL_CRITICAL,
            DegradationFlag.EXTREME_COLD,
            DegradationFlag.POWER_RAIL_DROOP,
        }
        return bool(self.flags & critical_flags) or self.scores.composite < 0.35


class ViabilityAssessor:
    """
    Ingests streaming readings across environment, device hardware, and physical wearer contact.
    Calculates sliding-window viability and raises silent degradation flags.
    """

    def __init__(self) -> None:
        self._last_readings: Dict[str, Dict[str, Any]] = {}
        self._pressure_history: List[tuple[float, float]] = []  # (timestamp, hpa)
        self._battery_voltage: float = 3.95                     # Nominal 3.7V - 4.2V LiPo
        self._charging_in_firebag: bool = False
        self._bus_error_count: int = 0
        self._wearer_contact: bool = True
        self._wearer_skin_temp: float = 32.5                    # Degrees C
        self._wearer_motion_accel: float = 0.05                 # g units

    def ingest_ecology_node(self, slug: str, metrics: Dict[str, Any]) -> None:
        """Ingests telemetry from outdoor / garden sensor ecology nodes."""
        self._last_readings[slug] = {
            "time": time.time(),
            "metrics": metrics,
        }
        if "barometric_pressure_hpa" in metrics:
            now = time.time()
            self._pressure_history.append((now, float(metrics["barometric_pressure_hpa"])))
            # Keep 30 minutes of pressure history
            cutoff = now - 1800.0
            self._pressure_history = [p for p in self._pressure_history if p[0] >= cutoff]

    def ingest_device_telemetry(
        self,
        battery_voltage: Optional[float] = None,
        charging_in_firebag: Optional[bool] = None,
        bus_errors: Optional[int] = None,
        extra_metrics: Optional[Dict[str, Any]] = None,
    ) -> None:
        """Ingests device health: power rails, mux status, bus integrity."""
        if battery_voltage is not None:
            self._battery_voltage = battery_voltage
        if charging_in_firebag is not None:
            self._charging_in_firebag = charging_in_firebag
        if bus_errors is not None:
            self._bus_error_count = bus_errors
        if extra_metrics:
            self._last_readings["device_health"] = {
                "time": time.time(),
                "metrics": extra_metrics,
            }

    def ingest_wearer_telemetry(
        self,
        contact_detected: Optional[bool] = None,
        skin_temp_c: Optional[float] = None,
        motion_magnitude_g: Optional[float] = None,
    ) -> None:
        """
        Ingests surface contact metrics.
        Strict boundary rule: no psychological, affective, or intent metrics permitted.
        """
        if contact_detected is not None:
            self._wearer_contact = contact_detected
        if skin_temp_c is not None:
            self._wearer_skin_temp = skin_temp_c
        if motion_magnitude_g is not None:
            self._wearer_motion_accel = motion_magnitude_g

    def assess(self) -> ViabilityState:
        now = time.time()
        flags: Set[DegradationFlag] = set()

        # ── 1. Environment Assessment ──────────────────────────────────
        env_score = 1.0

        # Retrieve ambient weather from sky reference or central env if available
        sky = self._last_readings.get("w-sky-reference", {}).get("metrics", {})
        central = self._last_readings.get("e1-central", {}).get("metrics", {})
        ambient_temp = sky.get("ambient_temp", central.get("ambient_temp", 15.0))
        is_raining = sky.get("is_raining", central.get("is_raining", False))
        rain_intensity = sky.get("rain_intensity", 0.0)

        # Whitehorse / Northern cold evaluation
        if ambient_temp <= -25.0:
            flags.add(DegradationFlag.EXTREME_COLD)
            env_score *= 0.4
        elif ambient_temp <= 0.0:
            flags.add(DegradationFlag.SUBZERO_COLD)
            env_score *= max(0.6, 1.0 - (abs(ambient_temp) / 50.0))

        if is_raining and rain_intensity > 0.6:
            flags.add(DegradationFlag.HEAVY_PRECIPITATION)
            env_score *= 0.85

        # Barometric pressure trend check (drop > 2.5 hPa in 30 min indicates approaching front)
        if len(self._pressure_history) >= 2:
            dt_s = self._pressure_history[-1][0] - self._pressure_history[0][0]
            if dt_s > 300:  # at least 5 minutes of data
                dp = self._pressure_history[-1][1] - self._pressure_history[0][1]
                if dp < -2.5:
                    flags.add(DegradationFlag.STORM_PRESSURE_DROP)
                    env_score *= 0.85

        # ── 2. Device & Hardware Assessment ────────────────────────────
        dev_score = 1.0

        # Battery / Power Rail
        # Nominal LiPo: 4.2V = 100%, 3.7V = ~40%, 3.4V = ~10%, <3.3V = Critical
        if self._battery_voltage <= 3.35:
            flags.add(DegradationFlag.CRITICAL_POWER)
            dev_score *= 0.2
        elif self._battery_voltage <= 3.60:
            flags.add(DegradationFlag.LOW_POWER)
            dev_score *= 0.65

        if self._charging_in_firebag:
            flags.add(DegradationFlag.CHARGING_FIREBAG_ACTIVE)
            # Device is intentionally constrained/isolated during firebag charge
            dev_score *= 0.9

        # Thermal checks from Hailo-8L vision chip or MCU
        hailo = self._last_readings.get("c1-hailo-camera", {}).get("metrics", {})
        hailo_temp = hailo.get("hailo_temp_c", 45.0)
        if hailo_temp >= 78.0:
            flags.add(DegradationFlag.THERMAL_CRITICAL)
            dev_score *= 0.3
        elif hailo_temp >= 68.0:
            flags.add(DegradationFlag.THERMAL_THROTTLE)
            dev_score *= 0.7

        # Bus integrity
        if self._bus_error_count > 5:
            flags.add(DegradationFlag.BUS_INTEGRITY_DEGRADED)
            dev_score *= 0.6

        # ── 3. Wearer Boundary Assessment ──────────────────────────────
        wearer_score = 1.0

        if not self._wearer_contact:
            flags.add(DegradationFlag.CONTACT_LOST)
            wearer_score *= 0.4
        else:
            # Physical surface temperature (contact)
            if self._wearer_skin_temp < 24.0:
                flags.add(DegradationFlag.RAPID_CHILL)
                wearer_score *= 0.65
            elif self._wearer_skin_temp < 28.0:
                wearer_score *= 0.85

            # Mechanical shock check (e.g. severe drop or impact)
            if self._wearer_motion_accel > 4.5:
                flags.add(DegradationFlag.EXCESSIVE_SHOCK)
                wearer_score *= 0.75

        # ── Composite Calculation ──────────────────────────────────────
        # Safeguard score lower bounds
        env_score = max(0.05, min(1.0, env_score))
        dev_score = max(0.05, min(1.0, dev_score))
        wearer_score = max(0.05, min(1.0, wearer_score))

        # Geometric mean: any catastrophic failure in one domain pulls total viability down
        composite = math.pow(env_score * dev_score * wearer_score, 1.0 / 3.0)

        scores = ViabilityScore(
            environmental=round(env_score, 3),
            device=round(dev_score, 3),
            wearer=round(wearer_score, 3),
            composite=round(composite, 3),
        )

        snapshot = {
            "ambient_temp_c": ambient_temp,
            "battery_voltage": self._battery_voltage,
            "hailo_temp_c": hailo_temp,
            "wearer_contact": self._wearer_contact,
            "wearer_skin_temp_c": self._wearer_skin_temp,
            "bus_errors": self._bus_error_count,
        }

        return ViabilityState(
            timestamp=now,
            scores=scores,
            flags=flags,
            telemetry_snapshot=snapshot,
        )
