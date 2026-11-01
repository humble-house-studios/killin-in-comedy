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
| 6 | THE LADDER | The door behind you | Promotion: upstairs noticed | Finishing this talk opens the door | — |

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
- Ch 6: fifteen years, never past the door. He's never even tried the handle.
- After: he's thinking about trying stand-up again. The seed for his own arc.

## The Ladder (built: scenes/office/ladder.gd)
Dale's last chapter opens the office door. Each room is one rung up the
studio, and each pays out what the next one spends:
paycheck → tokens → tickets → portfolio → board votes → material.

| Room | What you play | How you beat it |
|---|---|---|
| Arcade (the break room) | Claw King, Push Your Luck (coin pusher), Fall Guy (fling the Dale dummy), prize counter | Buy the DOOR KEY (300 tickets) |
| Archive (basement, secret) | Shelved games with notes about the founder | Ray's key opens it; finding it counts for the true ending |
| Trading floor | Five stocks from your world on a 90s ticker; RUMORS come before NEWS | Double your cashed-out tickets by day 8 |
| Boardroom | Answer each board member's objection with a matching card (YES, AND is wild) | 3 yeses of 5 |
| Corner office | The founder's memo; a putting toy; the fabled smoothie machine | Read the memo |
| The stage (The Brick Wall) | Five bits, 100 laughs; secrets become killer bits | Land the set |

Rules: `engine/ladder_state.gd` (currencies, doors, to-do), `engine/arcade_rules.gd`,
`engine/market.gd`, `engine/pitch.gd`, `engine/final_set.gd`. Screens:
`scenes/ladder/` (each a machine in its own SubViewport on a 3D screen).

### Coworkers (data/coworker_lines.gd, engine/coworkers.gd)
Talking is improv. Every reply has a stance (YES, AND / ASK / RIFF / PUSH).
Each coworker loves one (+1 trust) and hates one (-1, and they close off until
you play another machine round). Three tiers: a small bonus, their lore
secret, their perk. A prize-counter gift is worth a tier; so is a callback
(bringing one coworker's secret to another).

| Who | Where | Loves / hates | Secret | Perk | Wants |
|---|---|---|---|---|---|
| Gloria, QA lead | Claw | Ask / Riff | The first game's credits were blank | Gloria's Eye: shows the claw's full-strength grab | Top-shelf plush |
| Kev, intern | Pusher | Yes, And / Push | Nobody has met the CEO | Insider tip: a starred stock will pop | Ticker tie |
| Bernie, HR | Fall Guy | Riff / Ask | Dale's file is blank | HR badge (one redraw in the pitch) + style x2 | Stress ball |
| Theo, rival | Prize counter | Push / Yes, And | He wants to be a chef | 150 tickets + his yes vote | Beat any machine |
| Ray, night janitor | Back corner (after 2 machines beaten) | Yes, And / Push | The building was a comedy club | The archive key | Hot coffee |

### The mystery
Dale is the founder. He did stand-up for one week as "Big Deal", bought the
comedy club (The Brick Wall), turned it into the studio in 2011, built a
ladder with a corner office on top, got scared of the top and took the QA
desk by the window. The memo says so and sends you out to the open mic.
With all five secrets and the archive found, Dale is in the crowd for the
true ending.

## Writing rules
- Lines under ~110 characters; reply buttons under 28. Three replies per talk.
- Each chapter: react to the win → name the next desk → state the goal plainly.
- `goal` text is ALL CAPS and short; it's the TO-DO, not spoken.
- Lines are pre-recorded by `tools/dale_voice_lines.mjs` on deploy; new or
  changed lines get recorded automatically.
- `fact` keeps the voice chat honest: Dale knows finished chapters and dodges
  later ones.
