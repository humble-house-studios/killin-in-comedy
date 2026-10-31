class_name DaleLines
## Everything Dale says. Dale is the guy at the desk under the window: fifteen
## years in QA at Humble House Games, a small video game studio where you're
## the new hire, bored most of the day, with bigger dreams. He's tried every
## dream for exactly one week. He becomes your guide: each chapter points you
## at the next desk game, aimed at a bigger ambition, until upstairs notices.
## Full design: docs/narrative.md.
##
## Arc: Pong (where games began) -> beat the world's best at the cube -> try
## stand-up -> the Loot Machine makes everything easier -> solve a Millennium
## Problem at the Proof Desk -> the next floor (promotion; next room TBD).
##
## A step is {"dale": line} or {"choices": [{"text", "reply", "trust"}]}.
## `need` = stats that unlock the chapter (all of them, or any one if "any").
## `goal` = the to-do shown on screen while the chapter is locked (not spoken).
## `hint` = what Dale says while the chapter is still locked.
## `fact` = what the chapter reveals, for the voice chat (Dale knows the facts
## of chapters you've finished and keeps the rest secret).
## Stats come from the shared save (user://office_relics.cfg): the Loot Machine
## link writes comedy_sets/comedy_shows/pong_stages/cube_solves/loot_runs/
## loot_wins; the office writes pong_bosses/cube_records/proof_wins
## (engine/office_goals.gd).
## Keep lines short enough for the talk box (under ~110 characters).

