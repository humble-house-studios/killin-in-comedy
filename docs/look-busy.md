# Look Busy — Design Doc

2026-11-01 · Samuel Curtis

## Vision

**Look Busy** is a first-person PS1-style office game where you play games at
work without getting caught, talk your coworkers into helping you, and build
your own game from what you learn. Playing games at work is the joke; the boss
walking by is the tension; shipping your own game is the dream.

The working title is *Look Busy* (alternates: *Crunch Time*, *Clocked Out*). It
grows out of the existing Humble House office in the killin-in-comedy repo: the
3D office, Dale, the coworkers and the desk games are already built.

**How it relates to Killin' in Comedy:** the office is the brand and the hub;
each desk is a seed game. Comedy is the flagship desk and the in-universe hit,
and stays the deepest game. If any desk takes off in playtests, it spins out
into its own full release.

**Three pillars:**

1. Slacking off is the core verb
2. You're making your own game
3. Coworkers you talk to with your voice

## Core loop

A work week is a run: you slack off to earn pieces, use coworkers to slack more
safely, and ship your game on Friday.

```
Clock in ──▶ Slack off ──▶ Coworkers ──▶ Your game ──▶ Ship Friday
9 a.m., the   play desk     lookouts and   pieces combine  reviews pay out,
day ticks     games as the  collaborators  at your desk    promotion
toward 5      boss patrols
   ▲                                                          │
   └──────────── next week, next floor, a new boss ◀──────────┘
```

Each part feeds the others: slacking earns pieces, coworkers make slacking
safer and your game better, and your game is the reason to risk slacking at
all. Getting fired ends the run.

## Pillar 1: Slacking off

Every desk game is played under the threat of getting caught, which gives even
Pong an edge.

- **Suspicion meter.** The boss walks routes you learn. Tells: footsteps, a door
  creak, his reflection in your CRT.
- **Alt-tab.** One button swaps to a fake work screen (a spreadsheet, an email
  to type). Fake work can be its own tiny, dumb, satisfying game.
- **Getting caught.** A warning, then a write-up. Three strikes and you're
  fired, which ends the run.
- **The magic moment.** The boss rounds the corner just as you're about to land
  a jackpot comedy bit. Cash out or hide?
- **A new boss per floor**, each with their own habits: a micromanager, a
  work-from-home boss who pops up on video calls, a CEO nobody has met.

## Pillar 2: Making your own game

Your game is the reason to risk slacking at all: every desk you beat hands you
a piece of it.

- **Pieces:** a genre (from that desk), a mechanic, an art style, a sound, a
  coworker's character.
- **Combos:** pieces synergize, Game Dev Story or Balatro-joker style (comedy +
  slot machine = Laugh Slots).
- **Start abstract:** a combo score plus a short generated trailer. Truly
  playable mashups come later, once the loop is proven.
- **Friday ship day:** coworkers and fake press review it; Theo the rival ships
  too. Reviews pay out.
- **The marketing story:** this is the real life of a solo AI-native developer,
  told as a game.

## Pillar 3: Voice coworkers

You talk to coworkers out loud, and what you say decides whether they cover for
you, build with you or rat you out. Dale already works this way.

- **Everyone has** a personality, a secret and a side project.
- **Trust** comes from your improv replies (Yes, And / Ask / Riff / Push), which
  the ladder coworkers already use.
- **Trust unlocks roles:**
  - Lookout: coughs when the boss is coming
  - Collaborator: adds their side project to your game as a piece
  - Snitch: what a burned coworker becomes
- **Cost:** live voice AI costs money at Steam scale. Tap-to-reply stays as the
  free fallback.
- **Safety:** players will try to break the characters. Keep them in persona and
  plan for the content rating early.

## Structure

Each floor of the building has its own boss and a handful of desks, each one a
fun, clever little game; the mystery ties them together.

- **Desks are any clever idea:** not tied to decades. Balatro-style games (the
  Millennium Prize math game), a great claw machine, a stock market, novel
  little toys like the Rubik's Cube, addictive mechanics and fidgets. The office
  is a lab to test them all.
- **The mystery:** Dale is secretly the founder. He built the ladder to the
  corner office, got scared of the top, and has hidden at the QA desk for
  fifteen years. Revealed partway up the ladder, not at the end. A hidden extra
  for players who dig: the building used to be a comedy club, where Dale did
  stand-up for one week as "Big Deal." No open mic finale.

| Desk game | Role in the office | Spin-off potential |
|---|---|---|
| Killin' in Comedy | Flagship desk, the in-universe hit, the finale | High: deepest, mobile-first |
| Proof Hand | Balatro-style math desk | Medium |
| Loot Machine | Relics that power every desk | Medium; gambling optics may hurt on app stores |
| Pong | Tutorial for walking, sitting, playing | Low: flavor |
| Cube Desk | Short skill flex | Low: flavor |

**Platforms:** the office goes Steam-first, since first-person walking is clunky
on a phone and the UFO 50 and Inscryption audience is on PC. Comedy stays
mobile-first. Open question: test early how the office plays on a phone.

## Risks and the first playtest

