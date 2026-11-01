extends "res://scenes/ladder/machine.gd"
## The trading floor terminal. Your leftover tickets cashed out as the
## starting portfolio; double it before the closing bell on day 8. Pick a
## stock, watch its chart and the headline ticker (RUMORS come a few seconds
## before the NEWS), buy, sell. The clock only runs while you sit here. Kev's
## insider tip puts a star on the stock that will pop the most. Run out of
## days and the market reopens for another try.

var market: Market
var _sel := "HHG"
var _rows := {}
var _status: Label
var _goal: Label
var _ticker: Label
var _chart: Control
var _buttons: Array[Button] = []
var _start_btn: Button
var _ticker_x := 0.0


func _ready() -> void:
	super._ready()
	frame("TRADING FLOOR", Color(0.02, 0.05, 0.03), Color(0.35, 1.0, 0.45))
	_status = label("", 22, Color(0.6, 1.0, 0.65))
	_status.position = Vector2(0, 150)
	_status.size = Vector2(W, 34)
	add_child(_status)
	_goal = label("", 22, Color(1.0, 0.92, 0.55))
	_goal.position = Vector2(0, 186)
	_goal.size = Vector2(W, 34)
	add_child(_goal)
	var list := VBoxContainer.new()
	list.position = Vector2(20, 230)
	list.size = Vector2(W - 40, 450)
	list.add_theme_constant_override("separation", 8)
	add_child(list)
	for s in Market.STOCKS:
		var b := button("", 22, Color(0.04, 0.14, 0.07), Color(0.35, 1.0, 0.45, 0.6))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 88)
		b.pressed.connect(func():
			_sel = s.sym
			sfx("click", -8.0)
			_refresh())
		list.add_child(b)
		_rows[s.sym] = b
	_chart = Control.new()
	_chart.position = Vector2(20, 700)
	_chart.size = Vector2(W - 40, 240)
	_chart.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chart.draw.connect(_draw_chart)
	add_child(_chart)
	var strip := ColorRect.new()
	strip.color = Color(0.0, 0.0, 0.0)
	strip.position = Vector2(0, 952)
	strip.size = Vector2(W, 50)
	strip.clip_contents = true
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(strip)
	_ticker = label("", 24, Color(1.0, 0.75, 0.2), HORIZONTAL_ALIGNMENT_LEFT)
	_ticker.autowrap_mode = TextServer.AUTOWRAP_OFF
	_ticker.position = Vector2(W, 12)
	strip.add_child(_ticker)
	var row := HBoxContainer.new()
	row.position = Vector2(20, 1030)
	row.size = Vector2(W - 40, 220)
	row.add_theme_constant_override("separation", 12)
	add_child(row)
	for spec in [["BUY\n10", _buy.bind(10)], ["BUY\nMAX", _buy.bind(-1)], ["SELL\nALL", _sell_all]]:
		var b := button(spec[0], 28, Color(0.05, 0.3, 0.1) if spec[0].begins_with("BUY") else Color(0.35, 0.08, 0.06))
		b.custom_minimum_size = Vector2(0, 150)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(spec[1])
		row.add_child(b)
		_buttons.append(b)
	_start_btn = button("OPEN THE MARKET", 34, Color(0.1, 0.4, 0.15))
	_start_btn.position = Vector2(60, 560)
	_start_btn.size = Vector2(W - 120, 160)
	_start_btn.z_index = 10
	_start_btn.pressed.connect(_open)
	_start_btn.set_meta("pad_default", true)
	add_child(_start_btn)
	_refresh()


func set_active(on: bool) -> void:
	super.set_active(on)
	_refresh()


func _open() -> void:
	var start: int = hub.state.market_start() if hub else LadderState.MARKET_BASE_CASH
	market = Market.new(float(start), -1, hub != null and hub.state.has("insider_tip"))
	if market.tip != "":
		_sel = market.tip
	_start_btn.visible = false
	sfx("ding")
	banner("OPENING BELL!", 1.6, Color(0.5, 1.0, 0.6))
	_refresh()


func _buy(n: int) -> void:
	if market == null or market.over:
		return
	var got := market.buy(_sel, market.max_buy(_sel) if n < 0 else n)
	sfx("coin" if got > 0 else "groan", -6.0)
	_refresh()


func _sell_all() -> void:
	if market == null:
		return
	var got := market.sell(_sel, market.shares[_sel])
	if got > 0:
		sfx("chime", -6.0)
	_check_end()
	_refresh()


