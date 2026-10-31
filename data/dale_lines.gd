class_name DaleLines
## Everything Dale says. Dale is the coworker at the desk under the window in
## the office: twelve years in Accounts Receivable, a purple pen, and a secret.
## The story is a little mystery (who writes the sticky notes?) about following
## your dreams. Chapters unlock from what you do in the office games; the stats
## come from the shared save (user://office_relics.cfg).
##
## A step is {"dale": line} or {"choices": [{"text", "reply", "trust"}]}.
## `need` = stats that unlock the chapter (all of them, or any one if "any").
## `hint` = what Dale says while the chapter is still locked.
## Keep lines short enough for the talk box (under ~110 characters).

const CHAPTERS := [
	{
		"id": "notes",
		"title": "THE NOTES",
		"need": {},
		"hint": "",
		"steps": [
			{"dale": "Oh! Hey. New hire, right? Dale. Accounts Receivable. Twelve years, third desk from the window."},
			{"dale": "Can I tell you something weird? Every morning there's a new sticky note on somebody's monitor."},
			{"dale": "'TIGHT FIVE.' 'LAND AT THE PEAK.' Nobody admits to writing them."},
			{"choices": [
				{"text": "Maybe it's you.", "reply": "Me? Ha! No. I write invoices. Invoices don't have punchlines.", "trust": 0},
				{"text": "That's kind of nice.", "reply": "Nice? It's psychological warfare. ...But yeah. A little nice.", "trust": 1},
				{"text": "Who cares?", "reply": "You will. Yours says TIGHT FIVE. That's a comedy thing. Somebody's watching you.", "trust": 0},
			]},
			{"dale": "Anyway. Your computer runs a comedy game. Go do a set. I'm not curious or anything."},
		],
	},
	{
		"id": "open_mic",
		"title": "FIRST LAUGH",
		"need": {"comedy_sets": 1},
		"hint": "Go play a set on your computer. Then come tell me how it went.",
		"steps": [
			{"dale": "So? How'd the set go? Don't tell me. I can see it on your face. You got a laugh."},
			{"dale": "First laugh's a drug. You chase it forever. ...That's what I've heard. From a magazine."},
			{"choices": [
				{"text": "You've done stand-up?", "reply": "Me? I've done TAXES. Next question.", "trust": 0},
				{"text": "It was terrifying.", "reply": "Good. Scared means it matters. The day it stops scaring you, quit.", "trust": 1},
				{"text": "I killed.", "reply": "Ha! Okay, big shot. Stay hungry, though. Rooms can smell comfort.", "trust": 0},
			]},
			{"dale": "Hey. The Pong machine. Somebody's got a high score on there nobody's ever beaten. Just saying."},
		],
	},
	{
		"id": "high_score",
		"title": "BEAT MY BEST",
		"need": {"pong_stages": 3},
		"hint": "That Pong machine by the wall? Clear a few stages. I want to see something.",
		"steps": [
			{"dale": "You played Pong. Did you see the note on it? BEAT MY BEST."},
			{"dale": "Same handwriting as yours. Same pen, even. Purple. Who uses a purple pen?"},
			{"dale": "...I use a purple pen. LOTS of people use a purple pen."},
			{"choices": [
				{"text": "Dale, did you write them?", "reply": "I plead the fifth. Also the sixth. Is there a sixth?", "trust": 0},
				{"text": "Show me your pen.", "reply": "Absolutely not. It's a personal pen.", "trust": 0},
				{"text": "Whoever it is, thanks.", "reply": "...I'll pass it on. To whoever. Probably nobody.", "trust": 1},
			]},
			{"dale": "Go feed the Loot Machine. Accounting bought it with a... weird budget line. Look into it."},
		],
	},
	{
		"id": "machine",
		"title": "THE BUDGET LINE",
		"need": {"loot_runs": 1},
		"hint": "Pull the Loot Machine lever once. That thing has a story.",
		"steps": [
			{"dale": "The Loot Machine. Line item from 2014: 'Morale equipment. Paid in cash. Approved by D.P.'"},
			{"dale": "D.P. Could be anybody. Dave Peterson. Diane Park. Don Pickles."},
			{"dale": "There is no Don Pickles."},
			{"choices": [
				{"text": "D.P. is Dale Pruitt.", "reply": "Keep your voice down! ...It was MY money. My last paycheck from a different job.", "trust": 1},
				{"text": "Why a slot machine?", "reply": "Every spin is a tiny bet on yourself. People forget how to do that.", "trust": 1},
				{"text": "That's embezzlement.", "reply": "It's ANTI-bezzlement. I put money IN.", "trust": 0},
			]},
			{"dale": "Keep doing your sets. When you're further along, maybe I'll show you what's in my drawer."},
		],
	},
	{
		"id": "drawer",
		"title": "THE DRAWER",
		"need": {"comedy_sets": 4},
		"hint": "Clear four sets on your computer. Then we'll talk about the drawer.",
		"steps": [
			{"dale": "Four sets. Okay. You earned this. Bottom drawer. Don't laugh."},
			{"dale": "A set list. 'Airport bit. Mom's voicemail. The goose.' Dated May 2009."},
			{"dale": "And a flyer. 'BIG DEAL: LIVE.' That's... that's me. I was Big Deal."},
			{"choices": [
				{"text": "You were a comedian?!", "reply": "Six years. Almost a headliner. The goose bit got a standing ovation in Akron.", "trust": 1},
				{"text": "Big Deal? Really?", "reply": "It's a pun! On being big! And a deal! It killed in 2006!", "trust": 0},
				{"text": "What happened?", "reply": "That's the part I don't tell. Not yet.", "trust": 0},
			]},
			{"dale": "Win me something big and I'll tell you the rest. A jackpot. Or a real run of sets."},
		],
	},
	{
		"id": "the_night",
		"title": "THE BACK DOOR",
		"need": {"loot_wins": 1, "comedy_sets": 8},
		"any": true,
		"hint": "Win a Loot Machine run, or clear eight sets. Then I'll tell you what happened.",
		"steps": [
			{"dale": "Okay. 2009. I got booked for TV. Five minutes. National. My big break."},
			{"dale": "I stood behind the curtain. Heard my name. And I walked out the back door."},
			{"dale": "Got a job here the next Monday. Never told anybody. Fifteen years of invoices."},
			{"choices": [
				{"text": "You were scared.", "reply": "Terrified. And scared never goes away. I just let it drive.", "trust": 1},
				{"text": "It's not too late.", "reply": "Says the one who still has hair. ...Thanks, though.", "trust": 1},
				{"text": "Why tell me?", "reply": "Because you've got the thing. And I've watched you almost not use it.", "trust": 0},
			]},
			{"dale": "So I wrote notes. If I couldn't do it, maybe somebody in this office would."},
			{"dale": "Headline the big show. Win the whole thing. Do it for both of us."},
		],
	},
	{
		"id": "finale",
		"title": "YOUR TURN",
		"need": {"comedy_shows": 1},
		"hint": "Headline the big show. Win a whole comedy run. I'll be right here.",
		"steps": [
			{"dale": "You did it. You headlined. I heard it through the wall. The whole office heard it."},
			{"dale": "And look. There was a sticky note on MY monitor this morning."},
			{"dale": "It says 'YOUR TURN, BIG DEAL.' ...Did you write this?"},
			{"choices": [
				{"text": "Maybe.", "reply": "Purple pen. Huh. Okay. OKAY.", "trust": 1},
				{"text": "Open mic tonight. 8 PM.", "reply": "That's in like five hours. I'd need a tie. ...I HAVE a tie.", "trust": 1},
				{"text": "Do it for both of us.", "reply": "Throwing my own line back at me. That's a callback. That's good comedy.", "trust": 1},
			]},
			{"dale": "Alright. Open mic. Tonight. If I bomb, I'm blaming you."},
			{"dale": "Thanks, kid. Follow the dream. Even if it takes fifteen years to come back around."},
		],
	},
]

