# hh_minigames — Humble House mini games

Every mini game the Humble House games share lives here: the desk games in
**Look Busy** (the office) and the whole stand-up game that **Killin' in
Comedy** ships on phones.

## Source of truth: look-busy

**Edit mini games only in [humble-house-studios/Look-busy](https://github.com/humble-house-studios/Look-busy).**
Every push to look-busy's `main` that touches `addons/hh_minigames/**` copies
this folder into killin-in-comedy on the branch `sync/minigames` and opens (or
updates) a pull request there. killin-in-comedy rejects any other pull request
that edits this folder.

## The interface

Every game has its own folder with **one entry scene, `main.tscn`**, and a
README. Its root node has:

```gdscript
signal finished(result: Dictionary)   # {game, score, outcome: "win"/"lose", ...extras}
func start(config: Dictionary = {}) -> void
```

- Call `start(config)` **before** adding the scene to the tree (or never: every
  game has sensible defaults and plays on its own).
- `finished` fires when a play is over: one claw drop, one pusher payout, one
  Fall Guy bounce, one Rage Cage play (3 swings), one trading day, one golf
  round, one pitch, one open mic set, one whole stand-up run.
- `result.game` is the folder name, `score` an int (see each README for what
  it counts), `outcome` is `"win"` or `"lose"`; extras are listed per game.

```gdscript
var game := load(HHMinigames.scene_for("claw")).instantiate()
game.start({"host": my_economy})
game.finished.connect(func(r): print(r.game, " ", r.outcome, " ", r.score))
add_child(game)
```

### Common config keys

| key | games | what |
|---|---|---|
| `host` | all but standup | the economy that pays for plays (below). Missing = a pretend one (`_shared/house.gd`) |
| `cage` | claw, pusher, fall_guy, rage_cage | a `_shared/cage3d.gd` node to build the glass cage into, when the host puts the machine in its own 3D world (the office does). The entry scene makes its own. |
| `dev` | standup | dev shortcuts in the pause menu (default on; turn off before shipping) |

### The host

The office's economy is passed in, never named: games only call these on
`config.host`, by duck typing (`_shared/house.gd` is the reference):

- `state`: `tokens`, `tickets`, `best` (dict), `stress`, `has(item)`,
  `is_done(id)`, `give_token(n)`, `market_start()`, `trading_record(days)`
- `spend_token() -> bool`, `win_tickets(n, machine, beats)`, `pay_rage() -> String`,
  `add_stress(n) -> int`, `market_won()`, `pitch_won()`, `stage_won()`
- `missions` (an `ArcadeMissions`, or null), `crew.secrets` (open mic)

## Rules

- **No mini game depends on office-only or comedy-only code.** Paths stay
  inside `res://addons/hh_minigames/`, and no class from outside it is used.
  `tests/test_interface.gd` checks this on every build.
- **No autoloads.** None of these games needs one; keep it that way (a game
  that needs a singleton makes it a child of its own entry scene).
- Shared bits live in `_shared/`: the controller frame (`pad_cursor.gd`), the
  phone safe area, fonts, the common sounds, the machine base (`machine.gd`),
  the glass cage (`cage3d.gd`, `glass`/`retro3d` shaders), arcade numbers
  (`arcade_rules.gd`) and missions.
- Games read the controller from input events, never `Input` polling, so a pad
  never leaks between desks.
- Look games up with `HHMinigames` (`minigames.gd`): `scene_for(id)`,
  `script_for(id)`, `is_cage(id)`. Old office ids work too (`ragdoll`, `rage`,
  `putt`, `final_set`).
- Tests sit in each game's `tests/` and run with GUT in both projects
  (`.gutconfig.json` lists `res://addons/hh_minigames/`).

## Games

| folder | game |
|---|---|
| `standup/` | Killin' in Comedy: the whole stand-up roguelike (sets, cards, crowds, crew, headline show) |
| `claw/` | CLAW KING claw machine |
| `pusher/` | PUSH YOUR LUCK coin pusher |
| `fall_guy/` | FALL GUY trampoline ragdoll |
| `rage_cage/` | RAGE CAGE smash room (Voronoi fracture) |
| `trading/` | the trading floor's stock market week |
| `golf/` | CORNER LINKS, 3 holes of desk golf |
| `pitch/` | the boardroom pitch |
| `open_mic/` | the open mic at the end of the ladder |

Phone Pong, Proof Hand, Cube Desk and the Loot Machine are their own repos;
look-busy fetches them at build time (`tools/fetch_games.sh`).
