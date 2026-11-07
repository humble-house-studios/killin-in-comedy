# Killin' in Comedy — read before every change

A roguelike deckbuilder about being a stand-up comedian: Slay the Spire
structure, Balatro-style scoring, played live like a trading sim (Space Warlord
Baby Trading Simulator): the room is a moving chart, you build a bit and cash it
in at the peak. Setup → punchline → tag, reading the room, beating the light.
Godot 4.3, GDScript only.

Samuel builds from his phone: Claude writes and pushes the code, GitHub builds a
web version, and he playtests it in Safari. Keep replies short and in plain words,
and handle git, builds and fixes yourself.
**End every reply with the play link:** https://humble-house-studios.github.io/killin-in-comedy/

## The scaling rule
The web build in Safari is the test for every platform. If it looks and plays
right there, it's right on iPhone, Android and Steam. To keep that true:

- **Phones = vertical. Steam = horizontal.** Same game, same code, two layouts.
  - Base resolution 720×1280, stretch mode `canvas_items`, aspect `expand`.
    When the screen is wider than tall, `main.gd` swaps the base to 1280×720
    so text stays readable sideways.
  - Mobile exports lock to portrait (`display/window/handheld/orientation`).
  - Desktop opens a 1280×720 window (`window_width_override.pc` /
    `window_height_override.pc`).
  - The UI picks its layout from the screen shape (wider than tall = landscape
    layout) and switches live on resize. Build it from Control nodes, anchors
    and containers, never fixed pixel positions.
  - Testing both on a phone: hold it upright for the mobile layout, turn it
    sideways for the Steam layout.
- **Compatibility renderer everywhere**, so the web build looks exactly like the
  shipped apps. The game isn't graphics-heavy, so nothing is lost.
- **Nothing web-only.** No browser-only APIs; anything platform-specific is
  wrapped in `OS.has_feature(...)` with a working fallback.
- **Touch and mouse both work** for every action; touch targets at least 88 px
  tall at 720 wide (cards in hand included). Respect the phone's safe area so
  nothing hides under the notch.
- **Stay light:** web build under ~30 MB, no reliance on threads.

## Testing pipeline
- After each change: push to `main`, wait for the build to pass (fix it if it
  doesn't), then send Samuel https://humble-house-studios.github.io/killin-in-comedy/
  with one line on what changed and what to playtest.
- If GitHub Pages isn't on yet, tell him: repo → **Settings → Pages → Source:
  GitHub Actions.**
- The old office link (`/office/`) forwards to
  https://humble-house-studios.github.io/Look-busy/.

## The game is a shared mini game — edit it in look-busy
- The whole stand-up game lives in `addons/hh_minigames/standup/` (rules in
  `engine/`, cards and crowds in `data/`, numbers in `engine/balance.gd`,
  jokes in `data/jokes.gd`). **That folder is a copy.** Its source of truth is
  `humble-house-studios/Look-busy` (`addons/hh_minigames/`), which also runs
  it on the office's main desk.
- Changes arrive here as a PR from the branch `sync/minigames`, opened by
  look-busy's `sync-minigames.yml`. Merge it to ship them. Any other PR that
  touches `addons/hh_minigames/` fails the "Mini games come from look-busy"
  check (`.github/workflows/guard-minigames.yml`): edit mini games in look-busy.
- Design and rules: `addons/hh_minigames/standup/DESIGN.md`; the shared
  interface: `addons/hh_minigames/README.md`.

## Code structure (this repo)
- `scenes/main.tscn` / `main.gd`: the app. It loads the stand-up game
  (`HHMinigames.scene_for("standup")`), calls `start({"dev": DEV})` and adds it
  full screen. `DEV` = dev shortcuts; set it to false before shipping.
- `project.godot`, `export_presets.cfg`, `default_bus_layout.tres`: the phone
  app's own settings (portrait lock, 1280×720 desktop window).
- Tests: `tests/` (the app) plus the mini games' own tests, all run by GUT on
  every push (`.gutconfig.json`).
- Balance check: `godot --headless -s res://addons/hh_minigames/standup/tools/tune.gd`.
- Screenshots: `addons/hh_minigames/standup/tools/screenshot.gd` (see its header).
- Placeholder art only: colored panels and labels. No image generation.
- Ask before adding any addon beyond GUT (and our own `hh_minigames`).
