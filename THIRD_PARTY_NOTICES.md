# Third-party notices

## Discovery source

The user-supplied index https://github.com/bobeff/open-source-games lists Space Station 14 among its role-playing games. It is a discovery index, not a single Godot starter project. No text or assets from the index are included as game content.

## Space Station 14 — Ulam spiral utility

- Upstream: https://github.com/space-wizards/space-station-14
- Source: `Content.Shared/Maths/UlamSpiral.cs`
- Exact reviewed source blob: `1226d6022bb669d7a720f3b78007a0110c1a4d8d`
- Immutable source endpoint: https://api.github.com/repos/space-wizards/space-station-14/git/blobs/1226d6022bb669d7a720f3b78007a0110c1a4d8d
- Source path: https://github.com/space-wizards/space-station-14/blob/master/Content.Shared/Maths/UlamSpiral.cs
- License reviewed: https://github.com/space-wizards/space-station-14/blob/master/LICENSE.TXT
- Copyright (c) 2017–2026 Space Wizards Federation.
- License: MIT. The full notice is preserved in `third_party/space_station_14/LICENSE.txt`.
- Adaptation: `third_party/space_station_14/ulam_spiral.gd` translates the C# `Point` and `PointsForMaxDistance` functions into typed GDScript, retaining the integer square-spiral ordering.
- Actual use: `Game.nearest_cell()` selects the nearest legal furniture location; `BHHabitat.closest_cell()` resolves a nearby legal navigation cell. These calls are exercised by headless integration tests.

Only this small utility is adapted. No Space Station 14 art, sound, character, content pack, network system or C# engine is distributed here. Licenses of unimported assets are not assumed to match the code license.

## Godot Engine

This source project runs on Godot; it does not bundle the engine executable. Godot's own license and attribution requirements remain applicable to any later exported distribution. Engine: https://godotengine.org/license/

## Original materials and fonts

Game-specific code, procedural SVG paintings, cutout shapes, module geometry, shaders and synthesized effects were authored for this prototype. No third-party font binaries, game illustrations or sound recordings are bundled. `SystemFont` resolves an installed Korean-capable font at runtime.

No blanket open-source redistribution license has been selected for the original Bounty Haven materials. The preserved MIT notice applies specifically to the adapted upstream utility, not automatically to the entire game.
