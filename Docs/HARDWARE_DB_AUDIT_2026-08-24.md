# Meridian Hardware + DB Audit
*2026-08-24 — written from a full read of the repo (`hardware/`, `Docs/`, `schemas/`, `seed/`, `services/`, `context/`, `sessions/`), not from the Outlook/Copilot thread, which had no access to any of this and was reconstructing from Amazon order history alone.*

This is a starting reference, not a finished plan. Treat every "recommend" below as a proposal to accept, edit, or reject — nothing described here as a *draft* has been applied to the live repo or the live db.

---

## 0. The headline finding

You've done more organizing than you're giving yourself credit for, and Copilot's Outlook thread was operating blind. It never saw `hardware/README.md`, `Docs/WRIST_PUCK.md`, the wiring guide, the commissioning protocol, or the parts/BOM schema that's already designed. Its BOM was a reasonable reconstruction from Amazon history with real gaps (no Wrist-Puck-specific line at all, and no idea a schema already exists to hold it). The one in this doc is grounded in your own docs instead, so it should be closer to true.

The real gaps aren't "nothing is organized." They're:

1. **`hardware/` was reorganized on 2026-08-12** (its own README says so) but the reorg moved files into folders without curating what's *in* them — `docs/markdown/` is half hardware notes, half unrelated essays; `models/` and `media/` hold personal prints and AI-generated video that have nothing to do with sensor nodes.
2. **Almost none of `hardware/` is in git.** Only `ar_client/`, `sensor_puck/`, and part of `wrist_puck/` are tracked (87 files total). `bom/`, `sql/`, `scripts/`, `data/`, `docs/`, `presence_node/` — including the BOM spreadsheets and the parts-DB schema itself — are untracked and one `git clean` or drive failure away from gone.
3. **There are three separate "parts" systems and none of them talk to v2.** See §2.
4. **`Docs/WRIST_PUCK.md`'s status table is stale.** It says firmware is "not started" — the repo has five `.ino` files including power-autocycle and 2AFC psychophysics trial firmware. The doc undersells where you actually are.
5. **CLAUDE.md's Slice B checklist is stale in the other direction.** It shows unchecked boxes for work that `Docs/lessons/slice-b-nothing-is-claimed.md` says is done, with a stated result (5/31 motifs earned real evidence). Worth a five-minute pass to reconcile before anyone (human or AI) re-enters this repo and assumes Slice B hasn't started.

---

## 1. `hardware/` folder — current state and specific fixes

### What's already right
The layout is sound: `ar_client/`, `sensor_puck/`, `presence_node/`, `wrist_puck/`, `models/`, `scripts/`, `sql/`, `bom/`, `data/`, `docs/`, `media/`. The README documents the convention (`.scad` is source of truth, STL/3MF are exports) and honestly logs known issues instead of hiding them. Keep this pattern — it's the right instinct and it's the one Copilot has no visibility into at all.

