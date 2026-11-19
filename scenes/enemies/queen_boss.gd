class_name QueenBoss
extends Node3D

signal boss_defeated(score_award: int)
signal boss_hp_changed(ratio: float, phase: int)

const PROJECTILE_SCENE: PackedScene = preload("res://scenes/player/projectile.tscn")
const ENEMY_SCENE: PackedScene = preload("res://scenes/enemies/enemy_unit.tscn")

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
var _hangar_timer: float = 5.0
var _spiral_timer: float = 1.6
var _spiral_angle: float = 0.0
var _defeated: bool = false
var _core_armor_carry: bool = false

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
		_cannon_timer -= delta
		if _cannon_timer <= 0.0:
			_cannon_timer = 2.6
			_fire_cannon_barrage()

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


func _fire_cannon_barrage() -> void:
	if not is_instance_valid(_player) or not is_instance_valid(_left_area):
		return
	var origin: Vector3 = _left_area.global_position + Vector3(0.0, 0.0, 3.0)
	for spread: float in [-0.14, 0.0, 0.14]:
		var dir: Vector3 = (_player.global_position - origin).normalized()
		dir = dir.rotated(Vector3.UP, spread)
		var orb: Projectile = PROJECTILE_SCENE.instantiate()
		get_parent().add_child(orb)
		orb.setup(Projectile.Kind.ENEMY_ORB, origin, dir, 40.0, 1)


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
	match part_name:
		"cannon":
			if left_hp <= 0:
				return 0
			left_hp = maxi(0, left_hp - raw_damage)
			if left_hp == 0:
				_destroy_part_area(_left_area)
				SfxManager.play("explode")
		"hangar":
			if right_hp <= 0:
				return 0
			right_hp = maxi(0, right_hp - raw_damage)
			if right_hp == 0:
				_destroy_part_area(_right_area)
				SfxManager.play("explode")
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
		_destroy_part_area(_core_area)
		@warning_ignore("integer_division")
		var award: int = 5000 * maxi(1, _stage_num / 5)
		GameState.add_score(award)
		GameState.grant_powerup(GameState.PowerupType.SHIELD)
		SfxManager.play("boss_explode")
		boss_defeated.emit(award)
		queue_free()
	return actual


func get_total_hp_ratio() -> float:
	return float(maxi(0, core_hp + left_hp + right_hp)) / float(maxi(1, _max_total_hp))
