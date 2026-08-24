//////////////////////////////////////////////////////////////
// Meridian Presence Node — Shared Parameters
// Single source of truth. Both presence_node and lid files
// `include` this — edit values here, not in either file.
//////////////////////////////////////////////////////////////

// --- LD2410B module (35 x 7 x 7.4 mm) ---
ld_len   = 35;
ld_wid   = 7;
ld_thick = 7.4;

// --- Enclosure body ---
body_width  = 68;   // widened from 60 — see battery note below
body_depth  = 45;
body_height = 55;
wall        = 3.66;

// --- Sensor window (derived from LD2410B size) ---
window_width  = ld_len + 6;
window_height = ld_wid + 6;

// --- PVC saddle mount ---
bolt_circle_d = 36;
screw_hole_d  = 1.6;
clearance     = 0.6;

// --- Battery: actual 2000mAh unit measured at 56 x 34 x 11mm.
// The old 50 x 30 x 8 guess was too small in every dimension —
// 56mm length in particular exceeded the old interior width
// (55.2mm) outright, not just the bay's margin. body_width
// went 60 -> 68 to give this real clearance (63.2mm interior,
// ~1.6mm clear on each side of the battery with the bay's
// existing +4mm margin formula, instead of a razor-thin fit).
bat_len   = 56;
bat_wid   = 34;
bat_thick = 11;
