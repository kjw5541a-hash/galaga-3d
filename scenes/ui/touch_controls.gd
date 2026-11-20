class_name TouchControls
extends Control

const STICK_DEADZONE := 0.12

var _active: bool = false
var _stick_touch_id: int = -1
var _stick_origin: Vector2 = Vector2.ZERO
var _stick_knob: Vector2 = Vector2.ZERO
var _button_touches: Dictionary = {} # touch_index: int -> btn_id: String
var _override_canvas_size: Vector2 = Vector2.ZERO


static func is_mobile_environment() -> bool:
	return (
		DisplayServer.is_touchscreen_available()
		or OS.has_feature("web_android")
		or OS.has_feature("web_ios")
		or OS.has_feature("mobile")
	)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var vp: Viewport = get_viewport()
	if vp != null and not vp.size_changed.is_connected(_on_viewport_resized):
		vp.size_changed.connect(_on_viewport_resized)


func _on_viewport_resized() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if _stick_touch_id == -1:
		var layout: Dictionary = _get_layout()
		_stick_origin = layout["stick_default"] as Vector2
		_stick_knob = _stick_origin
	queue_redraw()


func set_override_canvas_size(sz: Vector2) -> void:
	_override_canvas_size = sz
	queue_redraw()


func _get_canvas_size() -> Vector2:
	if _override_canvas_size.x > 1.0 and _override_canvas_size.y > 1.0:
		return _override_canvas_size
	var vp_sz: Vector2 = get_viewport_rect().size
	if vp_sz.x > 1.0 and vp_sz.y > 1.0:
		return vp_sz
	if size.x > 1.0 and size.y > 1.0:
		return size
	return Vector2(1280.0, 720.0)


func is_portrait() -> bool:
	var cs: Vector2 = _get_canvas_size()
	return cs.y > cs.x


func set_active(flag: bool) -> void:
	_active = flag
	visible = flag
	if not flag:
		release_all()
	else:
		_on_viewport_resized()
	queue_redraw()


func release_all() -> void:
	_stick_touch_id = -1
	GameState.touch_move = Vector2.ZERO
	for idx: Variant in _button_touches.keys():
		var btn_id: String = str(_button_touches[idx])
		_set_button_action(btn_id, false)
	_button_touches.clear()
	queue_redraw()


func _get_layout() -> Dictionary:
	var cs: Vector2 = _get_canvas_size()
	var w: float = cs.x
	var h: float = cs.y
	if h > w:
		# Portrait layout: lower control deck above bottom status bar
		var scale_p: float = clampf(w / 720.0, 0.72, 1.15)
		var stick_r: float = 72.0 * scale_p
		var bottom_pad: float = clampf(h * 0.13, 145.0, 210.0)
		var side_pad: float = clampf(w * 0.15, 76.0, 125.0)
		var right_x: float = w - side_pad
		var base_y: float = h - bottom_pad
		return {
			"stick_default": Vector2(side_pad, base_y),
			"stick_radius": stick_r,
			"stick_zone_x": w * 0.46,
			"stick_zone_min_y": h * 0.52,
			"fire": {"center": Vector2(right_x, base_y + 10.0 * scale_p), "radius": 52.0 * scale_p, "label": "FIRE", "color": Color(0.2, 0.92, 1.0)},
			"lock": {"center": Vector2(right_x - 116.0 * scale_p, base_y + 18.0 * scale_p), "radius": 42.0 * scale_p, "label": "LOCK", "color": Color(1.0, 0.65, 0.14)},
			"roll": {"center": Vector2(right_x - 108.0 * scale_p, base_y - 84.0 * scale_p), "radius": 37.0 * scale_p, "label": "ROLL", "color": Color(0.22, 1.0, 0.72)},
			"emp": {"center": Vector2(right_x + 4.0 * scale_p, base_y - 96.0 * scale_p), "radius": 37.0 * scale_p, "label": "EMP", "color": Color(0.75, 0.32, 1.0)},
			"auto": {"center": Vector2(right_x - 52.0 * scale_p, base_y - 166.0 * scale_p), "radius": 29.0 * scale_p, "label": "AUTO", "color": Color(0.35, 0.95, 1.0)},
		}

	# Landscape layout: bottom-left stick & bottom-right ergonomic thumb arc (with safe area margins)
	var scale_l: float = clampf(h / 720.0, 0.75, 1.15)
	var stick_rl: float = 78.0 * scale_l
	var margin_x: float = clampf(w * 0.085, 88.0, 165.0)
	var base_yl: float = h - clampf(h * 0.25, 145.0, 200.0)
	return {
		"stick_default": Vector2(margin_x + 36.0 * scale_l, base_yl),
		"stick_radius": stick_rl,
		"stick_zone_x": w * 0.45,
		"stick_zone_min_y": 80.0,
		"fire": {"center": Vector2(w - margin_x - 24.0 * scale_l, base_yl + 10.0 * scale_l), "radius": 54.0 * scale_l, "label": "FIRE", "color": Color(0.2, 0.92, 1.0)},
		"lock": {"center": Vector2(w - margin_x - 144.0 * scale_l, base_yl + 20.0 * scale_l), "radius": 44.0 * scale_l, "label": "LOCK", "color": Color(1.0, 0.65, 0.14)},
		"roll": {"center": Vector2(w - margin_x - 122.0 * scale_l, base_yl - 88.0 * scale_l), "radius": 38.0 * scale_l, "label": "ROLL", "color": Color(0.22, 1.0, 0.72)},
		"emp": {"center": Vector2(w - margin_x - 14.0 * scale_l, base_yl - 100.0 * scale_l), "radius": 38.0 * scale_l, "label": "EMP", "color": Color(0.75, 0.32, 1.0)},
		"auto": {"center": Vector2(w - margin_x - 224.0 * scale_l, base_yl - 64.0 * scale_l), "radius": 30.0 * scale_l, "label": "AUTO", "color": Color(0.35, 0.95, 1.0)},
	}


