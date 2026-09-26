# Verification and scope

## Commands

```sh
godot --headless --editor --path . --quit
godot --headless --path . --audio-driver Dummy -- --self-test
# Requires a functioning graphics backend, or Xvfb + Mesa on Linux:
godot --path . --audio-driver Dummy -- --capture-all
```

The initial local verification was performed with `Godot 4.7.2.stable.official.ed1daf0bf` on Linux. The deterministic suite contains **111 checks** covering transactions, corrupted save rejection/recovery, navigation and actual combat nodes. Consult the latest `artifacts/test-results.json` rather than treating this document as proof that a later revision passed.

Capture mode produces six actual Godot viewport PNGs: the harbor, contract panel, furnished interior, module screen, pursuit and boarding. Capture mode deliberately stages sample states; these are engine-rendered screenshots, not evidence of an entire human playthrough. The headless suite separately exercises pursuit/boarding/extraction transitions and collision.

The `Godot verification` Actions workflow imports the project, runs the tests, rejects script/parse failures and captures the scenes under Xvfb. Logs, JSON results and screenshots are available in the `bountyhaven-verification` artifact of each successful run.

## Not claimed by these checks

No human playtest of pacing or long-term fun; no Windows/macOS executable export certification; no gamepad/mobile usability certification; no multiplayer/network security claim; no guarantee against all power-loss storage failures; no final-art approval. Second-port geometry and the two bounty encounter templates are currently shared, with data-driven variation.
