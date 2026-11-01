class_name Market
extends RefCounted
## The trading floor: five stocks from your own world on a 90s ticker. Prices
## wander every half second; a few big news events per session move them
## hard, each one teased by a RUMOR a few seconds ahead, so reading the ticker
## pays. Buy low, sell high, double your money before the last closing bell.
## Kev's insider tip stars the stock with the biggest pop. Pure rules: the
## trading terminal (scenes/ladder/trading.gd) ticks it and draws it.

const STOCKS := [
	{"sym": "HHG", "name": "HUMBLE HOUSE GAMES", "price": 40.0, "vol": 0.02},
	{"sym": "PRZ", "name": "PRIZE KING ARCADES", "price": 12.0, "vol": 0.035},
	{"sym": "BRCK", "name": "BRICK WALL COMEDY", "price": 8.0, "vol": 0.045},
	{"sym": "LOOT", "name": "LOOT MACHINE INC", "price": 25.0, "vol": 0.04},
	{"sym": "PRF", "name": "PROOF HAND LABS", "price": 60.0, "vol": 0.025},
]
## Headlines: [rumor, news] per direction. %s = the company name.
const UP_NEWS := [
	["RUMOR: %s IN TALKS FOR A HUGE DEAL", "%s SIGNS HUGE DEAL!"],
	["RUMOR: %s HAS A HIT IN TESTING", "%s'S NEW HIT SELLS OUT!"],
	["RUMOR: BIG STREAMER PLAYING %s", "%s GOES VIRAL!"],
]
const DOWN_NEWS := [
	["RUMOR: TROUBLE AT %s", "%s RECALLS ITS PRODUCT"],
	["RUMOR: %s CEO SPOTTED FLEEING", "%s CEO RESIGNS"],
]
const QUIET := ["MARKETS STEADY", "TRADERS BREAK FOR LUNCH", "SMOOTHIE MACHINE STOCK UNLISTED", "ANALYSTS SAY: NUMBERS"]

const DAYS := 8
const DAY_SECONDS := 22.0
const TICK := 0.5
## A rumor shows this many seconds before its news hits.
const RUMOR_LEAD := 4.0
const HISTORY := 90
## Big moves per session.
const POPS := 3
const DROPS := 2

var cash := 0.0
var start_cash := 0.0
var target := 0.0
var prices := {}
var shares := {}
var history := {}
var day := 1
var clock := 0.0
var headline := ""
var over := false
var won := false
## The stock Kev tipped (its pop is the biggest), or "".
var tip := ""
## Scheduled moves: {at (seconds since open), sym, move (×price), rumor, news}.
var events: Array = []

var _rng := RandomNumberGenerator.new()
var _acc := 0.0
var _elapsed := 0.0


func _init(start: float, rng_seed := -1, insider := false) -> void:
	if rng_seed >= 0:
		_rng.seed = rng_seed
	else:
		_rng.randomize()
	start_cash = start
	cash = start
	target = start * LadderState.MARKET_GOAL
	for s in STOCKS:
		prices[s.sym] = s.price
		shares[s.sym] = 0
		history[s.sym] = [s.price]
	_schedule(insider)
	headline = "OPENING BELL. GOOD LUCK."


static func stock(sym: String) -> Dictionary:
	for s in STOCKS:
		if s.sym == sym:
			return s
	return {}


func total_seconds() -> float:
	return DAYS * DAY_SECONDS


func _schedule(insider: bool) -> void:
	var span := total_seconds()
	var syms: Array = []
	for s in STOCKS:
		syms.append(s.sym)
	var slots: Array = []
	var n := POPS + DROPS
	# Spread the events across the session, away from the very start and end.
	for i in n:
		slots.append(span * (0.08 + 0.84 * (i + _rng.randf_range(0.15, 0.85)) / n))
	var kinds: Array = []
	for i in POPS:
		kinds.append(true)
	for i in DROPS:
		kinds.append(false)
	_shuffle(kinds)
	var biggest := -1.0
	for i in n:
		var up: bool = kinds[i]
		var sym: String = syms[_rng.randi_range(0, syms.size() - 1)]
		var move := _rng.randf_range(1.5, 1.9) if up else _rng.randf_range(0.55, 0.7)
		var lines: Array = (UP_NEWS if up else DOWN_NEWS)[_rng.randi_range(0, (UP_NEWS if up else DOWN_NEWS).size() - 1)]
		var name: String = stock(sym).name
		events.append({"at": slots[i], "sym": sym, "move": move, "rumor": lines[0] % name, "news": lines[1] % name, "teased": false, "hit": false})
		if up and move > biggest:
			biggest = move
			if insider:
				tip = sym
	events.sort_custom(func(a, b): return a.at < b.at)


## Advance the clock. Returns what happened: "rumor", "news", "bell" (a day
## closed), "won", "closed" (the session ended short of the target).
func tick(dt: float) -> Array[String]:
	var out: Array[String] = []
	if over:
		return out
	_acc += dt
	while _acc >= TICK and not over:
		_acc -= TICK
		_elapsed += TICK
		clock += TICK
		for ev in events:
			if not ev.teased and _elapsed >= ev.at - RUMOR_LEAD:
				ev.teased = true
				headline = ev.rumor
				out.append("rumor")
			if not ev.hit and _elapsed >= ev.at:
				ev.hit = true
				prices[ev.sym] = maxf(0.5, prices[ev.sym] * ev.move)
				headline = ev.news + "  %s %+d%%" % [ev.sym, roundi((ev.move - 1.0) * 100.0)]
				out.append("news")
		for s in STOCKS:
			var p: float = prices[s.sym]
			p *= 1.0 + _rng.randfn(0.0, s.vol) * 0.35 + 0.0008
			prices[s.sym] = clampf(p, 0.5, 9999.0)
			var h: Array = history[s.sym]
			h.append(prices[s.sym])
			if h.size() > HISTORY:
				h.pop_front()
		if net_worth() >= target:
			over = true
			won = true
			out.append("won")
			break
		if clock >= DAY_SECONDS:
			clock = 0.0
			if day >= DAYS:
				over = true
				out.append("closed")
				break
			day += 1
			out.append("bell")
			if _rng.randf() < 0.5 and not _pending_rumor():
				headline = QUIET[_rng.randi_range(0, QUIET.size() - 1)]
	return out


func _pending_rumor() -> bool:
	for ev in events:
		if ev.teased and not ev.hit:
			return true
	return false


## How many shares your cash buys right now.
func max_buy(sym: String) -> int:
	return int(floor(cash / prices[sym]))


func buy(sym: String, n: int) -> int:
	if over:
		return 0
	n = mini(n, max_buy(sym))
	if n <= 0:
		return 0
	cash -= n * prices[sym]
	shares[sym] += n
	return n


func sell(sym: String, n: int) -> int:
	if over:
		return 0
	n = mini(n, int(shares[sym]))
	if n <= 0:
		return 0
	cash += n * prices[sym]
	shares[sym] -= n
	if net_worth() >= target:
		over = true
		won = true
	return n


func net_worth() -> float:
	var w := cash
	for sym in shares:
		w += shares[sym] * prices[sym]
	return w


## Change since the start of the visible chart, as a share (0.1 = +10%).
func change(sym: String) -> float:
	var h: Array = history[sym]
	return prices[sym] / maxf(0.01, h[0]) - 1.0


func seconds_left() -> float:
	return (DAYS - day) * DAY_SECONDS + (DAY_SECONDS - clock)


func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp = a[i]
		a[i] = a[j]
		a[j] = tmp