### Fix now (low risk, high value)
| Issue | Where | Fix |
|---|---|---|
| Duplicate firmware, unclear which is current | `wrist_puck/wrist_puck_haptic_node/wrist_puck_haptic_node.ino` vs `wrist_puck/wrist_puck_haptic_node.ino.txt` | Diff them, delete or clearly mark the loser. This is a *safety* issue, not just tidiness — WIRING.md's Rev A power notes (PowerBoost LBO on GPIO2) assume specific pin behavior; flashing the wrong variant risks the reversed-polarity/PowerBoost damage scenario the wiring guide itself warns about. |
| Broken include | `hardware/models/cameo.scad` | `include <artwork.scad>` — neither `artwork.scad` nor `make_art.py` exists in the repo. Either recover them or delete `cameo.scad`; it can't render as-is. |
| `hardware/docs/markdown/` mixes hardware notes with ~35 general essays | e.g. `musings_complete_1.md`, `research_statement_draft*.md`, `INKY_7.3_SETUP.md`, `zen_kiosk_setup.md` next to `MOTIF_GRAPH_SETUP.md`, `device_registry_walkthrough.md` | These aren't duplicated in `Docs/Philosophy/` (2 files) or `philosophy/` (1 file) — they're just stranded. Recommend a `Docs/essays/` or `archive/` and a triage pass; I didn't move them since categorizing 35 files by hand is a judgment call, not a mechanical one. |
| `hardware/models/` and `hardware/media/` hold non-Meridian content | hedgehog_car, squirrel_relief_box, mushroom_cluster, cameo (personal prints); NotebookLM videos, Gemini-generated images, mind maps | Not wrong to keep them somewhere, but they inflate what should be a "what does a sensor node need" folder. Consider `personal/` or `misc/` siblings to `hardware/` so `hardware/` stays legible as *ecology hardware only*. |
| `hardware/data/windows-apps-copilot-activity-history (1).csv` | `hardware/data/` | Not hardware data at all — a Windows Copilot activity export that landed here by accident. Safe to delete or move out. |
| `data/library-export-2026-02-25.csv` | `hardware/data/` | Zero bytes, already flagged in the README. Delete. |
| `ar_client/Library/` — 2.4 GB Unity cache | `hardware/ar_client/` | Gitignored, Unity regenerates it, README already says deleting is safe. I can't delete files on your machine without you granting delete permission first (a one-time approval) — say the word and I'll reclaim it. |
| Nothing stops re-accumulation | `.gitignore` | Doesn't exclude `media/`, installers, or large binaries. If you want `hardware/` to stop silently growing, add patterns for `*.mp4`, `*.mov`, and a `media/` opt-in policy. |

### Untracked-in-git risk
87 files tracked, hundreds untracked. The parts-DB schema (`hardware/sql/meridian_parts_schema.sql`), the BOM spreadsheets, the import script — none of this is in git. If you like the direction of §2 below, git-adding `hardware/sql/`, `hardware/bom/`, and `hardware/scripts/` first (before touching `docs/`, `media/`, `models/`, which need curation first) is a five-minute, zero-risk win.

---

## 2. The database: three systems, and only one of them is in v2

This is the part of your question that matters most, so here it is plainly.

### System A — `parts_catalogue` (image OCR ingestion)
`hardware/sql/parts_catalogue_schema.sql`. One row per *photo* of a component: OCR text, a parsed component model guess, a 1024-dim `bge-large` embedding, semantic search via `parts_query.py`. This is what Copilot called "the parts identifier that wasn't super accurate yet." It's an **evidence stream**, not a catalog — a way of turning "I took a picture of a board on my bench" into something searchable. The columns you pasted at the very top of this conversation (`id, ingested_at, image_path, image_filename, ocr_raw...`) are this table.

### System B — the structured parts/BOM/inventory schema
`hardware/sql/meridian_parts_schema.sql`. This is the one worth taking seriously — `parts`, `bom_sources`, `bom_line_items`, `inventory`, `node_configurations`, `node_parts`, `deployed_nodes`, and (notably) `mnp_gap_reports` / `mnp_proposals` — a **Morphology Negotiation Protocol**: a node reports "this mounting keeps failing" or "this sensor saturates outdoors," and a proposal (system- or human-authored) responds with a configuration change, optionally requiring fabrication. This table pair is *already* a first draft of the negotiation mechanism Slice C ("pod first contact," not yet started per CLAUDE.md) will need. That's a genuinely useful head start you may not have clocked.

### System C — v2's own schema
`schemas/001_durability_spine.sql` (Slice A) + `schemas/002_motif_lifecycle.sql` (Slice B). Perceptual events and earned motifs only. No parts, no BOM, no inventory concept exists here at all.

### Where they actually live
Both System A and System B were built against **v1's `sensor_ecology` database** — confirmed directly in the scripts (`import_bom.py`: `PGDATABASE=sensor_ecology`, port 5432; `parts_query.py`: `dbname=sensor_ecology user=sean`). That's the *same* frozen v1 Postgres CLAUDE.md says not to touch. The table list you pasted — `parts`, `parts_catalogue`, `bom_line_items`, `inventory`, `node_bom`, `mnp_proposals`, alongside `motifs`, `entities`, `cards`, `boards` and the rest — **is v1's `sensor_ecology`, not v2's `meridian` docker db.** Nothing from A or B has been ported into the pgvector container on port 5544. That's the honest answer to "we didn't update Meridian's db" — it's not that nothing was built, it's that what was built is sitting in the frozen v1 database, unreachable from v2 without a deliberate migration, exactly the same situation as the perceptual corpus that Slice B's `seed/` step already solved once.

