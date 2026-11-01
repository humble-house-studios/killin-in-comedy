class_name CoworkerLines
## The five coworkers on break in the arcade, past the office door. Talking to
## them works like improv: every reply has a stance (YES, AND / ASK / RIFF /
## PUSH); each coworker loves one and hates one. Loved raises trust, hated
## drops it and they close off until you play another machine round.
## Trust tiers: 1 = a small bonus, 2 = their lore secret, 3 = their big perk.
## Rules: engine/coworkers.gd. Design: docs/narrative.md (The Ladder).
##
## Each prompt: the coworker's line, then one reply per stance:
##   stance: [what you say (under 28 chars), what they answer (under ~110)].
## Rewards: "tokens:5", "tickets:25", "item:<id>" (applied by LadderState).
## `gift` = the prize-counter item they want (giving it is worth a tier);
## `gift_need` = a stat instead of an item (Theo: beat any machine).
## Callbacks: what one coworker told you, brought to another (+1 trust).

const ORDER := ["gloria", "kev", "bernie", "theo", "ray"]

const PEOPLE := {
	"gloria": {
		"name": "GLORIA", "title": "QA LEAD", "spot": "claw",
		"loves": "ask", "hates": "riff",
		"gift": "plush", "gift_text": "Give her the plush",
		"gift_reply": "The top-shelf plush. Eleven years I wanted this. ...Thank you. Really.",
		"closed": "Not now. Go play something. Come back when you've got quarters.",
		"hello": ["Shh. The claw's thinking.", "Oh. You again. Hi.", "Pull up a quarter. I like you."],
		"prompts": [
			{"line": "Eleven years and this claw still gets me. Every. Single. Time.", "replies": {
				"ask": ["What keeps you coming back?", "...Nobody's asked me that. The one time it works, the whole room cheers. I like that."],
				"yes_and": ["And one day it'll pay up.", "Optimist. Cute. I said that in 2015."],
				"riff": ["Maybe it's rigged against QA.", "Heard it. Heard all of them. Next."],
				"push": ["Maybe try something else?", "Maybe you try minding your own quarters."],
			}},
			{"line": "QA is finding what's broken before anyone else does. I'm very good at it.", "replies": {
				"ask": ["What's the worst bug ever?", "A door you could walk through backwards into 1998. We shipped it. Players loved it."],
				"yes_and": ["And you found me.", "Ha. Jury's still out on whether you're a bug."],
				"riff": ["So, a professional critic.", "Critics get paid more. Don't be cute."],
				"push": ["Bet I find more bugs.", "Bet you don't. Sit down."],
			}},
			{"line": "I've been here since day one. The very first week. Before the carpet.", "replies": {
				"ask": ["What was day one like?", "Tiny. Loud. One game, one founder, one coffee pot. I tested every inch of it."],
				"yes_and": ["And you've seen it all.", "Seen it, logged it, filed it."],
				"riff": ["Before carpet? Barbaric.", "You're doing a bit. I can tell."],
				"push": ["So why are you still QA?", "Because I'm good at it. Next question."],
			}},
		],
		"rewards": [
			{"line": "Here. Five tokens. Don't tell Theo.", "reward": "tokens:5"},
			{"line": "I tested this studio's very first game. Great game. The credits screen was blank. No name. Ever.", "secret": "The first game's credits were blank. Nobody knows who made it."},
			{"line": "Fine. Claw secret: it grabs full strength every fourth try. I'll put a light on it for you.", "reward": "item:gloria_eye", "perk": "GLORIA'S EYE: the claw shows when it's at full strength"},
		],
		"after": ["Fourth grab's the strong one. Go.", "My eye's on that top shelf. Always.", "Logged eleven bugs before lunch. Personal best."],
	},
	"kev": {
		"name": "KEV", "title": "INTERN", "spot": "pusher",
		"loves": "yes_and", "hates": "push",
		"gift": "tie", "gift_text": "Give him the ticker tie",
		"gift_reply": "A stock-ticker tie?! Bro. I'm wearing this to my performance review. And my wedding.",
		"closed": "Not feeling it right now, bro. Go drop some coins.",
		"hello": ["Bro. Watch this.", "My guy! You're back!", "Best friend! Look at my coins!"],
		"prompts": [
			{"line": "Bro. The pusher's about to drop. I can feel it. Like the stock market, but louder.", "replies": {
				"yes_and": ["And you've got the touch.", "I DO have the touch! Finally someone sees it."],
				"ask": ["Does it ever actually drop?", "Sometimes. Mostly no. But sometimes!"],
				"riff": ["Louder AND worse odds.", "Haha. Ha. Okay, but you're wrong though."],
				"push": ["That's just gambling, Kev.", "Wow. Okay. Didn't ask, bro."],
			}},
			{"line": "I'm gonna be a millionaire by thirty. I've got a plan. It's mostly vibes.", "replies": {
				"yes_and": ["And vibes are underrated.", "Thank you! Vibes built the pyramids. Probably."],
				"ask": ["What's step one?", "Step one is vibes. I told you. Keep up."],
				"riff": ["Thirty's coming fast, bro.", "I'm twenty-two. I have like eight years. Easy."],
				"push": ["Vibes aren't a plan.", "You sound like my mom. Bye."],
			}},
			{"line": "Everyone thinks I got this internship 'cause I'm the CEO's nephew.", "replies": {
				"yes_and": ["And you're crushing it anyway.", "Right?! I refilled the stapler twice today."],
				"ask": ["Are you?", "...That's complicated. Ask me later."],
				"riff": ["Nepotism, but make it coins.", "Okay, that's actually funny. Still rude."],
				"push": ["So you didn't earn it.", "I earned it! Kind of. Ugh."],
			}},
		],
		"rewards": [
			{"line": "You're cool. Have some tokens. I have a system. The system is I have tokens.", "reward": "tokens:5"},
			{"line": "Real talk? I'm the CEO's nephew. I've never met the CEO. Nobody has. Is that weird?", "secret": "Nobody has ever met the CEO. Not even his 'nephew'."},
			{"line": "Tip from my group chat for the trading floor: watch the stock with the star. It's gonna pop.", "reward": "item:insider_tip", "perk": "INSIDER TIP: one stock on the trading floor wears a star. It will pop."},
		],
		"after": ["The pusher's ready. I can feel it.", "Star stock, bro. Remember the star.", "Day three of my investing journey. Down eleven tokens."],
	},
	"bernie": {
		"name": "BERNIE", "title": "HR", "spot": "ragdoll",
		"loves": "riff", "hates": "ask",
		"gift": "stress_ball", "gift_text": "Give her the stress ball",
		"gift_reply": "A stress ball! For my desk! So I can stop flinging Dale! ...I'll still fling Dale.",
		"closed": "HR's office hours are over. Go fling something.",
		"hello": ["This is a safe space. Mostly.", "Oh good. A fun one.", "My favorite employee! Don't tell anyone."],
		"prompts": [
			{"line": "It's not personal. It's a stress dummy that happens to look exactly like Dale.", "replies": {
				"riff": ["He'd be honored, honestly.", "He WOULD! He asked to sign it."],
				"yes_and": ["And it's very therapeutic.", "Very. HR approved. I'm HR."],
				"ask": ["Does Dale know?", "I can't discuss personnel matters."],
				"push": ["Isn't that a little weird?", "Everything's weird in HR. Pick a lane."],
			}},
			{"line": "Today I mediated a fight about the thermostat. Two hours. Nobody won.", "replies": {
				"riff": ["The thermostat won.", "The thermostat always wins. It knows it."],
				"yes_and": ["And you'll do it again.", "Thursday. It's on the calendar."],
				"ask": ["Who started it?", "Confidential. Don't ask HR questions."],
				"push": ["Just pick a temperature.", "Oh sure. Let me just solve war."],
			}},
			{"line": "Fifteen years Dale's been here. We're doing a cake. I'm writing the card.", "replies": {
				"riff": ["'Congrats on not leaving.'", "That's honestly perfect. I'm stealing it."],
				"yes_and": ["And he'll cry.", "He'll cry at the cake. He cries at cake."],
				"ask": ["What do you know about him?", "Personnel matters are personal. Literally."],
				"push": ["Fifteen years in QA?", "Some people like it there. Don't judge."],
			}},
		],
		"rewards": [
			{"line": "You made me laugh. HR has a petty-cash drawer. Take five tokens.", "reward": "tokens:5"},
			{"line": "Between us: I pulled Dale's file for his cake. It's blank. No hire date. No manager. No salary.", "secret": "Dale's personnel file is blank. No hire date, no manager, no salary."},
			{"line": "Spare HR badge: lets you redraw your hand once in the boardroom. And fling him spinning: style counts double.", "reward": "item:hr_badge,item:style", "perk": "HR BADGE + STYLE: one redraw in the pitch, and flips score double"},
		],
		"after": ["Spin him. Style counts.", "Writing the cake card. Need a rhyme for 'QA'.", "Reminder: the dummy is not Dale. Legally."],
	},
	"theo": {
		"name": "THEO", "title": "YOUR RIVAL", "spot": "counter",
		"loves": "push", "hates": "yes_and",
		"gift_need": "beaten", "gift_text": "I beat a machine.",
		"gift_reply": "...You did? On your own? Okay. Respect. A little. Don't make it weird.",
		"closed": "We're not friends. Go win something, then talk.",
		"hello": ["Oh. The new hire.", "You again. Fine.", "Hey. ...Rival."],
		"prompts": [
			{"line": "That promotion's mine. Two years I've been here. You've been here a week.", "replies": {
				"push": ["May the best one win.", "Ha. Okay. I like that. You're on."],
				"yes_and": ["And you totally deserve it!", "Don't suck up. It's embarrassing for both of us."],
				"ask": ["Why do you want it?", "Money. Title. A chair that doesn't squeak."],
				"riff": ["Two years? Rookie.", "Funny. I'm still winning."],
			}},
			{"line": "Four thousand tickets saved. Know what I'm buying? Nothing. It's about having them.", "replies": {
				"push": ["That's a weird flex.", "It's a GREAT flex. ...But yeah. It's a little weird."],
				"yes_and": ["And that's so smart!", "Are you being nice? Stop that."],
				"ask": ["Why save them?", "So I never have to want something. Deep, right?"],
				"riff": ["Dragon hoard energy.", "Dragons are cool. I'll allow it."],
			}},
			{"line": "You know what? Some days I don't even want to be up there.", "replies": {
				"push": ["Then what DO you want?", "...Honestly? Nobody's ever asked me straight."],
				"yes_and": ["And that's okay!", "Don't therapy me. I can tell when I'm being therapied."],
				"ask": ["Since when?", "Since always. Forget it."],
				"riff": ["Bold words for a rival.", "Yeah, yeah. Still your rival."],
			}},
		],
		"rewards": [
			{"line": "Fine. Twenty-five tickets. Consider it a loan you never pay back.", "reward": "tickets:25"},
			{"line": "I don't want the promotion. I want to be a chef. I'm you, one floor up. Tell no one.", "secret": "Theo doesn't want the promotion. He wants to be a chef."},
			{"line": "Here. Half my stash, 150 tickets. And when you pitch the board? I'm voting yes.", "reward": "tickets:150,item:theo_vote", "perk": "THEO'S VOTE: one yes in the boardroom before you start"},
		],
		"after": ["Still your rival. Just so we're clear.", "Made risotto last night. Don't tell anyone.", "Go get that key. I'll be fine down here."],
	},
	"ray": {
		"name": "RAY", "title": "NIGHT JANITOR", "spot": "corner",
		"loves": "yes_and", "hates": "push",
		"gift": "coffee", "gift_text": "Give him the coffee",
		"gift_reply": "Hot coffee. Nobody brings the janitor coffee. You're alright, kid.",
		"closed": "Floor's wet. Come back after you've played something.",
		"hello": ["Mind the bucket.", "Evening, kid.", "There's my favorite."],
		"prompts": [
			{"line": "Thirty years I've swept this floor. Since before it was an office, even.", "replies": {
				"yes_and": ["And it shows. Very clean.", "Ha! Somebody noticed. You're alright."],
				"ask": ["What was it before?", "Long story. Ask me when I know you better."],
				"riff": ["The floor owes you.", "The floor owes me nothing. The boss owes me overtime."],
				"push": ["Shouldn't you be done by now?", "Shouldn't you be working? That's what I thought."],
			}},
			{"line": "Late nights, this place hums. The machines talk to each other. I swear it.", "replies": {
				"yes_and": ["And you're the one listening.", "Exactly. Somebody has to."],
				"ask": ["What do they say?", "Mostly 'insert coin'. Not big talkers."],
				"riff": ["The claw says 'not today'.", "Ha. That one's the meanest."],
				"push": ["Machines don't talk, Ray.", "And you know everything, huh? Night."],
			}},
			{"line": "Used to be you could hear laughing through these walls every night.", "replies": {
				"yes_and": ["And maybe you will again.", "...Yeah. Maybe I will."],
				"ask": ["Laughing at what?", "Ask the walls. They were here first."],
				"riff": ["Was it Theo's jokes?", "Nobody's ever laughed at Theo's jokes."],
				"push": ["Sounds like a ghost story.", "Suit yourself. I know what I heard."],
			}},
		],
		"rewards": [
			{"line": "Found these under the claw machine. Five tokens. Yours.", "reward": "tokens:5"},
			{"line": "This building was a comedy club. The Brick Wall. A comic bought it in 2011, put in desks.", "secret": "The building was a comedy club, The Brick Wall. A comic bought it in 2011."},
			{"line": "Here. Key to the basement door, by the claw. Stuff they shelved is down there. Lock up after.", "reward": "item:archive_key", "perk": "ARCHIVE KEY: opens the basement door in the arcade"},
		],
		"after": ["Basement's by the claw. Lock up after.", "Mind the bucket.", "Sometimes I still hear them laughing."],
	},
}

