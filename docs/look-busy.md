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
