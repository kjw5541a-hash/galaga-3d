class_name QueenBoss
extends Node3D

signal boss_defeated(score_award: int)
signal boss_hp_changed(ratio: float, phase: int)
signal boss_part_destroyed(world_pos: Vector3)

const PROJECTILE_SCENE: PackedScene = preload("res://scenes/player/projectile.tscn")
const ENEMY_SCENE: PackedScene = preload("res://scenes/enemies/enemy_unit.tscn")
const SWEEP_TELEGRAPH_DUR := 0.45
const SWEEP_ACTIVE_DUR := 1.10
const SWEEP_HIT_RADIUS := 1.85

class BossPartArea extends Area3D:
	var boss_owner: QueenBoss
	var part_name: String = "core"

	func take_damage(amount: int, _from_missile: bool = false) -> void:
		if not is_queued_for_deletion() and is_instance_valid(boss_owner):
			boss_owner.apply_part_damage(part_name, amount)

	func is_high_priority_lock() -> bool:
		return not is_queued_for_deletion()

var phase: int = 1
var core_hp: int = 60
var left_hp: int = 28
var right_hp: int = 28

var _max_total_hp: int = 116
var _stage_num: int = 5
var _player: PlayerFighter = null
var _sway_t: float = 0.0
var _entering: bool = true
var _cannon_timer: float = 2.5
var _cannon_alt_sweep: bool = true
var _hangar_timer: float = 5.0
var _spiral_timer: float = 1.6
var _spiral_angle: float = 0.0
var _defeated: bool = false
var _core_armor_carry: bool = false
var _beam_mesh: MeshInstance3D = null
var _beam_mat: StandardMaterial3D = null
var _beam_elapsed: float = -1.0
var _sweep_start_x: float = -6.0
var _sweep_end_x: float = 6.0
var _sweep_y: float = 0.0
var _hit_kicks: Dictionary = {}

var _core_area: BossPartArea
var _left_area: BossPartArea
var _right_area: BossPartArea


func _ready() -> void:
	GameState.emp_triggered.connect(_on_emp_triggered)


func setup_boss(stage_num: int, player: PlayerFighter) -> void:
	_stage_num = stage_num
	_player = player
	phase = 1
	left_hp = 18 + stage_num * 2
	right_hp = 18 + stage_num * 2
	core_hp = 40 + stage_num * 4
	_max_total_hp = left_hp + right_hp + core_hp
	_defeated = false
	_core_armor_carry = false
	_cannon_alt_sweep = true
	_clear_cannon_beam()
	_hit_kicks.clear()
	_entering = true
	global_position = Vector3(0.0, 2.0, -150.0)
	_build_parts()
	boss_hp_changed.emit(1.0, phase)


func _build_parts() -> void:
	for c: Node in get_children():
		c.queue_free()
	_core_area = _create_part("core", Vector3.ZERO, Vector3(7.5, 4.0, 5.5))
	_left_area = _create_part("cannon", Vector3(-6.2, -0.4, 1.2), Vector3(3.4, 2.4, 4.8))
	_right_area = _create_part("hangar", Vector3(6.2, -0.4, 1.2), Vector3(3.8, 2.6, 4.8))


func _create_part(p_name: String, offset: Vector3, box_size: Vector3) -> BossPartArea:
	var area := BossPartArea.new()
	area.boss_owner = self
	area.part_name = p_name
	area.position = offset
	area.collision_layer = 1 << 2 # Layer 3: enemy
	area.collision_mask = 1 << 1  # Layer 2: player_projectile
	area.add_to_group("lockable_enemies")
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box_size
	col.shape = shape
	area.add_child(col)
	area.add_child(MeshFactory.build_boss_module(p_name))
	add_child(area)
	return area


