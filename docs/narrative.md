# The Office — narrative guide

## Premise
You're the new hire at **Humble House Games**, a small video game studio.
There's not much to do most days, and you've got bigger dreams. The office
computers run games, each one pointed at a different ambition. Play them, find
out what you're great at, and climb the ladder.

**Dale** (desk under the window) is your guide. Fifteen years in QA, warm,
nervous, very funny. He has tried every dream for exactly one week (cubing,
stand-up as "Big Deal", math, juggling) and quit. He sends you desk to desk,
each a bigger ambition than the last. Watching you actually finish things is
what slowly gets him unstuck.

**Tone:** bright, cozy, a little absurd. Office boredom as comedy, ambition as
the heart. Dale cheers sincerely, then undercuts it with a joke.

## The loop (every chapter)
1. **Dale gives a goal** — one desk, one clear target, shown as the on-screen
   **TO-DO** (top left) with progress (`CLEAR 2 COMEDY SETS (1/2)`).
2. **You play** that desk's game.
3. **The `!` pops over Dale** when the goal is met. TO-DO says `TALK TO DALE`.
4. **Payoff talk** — he reacts to what you did, sets up the next ambition, and
   you pick one of three replies (kind ones raise trust, which warms him up in
   voice chat).

## Chapters (data/dale_lines.gd)
| # | Chapter | Desk | Ambition | Goal to unlock the next talk | Stat |
|---|---|---|---|---|---|
| 1 | THE ORIGINAL | Pong | Where games began (1972) | Beat the first Pong boss (stage 4) | `pong_bosses` |
| 2 | WORLD RECORD | Cube Desk | Beat the world's best (2.51 s) | Solve the record scramble (level 9) | `cube_records` |
| 3 | OPEN MIC | Your desk | Maybe you're a comic | Clear 2 comedy sets | `comedy_sets` |
| 4 | EASY MODE | Loot Machine | Gambling makes it easy (fun, "not problematic at all") | Play a Loot Machine run | `loot_runs` |
| 5 | THE BIG PROBLEMS | Proof Desk | Solve a Millennium Problem | Prove a theorem | `proof_wins` |
| 6 | THE LADDER | Stairwell | Promotion: upstairs noticed | Next room — coming soon | — |

Why this order: it's a difficulty and ambition ramp. Pong teaches the office
(walk, sit, play), the cube is a short skill flex, stand-up is the heart of the
studio's flagship game, the Loot Machine arrives right when comedy gets hard
and its relics make every game easier, and the Proof Desk is the "you're
smart now, think world-sized" capstone that earns the promotion.

Stats: `pong_bosses`, `cube_records`, `proof_wins` are counted by the office
(`engine/office_goals.gd`); the rest by the Loot Machine link. All in the
shared save `user://office_relics.cfg`.

## Dale's thread
- Ch 2: he tried cubing for a week in 2011 (peeled the stickers).
- Ch 3: he was a comic called "Big Deal" for a week in 2009.
- Ch 5: he tried a Millennium Problem in 2016; the chalkboard is his.
- Ch 6: fifteen years, never past the stairwell. "Come with me, Dale."
- After: he's thinking about trying stand-up again. The seed for his own arc.

## Next: climbing the ladder (ideas, not built)
Each promotion is a new room with new desks, a new guide, and a bigger
ambition. Dale comes along or visits.
- **Floor 2 — Management.** Corner office, a squeaky-free chair. Desks about
  pitching, budgets and meetings as games (a "meeting bingo" roguelike, a
  pitch-deck card battler). Guide: a manager who's secretly a frustrated artist.
- **Floor 3 — The Stage.** The studio's launch event / livestream: on-camera
  ambitions (hosting, streaming, a talk show desk). Dale's Big Deal comeback
  could be the floor's finale.
- **The Roof — Founder.** Start your own studio. The game becomes about making
  games: your earlier desks become your studio's catalog.
- Running threads to pay off later: the second-floor smoothie machine, Dale's
  purple pen, Thursday being the only day anything happens.

## Writing rules
- Lines under ~110 characters; reply buttons under 28. Three replies per talk.
- Each chapter: react to the win → name the next desk → state the goal plainly.
- `goal` text is ALL CAPS and short; it's the TO-DO, not spoken.
- Lines are pre-recorded by `tools/dale_voice_lines.mjs` on deploy; new or
  changed lines get recorded automatically.
- `fact` keeps the voice chat honest: Dale knows finished chapters and dodges
  later ones.