func get_stick_default_center() -> Vector2:
	return _get_layout()["stick_default"] as Vector2


func get_button_center(btn_id: String) -> Vector2:
	var layout: Dictionary = _get_layout()
	if layout.has(btn_id) and layout[btn_id] is Dictionary:
		return (layout[btn_id] as Dictionary)["center"] as Vector2
	return Vector2.ZERO


func _input(event: InputEvent) -> void:
	if not _active:
		return
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		handle_touch_event(event)


func handle_touch_event(event: InputEvent) -> void:
	if not _active:
		return
	var layout: Dictionary = _get_layout()
	var stick_r: float = float(layout["stick_radius"])
	if event is InputEventScreenTouch:
		var te: InputEventScreenTouch = event as InputEventScreenTouch
		if te.pressed:
			var hit_btn: String = _hit_test_button(te.position, layout)
			if hit_btn != "":
				_button_touches[te.index] = hit_btn
				_on_button_pressed(hit_btn)
			elif _stick_touch_id == -1 and te.position.x < float(layout["stick_zone_x"]) and te.position.y >= float(layout["stick_zone_min_y"]):
				_stick_touch_id = te.index
				_stick_origin = te.position
				_stick_knob = te.position
				GameState.touch_move = Vector2.ZERO
		else:
			if te.index == _stick_touch_id:
				_stick_touch_id = -1
				_stick_knob = layout["stick_default"] as Vector2
				GameState.touch_move = Vector2.ZERO
			elif _button_touches.has(te.index):
				var released_btn: String = str(_button_touches[te.index])
				_button_touches.erase(te.index)
				_set_button_action(released_btn, false)
		queue_redraw()
	elif event is InputEventScreenDrag:
		var de: InputEventScreenDrag = event as InputEventScreenDrag
		if de.index == _stick_touch_id:
			var delta: Vector2 = de.position - _stick_origin
			var mag: float = delta.length()
			if mag > stick_r:
				delta = delta.normalized() * stick_r
			_stick_knob = _stick_origin + delta
			var norm: Vector2 = delta / stick_r
			if norm.length() < STICK_DEADZONE:
				GameState.touch_move = Vector2.ZERO
			else:
				GameState.touch_move = Vector2(clampf(norm.x, -1.0, 1.0), clampf(-norm.y, -1.0, 1.0))
			queue_redraw()


func _hit_test_button(pos: Vector2, layout: Dictionary) -> String:
	for btn_id: String in ["fire", "lock", "roll", "emp", "auto"]:
		var info: Dictionary = layout[btn_id] as Dictionary
		var center: Vector2 = info["center"] as Vector2
		var radius: float = float(info["radius"]) * 1.18
		if pos.distance_to(center) <= radius:
			return btn_id
	return ""


func _on_button_pressed(btn_id: String) -> void:
	if btn_id == "auto":
		GameState.touch_auto_fire = not GameState.touch_auto_fire
		return
	_set_button_action(btn_id, true)


func _set_button_action(btn_id: String, pressed: bool) -> void:
	var action: String = ""
	match btn_id:
		"fire":
			action = "fire_primary"
		"lock":
			action = "fire_lockon"
		"roll":
			action = "barrel_roll"
		"emp":
			action = "emp_pulse"
	if action == "":
		return
	if pressed:
		Input.action_press(action)
	else:
		Input.action_release(action)


func _draw() -> void:
	if not _active:
		return
	var layout: Dictionary = _get_layout()
	var font: Font = ThemeDB.fallback_font
	var stick_r: float = float(layout["stick_radius"])
	var origin: Vector2 = _stick_origin if _stick_touch_id != -1 else (layout["stick_default"] as Vector2)
	var knob: Vector2 = _stick_knob if _stick_touch_id != -1 else origin
	draw_circle(origin, stick_r, Color(0.12, 0.78, 1.0, 0.12))
	draw_arc(origin, stick_r, 0.0, TAU, 36, Color(0.25, 0.92, 1.0, 0.55), 2.5, true)
	var knob_r: float = stick_r * 0.36
	draw_circle(knob, knob_r, Color(0.25, 0.95, 1.0, 0.42))
	draw_arc(knob, knob_r, 0.0, TAU, 24, Color(0.65, 1.0, 1.0, 0.85), 2.0, true)

	for btn_id: String in ["fire", "lock", "roll", "emp", "auto"]:
		var info: Dictionary = layout[btn_id] as Dictionary
		var center: Vector2 = info["center"] as Vector2
		var radius: float = float(info["radius"])
		var col: Color = info["color"] as Color
		var is_down: bool = _button_touches.values().has(btn_id) or (btn_id == "auto" and GameState.touch_auto_fire)
		var fill_a: float = 0.42 if is_down else 0.16
		var ring_a: float = 0.95 if is_down else 0.62
		draw_circle(center, radius, Color(col.r, col.g, col.b, fill_a))
		draw_arc(center, radius, 0.0, TAU, 32, Color(col.r, col.g, col.b, ring_a), 2.5, true)
		var lbl: String = str(info["label"])
		var fsize: int = 16 if radius >= 40.0 else 13
		var tsize: Vector2 = font.get_string_size(lbl, HORIZONTAL_ALIGNMENT_CENTER, -1, fsize)
		draw_string(font, center + Vector2(-tsize.x * 0.5, fsize * 0.35), lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, Color(0.96, 0.99, 1.0, 0.92))