func _physics_process(delta: float) -> void:
	if _defeated or GameState.is_game_over:
		return
	if _entering:
		global_position.z = lerpf(global_position.z, -55.0, clampf(2.2 * delta, 0.0, 1.0))
		if absf(global_position.z - (-55.0)) < 0.8:
			global_position.z = -55.0
			_entering = false
		return

	_sway_t += delta * (1.25 if phase == 2 else 0.75)
	var lunge_z: float = sin(_sway_t * 1.4) * 8.0 if phase == 2 else 0.0
	global_position = Vector3(sin(_sway_t) * 6.0, sin(_sway_t * 2.0) * 2.0 + 1.5, -55.0 + lunge_z)
	rotation = Vector3(-0.16 + sin(_sway_t * 2.0) * 0.08, cos(_sway_t) * 0.18, -cos(_sway_t) * 0.08)

	if left_hp > 0:
		if is_cannon_beam_active():
			_step_sweeping_laser(delta)
		else:
			_cannon_timer -= delta
			if _cannon_timer <= 0.0:
				_cannon_timer = 3.0
				if _cannon_alt_sweep:
					start_sweeping_laser()
				else:
					_fire_tractor_hazard_pulse()
				_cannon_alt_sweep = not _cannon_alt_sweep

	_step_hit_kicks(delta)

	if right_hp > 0:
		_hangar_timer -= delta
		if _hangar_timer <= 0.0:
			_hangar_timer = 8.0
			_launch_drone_squad()

	if phase == 2:
		_spiral_timer -= delta
		if _spiral_timer <= 0.0:
			_spiral_timer = 0.85
			_fire_phase2_spiral()


func is_cannon_beam_active() -> bool:
	return _beam_elapsed >= 0.0 and is_instance_valid(_beam_mesh)


func start_sweeping_laser() -> void:
	if left_hp <= 0 or not is_instance_valid(_left_area):
		return
	_clear_cannon_beam()
	var px: float = _player.global_position.x if is_instance_valid(_player) else 0.0
	var py: float = _player.global_position.y if is_instance_valid(_player) else 0.0
	_sweep_start_x = clampf(px - 6.5, -13.0, 5.0)
	_sweep_end_x = clampf(px + 6.5, -5.0, 13.0)
	_sweep_y = clampf(py, -6.5, 6.5)
	_beam_elapsed = 0.0
	_beam_mesh = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.22
	cyl.bottom_radius = 0.52
	cyl.height = 1.0
	_beam_mesh.mesh = cyl
	_beam_mat = MeshFactory.make_neon_mat(Color(0.3, 0.95, 1.0), Color(0.2, 0.9, 1.0), 1.4, 0.42)
	_beam_mesh.material_override = _beam_mat
	_beam_mesh.top_level = true
	add_child(_beam_mesh)
	SfxManager.play("tractor")
	_position_beam_toward(Vector3(_sweep_start_x, _sweep_y, 0.0), 0.35)


func _step_sweeping_laser(delta: float) -> void:
	if left_hp <= 0 or not is_instance_valid(_left_area) or not is_instance_valid(_beam_mesh):
		_clear_cannon_beam()
		return
	_beam_elapsed += delta
	var total_dur: float = SWEEP_TELEGRAPH_DUR + SWEEP_ACTIVE_DUR
	if _beam_elapsed >= total_dur:
		_clear_cannon_beam()
		return
	if _beam_elapsed < SWEEP_TELEGRAPH_DUR:
		var pulse: float = 0.3 + 0.25 * sin(_beam_elapsed * 28.0)
		_beam_mat.albedo_color.a = pulse
		_beam_mat.emission_energy_multiplier = 1.3
		_position_beam_toward(Vector3(_sweep_start_x, _sweep_y, 0.0), 0.35)
		return
	var u: float = clampf((_beam_elapsed - SWEEP_TELEGRAPH_DUR) / SWEEP_ACTIVE_DUR, 0.0, 1.0)
	var target_x: float = lerpf(_sweep_start_x, _sweep_end_x, u)
	var target_pt := Vector3(target_x, _sweep_y, 0.0)
	_beam_mat.albedo_color.a = 0.85
	_beam_mat.emission_energy_multiplier = 2.4
	_position_beam_toward(target_pt, 1.15)
	if is_instance_valid(_player) and not _player.is_captured:
		var hit_dist: float = Vector2(_player.global_position.x - target_x, _player.global_position.y - _sweep_y).length()
		if hit_dist <= SWEEP_HIT_RADIUS:
			_player.apply_damage(target_x)


