# hardware/

Physical layer of Meridian: enclosures, firmware, bench scripts, BOMs, and the
Unity AR client. Reorganized 2026-08-12 from a flat dumping ground.

## Layout

| Path | Contents |
|---|---|
| `ar_client/` | Unity AR client (unchanged — speaks the ws-bridge WebSocket contract) |
| `sensor_puck/` | Pollen pod / PM2.5 / presence housings — `.scad` sources, `.stl`, `.3mf` |
| `presence_node/` | LD2410B presence node case, v0.5 → v0.16 (was `Cases/Presence_Node/files/`) |
| `wrist_puck/` | Dual-channel haptic node: enclosures, satellite pods, wrist mount, firmware sketch |
| `models/` | Prints not part of a sensor node (hedgehog car, mushroom cluster, squirrel box, cameo) |
| `scripts/` | Bench + node Python: display managers, inference benchmarks, BOM import, parts watchdog, ws bridge |
| `sql/` | Parts catalogue, device registry, pinout, semantic-twin query SQL |
| `bom/` | Bills of materials (Sensor Species Family, Morphogenesis, LoRa backbone) |
| `data/` | Stray exports that aren't BOMs (book library CSV, LEAP results) |
| `docs/markdown/` | Session notes, essays, runbooks, setup guides |
| `docs/html/` | Generated dashboards, blueprints, wiring references |
| `docs/guides/` | `.docx` build guides and project documents |
| `media/` | Renders, mind maps, infographics, video |

CAD convention: `.scad` is the source of truth; `.stl` / `.3mf` are exports of it.
Where both exist, edit the `.scad`.

## Known issues

- **`models/cameo.scad` will not render** — it `include <artwork.scad>`s, and neither
  `artwork.scad` nor the `make_art.py` that generates it is anywhere in the repo.
- **Two firmware variants exist.** `wrist_puck/wrist_puck_haptic_node/wrist_puck_haptic_node.ino`
  (git-tracked) and `wrist_puck/wrist_puck_haptic_node.ino.txt` differ. Which is current
  is undetermined — reconcile before flashing.
- **`*_alt` files are collision renames**, not versions:
  `sensor_puck/pollen_pod_v0_2_alt.3mf` and `wrist_puck/floorplan_alt.stl` had the same
  filename as an existing, different file in the destination folder.
- `presence_node/lid_v0.2.scad` was a loose `lid.scad`; renamed per its own header
  (`LD2410B Presence Node — LID v0.2`) because `presence_node/lid.scad` was taken.
- `media/floorplan.png` is a dimensioned room plan in cm (deployment context), not a
  CAD render — it may belong under `Docs/` instead.
- `data/library-export-2026-02-25.csv` is zero bytes.
- `ar_client/Library/` is 2.4 GB of Unity build cache. It is gitignored and Unity
  regenerates it; deleting it is safe and reclaims almost all of this folder's size.

## Not covered by version control

Most of this folder is untracked — only `ar_client/`, `sensor_puck/`, and part of
`wrist_puck/` are in git. The `.gitignore` does not currently exclude `media/`,
installers, or large binaries, so nothing stops another 2 GB of downloads from
landing here again.
