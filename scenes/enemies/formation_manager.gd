class_name FormationManager
extends Node3D

signal wave_cleared
signal challenge_completed(hits: int, total: int, wave_bonuses: int, perfect_bonus: int)

const ENEMY_SCENE: PackedScene = preload("res://scenes/enemies/enemy_unit.tscn")
const CAPSULE_SCENE: PackedScene = preload("res://scenes/pickups/powerup_capsule.tscn")
const TRACTOR_COOLDOWN_SEC := 12.0
const MAX_DROPS_PER_WAVE := 2

var tractor_cooldown: float = 8.0
var is_challenge: bool = false

var _player: PlayerFighter = null
var _stage_num: int = 1
var _sway_time: float = 0.0
var _spawn_queue: Array[Dictionary] = []
var _spawn_timer: float = 0.0
var _dive_timer: float = 2.0
var _units: Array[EnemyUnit] = []
var _active_tractor_boss: EnemyUnit = null
var _captured_unit: EnemyUnit = null
var _drops_this_wave: int = 0
var _drop_cycle: int = 0
var _finished: bool = false

# Challenge tracking
var _challenge_hits: int = 0
var _challenge_resolved: int = 0
var _challenge_wave_hits: Array[int] = [0, 0, 0, 0, 0]


func _ready() -> void:
	GameState.emp_triggered.connect(handle_emp_pulse)


func start_standard_wave(stage_num: int, player: PlayerFighter) -> void:
	_reset_internal(stage_num, player, false)
	# Build 40-enemy queue grouped into 5 squads of 8
	var all_slots: Array[Dictionary] = []
	for r: int in range(WavePatterns.ROW_COUNTS.size()):
		var arch: EnemyUnit.Archetype = EnemyUnit.Archetype.BOSS_GALAGA if r == 0 else (EnemyUnit.Archetype.GOEI if r <= 2 else EnemyUnit.Archetype.ZAKO)
		for c: int in range(WavePatterns.ROW_COUNTS[r]):
			all_slots.append({"arch": arch, "row": r, "col": c})
	for i: int in range(all_slots.size()):
		@warning_ignore("integer_division")
		var sq: int = i / 8
		var entry: Dictionary = all_slots[i]
		entry["squad"] = sq
		entry["delay"] = float(sq) * 1.45 + float(i % 8) * 0.16
		_spawn_queue.append(entry)


func start_challenge_stage(stage_num: int, player: PlayerFighter) -> void:
	_reset_internal(stage_num, player, true)
	for w: int in range(5):
		for k: int in range(8):
			var arch: EnemyUnit.Archetype = EnemyUnit.Archetype.GOEI if w % 2 == 1 else EnemyUnit.Archetype.ZAKO
			_spawn_queue.append({
				"arch": arch,
				"row": 0,
				"col": k,
				"squad": w,
				"challenge_wave": w,
				"delay": float(w) * 3.4 + float(k) * 0.22,
			})


func _reset_internal(stage_num: int, player: PlayerFighter, challenge_flag: bool) -> void:
	_stage_num = stage_num
	_player = player
	is_challenge = challenge_flag
	_sway_time = 0.0
	_spawn_timer = 0.0
	_dive_timer = 2.4
	_spawn_queue.clear()
	_units.clear()
	_active_tractor_boss = null
	_captured_unit = null
	_drops_this_wave = 0
	_finished = false
	_challenge_hits = 0
	_challenge_resolved = 0
	_challenge_wave_hits = [0, 0, 0, 0, 0]
	tractor_cooldown = 8.0


func _physics_process(delta: float) -> void:
	if _finished or GameState.is_game_over:
		return
	_sway_time += delta
	_spawn_timer += delta
	if tractor_cooldown > 0.0:
		tractor_cooldown = maxf(0.0, tractor_cooldown - delta)

	# Process spawn queue
	while not _spawn_queue.is_empty() and float(_spawn_queue[0]["delay"]) <= _spawn_timer:
		var item: Dictionary = _spawn_queue.pop_front()
		_spawn_unit(item)

	# Update formation slot sway
	var sway_offset := Vector3(sin(_sway_time * 1.1) * 2.0, sin(_sway_time * 1.7) * 0.6, 0.0)
	_prune_units()
	for u: EnemyUnit in _units:
		if not is_challenge:
			u.slot_world = WavePatterns.get_formation_slot_local(u.row, u.col) + sway_offset

	if not is_challenge:
		_dive_timer -= delta
		if _dive_timer <= 0.0 and _spawn_queue.is_empty():
			_schedule_next_dive()
			_dive_timer = maxf(1.2, 2.8 - float(_stage_num - 1) * 0.14)
		if _spawn_queue.is_empty() and _units.is_empty() and _captured_unit == null:
			_finished = true
			wave_cleared.emit()


func _spawn_unit(item: Dictionary) -> void:
	var u: EnemyUnit = ENEMY_SCENE.instantiate()
	add_child(u)
	var slot: Vector3 = WavePatterns.get_formation_slot_local(int(item["row"]), int(item["col"]))
	u.setup_unit(
		int(item["arch"]) as EnemyUnit.Archetype,
		int(item["row"]),
		int(item["col"]),
		int(item["squad"]),
		slot,
		_player,
		is_challenge,
		int(item.get("challenge_wave", 0))
	)
	u.destroyed.connect(_on_unit_destroyed)
	u.escaped.connect(_on_unit_escaped)
	u.capture_succeeded.connect(_on_capture_succeeded)
	u.tractor_finished.connect(_on_tractor_finished)
	_units.append(u)


