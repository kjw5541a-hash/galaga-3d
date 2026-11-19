class_name HUD
extends CanvasLayer

signal start_requested
signal restart_requested
signal resume_requested
signal pause_toggle_requested

var _score_lbl: Label
var _hi_lbl: Label
var _stage_lbl: Label
var _status_lbl: Label
var _energy_bar: ProgressBar
var _boss_bar: ProgressBar
var _banner_box: PanelContainer
var _banner_title: Label
var _banner_sub: Label
var _overlay_box: CenterContainer
var _overlay_title: Label
var _overlay_hint: Label
var _bracket_layer: Control
var _touch_controls: TouchControls = null
var _banner_timer: float = 0.0
var _mode: String = "title"
var _enter_was_down: bool = false
var _mute_was_down: bool = false


func _ready() -> void:
	_build_ui()
	GameState.score_changed.connect(_on_score_changed)
	GameState.lives_changed.connect(_on_int_status_changed)
	GameState.fighter_mode_changed.connect(_on_int_status_changed)
	GameState.shield_changed.connect(_on_int_status_changed)
	GameState.rapid_changed.connect(_on_float_status_changed)
	GameState.emp_changed.connect(_on_int_status_changed)
	GameState.energy_changed.connect(_on_energy_changed)
	GameState.stage_changed.connect(_on_stage_changed)
	SfxManager.mute_changed.connect(_on_mute_changed)
	_on_score_changed(GameState.score, GameState.high_score)
	_refresh_status()


func _on_mute_changed(_muted: bool) -> void:
	_refresh_status()


func _on_int_status_changed(_val: int) -> void:
	_refresh_status()


func _on_float_status_changed(_val: float) -> void:
	_refresh_status()


func _on_energy_changed(e: float) -> void:
	if is_instance_valid(_energy_bar):
		_energy_bar.value = e


func _build_ui() -> void:
	_bracket_layer = Control.new()
	_bracket_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bracket_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bracket_layer)

	var top_bar := HBoxContainer.new()
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_left = 20
	top_bar.offset_top = 14
	top_bar.offset_right = -20
	top_bar.offset_bottom = 52
	add_child(top_bar)

	_score_lbl = _make_label("SCORE 0", 22, Color(0.25, 0.95, 1.0))
	_score_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stage_lbl = _make_label("STAGE 1", 22, Color(1.0, 0.85, 0.25))
	_stage_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stage_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hi_lbl = _make_label("HI 0", 22, Color(1.0, 0.35, 0.7))
	_hi_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hi_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(_score_lbl)
	top_bar.add_child(_stage_lbl)
	top_bar.add_child(_hi_lbl)

	_boss_bar = ProgressBar.new()
	_boss_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_boss_bar.offset_left = 260
	_boss_bar.offset_right = -260
	_boss_bar.offset_top = 56
	_boss_bar.offset_bottom = 74
	_boss_bar.max_value = 100.0
	_boss_bar.show_percentage = false
	_boss_bar.visible = false
	add_child(_boss_bar)

	var bottom := VBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 20
	bottom.offset_right = -20
	bottom.offset_top = -76
	bottom.offset_bottom = -14
	add_child(bottom)

	_status_lbl = _make_label("", 18, Color(0.9, 0.96, 1.0))
	bottom.add_child(_status_lbl)

	_energy_bar = ProgressBar.new()
	_energy_bar.custom_minimum_size = Vector2(320, 14)
	_energy_bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_energy_bar.max_value = 100.0
	_energy_bar.value = 100.0
	_energy_bar.show_percentage = false
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.08, 0.12, 0.22, 0.78)
	bar_bg.set_corner_radius_all(4)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.18, 0.88, 1.0, 0.92)
	bar_fill.set_corner_radius_all(4)
	_energy_bar.add_theme_stylebox_override("background", bar_bg)
	_energy_bar.add_theme_stylebox_override("fill", bar_fill)
	bottom.add_child(_energy_bar)

	_banner_box = PanelContainer.new()
	_banner_box.set_anchors_preset(Control.PRESET_CENTER)
	_banner_box.offset_left = -240
	_banner_box.offset_right = 240
	_banner_box.offset_top = -55
	_banner_box.offset_bottom = 55
	_banner_box.visible = false
	add_child(_banner_box)
	var bv := VBoxContainer.new()
	bv.alignment = BoxContainer.ALIGNMENT_CENTER
	_banner_box.add_child(bv)
	_banner_title = _make_label("", 30, Color(0.25, 1.0, 0.9))
	_banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_sub = _make_label("", 18, Color(1.0, 0.9, 0.4))
	_banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bv.add_child(_banner_title)
	bv.add_child(_banner_sub)

	_overlay_box = CenterContainer.new()
	_overlay_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay_box)
	var ov := VBoxContainer.new()
	ov.alignment = BoxContainer.ALIGNMENT_CENTER
	_overlay_box.add_child(ov)
	_overlay_title = _make_label("GALAGA 3D: VANGUARD", 44, Color(0.2, 0.95, 1.0))
	_overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_hint = _make_label("WASD/Stick Move  |  Z/Space/A Fire  |  X/RB Lock-On  |  Shift/B Roll  |  V/Y EMP\n\nPress FIRE or ENTER to Launch", 18, Color(0.95, 0.95, 1.0))
	_overlay_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ov.add_child(_overlay_title)
	ov.add_child(_overlay_hint)

	_touch_controls = TouchControls.new()
	add_child(_touch_controls)
	_touch_controls.pause_tapped.connect(func() -> void: pause_toggle_requested.emit())
	_touch_controls.mute_tapped.connect(func() -> void: SfxManager.toggle_mute())


