extends RefCounted


func run(tree: SceneTree) -> void:
	var t := TestAssert.new()
	var gs: Node = tree.root.get_node("GameState")
	gs.reset_run()

	# 1. TouchControls adapts to wide mobile landscape (1560x720) and portrait (720x1560)
	var tc := TouchControls.new()
	tree.root.add_child(tc)
	tc.set_override_canvas_size(Vector2(1560.0, 720.0))
	tc.set_active(true)
	t.is_true(not tc.is_portrait(), "1560x720 detected as landscape")
	var l_stick: Vector2 = tc.get_stick_default_center()
	var l_fire: Vector2 = tc.get_button_center("fire")
	var l_auto: Vector2 = tc.get_button_center("auto")
	t.is_true(l_stick.x < 300.0 and l_stick.y > 450.0, "landscape stick in bottom-left")
	t.is_true(l_fire.x > 1300.0 and l_fire.y > 450.0, "landscape FIRE in bottom-right")
	t.is_true(l_auto.x > 1050.0 and l_auto.y > 380.0, "landscape AUTO stays on right side")

	tc.set_override_canvas_size(Vector2(720.0, 1560.0))
	t.is_true(tc.is_portrait(), "720x1560 detected as portrait")
	var p_stick: Vector2 = tc.get_stick_default_center()
	var p_fire: Vector2 = tc.get_button_center("fire")
	var p_lock: Vector2 = tc.get_button_center("lock")
	t.is_true(p_stick.x < 200.0 and p_stick.y > 1200.0, "portrait stick in lower-left deck")
	t.is_true(p_fire.x > 520.0 and p_fire.y > 1200.0, "portrait FIRE in lower-right deck")
	t.is_true(p_lock.x > p_stick.x + 220.0, "portrait LOCK does not overlap left stick")

	# Restore 1280x720 for multi-touch drag & button interaction checks
	tc.set_override_canvas_size(Vector2(1280.0, 720.0))

	var down := InputEventScreenTouch.new()
	down.index = 0
	down.pressed = true
	down.position = Vector2(160.0, 560.0)
	tc.handle_touch_event(down)

	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = Vector2(240.0, 500.0) # +80 right, -60 screen Y -> +Y up
	tc.handle_touch_event(drag)
	t.is_true(gs.touch_move.x > 0.5, "right drag produces positive touch_move.x")
	t.is_true(gs.touch_move.y > 0.3, "up drag produces positive touch_move.y")

	# Simultaneous right-side button touch (index 1) must not disturb left stick (index 0)
	var btn_pos: Vector2 = tc.get_button_center("lock")
	var btn_down := InputEventScreenTouch.new()
	btn_down.index = 1
	btn_down.pressed = true
	btn_down.position = btn_pos
	tc.handle_touch_event(btn_down)
	t.is_true(Input.is_action_pressed("fire_lockon"), "right LOCK pad presses fire_lockon")
	t.is_true(gs.touch_move.x > 0.5, "multi-touch right pad preserves left stick vector")

	var btn_up := InputEventScreenTouch.new()
	btn_up.index = 1
	btn_up.pressed = false
	btn_up.position = btn_pos
	tc.handle_touch_event(btn_up)
	t.is_true(not Input.is_action_pressed("fire_lockon"), "releasing LOCK pad releases fire_lockon")

	var up := InputEventScreenTouch.new()
	up.index = 0
	up.pressed = false
	up.position = Vector2(240.0, 500.0)
	tc.handle_touch_event(up)
	t.approx(gs.touch_move.length(), 0.0, 0.001, "releasing left thumb zeroes touch_move")

	# Auto-fire toggle pill
	var auto_pos: Vector2 = tc.get_button_center("auto")
	var auto_tap := InputEventScreenTouch.new()
	auto_tap.index = 2
	auto_tap.pressed = true
	auto_tap.position = auto_pos
	tc.handle_touch_event(auto_tap)
	var auto_up := InputEventScreenTouch.new()
	auto_up.index = 2
	auto_up.pressed = false
	auto_up.position = auto_pos
	tc.handle_touch_event(auto_up)
	t.is_true(gs.touch_auto_fire, "AUTO pill toggles GameState.touch_auto_fire on")

	tc.set_active(false)
	tc.queue_free()

	# 2. HUD overlay tap starts game on title screen
	var hud: HUD = load("res://scenes/ui/hud.tscn").instantiate()
	tree.root.add_child(hud)
	hud.show_title(true)
	var started := {"flag": false}
	hud.start_requested.connect(func() -> void: started["flag"] = true)
	var tap := InputEventScreenTouch.new()
	tap.index = 0
	tap.pressed = true
	tap.position = Vector2(640.0, 360.0)
	hud._input(tap)
	t.is_true(started["flag"], "tapping title overlay emits start_requested")

	# 3. Fixed top-right HUD Sound ON/OFF button toggles SfxManager mute independently
	var sfx: Node = tree.root.get_node("SfxManager")
	var sound_btn: Button = hud.get("_sound_btn") as Button
	t.is_true(sound_btn != null, "HUD has top-fixed sound toggle button")
	var muted_before: bool = sfx.get("is_muted")
	sound_btn.pressed.emit()
	t.eq(sfx.get("is_muted"), not muted_before, "top sound button toggles mute")
	sound_btn.pressed.emit()
	t.eq(sfx.get("is_muted"), muted_before, "top sound button restores mute")
	hud.queue_free()

	gs.touch_auto_fire = false
	gs.touch_move = Vector2.ZERO
	t.finish(tree, "test_touch_and_mobile")
