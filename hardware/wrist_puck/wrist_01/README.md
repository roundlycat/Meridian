# Wrist mount piece (rev 5 planning)

Independent, foam-backed side piece for the wrist puck. Two printed
(mirror pair), sitting on either side of the puck with the LRA window
left bare so skin contact stays direct.

## Files
- `wrist_mount_piece.scad` — the parametric piece (one side; mirror
  for the other)
- `preview_assembly.scad` — renders both mirrored pieces for a quick
  visual check, `use`s the piece file
- `piece.stl` — one exported side, at current default parameters
- `preview_iso.png`, `preview_xy.png` — renders for reference

## Geometry approach
Cross-section is a smooth blend of two circular arcs (`r_inner` near
the puck, `r_outer` toward the strap edge, blended over
`[blend_start, blend_end]`) — a compound curve, not a single radius.
Extruded straight along the wrist-width direction, so there's no
curvature along that axis (matches what we discussed: the piece
curves across, not along).

This is a single `difference()` between two smooth, non-spiky
extruded solids (shell minus pocket) — not the multi-concave-union
pattern that broke CGAL on the cameo project, so it renders clean at
`Simple: yes` with no heightmap workaround needed.

**Axis convention** (before you rotate for your own print
orientation): X = curve run (puck edge → strap edge), Y = height/sag,
Z = width along the wrist (extrusion direction). Reorient with
`rotate()` to suit your slicer.

## Foam pocket
Recessed pocket inset by `rim_width` on all four sides (both across
the curve and along the width), so a solid rim survives all the way
around and is what contacts skin where there's no foam. Pocket depth
is `foam_thickness - foam_proud`, so once you glue in your actual
2mm foam it should sit proud of the rim by about `foam_proud`
(0.3mm default) — the foam takes the primary contact, not the hard
rim edge.

**2mm foam is a reasonable starting point.** With `foam_proud = 0.3mm`
that's a 1.7mm pocket depth and roughly 1.6mm of solid backing above
the floor — plenty of stiffness for a piece this size. If you land on
something thinner or thicker once you've got stock in hand, just
update `foam_thickness` (and `foam_proud`/`back_thickness` if the
compression feel needs adjusting) and re-render.

## Not yet decided / open questions
- Attachment to strap: no strap slot/loop feature yet — piece is just
  the curved shell + pocket right now
- `mount_run`, `mount_length`, `r_inner`, `r_outer` are placeholder
  values — need real wrist measurements to dial in
- Independent mounting confirmed (no rigid connection to puck body)
  but the actual strap interface (slot, rivet holes, loop) still
  needs a pass

## Printing
Blue PETG, same as the puck enclosure. Orient with the pocket face
up (supports-free — it's a shallow open recess, nothing overhangs)
once you've picked a final rotation for your slicer.