func _prune_units() -> void:
	var alive: Array[EnemyUnit] = []
	for u: EnemyUnit in _units:
		if is_instance_valid(u):
			alive.append(u)
	_units = alive
	if _active_tractor_boss != null and not is_instance_valid(_active_tractor_boss):
		_active_tractor_boss = null
	if _captured_unit != null and (not is_instance_valid(_captured_unit) or _captured_unit.is_queued_for_deletion() or _captured_unit.is_dead()):
		_captured_unit = null


func can_start_tractor_beam() -> bool:
	_prune_units()
	return (
		not is_challenge
		and GameState.fighter_mode == GameState.FighterMode.SINGLE
		and _captured_unit == null
		and _active_tractor_boss == null
		and tractor_cooldown <= 0.0
	)


func try_trigger_tractor_beam(boss: EnemyUnit) -> bool:
	if not can_start_tractor_beam():
		return false
	if not is_instance_valid(boss) or boss.archetype != EnemyUnit.Archetype.BOSS_GALAGA or boss.state != EnemyUnit.State.FORMATION:
		return false
	_active_tractor_boss = boss
	tractor_cooldown = TRACTOR_COOLDOWN_SEC
	boss.start_tractor_dive()
	return true


func _schedule_next_dive() -> void:
	var diving_count: int = 0
	var ready_bosses: Array[EnemyUnit] = []
	var ready_others: Array[EnemyUnit] = []
	for u: EnemyUnit in _units:
		if u.state == EnemyUnit.State.DIVING or u.state == EnemyUnit.State.TRACTOR_BEAM:
			diving_count += 1
		elif u.state == EnemyUnit.State.FORMATION:
			if u.archetype == EnemyUnit.Archetype.BOSS_GALAGA:
				ready_bosses.append(u)
			else:
				ready_others.append(u)
	if diving_count >= GameState.get_max_divers(_stage_num):
		return

	# Prefer tractor beam if eligible
	if can_start_tractor_beam() and not ready_bosses.is_empty():
		var chosen_boss: EnemyUnit = ready_bosses[randi() % ready_bosses.size()]
		if try_trigger_tractor_beam(chosen_boss):
			return

	# Boss + up to 2 Goei escorts, or single diver
	if not ready_bosses.is_empty() and randf() < 0.35:
		var boss: EnemyUnit = ready_bosses[randi() % ready_bosses.size()]
		var escorts: Array[EnemyUnit] = []
		for u: EnemyUnit in ready_others:
			if u.archetype == EnemyUnit.Archetype.GOEI and escorts.size() < 2:
				escorts.append(u)
		boss.start_dive(escorts.size())
		for e: EnemyUnit in escorts:
			e.start_dive(0)
	elif not ready_others.is_empty():
		var diver: EnemyUnit = ready_others[randi() % ready_others.size()]
		diver.start_dive(0)


func _on_unit_destroyed(unit: EnemyUnit, score_award: int, drop_capsule: bool, world_pos: Vector3) -> void:
	GameState.add_score(score_award)
	_units.erase(unit)
	if unit == _active_tractor_boss:
		_active_tractor_boss = null
	if unit == _captured_unit:
		_captured_unit = null
	if is_challenge:
		report_challenge_outcome(unit.challenge_wave, true)
		return
	if drop_capsule and _drops_this_wave < MAX_DROPS_PER_WAVE:
		_drops_this_wave += 1
		var cap: PowerupCapsule = CAPSULE_SCENE.instantiate()
		get_parent().add_child(cap)
		var kind: GameState.PowerupType = (_drop_cycle % 3) as GameState.PowerupType
		_drop_cycle += 1
		cap.setup(kind, world_pos, _player)


func _on_unit_escaped(unit: EnemyUnit) -> void:
	_units.erase(unit)
	if unit == _captured_unit:
		_captured_unit = null
	if is_challenge:
		report_challenge_outcome(unit.challenge_wave, false)


func _on_capture_succeeded(_boss: EnemyUnit, captured_unit: EnemyUnit) -> void:
	_captured_unit = captured_unit
	captured_unit.destroyed.connect(_on_unit_destroyed)
	captured_unit.escaped.connect(_on_unit_escaped)
	captured_unit.rescue_docked.connect(_on_rescue_docked)


func _on_rescue_docked(unit: EnemyUnit) -> void:
	if unit == _captured_unit:
		_captured_unit = null


func _on_tractor_finished(boss: EnemyUnit) -> void:
	if boss == _active_tractor_boss:
		_active_tractor_boss = null


func report_challenge_outcome(wave_idx: int, was_destroyed: bool) -> void:
	if _finished or not is_challenge:
		return
	_challenge_resolved += 1
	if was_destroyed:
		_challenge_hits += 1
		if wave_idx >= 0 and wave_idx < _challenge_wave_hits.size():
			_challenge_wave_hits[wave_idx] += 1
	if _challenge_resolved >= 40:
		_finished = true
		var wave_bonuses: int = 0
		for hits_in_wave: int in _challenge_wave_hits:
			if hits_in_wave >= 8:
				wave_bonuses += 1000
		var perfect_bonus: int = 10000 if _challenge_hits >= 40 else 0
		GameState.add_score(wave_bonuses + perfect_bonus)
		challenge_completed.emit(_challenge_hits, 40, wave_bonuses, perfect_bonus)


func handle_emp_pulse() -> void:
	for proj: Node in get_tree().get_nodes_in_group("enemy_projectiles"):
		if is_instance_valid(proj):
			proj.queue_free()
	_prune_units()
	for u: EnemyUnit in _units:
		u.apply_stun(2.0)
