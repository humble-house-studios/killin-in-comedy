# Killin' in Comedy

A roguelike deckbuilder about being a comedian. Built in Godot 4.3.

**Play the latest build:** https://humble-house-studios.github.io/killin-in-comedy/

Hold your phone upright for the mobile layout; turn it sideways for the Steam layout.
Every push to `main` rebuilds that link (see `.github/workflows/deploy.yml`).
Project rules and the MVP plan are in `CLAUDE.md`.

## Engine and tests
Game rules live in `engine/` (no scenes), cards and audiences in `data/` as
`.tres` files, and tuning numbers in `engine/balance.gd`. Tests use GUT and run
on every push before the web build:

    godot --headless -s addons/gut/gut_cmdln.gd
