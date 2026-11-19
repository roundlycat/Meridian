"""
Meridian V2 — Relational Autonomy Core.

A cybernetic, ecologically situated architecture for wearable and ambient sensing.
Moves beyond traditional command-and-control to relational autonomy, pre-thematic awareness,
and non-directive stigmergic deposits.

The 5 Layers:
1. Viability Sensing Layer      (the archive the body cannot hear)
2. Boundary Maintenance Layer   (no reaching in)
3. Constraint Engine            (refusal as a first-class state)
4. Regime Manager               (continuance instead of rupture)
5. Autopoietic Core             (deposited, not commanded)
"""

from services.autonomy.viability import ViabilityAssessor, ViabilityScore, ViabilityState, DegradationFlag
from services.autonomy.boundary import BoundaryMaintainer, BoundaryState, EnergyBudget
from services.autonomy.constraint import ConstraintEngine, RefusalState, RefusalReason, ConstraintRule
from services.autonomy.regime import RegimeManager, RegimeType, RegimeState
from services.autonomy.autopoietic import AutopoieticCore, HapticDeposit, ARDeposit, AutopoieticDeposits
from services.autonomy.core import RelationalAutonomyCore

__all__ = [
    "ViabilityAssessor",
    "ViabilityScore",
    "ViabilityState",
    "DegradationFlag",
    "BoundaryMaintainer",
    "BoundaryState",
    "EnergyBudget",
    "ConstraintEngine",
    "RefusalState",
    "RefusalReason",
    "ConstraintRule",
    "RegimeManager",
    "RegimeType",
    "RegimeState",
    "AutopoieticCore",
    "HapticDeposit",
    "ARDeposit",
    "AutopoieticDeposits",
    "RelationalAutonomyCore",
]
