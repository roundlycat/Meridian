// ============================================================
//  Battery Shim — sits ON TOP of foam tape, UNDER the DRV2605L
//  Spreads DRV's solder-pip/header-pin contact points across a
//  rigid plate instead of letting them press into the bare
//  LiPo pouch. Foam tape goes BETWEEN the cell and this shim —
//  the shim alone does not replace the foam, they work together.
//
//  Stack order (bottom to top): floor -> LiPo -> foam tape ->
//  this shim -> DRV2605L -> PowerBoost
//
//  Sized intentionally SHORTER than the 40mm cell length (not
//  full coverage) so a JST/wire tail exiting either short end
//  of the cell has clear room to escape without being pinched
//  under the shim's edge — direction of the tail wasn't known,
//  so clearance is symmetric on both ends.
//
//  SHIM_T is the one parameter you'll likely iterate on: print
//  a couple of thicknesses (e.g. 0.8 / 1.2 / 1.6mm) and use
//  whichever brings PB's top closest to the ~19mm-from-floor
//  height the lid capture nubs (wrist_puck_enclosure_4_5.scad)
//  were sized against. Each is cheap and fast to print flat.
//
//  Print flat on the bed, no supports, PETG, 0.2mm layers.
// ============================================================

SHIM_W      = 21.0;   // X — comfortably wider than DRV_W (20.3mm)
SHIM_D      = 34.0;   // Y — shorter than the 40mm cell on purpose
SHIM_T      = 1.0;    // thickness — the parameter to iterate on
CORNER_R    = 2.0;    // corner rounding radius
$fn         = 48;

module battery_shim() {
    hull() {
        for (sx = [-1, 1])
            for (sy = [-1, 1])
                translate([sx*(SHIM_W/2 - CORNER_R),
                           sy*(SHIM_D/2 - CORNER_R), 0])
                    cylinder(h = SHIM_T, r = CORNER_R);
    }
}

battery_shim();