## Filler while the next chapter is still locked (followed by its hint).
const SMALL_TALK := [
	"Coffee's terrible today. Same as every day. I respect the consistency.",
	"My chair squeaks in B flat. I checked.",
	"Don't tell anyone, but I'm on my fourth donut.",
	"Printer's jammed again. It knows what it did.",
	"You ever stare at a spreadsheet until it stares back?",
	"Somebody microwaved fish. In THIS economy.",
]

## What Dale says when he noticed you did something since you last talked.
## Checked in this order; only the first one that happened is said.
const REACT := {
	"comedy_shows": ["You HEADLINED! Somebody get this person a stool and a mic!"],
	"loot_wins": ["JACKPOT bells! The whole floor heard that."],
	"comedy_sets": ["Heard laughs from your desk. Real ones!", "Another set? You're finding a rhythm.", "That last set sounded tight. Tight five tight."],
	"pong_stages": ["Pong's been beeping like crazy. You're on a run.", "Saw you on the Pong machine. Nice wrists."],
	"loot_runs": ["Heard the Loot Machine ding. Feed it, it feeds you."],
}

## After the finale.
const AFTER := [
	"Rewriting the goose bit. It needs a second goose.",
	"Open mic went okay! Three laughs. One of them was mine.",
	"Keep doing sets. I'm keeping score. Purple pen.",
	"Every note I wrote was for me too, I think. Took me a while.",
	"Got a spot Thursday. Thursday! Don't tell accounting.",
]
