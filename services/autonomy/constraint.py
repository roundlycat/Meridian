"""
Meridian V2 — Constraint Engine (Layer 3)
"Refusal as a first-class state"

Rather than treating constraints or refusals as errors or exceptions, the Constraint
Engine treats refusal as an ontological state of respect and relational co-existence.

Constraints:
  • Ecological refusal: Sensitive species nearby (e.g. raven, nesting birds, wildlife)
    → mandates quiet mode, silences loud actuators.
  • Social refusal: Land protocols, traditional territory treaties, domestic sacredness
    → mandates no recording, disables persistent visual/acoustic capture.
  • Wearer refusal: Wearer opacity gesture, puck covering, or withdrawal
    → respected unconditionally, halts probing, suppresses haptic intrusion.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass, field
from enum import Enum
from typing import Any, Callable, Dict, List, Optional, Set

log = logging.getLogger("autonomy.constraint")


class RefusalReason(str, Enum):
    ECOLOGICAL_SPECIES_PRESENCE = "ecological:species_nearby"
    ECOLOGICAL_HABITAT_QUIET = "ecological:habitat_quiet"
    SOCIAL_LAND_PROTOCOL = "social:land_protocol_treaty"
    SOCIAL_PRIVACY_BOUNDARY = "social:privacy_boundary"
    WEARER_OPACITY_REQUEST = "wearer:opacity_asserted"
    WEARER_CONTACT_WITHDRAWN = "wearer:contact_withdrawn"


@dataclass
class RefusalState:
    timestamp: float
    is_refusing: bool
    active_refusals: List[RefusalReason] = field(default_factory=list)
    quiet_mode_mandated: bool = False
    recording_prohibited: bool = False
    haptics_inhibited: bool = False
    vision_inhibited: bool = False
    ar_overlays_inhibited: bool = False
    rationales: List[str] = field(default_factory=list)

    @property
    def summary(self) -> str:
        if not self.is_refusing:
            return "No active refusals; open relational state"
        return "Active Refusals: " + "; ".join(
            f"{r.value} ({rationale})" for r, rationale in zip(self.active_refusals, self.rationales)
        )


class ConstraintRule:
    """Base protocol for an ethical / ecological constraint rule."""

    def evaluate(self, context: Dict[str, Any]) -> Optional[tuple[RefusalReason, str]]:
        raise NotImplementedError


class SpeciesProximityRule(ConstraintRule):
    """
    Ecological refusal: If sensitive species (e.g. ravens, nesting birds, wildlife)
    are detected by synthetic vision or acoustic sensors, mandate quiet mode.
    """

    SENSITIVE_CLASSES = {"raven", "bird", "squirrel", "wildlife", "bear", "fox", "owl"}

    def __init__(self, sensitive_classes: Optional[Set[str]] = None):
        self.sensitive_classes = sensitive_classes or self.SENSITIVE_CLASSES

    def evaluate(self, context: Dict[str, Any]) -> Optional[tuple[RefusalReason, str]]:
        hailo = context.get("hailo_telemetry", {})
        detections = hailo.get("frame_detections", [])

        detected_species = [
            d["class"] for d in detections
            if d.get("class") in self.sensitive_classes and d.get("confidence", 0.0) >= 0.60
        ]

        if detected_species:
            unique_species = sorted(list(set(detected_species)))
            return (
                RefusalReason.ECOLOGICAL_SPECIES_PRESENCE,
                f"Sensitive species detected ({', '.join(unique_species)}); honoring ecological quiet",
            )
        return None


class LandProtocolRule(ConstraintRule):
    """
    Social refusal: When entering areas governed by land protocols, treaty boundaries,
    or domestic privacy thresholds, prohibit recording and persistent visual indexing.
    """

    def evaluate(self, context: Dict[str, Any]) -> Optional[tuple[RefusalReason, str]]:
        land_protocol = context.get("land_protocol", {})
        if land_protocol.get("active", False):
            name = land_protocol.get("protocol_name", "Traditional Land Protocol")
            return (
                RefusalReason.SOCIAL_LAND_PROTOCOL,
                f"Protocol active: '{name}' — persistent capture and indexing refused",
            )

        if context.get("privacy_zone_active", False):
            return (
                RefusalReason.SOCIAL_PRIVACY_BOUNDARY,
                "Wearer in designated domestic privacy threshold — recording prohibited",
            )

        return None


class WearerOpacityRule(ConstraintRule):
    """
    Wearer refusal: Respect the wearer's opacity. If the puck is covered,
    removed, or opacity toggled, do not probe or send haptic cues.
    """

    def evaluate(self, context: Dict[str, Any]) -> Optional[tuple[RefusalReason, str]]:
        wearer = context.get("wearer_telemetry", {})

        if wearer.get("opacity_demanded", False) or wearer.get("puck_covered", False):
            return (
                RefusalReason.WEARER_OPACITY_REQUEST,
                "Wearer covered haptic node or asserted opacity — haptic emissions inhibited",
            )

        if wearer.get("contact_detected") is False:
            return (
                RefusalReason.WEARER_CONTACT_WITHDRAWN,
                "Puck not worn / contact withdrawn — respecting boundary",
            )

        return None


class ConstraintEngine:
    """
    Filters all system actions through ethical, ecological, and bodily constraints.
    Produces an explicit RefusalState.
    """

    def __init__(self) -> None:
        self._rules: List[ConstraintRule] = [
            SpeciesProximityRule(),
            LandProtocolRule(),
            WearerOpacityRule(),
        ]

    def add_rule(self, rule: ConstraintRule) -> None:
        self._rules.append(rule)

    def evaluate(self, timestamp: float, context: Dict[str, Any]) -> RefusalState:
        active_refusals: List[RefusalReason] = []
        rationales: List[str] = []

        quiet_mandated = False
        recording_prohibited = False
        haptics_inhibited = False
        vision_inhibited = False
        ar_inhibited = False

        for rule in self._rules:
            result = rule.evaluate(context)
            if result is not None:
                reason, rationale = result
                active_refusals.append(reason)
                rationales.append(rationale)

                if reason in {RefusalReason.ECOLOGICAL_SPECIES_PRESENCE, RefusalReason.ECOLOGICAL_HABITAT_QUIET}:
                    quiet_mandated = True
                elif reason in {RefusalReason.SOCIAL_LAND_PROTOCOL, RefusalReason.SOCIAL_PRIVACY_BOUNDARY}:
                    recording_prohibited = True
                    vision_inhibited = True
                    ar_inhibited = True
                elif reason in {RefusalReason.WEARER_OPACITY_REQUEST, RefusalReason.WEARER_CONTACT_WITHDRAWN}:
                    haptics_inhibited = True
                    ar_inhibited = True

        is_refusing = len(active_refusals) > 0

        return RefusalState(
            timestamp=timestamp,
            is_refusing=is_refusing,
            active_refusals=active_refusals,
            quiet_mode_mandated=quiet_mandated,
            recording_prohibited=recording_prohibited,
            haptics_inhibited=haptics_inhibited,
            vision_inhibited=vision_inhibited,
            ar_overlays_inhibited=ar_inhibited,
            rationales=rationales,
        )