### Recommendation
Don't copy System B into v2 verbatim — you said it yourself, you know more now. Specifically:

- **Slice B's own lesson applies here too.** v1 asserted 31 motifs and 26 were hallucinated because nothing required evidence before something got called "real." System A (photo → OCR → embedding) is exactly the kind of low-confidence, high-volume evidence stream that should feed a candidate, not write directly into a trusted `parts` row. Consider `parts_catalogue` (or its v2 equivalent) as **evidence for a part**, not a duplicate of it — a `source_scan_id` FK from `parts` back to the scan(s) that support its existence, mirroring `motif_members`. A part *asserted* by one blurry board photo and a part *confirmed* by five consistent scans plus a datasheet match shouldn't carry equal confidence, and right now nothing in System B tracks that distinction.
- **System B's actual relational design is solid** — keep the shape (`parts` / `bom_sources` / `bom_line_items` / `inventory` / `node_configurations` / `node_parts` / `deployed_nodes` / `mnp_gap_reports` / `mnp_proposals`). It doesn't need a rebuild, it needs (a) the evidence-linking change above, and (b) a home in v2.
- **Treat this as its own schema file, not a Slice B/C blocker.** CLAUDE.md's "one slice in flight" rule is about the perceptual pipeline (Slice B → C in sequence); a parts/inventory schema doesn't touch `perceptual_events` or `motifs` at all, so there's a reasonable argument it can land as `schemas/003_parts_inventory.sql` without violating "don't start Slice C early" — it's infrastructure Slice C's MNP tables will want anyway. Your call whether that's true in spirit as well as in code; I've drafted it as a **separate, unapplied file** either way so you can decide before anything touches the live db.
- **Migration path when you're ready:** same shape as `seed/`'s v1→v2 inheritance (`export_corpus.py` → `replay.py`) — export `parts`, `bom_sources`, `bom_line_items`, `inventory`, `node_configurations`, `node_parts` from v1's `sensor_ecology`, review/dedupe by hand (you already know some of it is stale — e.g. LoRa backbone parts for a Portenta/RPi5/Jetson chain that may or may not still reflect current plans), then load into v2 under the evidence-aware schema.

I've drafted `schemas/003_parts_inventory_DRAFT.sql` along these lines — **not applied, not renamed into the real migration sequence**, just sitting next to it for you to read. See the delivered file.

---

## 3. Wrist-Puck — reality check + a grounded BOM

`Docs/WRIST_PUCK.md`'s status table says firmware is "not started." The repo says otherwise:

| What the doc says | What's actually in `hardware/wrist_puck/` |
|---|---|
| XIAO firmware skeleton — Not started | `wrist_puck_haptic_node.ino` (+ a `.ino.txt` variant of unclear precedence — see §1) |
| Servo sliding mass test — Not started | `wrist_puck_power_autocycle.ino`, `_v2`, `_v2_1`, `wrist_puck_power_budget_test.ino` (×2) |
| (not mentioned at all) | `wrist_pod_2afc_trial_v1.ino` and `wrist_pod_2afc_trial_mux_v1.ino` — two-alternative-forced-choice psychophysics trial firmware, which is a *third*, more sophisticated thing than the status table lets on |
| Wear testing — Not started | `WIRING.md` (Rev A power architecture, fully specified pinout) and `node_commissioning_protocol.md` (33-item bench protocol, already run through calibration and UDP motif tests) both read as post-bring-up documents, not pre-hardware planning |

Recommend a five-minute status-table refresh in `WRIST_PUCK.md` next time you're in there — not urgent, but the current version will mislead an AI (or you, six months from now) into thinking this is earlier-stage than it is.

