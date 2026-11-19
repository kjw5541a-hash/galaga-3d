class_name EnemyUnit
extends Area3D

enum Archetype { ZAKO, GOEI, BOSS_GALAGA, CAPTURED_FIGHTER }
enum State {
	ENTERING,
	FORMATION,
	DIVING,
	TRACTOR_BEAM,
	RETURNING,
	CAPTURED_ATTACHED,
	CAPTURED_HOSTILE,
	RESCUED_DOCKING,
	CHALLENGE,
}

signal destroyed(unit: EnemyUnit, score_award: int, drop_capsule: bool, world_pos: Vector3)
signal escaped(unit: EnemyUnit)
signal capture_succeeded(boss: EnemyUnit, captured_unit: EnemyUnit)
signal rescue_docked(captured_unit: EnemyUnit)
signal tractor_finished(boss: EnemyUnit)

const PROJECTILE_SCENE: PackedScene = preload("res://scenes/player/projectile.tscn")
const TRACTOR_BEAM_SCENE: PackedScene = preload("res://scenes/enemies/tractor_beam.tscn")

var archetype: Archetype = Archetype.ZAKO
var state: State = State.ENTERING
var hp: int = 1
var row: int = 0
var col: int = 0
var squad_index: int = 0
var challenge_wave: int = 0
var slot_world: Vector3 = Vector3(0.0, 0.0, -48.0)
var speed_mult: float = 1.0
var escort_count_on_dive: int = 0
var captured_child: EnemyUnit = null
var one_shot_dive: bool = false

var _player: PlayerFighter = null
var _visual: Node3D = null
var _beam: TractorBeam = null
var _t: float = 0.0
var _dive_start: Vector3 = Vector3.ZERO
var _dive_target: Vector3 = Vector3.ZERO
var _dive_side: float = 1.0
var _tractor_hold: float = 0.0
var _tractor_aim_y: float = 0.0
var _stun_timer: float = 0.0
var _hit_flash_timer: float = 0.0
var _fired_in_dive: bool = false
var _dead: bool = false


func _ready() -> void:
	collision_layer = 1 << 2 # Layer 3: enemy
	collision_mask = (1 << 0) | (1 << 1)
	add_to_group("lockable_enemies")
	body_entered.connect(_on_body_entered)


func setup_unit(
	p_arch: Archetype,
	p_row: int,
	p_col: int,
	p_squad: int,
	p_slot_world: Vector3,
	p_player: PlayerFighter,
	p_is_challenge: bool = false,
	p_challenge_wave: int = 0
) -> void:
	archetype = p_arch
	row = p_row
	col = p_col
	squad_index = p_squad
	slot_world = p_slot_world
	_player = p_player
	challenge_wave = p_challenge_wave
	hp = 2 if archetype == Archetype.BOSS_GALAGA else 1
	speed_mult = GameState.get_wave_speed_mult(GameState.stage)
	_t = 0.0
	if p_is_challenge:
		state = State.CHALLENGE
		global_position = WavePatterns.sample_challenge_path(challenge_wave, 0.0)
	elif archetype == Archetype.CAPTURED_FIGHTER:
		state = State.CAPTURED_ATTACHED
		global_position = p_slot_world
	else:
		state = State.ENTERING
		global_position = WavePatterns.sample_entry_path(squad_index, 0.0)
	_rebuild_visual(false)


func _rebuild_visual(damaged_boss: bool) -> void:
	if is_instance_valid(_visual):
		_visual.queue_free()
	_visual = MeshFactory.build_enemy_mesh(archetype, damaged_boss)
	add_child(_visual)


func attach_captured_fighter(captured: EnemyUnit) -> void:
	captured_child = captured
	captured.state = State.CAPTURED_ATTACHED


func start_dive(p_escort_count: int = 0) -> void:
	if state != State.FORMATION:
		return
	escort_count_on_dive = p_escort_count
	state = State.DIVING
	_t = 0.0
	_fired_in_dive = false
	_dive_start = global_position
	_dive_target = _player.global_position if is_instance_valid(_player) else Vector3.ZERO
	_dive_side = -1.0 if global_position.x >= 0.0 else 1.0


func start_tractor_dive() -> void:
	if archetype != Archetype.BOSS_GALAGA or state != State.FORMATION:
		return
	state = State.TRACTOR_BEAM
	_t = 0.0
	_tractor_hold = 0.0
	_dive_start = global_position
	var px: float = _player.global_position.x if is_instance_valid(_player) else 0.0
	var py: float = _player.global_position.y if is_instance_valid(_player) else 0.0
	_tractor_aim_y = py
	_dive_target = Vector3(clampf(px, -10.0, 10.0), clampf(py + 3.0, -4.0, 6.0), -14.0)


func apply_stun(duration: float) -> void:
	if state == State.DIVING or state == State.TRACTOR_BEAM or state == State.CAPTURED_HOSTILE:
		_stun_timer = maxf(_stun_timer, duration)
		_despawn_beam()


func is_high_priority_lock() -> bool:
	return state == State.DIVING or state == State.TRACTOR_BEAM or archetype == Archetype.BOSS_GALAGA