const CHAPTERS := [
	{
		"id": "pong",
		"fact": "You welcomed the new hire to Humble House Games, admitted there's not much to do, called playing games 'research', and sent them to beat the first Pong boss.",
		"title": "THE ORIGINAL",
		"need": {},
		"goal": "",
		"hint": "",
		"steps": [
			{"dale": "Hey! New hire, right? Dale. QA. Fifteen years at this studio, third desk from the window."},
			{"dale": "Real talk: nothing happens here till Thursday. Most days I test the coffee machine."},
			{"dale": "So you play games. It's a game studio. Technically that's research."},
			{"choices": [
				{"text": "Isn't that slacking?", "reply": "In QA we call it regression testing. Say it with me. Regression testing.", "trust": 0},
				{"text": "What should I play?", "reply": "Glad you asked. I have a curriculum. It's laminated.", "trust": 1},
				{"text": "I have bigger dreams.", "reply": "Good! Dreams are free. Lunch is not. Let's start small and go big.", "trust": 1},
			]},
			{"dale": "Start with Pong. 1972. Two lines and a dot. The first video game anybody ever loved."},
			{"dale": "Beat the first boss. Stage four. Then come see me."},
		],
	},
	{
		"id": "cube",
		"fact": "The new hire beat the Pong boss. You dared them to beat the world's best: the 2.51-second Rubik's cube record at the Cube Desk. You tried cubing for one week in 2011.",
		"title": "WORLD RECORD",
		"need": {"pong_bosses": 1},
		"goal": "BEAT THE PONG BOSS (STAGE 4)",
		"hint": "Pong desk, by the wall. Clear stage four and beat the boss. History first.",
		"steps": [
			{"dale": "You beat Pong! The game that started it all. You're basically a historian now."},
			{"dale": "Okay. Harder. The desk by the door has a Rubik's cube. The world record is 2.51 seconds."},
			{"dale": "Can you beat the world's best player? Probably not. But I want to watch you try."},
			{"choices": [
				{"text": "2.51 seconds?!", "reply": "I know. It takes me 2.51 seconds to find my glasses. They're on my head.", "trust": 0},
				{"text": "Have you tried it?", "reply": "For one week in 2011. I peeled the stickers off. That counts, right?", "trust": 1},
				{"text": "Watch me.", "reply": "Ooh. Confidence. Put that on your resume.", "trust": 1},
			]},
			{"dale": "Work up through the levels. The last one is his exact scramble. Beat it."},
		],
	},
	{
		"id": "standup",
		"fact": "The new hire beat the cube world record. You told them they're quick and read a room, and pushed them to try stand-up on their desk's comedy club game. You were a comic called Big Deal for one week in 2009.",
		"title": "OPEN MIC",
		"need": {"cube_records": 1},
		"goal": "BEAT THE CUBE WORLD RECORD",
		"hint": "Cube Desk, by the door. The last level is the world record scramble. Beat it.",
		"steps": [
			{"dale": "You beat the world record. Somebody in this office cried. It was me."},
			{"dale": "Here's what I've noticed. You're quick. You read a room. You think on your feet."},
			{"dale": "So why not stand-up? Your desk runs a comedy club. Maybe you're good at that instead."},
			{"choices": [
				{"text": "Me? Stand-up?", "reply": "You made the whole morning standup laugh. The meeting. That's a tough room.", "trust": 1},
				{"text": "Have you done stand-up?", "reply": "One week in 2009. I called myself Big Deal. Let's not talk about it.", "trust": 0},
				{"text": "Comedy isn't a job.", "reply": "Neither is mine, and they pay me. Go.", "trust": 0},
			]},
			{"dale": "Do two sets. Build a bit, land it at the peak. Then come tell me how it went."},
		],
	},
	{
		"id": "slots",
		"fact": "The new hire cleared two comedy sets. You sent them to the Loot Machine slot cabinet, whose relics power up every game, and insisted office gambling is totally fine and not problematic (it's a running joke).",
		"title": "EASY MODE",
		"need": {"comedy_sets": 2},
		"goal": "CLEAR 2 COMEDY SETS",
		"hint": "Your desk runs a comedy club. Clear two sets, then come tell me.",
		"steps": [
			{"dale": "Two sets! I heard the laughs. Some of them were even from people."},
			{"dale": "But comedy is hard. So let's make everything easier. With gambling."},
			{"dale": "The Loot Machine, right wall. Win relics and they power up every game in here."},
			{"choices": [
				{"text": "Is gambling... okay?", "reply": "It's office gambling. Fake tokens. Totally fine. Not problematic. At all.", "trust": 0},
				{"text": "What's the catch?", "reply": "No catch! Just lights, bells, and the slow erosion of free will.", "trust": 1},
				{"text": "Sounds fun!", "reply": "That's the spirit! That's also exactly what the machine wants you to say.", "trust": 0},
			]},
			{"dale": "Pull the lever. Your sets get easier, Pong gets easier, life gets easier. Probably."},
		],
	},
	{
		"id": "proof",
		"fact": "The new hire played the Loot Machine. You said they're getting scary smart and sent them to the Proof Desk to solve a Millennium Problem: seven famous math problems, a million dollars each, only one ever solved.",
		"title": "THE BIG PROBLEMS",
		"need": {"loot_runs": 1},
		"goal": "PLAY A LOOT MACHINE RUN",
		"hint": "Loot Machine, right wall. Do one run. Relics make every game easier.",
		"steps": [
			{"dale": "Look at you. Pong, a world record, two sets, and a gambling habit. Kidding! Mostly."},
			{"dale": "You're getting good. Like, scary smart. So let's think bigger. World-sized."},
			{"dale": "There are seven Millennium Problems. A million dollars each. Only one's ever been solved."},
			{"choices": [
				{"text": "A million dollars?", "reply": "Real money. Not Comp Tokens. I checked. Twice.", "trust": 0},
				{"text": "That's impossible.", "reply": "So was the world record. You're on a streak. Don't break it for me.", "trust": 1},
				{"text": "Did you try one?", "reply": "One week. 2016. I got as far as buying a chalkboard. It's that one.", "trust": 1},
			]},
			{"dale": "The Proof Desk, under my old chalkboard. Go solve one of the world's biggest problems."},
		],
	},
	{
		"id": "ladder",
		"fact": "The new hire proved a theorem at the Proof Desk. Upstairs (the second floor, management) heard and wants to talk promotion. You've never been past the stairwell. You're finding out which room is next.",
		"title": "THE LADDER",
		"need": {"proof_wins": 1},
		"goal": "PROVE A THEOREM AT THE PROOF DESK",
		"hint": "Proof Desk, under the chalkboard. Prove one. Solve something big.",
		"steps": [
			{"dale": "You proved it. And somebody upstairs heard. UPSTAIRS, kid."},
			{"dale": "Second floor. Management. Fifteen years and I've never been past the stairwell."},
			{"dale": "They want to talk promotion. Corner office. A chair that doesn't squeak."},
			{"choices": [
				{"text": "What's up there?", "reply": "Nobody knows. Rumor says a smoothie machine. I've had dreams about it.", "trust": 0},
				{"text": "Come with me, Dale.", "reply": "Me? I'm QA. ...You'd really want me up there? Huh.", "trust": 1},
				{"text": "I'm not done down here.", "reply": "Good. The best ones never are.", "trust": 1},
			]},
			{"dale": "I'll find out which room is next. Till then, keep playing. Get even better."},
			{"dale": "Proud of you. Don't tell anyone I said that. I have a reputation."},
		],
	},
]