### Grounded BOM
`hardware/bom/` has four spreadsheets (Morphogenesis, Sensor Species Family, LoRa Backbone, motors) and **no Wrist-Puck line at all** — the Copilot thread's `2026-06-19_Wrist-Puck_BOM_Excel_Spreadsheet.md` never made it into the repo. I've built `wrist_puck_bom_v1_DRAFT.csv` from what's *actually specified* in `WIRING.md` + `WRIST_PUCK.md` + the commissioning protocol (exact pin assignments, the DRV2605L's confirmed I2C address 0x5A, the LRA's confirmed resonant class C10-100, the 22mm NATO strap constraint, the M5 brass sliding mass, PowerBoost 500C at 5.2V) rather than reconstructed from Amazon order guesses. Quantities and costs are left blank where I don't have a real number — better an honest blank than a fabricated $3.50.

Two things flagged as **open, not resolved** in that BOM:
- **Battery capacity** — `WRIST_PUCK.md` says "TBD — target full day wear." Needs your call once you know the servo's real duty cycle.
- **Sliding mass weight** — "affects feel character," also TBD, and it's a design decision (how the haptic grammar *feels*), not a lookup.

---

## 4. Meridian sensor hardware — what Copilot's BOM got right, and the real gaps

Copilot's synthesized BOM (pollen pod / garland / reef plate / perch pod) is a decent structural skeleton but was built entirely from Amazon history with no visibility into `hardware/sensor_puck/`, `hardware/presence_node/`, or the schema. Cross-checking against what's actually in the repo:

- **Confirmed real and in-progress**: pollen pod (`pollen_pod_v0_1` through `v0_2`, multiple lid/collar iterations), presence node (LD2410B housing, v0.5 → v0.16 — that's *twelve* enclosure iterations, worth a "which is current" note same as wrist-puck's firmware ambiguity), PM2.5 body, rain hood.
- **Not in the repo despite being in Copilot's BOM**: no CAD or docs for "garland links," "reef plate," "bloom node," or "drift fin" anywhere in `hardware/`. Either those live in the Sensor Species Family spreadsheet only (never became physical/CAD work) or Copilot invented plausible-sounding morphology names from the parts_catalogue category list. Worth confirming which before treating them as real scope.
- **`node_configurations`/`node_parts` (System B) already has the right shape** to answer "what does a presence node actually need" precisely, once populated — better than a flat BOM list, because it's per-node-type with roles and bus positions, not just a parts count.

I'm not fabricating a second full parts JSON here the way Copilot did — you already have `meridian_parts_schema.sql` designed to hold exactly that, better structured than a hand-typed JSON blob, and the risk of a second free-floating "best guess" catalogue is more of the duplication problem this audit is trying to reduce, not less.

---

## 5. Files delivered with this audit

| File | What it is | Status |
|---|---|---|
| `Docs/HARDWARE_DB_AUDIT_2026-08-24.md` | This document | New, additive |
| `schemas/003_parts_inventory_DRAFT.sql` | Proposed v2 parts/BOM/inventory schema, evidence-aware | **Draft — not applied to any database** |
| `hardware/bom/wrist_puck_bom_v1_DRAFT.csv` | Hand-built Wrist-Puck BOM from actual repo docs | **Draft — review before treating as authoritative** |

All three were written as new files at paths that don't already exist — nothing in your repo was overwritten, moved, or deleted to produce this.

---

## 6. Decisions that are yours, not mine

1. **Git-track `hardware/sql/`, `hardware/bom/`, `hardware/scripts/`?** Low-risk, recommended, but it's your repo's history.
2. **Delete `ar_client/Library/` (2.4 GB Unity cache)?** README says it's safe; I need one-time delete permission on the connected folder to do it myself, or you can do it locally.
3. **Where should the ~35 non-hardware essays in `hardware/docs/markdown/` live?** I didn't triage them — that's a categorization call, not a mechanical move.
4. **Resolve the two wrist-puck firmware variants** (`wrist_puck_haptic_node.ino` vs `.ino.txt`) before your next flash — I can diff them for you if you want a second opinion on which is current.
5. **Reconcile CLAUDE.md's Slice B checklist** against `Docs/lessons/slice-b-nothing-is-claimed.md` — the lessons doc reads as substantially done (research result stated, headline number in hand); the checklist reads as barely started. Worth five minutes so the next re-entry (human or AI) trusts the file.
6. **Accept, edit, or reject the draft schema and BOM** above before either goes anywhere near a live database or a fabrication order.
