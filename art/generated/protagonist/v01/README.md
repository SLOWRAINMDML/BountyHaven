# Protagonist v01: customizable paper doll

Source: the supplied design sheets in `assets/protagonist_customization/` (sheet SHA-256 values are in `assets/generated/protagonist/v01/parts/manifest.json`). No art was drawn or generated here; every part is a cut from those sheets.

Pipeline:
1. `python3 tools/art/extract_parts.py art/generated/protagonist/v01/parts_spec.json` cuts transparent PNGs from the cutout-parts sheet (body, limbs, boots, scarf, cloak, gear) and the 16 heads from the hair sheet into `assets/generated/protagonist/v01/parts/`.
2. `python3 tools/art/build_rig.py <preview.png>` writes `rig.json` (joints, pivots, draw order, gear attachments) and a rest/stride preview.
3. `tools/art/contact_sheet.py <parts dir> <out.png>` previews the cuts on dark and magenta backdrops.

Runtime: v01's `rig.json` was migrated once by `tools/art/migrate_rig_v2.py` into the skeletal rig `assets/characters/captain/captain.rig.json`, which the rig editor now owns (see `docs/art/CHARACTER_RIG_GUIDE.md`). `scripts/world/puppet.gd` (BHPuppet) plays it in eight directions with idle, walk and run; `scripts/core/appearance.gd` lists the options; the look is saved as `look` in the save file (optional key, older saves load with defaults). The creator panel opens from the harbor ("외형") and cabin ("옷장 · 외형") command bars. `--capture-look` renders the creator into `artifacts/look/`.

Options in v01: 16 hairstyles plus the base head, 12 catalog accent colours (C1–C12) applied to scarf and cloak, and six gear toggles (scarf, cloak, goggles, cap, satchel, compass charm).

Not yet used: the outfit, lower-body, face and expression sheets. Their figures are drawn as finished illustrations (arms baked into tops, faces joined to hair, framed panels), so using them as swappable parts needs either per-part redraws on a transparent background or careful hand-masking. The pose sheet is reference only; walk and idle are rig animation.