func _process(delta: float) -> void:
	super._process(delta)
	if market and active and not market.over:
		var evs := market.tick(delta)
		for e in evs:
			match e:
				"rumor":
					sfx("ding", -8.0, 1.3)
				"news":
					sfx("chime", -4.0)
				"bell":
					sfx("ding", -2.0, 0.8)
					banner("DAY %d" % market.day, 1.2, Color(0.5, 1.0, 0.6))
		_check_end()
		_refresh()
	_ticker_x -= delta * 140.0
	if _ticker.size.x > 0 and _ticker_x < -_ticker.size.x:
		_ticker_x = W
	_ticker.position.x = _ticker_x


func _check_end() -> void:
	if market == null or not market.over:
		return
	if market.won:
		if hub and not hub.state.is_done("market"):
			hub.market_won()
		sfx("jackpot")
		banner("DOUBLED!\nTHE BOARDROOM\nDOOR IS OPEN", 3.5, Color(0.5, 1.0, 0.6))
	else:
		sfx("sad_trombone", -4.0)
		banner("CLOSING BELL.\nNOT THIS TIME.", 3.0, Color(1.0, 0.5, 0.4))
	_start_btn.text = "TRADE AGAIN" if market.won else "REOPEN THE MARKET"
	_start_btn.visible = true
	market = null if not market.won else market


func _refresh() -> void:
	var m := market
	var prices := {}
	for s in Market.STOCKS:
		prices[s.sym] = m.prices[s.sym] if m else s.price
	for s in Market.STOCKS:
		var b: Button = _rows[s.sym]
		var star := "*" if m and m.tip == s.sym else " "
		var ch := m.change(s.sym) if m else 0.0
		var held := int(m.shares[s.sym]) if m else 0
		b.text = "%s%-5s $%7.2f %+4d%%  x%d" % [star, s.sym, prices[s.sym], roundi(ch * 100.0), held]
		b.add_theme_color_override("font_color", Color(0.5, 1.0, 0.55) if ch >= 0.0 else Color(1.0, 0.45, 0.4))
		var sel: bool = s.sym == _sel
		b.add_theme_stylebox_override("normal", box(Color(0.1, 0.32, 0.14) if sel else Color(0.04, 0.14, 0.07), Color(0.35, 1.0, 0.45, 1.0 if sel else 0.4), 4, 6))
	if m:
		_status.text = "DAY %d/%d  %02ds   CASH $%d" % [m.day, Market.DAYS, int(Market.DAY_SECONDS - m.clock), int(m.cash)]
		if not active and not m.over:
			_status.text = "PAUSED. SIT DOWN TO TRADE."
		_goal.text = "WORTH $%d / GOAL $%d" % [int(m.net_worth()), int(m.target)]
		_ticker.text = "%s     %s  ...  " % [m.headline, Market.stock(_sel).name]
	else:
		var start: int = hub.state.market_start() if hub else LadderState.MARKET_BASE_CASH
		_status.text = "YOUR TICKETS CASHED OUT: $%d" % start
		_goal.text = "DOUBLE IT: $%d BY DAY %d" % [start * 2, Market.DAYS]
		_ticker.text = "BUY ON THE RUMOR, SELL ON THE NEWS     STARRED = INSIDER TIP     " if hub and hub.state.has("insider_tip") else "BUY ON THE RUMOR, SELL ON THE NEWS     "
	for b in _buttons:
		b.disabled = m == null or m.over
	_chart.queue_redraw()


func _draw_chart() -> void:
	var r := Rect2(Vector2.ZERO, _chart.size)
	_chart.draw_rect(r, Color(0.0, 0.08, 0.03))
	for i in 5:
		var y := r.size.y * i / 4.0
		_chart.draw_line(Vector2(0, y), Vector2(r.size.x, y), Color(0.2, 0.5, 0.25, 0.3), 1.0)
	_chart.draw_rect(r, Color(0.35, 1.0, 0.45, 0.6), false, 3.0)
	if market == null:
		_chart.draw_string(FONT, Vector2(0, r.size.y * 0.5), Market.stock(_sel).name, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 22, Color(0.35, 1.0, 0.45, 0.6))
		return
	var h: Array = market.history[_sel]
	if h.size() < 2:
		return
	var lo: float = h.min()
	var hi: float = h.max()
	if hi - lo < 0.01:
		hi = lo + 0.01
	var pts := PackedVector2Array()
	for i in h.size():
		var x := r.size.x * i / float(Market.HISTORY - 1)
		var y: float = r.size.y - 10 - (r.size.y - 20) * (h[i] - lo) / (hi - lo)
		pts.append(Vector2(x, y))
	var up: bool = h.back() >= h[0]
	_chart.draw_polyline(pts, Color(0.4, 1.0, 0.5) if up else Color(1.0, 0.45, 0.4), 4.0)
	_chart.draw_string(FONT, Vector2(12, 30), "%s $%.2f" % [_sel, h.back()], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