func _sync_touch_visibility() -> void:
	if not is_instance_valid(_touch_controls):
		return
	var show_touch: bool = TouchControls.is_mobile_environment() and not _overlay_box.visible
	_touch_controls.set_active(show_touch)


func _input(event: InputEvent) -> void:
	if not _overlay_box.visible:
		return
	var tapped: bool = (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
	var clicked: bool = (
		event is InputEventMouseButton
		and (event as InputEventMouseButton).pressed
		and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
	)
	if tapped or clicked:
		_trigger_overlay_confirm()


func _trigger_overlay_confirm() -> void:
	if _mode == "title":
		start_requested.emit()
	elif _mode == "game_over":
		restart_requested.emit()
	elif _mode == "pause":
		resume_requested.emit()


func _make_label(txt: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


func _process(delta: float) -> void:
	if not get_tree().paused and _banner_timer > 0.0:
		_banner_timer -= delta
		if _banner_timer <= 0.0:
			_banner_box.visible = false
	var enter_down: bool = Input.is_key_pressed(KEY_ENTER)
	var enter_just_pressed: bool = enter_down and not _enter_was_down
	_enter_was_down = enter_down
	var mute_down: bool = Input.is_key_pressed(KEY_M)
	if mute_down and not _mute_was_down:
		SfxManager.toggle_mute()
	_mute_was_down = mute_down
	if Input.is_action_just_pressed("pause"):
		pause_toggle_requested.emit()
		return
	if _overlay_box.visible:
		if Input.is_action_just_pressed("fire_primary") or enter_just_pressed:
			_trigger_overlay_confirm()


func _on_score_changed(s: int, hi: int) -> void:
	_score_lbl.text = "SCORE %d" % s
	_hi_lbl.text = "HI %d" % hi


func _on_stage_changed(st: int, st_type: int) -> void:
	var tag: String = "BOSS" if st_type == GameState.StageType.BOSS else ("CHALLENGE" if st_type == GameState.StageType.CHALLENGE else "WAVE")
	_stage_lbl.text = "STAGE %d  [%s]" % [st, tag]


func _refresh_status() -> void:
	var mode_str: String = "DUAL" if GameState.fighter_mode == GameState.FighterMode.DUAL else "SINGLE"
	var rapid_str: String = ("  RAPID %.0fs" % GameState.rapid_timer) if GameState.rapid_timer > 0.0 else ""
	var mute_str: String = "  |  [MUTE]" if SfxManager.is_muted else ""
	_status_lbl.text = "LIVES %d  |  %s  |  SHIELD %d  |  EMP %d%s  |  LOCK-ON ENERGY%s" % [
		GameState.lives, mode_str, GameState.shield_count, GameState.emp_charges, rapid_str, mute_str
	]


func show_banner(title: String, subtitle: String, duration: float = 2.0) -> void:
	_banner_title.text = title
	_banner_sub.text = subtitle
	_banner_box.visible = true
	_banner_timer = duration


func show_title(visible_flag: bool) -> void:
	_mode = "title"
	_overlay_title.text = "GALAGA 3D: VANGUARD"
	var record_line: String = ""
	if GameState.high_score > 0:
		record_line = "HIGH SCORE: %d   |   BEST STAGE: %d\n\n" % [GameState.high_score, GameState.best_stage]
	var controls_line: String = (
		"Left Thumb Move  |  FIRE / AUTO  |  LOCK Missiles  |  ROLL  |  EMP\n\nTap Anywhere to Launch"
		if TouchControls.is_mobile_environment()
		else "WASD/Stick Move  |  Z/Space/A Fire  |  X/RB Lock-On  |  Shift/B Roll  |  V/Y EMP  |  M Mute\n\nPress FIRE, ENTER, or Click to Launch"
	)
	_overlay_hint.text = "%s%s" % [record_line, controls_line]
	_overlay_box.visible = visible_flag
	_sync_touch_visibility()


func show_pause(visible_flag: bool) -> void:
	_mode = "pause"
	_overlay_title.text = "PAUSED"
	_overlay_hint.text = "Tap or Press ESC / FIRE to Resume   |   M Mute"
	_overlay_box.visible = visible_flag
	_sync_touch_visibility()


func show_game_over(final_score: int, hi_score: int) -> void:
	_mode = "game_over"
	_overlay_title.text = "GAME OVER"
	var acc: float = GameState.get_accuracy_pct()
	_overlay_hint.text = (
		"FINAL SCORE: %d   |   HIGH SCORE: %d   |   STAGE: %d\n"
		+ "SHOTS %d   |   HITS %d   |   HIT-MISS RATIO %.1f%%   |   DESTROYED %d\n\n"
		+ "Tap or Press FIRE / ENTER to Retry"
	) % [final_score, hi_score, GameState.stage, GameState.shots_fired, GameState.shots_hit, acc, GameState.enemies_destroyed]
	_overlay_box.visible = true
	_sync_touch_visibility()


func set_boss_bar(visible_flag: bool, ratio: float = 1.0, phase: int = 1) -> void:
	_boss_bar.visible = visible_flag
	_boss_bar.value = clampf(ratio * 100.0, 0.0, 100.0)
	_boss_bar.modulate = Color(1.0, 0.25, 0.25) if phase == 2 else Color(0.25, 0.85, 1.0)


func update_lockon_brackets(camera: Camera3D, targets: Array[Node3D]) -> void:
	for c: Node in _bracket_layer.get_children():
		c.queue_free()
	if not is_instance_valid(camera):
		return
	for target: Node3D in targets:
		if not is_instance_valid(target) or camera.is_position_behind(target.global_position):
			continue
		var screen_pos: Vector2 = camera.unproject_position(target.global_position)
		var lbl := _make_label("[ + ]", 20, Color(1.0, 0.55, 0.1))
		lbl.position = screen_pos - Vector2(22, 14)
		_bracket_layer.add_child(lbl)
