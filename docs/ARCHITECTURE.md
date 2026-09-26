# Architecture / v0.1

## Responsibilities

- `scripts/main.gd`: application lifecycle, Korean UI, scene transitions, deferred settlement, capture entry point.
- `scripts/core/catalog.gd`: stable IDs and authored data for ports, contracts, hunters, modules and furniture.
- `scripts/core/game_state.gd`: authoritative local domain transactions; credits, equipment, furniture, contract lifecycle and persistence.
- `scripts/world/habitat.gd`: explicitly authored walk polygons, AStarGrid2D routing, interaction arrival, independent actors, housing input.
- `scripts/world/ink_art.gd`: deterministic original vector layer authoring and one-time texture creation.
- `scripts/world/walker.gd`: layered cutout body parts and small idle/walk motion.
- `scripts/world/furniture.gd`: functional furniture visual, ghost and placement dimensions.
- `scripts/space/space_world.gd`: live ship movement, telegraphed enemy shots, swept projectile collision, abilities, boarding support and extraction.
- `scripts/space/ship_visual.gd`: persistent ship silhouette and four hardpoints; equipped IDs also determine activation animation.
- `scripts/core/sound.gd`: original cached PCM sound effects, bounded voice pool.
- `tests/test_runner.gd`: in-engine isolated deterministic domain/combat/navigation tests.

## Contract state machine

`dock + no mission → ready contract → active flight → survey → pursuit → boarding → extraction → settlement → dock`

A noncombat salvage contract finishes after three crate scans. A failed operation returns to dock without deleting the ship. The application defers settlement until the physics callback has returned; simulation `finish` and domain `finish` independently guard duplicate completion.

Each accepted contract increments `sequence` and receives a unique `nonce`. Settled nonces are recorded. A reward cannot be awarded while docked or twice for the same nonce. Credits never become negative. Departure fee is charged only while `paid` is false. Changing hunter, fitting and inter-port travel are not possible mid-flight.

The pilot remains the spaceship owner. Pilot employment temporarily supplies the hunter for that contract; it does not transfer ship ownership or overwrite the permanently recruited crew ID.

## Combat contract

Basic shots are nonlethal engine suppression against the bounty target. They can destroy escort craft and boarding relays. The hunter boards only after engine zero and valid proximity. Relay destruction is an actual projectile collision, not a timed dialogue. Progress then requires maintaining the support radius, and extraction requires a separate proximity interaction at the pod.

There are at most three live escorts. Each enemy snapshots its aim, displays a 1.15 s warning and then fires. Projectile tests use swept segments rather than point samples. A directional shield rejects only incoming projectiles in its forward 140° sector. Active modules consume energy, heat and cooldown only after target/phase/resource validation.

## Housing contract

18×5 grid, 60 px cells. Row 2 and both end columns are reserved. All rotated footprints, budget and overlap checks run before a transaction applies. Moving an owned UID is free; selling removes the UID and refunds 75% once. The closest legal placement helper is the attributed SS14 square-spiral adaptation.

NPCs are independent from backgrounds and move among nearby furniture spaces. Detailed sitting, eating, talking, schedules and personal quests are future content; the current actor loop is walking/idle around usable spaces.

Comfort takes the maximum value in each furniture category, then caps the total at 40. Rest sets a baseline of at least 60, adds 12 and comfort, caps at 100. The initial prototype exposes one shared crew condition; separate per-person needs are not simulated. Condition ≥85 gives 1.12× ship energy/cooling recovery.

## Persistence

`user://bountyhaven_v1.json` contains `{version, payload, sha256}`. Payload is a JSON **string**; hashing that exact string avoids integer/float reserialization ambiguity. Loading validates schema, numeric ranges and integer values, arrays, IDs, footprints, unique equipment, active mission consistency, journal bounds and settlement nonces before applying state.

Write path: serialize → `.tmp` → flush and close → rename previous main to `.bak` → rename temporary main. Failed final rename attempts restoring the backup. This is a practical local-filesystem strategy, not a claim of power-loss-proof storage on every OS/filesystem. UI retains a warning when an automatic save fails.

Interrupted flight resumes from the departure checkpoint with `paid=true`, so the player does not pay another fee. Scene-local bullets, cooldowns and enemies restart. No real save is read or written by verification/capture modes. Save paths in tests are unique temporary test paths and are deleted by the suite.
