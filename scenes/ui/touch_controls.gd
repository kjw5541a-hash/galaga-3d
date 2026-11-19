class_name TouchControls
extends Control

signal pause_tapped
signal mute_tapped

const STICK_RADIUS := 78.0
const STICK_DEADZONE := 0.12

var _active: bool = false
var _stick_touch_id: int = -1
var _stick_origin: Vector2 = Vector2(148.0, 540.0)
var _stick_knob: Vector2 = Vector2(148.0, 540.0)
var _button_touches: Dictionary = {} # touch_index: int -> btn_id: String


static func is_mobile_environment() -> bool:
	return (
		DisplayServer.is_touchscreen_available()
		or OS.has_feature("web_android")
		or OS.has_feature("web_ios")
		or OS.has_feature("mobile")
	)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func set_active(flag: bool) -> void:
	_active = flag
	visible = flag
	if not flag:
		release_all()
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
	var w: float = maxf(640.0, size.x)
	var h: float = maxf(360.0, size.y)
	var margin_x: float = clampf(w * 0.08, 72.0, 140.0)
	var base_y: float = h - clampf(h * 0.22, 118.0, 175.0)
	return {
		"stick_default": Vector2(margin_x + 56.0, base_y),
		"fire": {"center": Vector2(w - margin_x - 32.0, base_y + 12.0), "radius": 56.0, "label": "FIRE", "color": Color(0.2, 0.92, 1.0)},
		"lock": {"center": Vector2(w - margin_x - 148.0, base_y + 22.0), "radius": 46.0, "label": "LOCK", "color": Color(1.0, 0.65, 0.14)},
		"roll": {"center": Vector2(w - margin_x - 124.0, base_y - 84.0), "radius": 40.0, "label": "ROLL", "color": Color(0.22, 1.0, 0.72)},
		"emp": {"center": Vector2(w - margin_x - 20.0, base_y - 96.0), "radius": 40.0, "label": "EMP", "color": Color(0.75, 0.32, 1.0)},
		"auto": {"center": Vector2(w - margin_x - 232.0, base_y - 68.0), "radius": 32.0, "label": "AUTO", "color": Color(0.35, 0.95, 1.0)},
		"pause": {"center": Vector2(w - 54.0, 88.0), "radius": 26.0, "label": "||", "color": Color(0.85, 0.92, 1.0)},
		"mute": {"center": Vector2(w - 118.0, 88.0), "radius": 26.0, "label": "SFX", "color": Color(0.85, 0.92, 1.0)},
	}


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
	if event is InputEventScreenTouch:
		var te: InputEventScreenTouch = event as InputEventScreenTouch
		if te.pressed:
			var hit_btn: String = _hit_test_button(te.position, layout)
			if hit_btn != "":
				_button_touches[te.index] = hit_btn
				_on_button_pressed(hit_btn)
			elif _stick_touch_id == -1 and te.position.x < maxf(640.0, size.x) * 0.48:
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
			if mag > STICK_RADIUS:
				delta = delta.normalized() * STICK_RADIUS
			_stick_knob = _stick_origin + delta
			var norm: Vector2 = delta / STICK_RADIUS
			if norm.length() < STICK_DEADZONE:
				GameState.touch_move = Vector2.ZERO
			else:
				GameState.touch_move = Vector2(clampf(norm.x, -1.0, 1.0), clampf(-norm.y, -1.0, 1.0))
			queue_redraw()


func _hit_test_button(pos: Vector2, layout: Dictionary) -> String:
	for btn_id: String in ["fire", "lock", "roll", "emp", "auto", "pause", "mute"]:
		var info: Dictionary = layout[btn_id] as Dictionary
		var center: Vector2 = info["center"] as Vector2
		var radius: float = float(info["radius"]) * 1.18
		if pos.distance_to(center) <= radius:
			return btn_id
	return ""


func _on_button_pressed(btn_id: String) -> void:
	match btn_id:
		"auto":
			GameState.touch_auto_fire = not GameState.touch_auto_fire
		"pause":
			pause_tapped.emit()
		"mute":
			mute_tapped.emit()
		_:
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
	var origin: Vector2 = _stick_origin if _stick_touch_id != -1 else (layout["stick_default"] as Vector2)
	var knob: Vector2 = _stick_knob if _stick_touch_id != -1 else origin
	draw_circle(origin, STICK_RADIUS, Color(0.12, 0.78, 1.0, 0.12))
	draw_arc(origin, STICK_RADIUS, 0.0, TAU, 36, Color(0.25, 0.92, 1.0, 0.55), 2.5, true)
	draw_circle(knob, 28.0, Color(0.25, 0.95, 1.0, 0.42))
	draw_arc(knob, 28.0, 0.0, TAU, 24, Color(0.65, 1.0, 1.0, 0.85), 2.0, true)

	for btn_id: String in ["fire", "lock", "roll", "emp", "auto", "pause", "mute"]:
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