The first test is whether the boss patrol is fun on top of one desk game;
everything else stacks on that.

**Risks:**

- **Scope:** one developer. Each desk game must be small but complete; the story
  is what makes a pile of minigames feel like one game.
- **Scattered effort:** five half-games are worth less than one great one. Rule:
  whichever game makes playtesters ask "can I keep playing?" gets the next month.
- **Voice AI cost and safety** at scale (see Pillar 3).

**First playtest (smallest version):**

- [ ] One desk (the comedy game), one boss route, one alt-tab button, a
  suspicion meter
- [ ] Five playtesters, watched silently: do they laugh when caught, and do they
  want another day?

**Plan if it works:** build a tight Steam demo (two floors, about five desks,
the mystery teased) while comedy keeps deepening as the flagship desk.
Playtests decide which becomes the first full release.

## The ending

The final room has you make your own game, and then the game ends by sending
you outside: we are human, and being good and compassionate to others is what
you walk away with.

- **The final game is the biggest build:** a more complex design and feature set
  than any desk before it.
- **Make your own basic roguelike** by talking out loud with an NPC. A very
  simple set of game design tools turns the conversation into a playable game.
- **The CEO plays it** and measurably enjoys it, scored by real play metrics.
- **Then you go outside:** a beach, a field, or time with family, just playing
  guitar and singing.
- **The message:** we are human. Being a good, compassionate person toward
  others is the final walk-away.

**Dale's payoff:** he's outside with you in the final scene, maybe the one who
brings the guitar. The founder who was scared of the top chooses people over the
corner office, which is the ending's message in one character.

## Fun pass (2026-11-02)

A full playthrough of the office with Look Busy on turned up four problems.
Each change below fixes one of them, and each is based on research on what
keeps people playing.

**What was wrong:**

- The first screen was a wall of text (bosses, times, strikes, crew).
- Playing a desk game earned nothing moment to moment. The only reward was
  a piece when you beat a whole desk, which can take minutes.
- Seated, you face the screen, so the boss is behind you. Footsteps were the
  only warning, and Safari often has the sound off.
- Seated upright, the clock HUD sat on top of STAND UP and ALT-TAB.

**What changed, and why:**

| Change | Why it works |
|---|---|
| **Title screen with a looping cartoon:** play, boss, alt-tab, safe; next loop too slow, strike; then your game ships. Three rules in words. | Show, don't tell: players learn a loop faster by watching it than by reading it. Most mobile players who leave never come back (typical day-1 retention is roughly 25–40%), so the first 30 seconds matter most. Nothing past floor 1 is named; "Nobody has seen the top one" opens a curiosity gap (Loewenstein, 1994) without spoiling Dale, the ladder or the club. |
| **Slack meter + daily quota:** every second at a game unseen fills it. | Clear goals and immediate feedback are the core conditions for flow (Csikszentmihalyi). It turns the whole day into a risk/reward meter: slack versus suspicion. |
| **The day starts with 0:15 of "coffee" already on the meter.** | Endowed progress (Nunes & Drèze, 2006): car-wash cards with 2 of 10 stamps already filled were completed 34% of the time, versus 19% for cards with 8 stamps needed and none filled. A head start makes the goal feel reachable. |
| **Quota bar + "GAME n/5" on the HUD.** | Goal gradient (Kivetz et al., 2006): people speed up as a goal gets close. A visible bar pulls players through the day. |
| **Countdown to the next visit ("MARGE WALKS BY IN 0:42").** | It's the comedy game's "NEXT IN 3s: Heckler" in office form. Telegraphing a threat makes it fair and learnable (Pac-Man ghosts, Hitman routes). Tension comes from the countdown, not from being surprised. |
| **Red screen edges toward the boss, throbbing ALT-TAB button; green edges while you're working in front of them.** | Stealth games use edge indicators to show which way a threat is. Seated, the boss is behind you, so the edges show what the camera can't. It also works with the sound off. |
| **Close call:** alt-tab with the boss within 4 m = +0:10 and a ding. **"COAST IS CLEAR"** when they leave. | Near misses activate the brain's reward system and raise the urge to keep playing (Clark et al., 2009). The all-clear completes the tension/release beat, the same red-light/green-light rhythm as Five Nights at Freddy's (watch the screen, manage the threat). |
| **Slack becomes research:** +2 points on your game per hour slacked, +5 per quota day. | It ties the moment-to-moment loop to the week's goal, so slacking is how you make your game. Strikes are losses, which weigh roughly twice as much as gains (Kahneman & Tversky), so the meter you protect matters. |
| **Morning card shortened. After the title, the first morning is one line of news.** | It cuts the number of screens before you can play: the title already taught the rules. |
| **Records on the title (best day, best floor, times fired).** | A score to beat gives each 5-minute day a reason to replay. 5 minutes matches typical mobile session lengths. |