## Filler while the next chapter is still locked (followed by its hint).
const SMALL_TALK := [
	"Build broke again. Nobody touch anything for an hour.",
	"Marketing wants the game to be more viral. I don't know what that means either.",
	"My chair squeaks in B flat. I filed it as a bug. Won't fix.",
	"Fourth donut. Don't log it.",
	"Crunch starts Monday. It's been starting Monday since 2014.",
	"Somebody microwaved fish in the kitchen. That's a severity one.",
]

## What Dale says when he noticed you did something since you last talked.
## Checked in this order; only the first one that happened is said.
const REACT := {
	"proof_wins": ["Did you just do math? On purpose? At work?"],
	"comedy_shows": ["You HEADLINED! Somebody get this person a stool and a mic!"],
	"cube_records": ["Faster than the world record. I timed it with my microwave."],
	"loot_wins": ["JACKPOT bells! The whole floor heard that."],
	"pong_bosses": ["You beat a Pong boss! The 1970s would be so proud."],
	"comedy_sets": ["Heard laughs from your desk. Real ones!", "Another set? You're finding a rhythm."],
	"cube_solves": ["Saw you on the cube. Your hands were a blur."],
	"pong_stages": ["Pong's been beeping like crazy. You're on a run.", "Saw you on the Pong machine. Nice wrists."],
	"loot_runs": ["Heard the Loot Machine ding. Feed it, it feeds you. That's how it gets you."],
}

## After the last chapter, while the next floor is still being built.
const AFTER := [
	"Still no word from upstairs. I sent a very polite email. In purple font.",
	"Heard the second floor has a nap pod. I'm emotionally ready.",
	"Keep sharpening up. When that elevator opens, you walk in like you own it.",
	"Took up juggling. One week. You know how it goes.",
	"Maybe I'll try stand-up again. Big Deal returns. ...Maybe.",
]

## What Dale says when the voice chat goes wrong (pre-recorded like the rest).
const MIC_LINES := [
	"Hold TALK the whole time you're speaking.",
	"I can't hear you. If your browser asked about the mic, tap Allow, then hold TALK again.",
	"That was a long one. Try something shorter.",
	"Couldn't reach Dale. Check the connection.",
	"My line went dead. Try again in a sec.",
	"Didn't catch that. Hold the button while you talk.",
	"I'm all talked out for today. Free AI limit. Catch me tomorrow!",
]

## Who Dale is, for the voice chat. DaleStory.persona() adds what he has and
## hasn't told you yet.
const PERSONA := """You are Dale, 50, a chubby, warm, nervous, very funny guy who has worked fifteen years in QA at Humble House Games, a small video game studio, at the desk under the window. You're talking out loud with the new hire, who is bored at work and has bigger dreams. They play the games on the office computers: Pong on the side desk, Cube Desk (a Rubik's cube game with the 2.51-second world record), a stand-up comedy game on their own desk, the Loot Machine slot cabinet (its relics power up every game) and the Proof Desk (a card game about solving Millennium Problems).
You've tried every dream for exactly one week (cubing, stand-up as Big Deal, math, juggling) and quit. Now you're the new hire's guide: you point them at the next game, each one aimed at a bigger ambition, so they can climb the ladder to the second floor (management).
How you talk: like a real coworker in a quick spoken chat. One to three short sentences, under 45 words. Plain words, dad jokes, self-deprecating, a little dramatic. No emojis, no lists, no stage directions, no asterisks. Never say you are an AI or a character. Stay in this office.
What you care about: secretly, following your dreams. You cheer the new hire on in small, sincere ways, then undercut it with a joke."""
