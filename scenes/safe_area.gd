extends RefCounted
## Safe-area insets (notch, status bar, home bar) for a viewport that fills the window.
## Returns Vector4(left, top, right, bottom) in that viewport's units.
## Native phones ask the OS; the web build (the iPhone home-screen app runs
## edge to edge) asks the page, which measures the CSS safe-area insets
## (see head_include in export_presets.cfg). Anywhere else: zero.


static func get_insets(view_size: Vector2) -> Vector4:
	var window_size := Vector2(DisplayServer.window_get_size())
	if window_size.x <= 0.0 or window_size.y <= 0.0:
		return Vector4.ZERO
	var to_view := view_size / window_size
	if OS.has_feature("mobile"):
		var safe := Rect2(DisplayServer.get_display_safe_area())
		return Vector4(
			safe.position.x * to_view.x,
			safe.position.y * to_view.y,
			(window_size.x - safe.end.x) * to_view.x,
			(window_size.y - safe.end.y) * to_view.y)
	if OS.has_feature("web"):
		# "top,right,bottom,left" in screen pixels, or "" if the page can't say.
		var raw = JavaScriptBridge.eval("window.kicSafeInsets ? window.kicSafeInsets() : ''")
		if raw is String and raw != "":
			var p: PackedStringArray = (raw as String).split(",")
			if p.size() == 4:
				return Vector4(
					float(p[3]) * to_view.x,
					float(p[0]) * to_view.y,
					float(p[1]) * to_view.x,
					float(p[2]) * to_view.y)
	return Vector4.ZERO
