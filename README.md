# Killin' in Comedy

A roguelike deckbuilder about being a comedian. Built in Godot 4.3.

**Play the latest build:** https://humble-house-studios.github.io/killin-in-comedy/

Hold your phone upright for the mobile layout; turn it sideways for the Steam layout.
Every push to `main` rebuilds that link (see `.github/workflows/deploy.yml`).
Project rules are in `CLAUDE.md`, the design in `addons/hh_minigames/standup/DESIGN.md`.

## Where the game lives
The game is the shared stand-up mini game in `addons/hh_minigames/standup/`.
That folder is a **copy** kept in sync from
[look-busy](https://github.com/humble-house-studios/Look-busy) (the office
game, which runs it on a desk): edit mini games there, and the change comes
back here as a pull request from `sync/minigames`.

## Tests
GUT tests run on every push before the web build:

    godot --headless -s addons/gut/gut_cmdln.gd