func _position_beam_toward(target_pt: Vector3, width_scale: float) -> void:
	if not is_instance_valid(_beam_mesh) or not is_instance_valid(_left_area):
		return
	var origin: Vector3 = _left_area.global_position + Vector3(0.0, -0.15, 4.35)
	var span: Vector3 = target_pt - origin
	var dist: float = maxf(1.0, span.length())
	var dir: Vector3 = span / dist
	var up_ref: Vector3 = Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	var x_axis: Vector3 = up_ref.cross(dir).normalized()
	var z_axis: Vector3 = x_axis.cross(dir).normalized()
	_beam_mesh.global_transform = Transform3D(
		Basis(x_axis * width_scale, dir * dist, z_axis * width_scale),
		origin + span * 0.5
	)


func _clear_cannon_beam() -> void:
	_beam_elapsed = -1.0
	if is_instance_valid(_beam_mesh):
		_beam_mesh.queue_free()
	_beam_mesh = null
	_beam_mat = null


func _fire_tractor_hazard_pulse() -> void:
	if not is_instance_valid(_player) or not is_instance_valid(_left_area):
		return
	var origin: Vector3 = _left_area.global_position + Vector3(0.0, 0.0, 3.8)
	var base_dir: Vector3 = (_player.global_position - origin).normalized()
	for i: int in range(5):
		var ang: float = float(i) * (TAU / 5.0)
		var ring_off := Vector3(cos(ang) * 0.14, sin(ang) * 0.14, 0.0)
		var orb: Projectile = PROJECTILE_SCENE.instantiate()
		get_parent().add_child(orb)
		orb.setup(Projectile.Kind.ENEMY_ORB, origin, (base_dir + ring_off).normalized(), 38.0, 1)


func _step_hit_kicks(delta: float) -> void:
	for key: String in _hit_kicks.keys():
		var rem: float = maxf(0.0, float(_hit_kicks[key]) - delta)
		_hit_kicks[key] = rem
		var area: BossPartArea = _core_area if key == "core" else (_left_area if key == "cannon" else _right_area)
		if is_instance_valid(area):
			var s: float = 1.0 + (rem / 0.10) * 0.12
			area.scale = Vector3(s, s, s)


func _launch_drone_squad() -> void:
	if not is_instance_valid(_right_area) or not is_instance_valid(_player):
		return
	for i: int in range(3):
		var u: EnemyUnit = ENEMY_SCENE.instantiate()
		u.top_level = true
		u.one_shot_dive = true
		add_child(u)
		var spawn_pos: Vector3 = _right_area.global_position + Vector3(float(i - 1) * 1.5, 0.0, 3.0)
		u.setup_unit(EnemyUnit.Archetype.ZAKO, 3, i, 0, spawn_pos, _player)
		u.global_position = spawn_pos
		u.state = EnemyUnit.State.FORMATION
		u.start_dive(0)
		u.destroyed.connect(_on_drone_destroyed)


func _on_drone_destroyed(_unit: EnemyUnit, pts: int, _drop: bool, _pos: Vector3) -> void:
	GameState.add_score(pts)


func _fire_phase2_spiral() -> void:
	if not is_instance_valid(_player):
		return
	var origin: Vector3 = global_position + Vector3(0.0, 0.0, 3.2)
	var base_dir: Vector3 = (_player.global_position - origin).normalized()
	_spiral_angle += 0.45
	for i: int in range(6):
		var ang: float = _spiral_angle + float(i) * (TAU / 6.0)
		var offset := Vector3(cos(ang) * 0.24, sin(ang) * 0.24, 0.0)
		var orb: Projectile = PROJECTILE_SCENE.instantiate()
		get_parent().add_child(orb)
		orb.setup(Projectile.Kind.ENEMY_ORB, origin, (base_dir + offset).normalized(), 44.0, 1)