**Follow-up (2026-11-07, Samuel's playtest):**

- The red edges came on while you were just standing around when Marge
  walked in, which read as "something's wrong" with nothing to do about it.
  Now they only show while you're seated at a screen, where ALT-TAB is the
  answer.
- Pong's glass reflects the room, so seated with your back to the door you
  can catch the boss walking up behind you in the screen, the way you would
  at a real desk.
- The office's Pong (the first desk) is a touch easier: +1 heart and a
  slightly slower CPU paddle each run.

**Comparable games:** Five Nights at Freddy's (a screen plus a threat you
watch for), Untitled Goose Game (comedy stealth), Papers, Please (a job under
pressure), and the real 90s "boss key" that swapped a DOS game for a fake
spreadsheet.

**Next playtest:** do players alt-tab in time on their first Marge visit, do
they laugh at the strike stamp, and do they press GO HOME for a second day?

## Desk pass (2026-11-02): every desk has a goal

A playthrough of every desk (5 office desks, 3 arcade machines) found two
problems they all shared:

- **No one says what "beating" a desk means.** Each game has its own win
  (a Pong boss on every 4th stage, a Proof Hand target, the claw's top-shelf
  star), but you only learn it by reading each game's rules or asking Dale.
- **The office's buttons covered the games.** Seated upright, STAND UP sat on
  each game's top-left: on Proof Hand that hid the target score, the one
  number you need.

**What changed:**

| Change | Why it works |
|---|---|
| **Three stars per desk** (`engine/desk_goals.gd`): one easy, one real, one master goal, such as clear a stage, beat a boss, then beat 3 bosses. | Three-star ratings (Angry Birds, Cut the Rope) give a first win in minutes, then a reason to replay. An easy first star is early success, the strongest predictor of sticking with a game (competence, in self-determination theory). |
| **Seated, a card shows the ONE next goal**, with progress ("WIN 3 SETS (2/3)"). | One clear goal, visible while you play, is the flow condition. Progress shown as a count uses the goal-gradient effect: people speed up near a goal. |
| **A gold star plaque over every other desk.** | Empty stars across the room are unfinished business: people remember and return to unfinished tasks (the Zeigarnik effect). Collecting a full set is a classic completion hook. The plaque hides at your own desk so it doesn't block the screen. |
| **Earning a star: a banner, a fanfare, and "OFFICE TOTAL n/24".** The total is also on the title screen. | A short, loud reward at the moment of success makes the win feel earned. A running total gives each desk a reason to be beaten. |
| **The seated camera frames the screen clear of the buttons, the HUD and the card.** | Nothing a game shows is hidden. |
| **Comedy's opening rules: 5 lines of small text became 3 big steps.** | On a desk monitor the old text was unreadable; the in-game coach teaches the rest live. |

## After hours (2026-11-02)

If 5 PM rings while you're seated at a game, you don't clock out: everyone
goes home (except Dale) and you stay. The office goes dark (ceiling lights
off, moonlight through the blinds, Dale's desk lamp, the CRTs and the Loot
Machine lighting the room) and the clock runs on to 7 PM.

| Rule | Why |
|---|---|
| **No boss, slack counts x2** until 7 PM. | The reward for being mid-game when the bell rings: finish what you started, and catch up on a missed quota. |
| **Tomorrow you come in tired:** suspicion starts at 0.25% per game minute you stayed (max 30%). A new week starts fresh. | A real cost, so staying late is a choice with a trade-off, not a free bonus. Crunch on Friday feeds your game's research before ship day. |
| Standing up doesn't end it; 7 PM does. | Switching desks after hours stays allowed (the arcade is open late too). |

Later: after hours as a relic or bonus mode (e.g. a relic that skips the
tiredness, or a night-only desk). Rules: `Workday.start_overtime()` /
`end_overtime()`, tested in `tests/test_workday.gd`. Lights:
`ps1.gdshader`'s `after_hours`, faded on every office material by `office.gd`
`set_after_hours()`.

## Pieces are floppy disks (2026-11-03)

Every piece of your game is a 3.5" floppy disk: the plastic is its kind's
colour, the paper label has its kind and its name in ink.

| Change | Why |
|---|---|
| **No separate card or deck system.** The rewards are the pieces the Dev Kit already uses. | The Dev Kit is already a deckbuilder: one slot per kind, about forty pieces, combos that add or multiply, a fresh kit each week. A second reward economy would compete with it ("five half-games are worth less than one great one"). |
| **Floppy disks, not cards, SD cards or hard drives.** You put disks into the GAMEMAKER 95 drives. | Inserting disks into a 90s PC is something you actually do in this office, and it matches the beige CRTs. SD cards belong to the 2000s and would break the look. |
| **NEW DISK! full-screen pop-up** for every piece, with what it clicks with; **COMBO FOUND!** when two disks light up a combo. | A reward you see and hear lands harder than a toast in the corner. Showing the combos it can make points at the next desk to beat. |
| **The disk binder keeps every disk you've ever found**, across weeks and getting fired. The weekly kit still starts empty. First finds get a fanfare. | That's the collection layer between runs, like Balatro's collection: a reason to start the next week, without making the week easier. |
| **Star cards share the binder.** A STAR CARDS tab shows every desk's stars as a card, coloured by tier (bronze, silver, gold). | Stars are permanent mastery, pieces are this week's tools. Keeping both in one binder gives one place to see everything you've done. |

Design samples: the "Look Busy — Award Cards" canvas.