## Bring what one coworker told you to another: `from` = whose secret you need.
const CALLBACKS := [
	{"id": "credits_ceo", "at": "kev", "from": "gloria", "text": "Gloria says no one's credited.",
		"reply": "No name on the first game? And nobody's met the CEO? ...Wait. Wait wait wait."},
	{"id": "ceo_file", "at": "bernie", "from": "kev", "text": "Nobody's met the CEO.",
		"reply": "...Huh. Nothing I file goes to a CEO. It all goes to a P.O. box, signed 'B.D.'"},
	{"id": "file_credits", "at": "gloria", "from": "bernie", "text": "Dale's file is blank.",
		"reply": "Blank? Like the credits. ...Dale was here that first week too. Said he tested the coffee pot."},
	{"id": "club_chef", "at": "theo", "from": "ray", "text": "This was a comedy club.",
		"reply": "A comedy club? Huh. Everybody here wanted to be something else, didn't they."},
	{"id": "chef_comic", "at": "ray", "from": "theo", "text": "Theo wants to be a chef.",
		"reply": "Kid's got sense. The comic who bought this place? Big guy. Big laugh. Same sandwich daily."},
]

## Look Busy (docs/look-busy.md): everyone's side project and what they do
## for you once trust unlocks a role (engine/coworkers.gd role()):
##   lookout (trust 1+): coughs before the boss comes by, and covers an empty
##     desk once a day.
##   collaborator (trust 2+): their side project (and themselves) become
##     pieces for your own game.
##   snitch: picking the reply they hate while they don't trust you at all
##     burns them; twice a day they tip the boss off. A gift or a callback
##     makes up.
## side: {name, pitch (their line), pieces: [[kind, piece name], ...]}.
const BUSY := {
	"gloria": {
		"side": {"name": "BUG ZOO", "pitch": "My side project: Bug Zoo. You collect famous bugs. Like pets. They escape.",
			"pieces": [["mechanic", "GLITCH HUNT"], ["character", "GLORIA"]]},
		"lookout": "*ahem* Heels on the stairs. Look busy.",
		"cover": "Gloria told the boss you're testing the bathroom.",
		"snitch": "Gloria logged a bug report about you. Severity: high.",
	},
	"kev": {
		"side": {"name": "VIBE COIN", "pitch": "Bro. Vibe Coin. The game is just vibes. Neon. Palm trees. You're in.",
			"pieces": [["art", "VAPORWAVE"], ["character", "KEV"]]},
		"lookout": "*cough cough* BRO. Boss. Incoming.",
		"cover": "Kev told the boss you're 'in a sync'. Nobody knows what that means.",
		"snitch": "Kev told his uncle you never work. His uncle told the boss.",
	},
	"bernie": {
		"side": {"name": "HR: THE RPG", "pitch": "I'm writing an RPG. You level up by filing forms. Final boss: compliance.",
			"pieces": [["genre", "RPG"], ["character", "BERNIE"]]},
		"lookout": "*cough* Policy reminder: the boss is on the stairs.",
		"cover": "Bernie filed your empty desk under 'wellness break'.",
		"snitch": "Bernie opened a file on you. It's thick already.",
	},
	"theo": {
		"side": {"name": "KNIFE FIGHT KITCHEN", "pitch": "Fine. My secret game: Knife Fight Kitchen. Cooking, but competitive. Very.",
			"pieces": [["genre", "COOKING"], ["character", "THEO"]]},
		"lookout": "*cough* Rival courtesy: the boss is coming. Now we're even.",
		"cover": "Theo said you were helping him. He hated saying it.",
		"snitch": "Theo mentioned your 'gaming' in standup. Loudly.",
	},
	"ray": {
		"side": {"name": "MOP DROP", "pitch": "I make beats on the mop bucket. Night shift. Call it Mop Drop.",
			"pieces": [["sound", "MOP BEATS"], ["character", "RAY"]]},
		"lookout": "*cough* Somebody's coming down the hall. Not me.",
		"cover": "Ray told the boss he's been mopping round your desk all day.",
		"snitch": "Ray mentioned you to the boss. Didn't mean to. Probably.",
	},
}

## How the stance tags read on the reply buttons.
const STANCE_TAG := {"yes_and": "YES, AND", "ask": "ASK", "riff": "RIFF", "push": "PUSH"}
