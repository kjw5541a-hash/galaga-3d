extends Node

enum StageType { STANDARD, CHALLENGE, BOSS }
enum FighterMode { SINGLE, DUAL }
enum PowerupType { SHIELD, RAPID, EMP }

signal score_changed(score: int, high_score: int)
signal lives_changed(lives: int)
signal stage_changed(stage: int, stage_type: int)
signal fighter_mode_changed(mode: int)
signal shield_changed(count: int)
signal rapid_changed(time_left: float)
signal emp_changed(charges: int)
signal energy_changed(energy: float)
signal emp_triggered
signal game_over_triggered

const FIRST_EXTRA_LIFE := 20000
const NEXT_EXTRA_LIFE_STEP := 70000
const MAX_ENERGY := 100.0
const ENERGY_REGEN_PER_SEC := 12.0
const MAX_EMP_CHARGES := 2
const RAPID_DURATION := 15.0
const DEFAULT_SAVE_PATH := "user://galaga3d_save.cfg"

var save_path: String = DEFAULT_SAVE_PATH
var score: int = 0
var high_score: int = 0
var best_stage: int = 1
var lives: int = 3
var stage: int = 1
var shots_fired: int = 0
var shots_hit: int = 0
var enemies_destroyed: int = 0
var fighter_mode: FighterMode = FighterMode.SINGLE
var shield_count: int = 0
var rapid_timer: float = 0.0
var emp_charges: int = 0
var lockon_energy: float = MAX_ENERGY
var is_game_over: bool = false
var touch_move: Vector2 = Vector2.ZERO
var touch_auto_fire: bool = false
var _next_extra_life: int = FIRST_EXTRA_LIFE


func _ready() -> void:
	if DisplayServer.get_name() != "headless":
		load_profile()
		SfxManager.mute_changed.connect(_on_mute_changed)


func _on_mute_changed(_muted: bool) -> void:
	if DisplayServer.get_name() != "headless":
		save_profile()


func reset_run() -> void:
	score = 0
	lives = 3
	stage = 1
	shots_fired = 0
	shots_hit = 0
	enemies_destroyed = 0
	fighter_mode = FighterMode.SINGLE
	shield_count = 0
	rapid_timer = 0.0
	emp_charges = 1
	lockon_energy = MAX_ENERGY
	is_game_over = false
	touch_move = Vector2.ZERO
	_next_extra_life = FIRST_EXTRA_LIFE
	score_changed.emit(score, high_score)
	lives_changed.emit(lives)
	stage_changed.emit(stage, get_stage_type(stage))
	fighter_mode_changed.emit(fighter_mode)
	shield_changed.emit(shield_count)
	rapid_changed.emit(rapid_timer)
	emp_changed.emit(emp_charges)
	energy_changed.emit(lockon_energy)


func record_shot_fired(count: int = 1) -> void:
	if count > 0:
		shots_fired += count


func record_shot_hit(count: int = 1) -> void:
	if count > 0:
		shots_hit += count


func record_enemy_destroyed(count: int = 1) -> void:
	if count > 0:
		enemies_destroyed += count


func get_accuracy_pct() -> float:
	if shots_fired <= 0:
		return 0.0
	return clampf(float(shots_hit) * 100.0 / float(shots_fired), 0.0, 100.0)


func save_profile() -> Error:
	var cfg := ConfigFile.new()
	cfg.set_value("stats", "high_score", high_score)
	cfg.set_value("stats", "best_stage", best_stage)
	cfg.set_value("audio", "muted", SfxManager.is_muted)
	return cfg.save(save_path)


func load_profile() -> Error:
	var cfg := ConfigFile.new()
	var err: Error = cfg.load(save_path)
	if err != OK:
		return err
	high_score = maxi(0, int(cfg.get_value("stats", "high_score", 0)))
	best_stage = maxi(1, int(cfg.get_value("stats", "best_stage", 1)))
	var saved_mute: bool = bool(cfg.get_value("audio", "muted", false))
	if SfxManager.is_muted != saved_mute:
		SfxManager.toggle_mute()
	score_changed.emit(score, high_score)
	return OK


func get_stage_type(stage_num: int) -> StageType:
	if stage_num % 5 == 0:
		return StageType.BOSS
	if stage_num % 3 == 0:
		return StageType.CHALLENGE
	return StageType.STANDARD


func add_score(points: int) -> void:
	if points <= 0:
		return
	score += points
	var new_hi: bool = false
	if score > high_score:
		high_score = score
		new_hi = true
	while score >= _next_extra_life:
		lives += 1
		_next_extra_life += NEXT_EXTRA_LIFE_STEP
		lives_changed.emit(lives)
	score_changed.emit(score, high_score)
	if new_hi and DisplayServer.get_name() != "headless":
		save_profile()


func advance_stage() -> StageType:
	stage += 1
	if stage > best_stage:
		best_stage = stage
		if DisplayServer.get_name() != "headless":
			save_profile()
	var st: StageType = get_stage_type(stage)
	stage_changed.emit(stage, st)
	return st


func set_fighter_mode(mode: FighterMode) -> void:
	fighter_mode = mode
	var cap: int = 2 if fighter_mode == FighterMode.DUAL else 1
	if shield_count > cap:
		shield_count = cap
		shield_changed.emit(shield_count)
	fighter_mode_changed.emit(fighter_mode)


func grant_powerup(kind: PowerupType) -> void:
	match kind:
		PowerupType.SHIELD:
			var cap: int = 2 if fighter_mode == FighterMode.DUAL else 1
			shield_count = mini(shield_count + 1, cap)
			shield_changed.emit(shield_count)
		PowerupType.RAPID:
			rapid_timer = RAPID_DURATION
			rapid_changed.emit(rapid_timer)
		PowerupType.EMP:
			emp_charges = mini(emp_charges + 1, MAX_EMP_CHARGES)
			emp_changed.emit(emp_charges)


func consume_shield() -> bool:
	if shield_count <= 0:
		return false
	shield_count -= 1
	shield_changed.emit(shield_count)
	return true


func spend_emp() -> bool:
	if emp_charges <= 0:
		return false
	emp_charges -= 1
	emp_changed.emit(emp_charges)
	emp_triggered.emit()
	return true


func spend_lockon_energy(amount: float) -> bool:
	if lockon_energy + 0.001 < amount:
		return false
	lockon_energy = maxf(0.0, lockon_energy - amount)
	energy_changed.emit(lockon_energy)
	return true


func add_lockon_energy(amount: float) -> void:
	if amount <= 0.0:
		return
	var next_val: float = minf(MAX_ENERGY, lockon_energy + amount)
	if not is_equal_approx(next_val, lockon_energy):
		lockon_energy = next_val
		energy_changed.emit(lockon_energy)


func lose_life() -> bool:
	lives = maxi(0, lives - 1)
	lives_changed.emit(lives)
	if lives <= 0:
		is_game_over = true
		if DisplayServer.get_name() != "headless":
			save_profile()
		game_over_triggered.emit()
		return false
	return true


func tick_timers(delta: float) -> void:
	if rapid_timer > 0.0:
		rapid_timer = maxf(0.0, rapid_timer - delta)
		rapid_changed.emit(rapid_timer)
	add_lockon_energy(ENERGY_REGEN_PER_SEC * delta)


func get_wave_speed_mult(stage_num: int) -> float:
	return minf(1.8, 1.0 + 0.06 * float(maxi(0, stage_num - 1)))


func get_max_divers(stage_num: int) -> int:
	@warning_ignore("integer_division")
	return mini(5, 2 + (maxi(1, stage_num) - 1) / 2)