func is_dead() -> bool:
	return _dead


func _mark_dead_and_unlink() -> void:
	_dead = true
	remove_from_group("lockable_enemies")
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)


func _physics_process(delta: float) -> void:
	if _dead or GameState.is_game_over:
		return
	if _hit_flash_timer > 0.0:
		_hit_flash_timer = maxf(0.0, _hit_flash_timer - delta)
		if is_instance_valid(_visual):
			var s: float = 1.0 + (_hit_flash_timer / 0.12) * 0.28
			_visual.scale = Vector3(s, s, s)
	if _stun_timer > 0.0:
		_stun_timer = maxf(0.0, _stun_timer - delta)
		rotation.y += delta * 12.0
		return

	var prev_pos: Vector3 = global_position
	match state:
		State.ENTERING:
			_t += delta * 0.48 * speed_mult
			if _t >= 1.0:
				state = State.FORMATION
				global_position = slot_world
				rotation = Vector3(-0.22, 0.0, 0.0)
			else:
				var p: Vector3 = WavePatterns.sample_entry_path(squad_index, _t)
				var blend: float = smoothstep(0.75, 1.0, _t)
				global_position = p.lerp(slot_world, blend)
				var vel: Vector3 = (global_position - prev_pos) / maxf(delta, 0.001)
				rotation.z = lerpf(rotation.z, clampf(-vel.x * 0.025, -0.7, 0.7), clampf(8.0 * delta, 0.0, 1.0))
				rotation.x = lerpf(rotation.x, clampf(vel.y * 0.018, -0.45, 0.45), clampf(8.0 * delta, 0.0, 1.0))
		State.FORMATION:
			global_position = global_position.lerp(slot_world, clampf(8.0 * delta, 0.0, 1.0))
			var target_rot := Vector3(-0.24, clampf(-global_position.x * 0.015, -0.22, 0.22), 0.0)
			rotation = rotation.lerp(target_rot, clampf(6.0 * delta, 0.0, 1.0))
		State.DIVING:
			_t += delta * 0.36 * speed_mult
			var base_pos: Vector3 = _dive_start.lerp(Vector3(_dive_target.x, _dive_target.y, 12.0), _t)
			global_position = base_pos + WavePatterns.sample_dive_offset(archetype, _t, _dive_side)
			var dive_vel: Vector3 = (global_position - prev_pos) / maxf(delta, 0.001)
			rotation.z = lerpf(rotation.z, clampf(-dive_vel.x * 0.032, -0.85, 0.85), clampf(10.0 * delta, 0.0, 1.0))
			rotation.x = lerpf(rotation.x, clampf(dive_vel.y * 0.02 - 0.15, -0.5, 0.4), clampf(10.0 * delta, 0.0, 1.0))
			if not _fired_in_dive and _t > 0.35 and _t < 0.72 and archetype != Archetype.CAPTURED_FIGHTER:
				_fired_in_dive = true
				_fire_enemy_orb()
			if _t >= 1.0:
				if one_shot_dive:
					_mark_dead_and_unlink()
					escaped.emit(self)
					queue_free()
					return
				state = State.RETURNING
				global_position = Vector3(slot_world.x, slot_world.y + 16.0, -90.0)
		State.TRACTOR_BEAM:
			if _t < 1.0:
				_t = minf(1.0, _t + delta * 0.65)
				global_position = _dive_start.lerp(_dive_target, smoothstep(0.0, 1.0, _t))
			else:
				if not is_instance_valid(_beam):
					_beam = TRACTOR_BEAM_SCENE.instantiate()
					add_child(_beam)
					_beam.rotation.x = atan2(global_position.y - _tractor_aim_y, 14.0)
					SfxManager.play("tractor")
				_tractor_hold += delta
				if is_instance_valid(_player) and _beam.tick_beam(delta, _player):
					_handle_player_captured()
					return
				if _tractor_hold >= 3.0:
					_despawn_beam()
					state = State.RETURNING
					tractor_finished.emit(self)
		State.RETURNING:
			global_position = global_position.lerp(slot_world, clampf(3.2 * delta, 0.0, 1.0))
			if global_position.distance_to(slot_world) < 0.8:
				global_position = slot_world
				state = State.FORMATION
		State.CAPTURED_HOSTILE:
			_t += delta * 0.55 * speed_mult
			global_position = _dive_start.lerp(Vector3(_dive_target.x, _dive_target.y, 14.0), _t)
			if _t >= 1.0:
				_mark_dead_and_unlink()
				escaped.emit(self)
				queue_free()
				return
		State.RESCUED_DOCKING:
			if not is_instance_valid(_player):
				queue_free()
				return
			var dock_pos: Vector3 = _player.global_position + Vector3(1.25, 0.0, 0.0)
			global_position = global_position.lerp(dock_pos, clampf(5.5 * delta, 0.0, 1.0))
			rotation.z += delta * 6.0
			if global_position.distance_to(dock_pos) < 0.7:
				complete_rescue_dock()
				return
		State.CHALLENGE:
			_t += delta * 0.24 * speed_mult
			global_position = WavePatterns.sample_challenge_path(challenge_wave, _t)
			if _t >= 1.0:
				_mark_dead_and_unlink()
				escaped.emit(self)
				queue_free()
				return

	if is_instance_valid(captured_child) and captured_child.state == State.CAPTURED_ATTACHED:
		captured_child.global_position = global_position + Vector3(0.0, 2.2, 0.0)


