# BountyHaven — agent entry point

## Art direction: read before generating or changing visuals

The user approved the 20 generated BountyHaven screen concepts in this conversation, NOT the earlier procedural SVG prototype as the final style. Do not use `scripts/world/ink_art.gd`, runtime screenshots, or other SLOWRAIN projects as style references for new art.

Read in this order:
1. `docs/art/CANONICAL_STYLE_GUIDE.md` — visual authority, including master reference 01.
2. `art/canonical/style_contract.json` — exact reference IDs, priority and scene recipes.
3. `docs/art/PROMPTS.md` and `docs/art/ASSET_HANDOFF.md` — generation and Godot assembly.
4. `docs/art/NEXT_AGENT_HANDOFF.md` — next concrete task and completion gates.

Before generation run `python tools/art_direction.py --scene harbor` (or the relevant recipe). This verifies real source bytes and prints the images to attach. A filename, Markdown list, catalog-only check, or historical screenshot is NOT an available image. If an original is missing, restore it from the user-provided ArtLibrary ZIP using the safe importer. Do not silently substitute procedural art, draw approximate geometry, or claim the reference was inspected. Config-only CI success does NOT mean image files are installed.

The main style is richly illustrated industrial science-fiction frontier art: fine structural ink drawing, translucent painterly color, weathered cream/rust machinery, warm practical lamps, cool atmospheric distance, monumental ports and small adult travelers. The approved images win over vague adjectives such as "pale watercolor". Avoid reducing them to flat SVG shapes, washed-out minimalist backgrounds, photorealistic rendering, voxel art, or neon cyberpunk.

Use reference 01 as the master; add only the scene-relevant references in the contract. The seven primary references are context-specific, not seven equally weighted styles to mix. UI-heavy concepts are content support only. Do not copy baked-in slogans, numbers, character names, or feature claims into gameplay data.

## Scope and implementation safety

Existing gameplay, save formats, input, and the other agent's combat/VFX changes remain valid implementation work. Do not revert them just to fix visual direction. Separate art replacement from new gameplay systems. The current main baseline includes 1600x900 2D harbor/interior scenes and a 3D quarter-view space renderer reading the authoritative 2D simulation (`scripts/space3d/`, added in 08d1a52). Preserve that hybrid implementation. Rendering technology is not style authority: neither revert space to 2D nor replace the view with a new free-flight/rear camera merely because of a concept image.

Generate environment clean plates, independent characters/props and masks, then assemble actual Godot layers and UI. Never place a full HUD-filled mockup behind another player character and call it integrated. Keep originals immutable; put candidates in `art/generated/` and reviewed runtime assets in `assets/generated/`. New candidates are not approved automatically.

Report separately: guidance/config updated, source files installed, images generated, layers extracted, runtime integrated, engine-tested, and remote commit verified. Never equate one with another.