func _on_emp_triggered() -> void:
	for proj: Node in get_tree().get_nodes_in_group("enemy_projectiles"):
		if is_instance_valid(proj):
			proj.queue_free()
	for c: Node in get_children():
		if c is EnemyUnit:
			(c as EnemyUnit).apply_stun(2.0)


func _tint_core_crimson() -> void:
	if not is_instance_valid(_core_area):
		return
	var dark_red := MeshFactory.make_hull_mat(Color(0.55, 0.12, 0.16), 0.65, 0.30, 0.85, 0.16)
	var crimson_glow := MeshFactory.make_neon_mat(Color(1.0, 0.18, 0.24), Color(1.0, 0.12, 0.18), 2.3)
	for child: Node in _core_area.get_children():
		for sub: Node in child.get_children():
			if sub is MeshInstance3D:
				(sub as MeshInstance3D).material_override = crimson_glow if sub.name == "CoreCrystal" else dark_red


func _destroy_part_area(area: BossPartArea) -> void:
	if not is_instance_valid(area):
		return
	area.remove_from_group("lockable_enemies")
	area.set_deferred("monitoring", false)
	area.set_deferred("monitorable", false)
	area.queue_free()


func apply_part_damage(part_name: String, raw_damage: int) -> int:
	if _defeated or raw_damage <= 0:
		return 0
	var actual: int = raw_damage
	_hit_kicks[part_name] = 0.10
	match part_name:
		"cannon":
			if left_hp <= 0:
				return 0
			left_hp = maxi(0, left_hp - raw_damage)
			if left_hp == 0:
				var pos: Vector3 = _left_area.global_position if is_instance_valid(_left_area) else global_position
				_clear_cannon_beam()
				_destroy_part_area(_left_area)
				if is_instance_valid(get_parent()):
					VfxBurst.spawn(get_parent(), pos, Color(0.2, 0.95, 0.95), 2.5, 10, 0.55)
				SfxManager.play("explode")
				boss_part_destroyed.emit(pos)
		"hangar":
			if right_hp <= 0:
				return 0
			right_hp = maxi(0, right_hp - raw_damage)
			if right_hp == 0:
				var pos: Vector3 = _right_area.global_position if is_instance_valid(_right_area) else global_position
				_destroy_part_area(_right_area)
				if is_instance_valid(get_parent()):
					VfxBurst.spawn(get_parent(), pos, Color(1.0, 0.35, 0.72), 2.5, 10, 0.55)
				SfxManager.play("explode")
				boss_part_destroyed.emit(pos)
		"core":
			if phase == 1:
				if raw_damage == 1:
					_core_armor_carry = not _core_armor_carry
					actual = 0 if _core_armor_carry else 1
				else:
					actual = int(floor(float(raw_damage) * 0.5))
			core_hp = maxi(0, core_hp - actual)
	if phase == 1 and left_hp <= 0 and right_hp <= 0:
		phase = 2
		_tint_core_crimson()
		SfxManager.play("emp")
	SfxManager.play("hit")
	boss_hp_changed.emit(get_total_hp_ratio(), phase)
	if core_hp <= 0:
		_defeated = true
		_clear_cannon_beam()
		var core_pos: Vector3 = global_position
		_destroy_part_area(_core_area)
		if is_instance_valid(get_parent()):
			VfxBurst.spawn(get_parent(), core_pos, Color(1.0, 0.28, 0.22), 3.4, 14, 0.7)
		@warning_ignore("integer_division")
		var award: int = 5000 * maxi(1, _stage_num / 5)
		GameState.add_score(award)
		GameState.record_enemy_destroyed(1)
		GameState.grant_powerup(GameState.PowerupType.SHIELD)
		SfxManager.play("boss_explode")
		boss_defeated.emit(award)
		queue_free()
	return actual


func get_total_hp_ratio() -> float:
	return float(maxi(0, core_hp + left_hp + right_hp)) / float(maxi(1, _max_total_hp))