func _handle_player_captured() -> void:
	_despawn_beam()
	if not is_instance_valid(_player):
		state = State.RETURNING
		tractor_finished.emit(self)
		return
	_player.begin_capture(self)
	var cap: EnemyUnit = load("res://scenes/enemies/enemy_unit.tscn").instantiate()
	get_parent().add_child(cap)
	cap.setup_unit(Archetype.CAPTURED_FIGHTER, row, col, squad_index, global_position + Vector3(0.0, 2.2, 0.0), _player)
	attach_captured_fighter(cap)
	state = State.RETURNING
	capture_succeeded.emit(self, cap)
	tractor_finished.emit(self)


func complete_rescue_dock() -> void:
	if _dead or GameState.is_game_over:
		return
	_mark_dead_and_unlink()
	GameState.set_fighter_mode(GameState.FighterMode.DUAL)
	GameState.add_score(1000)
	SfxManager.play("dock")
	rescue_docked.emit(self)
	queue_free()


func _despawn_beam() -> void:
	if is_instance_valid(_beam):
		_beam.queue_free()
		_beam = null


func _fire_enemy_orb() -> void:
	if not is_instance_valid(_player):
		return
	var orb: Projectile = PROJECTILE_SCENE.instantiate()
	get_parent().add_child(orb)
	var dir: Vector3 = (_player.global_position - global_position).normalized()
	orb.setup(Projectile.Kind.ENEMY_ORB, global_position + Vector3(0.0, 0.0, 1.2), dir, 36.0 * speed_mult, 1)


func take_damage(amount: int, _from_missile: bool = false) -> void:
	if _dead or state == State.RESCUED_DOCKING:
		return
	hp -= amount
	if hp > 0:
		if archetype == Archetype.BOSS_GALAGA:
			_rebuild_visual(true)
		_hit_flash_timer = 0.12
		SfxManager.play("hit")
		return
	_mark_dead_and_unlink()
	_despawn_beam()
	if is_instance_valid(get_parent()):
		var fx_scale: float = 1.45 if archetype == Archetype.BOSS_GALAGA else 1.0
		VfxBurst.spawn(get_parent(), global_position, _explosion_color(), fx_scale, 7)
	var was_diving: bool = (state == State.DIVING or state == State.TRACTOR_BEAM)
	if is_instance_valid(captured_child) and not captured_child.is_dead() and captured_child.state == State.CAPTURED_ATTACHED:
		if was_diving:
			captured_child.state = State.RESCUED_DOCKING
			captured_child.remove_from_group("lockable_enemies")
			if is_instance_valid(captured_child._visual):
				captured_child._visual.queue_free()
			captured_child._visual = MeshFactory.build_player_ship(Color(0.25, 1.0, 0.9))
			captured_child.add_child(captured_child._visual)
		else:
			captured_child.state = State.CAPTURED_HOSTILE
			captured_child._t = 0.0
			captured_child._dive_start = captured_child.global_position
			captured_child._dive_target = _player.global_position if is_instance_valid(_player) else Vector3.ZERO
	captured_child = null

	var pts: int = _compute_score(was_diving)
	var should_drop: bool = false
	if was_diving and archetype == Archetype.BOSS_GALAGA:
		should_drop = true
	elif was_diving and archetype == Archetype.GOEI and randf() < 0.15:
		should_drop = true
	SfxManager.play("explode")
	destroyed.emit(self, pts, should_drop, global_position)
	queue_free()


func _explosion_color() -> Color:
	match archetype:
		Archetype.ZAKO:
			return Color(1.0, 0.72, 0.12)
		Archetype.GOEI:
			return Color(1.0, 0.22, 0.58)
		Archetype.BOSS_GALAGA:
			return Color(0.22, 1.0, 0.45)
		_:
			return Color(1.0, 0.25, 0.28)


func _compute_score(was_diving: bool) -> int:
	if state == State.CHALLENGE:
		return 100
	match archetype:
		Archetype.ZAKO:
			return 100 if was_diving else 50
		Archetype.GOEI:
			return 160 if was_diving else 80
		Archetype.BOSS_GALAGA:
			if not was_diving:
				return 150
			if escort_count_on_dive >= 2:
				return 1600
			if escort_count_on_dive == 1:
				return 800
			return 400
		_: # CAPTURED_FIGHTER shot directly
			return 1000 if state == State.CAPTURED_HOSTILE else 0


func _on_body_entered(body: Node3D) -> void:
	if _dead or state == State.CHALLENGE or state == State.RESCUED_DOCKING:
		return
	if body.has_method("apply_damage"):
		body.call("apply_damage", global_position.x)
		take_damage(99)
