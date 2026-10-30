# Yes And — read before every change

A roguelike deckbuilder about being a stand-up/improv comedian: Slay the Spire
structure, improv comedy as the core system. Godot 4.3, GDScript only.

Samuel builds from his phone: Claude writes and pushes the code, GitHub builds a
web version, and he playtests it in Safari. Keep replies short and in plain words,
and handle git, builds and fixes yourself.
**End every reply with the play link:** https://humble-house-studios.github.io/yes-and/

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
- On the first session, copy `.github/workflows/deploy.yml` and
  `export_presets.cfg` from https://github.com/humble-house-studios/phone-pong
  — they build the web version on every push to `main` and publish it.
- After each change: push to `main`, wait for the build to pass (fix it if it
  doesn't), then send Samuel https://humble-house-studios.github.io/yes-and/
  with one line on what changed and what to playtest.
- If GitHub Pages isn't on yet, tell him: repo → **Settings → Pages → Source:
  GitHub Actions.**

## Code structure
- Game logic in `res://engine/`, with no scene dependencies, tested headless
  with GUT.
- Cards, audiences and map nodes are `.tres` Resources in `res://data/`.
- All game numbers in `res://engine/balance.gd` so they can be tuned in one place.
- Placeholder art only: colored panels and labels. No image generation.
- Ask before adding any addon beyond GUT.

---

# MVP

## Goal
Prove the core loop is fun in under 10 minutes on a phone:
**pick a path → play a set (card battle) → earn a card → repeat → headline show (boss).**

## Core rules
- **The set = a battle.** The audience has a **Laugh meter** you fill to win.
- **Crowd Energy** drifts down each turn; some cards raise it, bombing lowers it.
  At 0 you "lose the room" = lose the run. High energy multiplies laughs.
- **Mic time** = 3 energy per turn. **Hand:** draw 5, discard at end of turn.
- **Audience intents:** each turn the audience shows its next move (e.g.
  "Heckler: −4 Crowd Energy", "Restless: −1 energy next turn").

### Starter cards
| Card | Cost | Effect |
|---|---|---|
| Yes, And | 1 | +4 laughs; if you played a card already this turn, +3 more |
| Setup | 1 | Next Punchline deals double |
| Punchline | 1 | +6 laughs |
| Crowd Work | 1 | +3 Crowd Energy, reveal next audience intent |
| Callback | 2 | +2 laughs for each card played earlier this set |
| Pause for Effect | 0 | Skip; +2 Crowd Energy |

Starter deck: 4× Punchline, 3× Yes And, 2× Setup, 1× Crowd Work.
Reward pool: ~15 more cards in the same style (propose them, one line of rules each).

## Scope
**In:** 1 class ("The Improviser"), 1 branching map of ~8 nodes (Open Mic,
Showcase, Green Room, Headline Show), 3 audiences + 1 boss, pick-1-of-3 card
rewards, win/lose/restart, text speech bubbles for card plays.

**Out (later):** other four classes, other two career maps, Mad Libs Career
Cutaway, voiced Bubble Voice System, final art, saves, sound.

## Build order
Each step live on the play link before the next:
1. Project + pipeline: blank screen live, switching layout when the phone turns
2. Engine with GUT tests
3. One battle, playable end to end, in both layouts
4. Map + reward screen
5. Boss + win/lose + restart
