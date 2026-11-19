class_name PlayerFighter
extends CharacterBody3D

signal damaged(remaining_lives: int)
signal barrel_roll_started
signal captured_by_boss(boss: Node3D)

const PLAY_BOUND_X := 14.0
const PLAY_BOUND_Y := 8.0
const SPEED_X := 22.0
const SPEED_Y := 18.0
const BASE_FIRE_INTERVAL := 0.16
const RAPID_FIRE_INTERVAL := 0.09
const BASE_LASER_SPEED := 120.0
const RAPID_LASER_SPEED := 160.0
const BARREL_ROLL_DUR := 0.45
const BARREL_ROLL_INVULN := 0.32
const BARREL_ROLL_COOLDOWN := 1.5
const DUAL_OFFSET_X := 1.25
const MISSILE_ENERGY_COST := 25.0

const PROJECTILE_SCENE: PackedScene = preload("res://scenes/player/projectile.tscn")

var invuln_timer: float = 0.0
var is_captured: bool = false
var reticle_rig: ReticleRig

var _fire_cd: float = 0.0
var _roll_timer: float = 0.0
var _roll_cd: float = 0.0
var _roll_dir: float = 1.0
var _locking: bool = false
var _ship_visual_root: Node3D
var _left_ship: Node3D
var _right_ship: Node3D
var _shield_bubble: MeshInstance3D
var _collider: CollisionShape3D


func _ready() -> void:
	collision_layer = 1 << 0 # Layer 1: player
	collision_mask = (1 << 2) | (1 << 3) | (1 << 4) | (1 << 5)
	_collider = $CollisionShape3D
	_ship_visual_root = Node3D.new()
	add_child(_ship_visual_root)
	reticle_rig = ReticleRig.new()
	add_child(reticle_rig)
	_build_shield_bubble()
	_rebuild_ships()
	GameState.fighter_mode_changed.connect(_on_fighter_mode_changed)
	GameState.shield_changed.connect(_on_shield_changed)


func _build_shield_bubble() -> void:
	_shield_bubble = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.55
	sm.height = 3.1
	_shield_bubble.mesh = sm
	var shield_mat := MeshFactory.make_neon_mat(Color(0.2, 0.9, 1.0), Color(0.18, 0.85, 1.0), 0.25, 0.08)
	shield_mat.rim_enabled = true
	shield_mat.rim = 0.85
	shield_mat.rim_tint = 0.85
	_shield_bubble.material_override = shield_mat
	_shield_bubble.visible = GameState.shield_count > 0
	_ship_visual_root.add_child(_shield_bubble)


func _rebuild_ships() -> void:
	if is_instance_valid(_left_ship):
		_left_ship.queue_free()
	if is_instance_valid(_right_ship):
		_right_ship.queue_free()
	_left_ship = MeshFactory.build_player_ship()
	_ship_visual_root.add_child(_left_ship)
	var box := _collider.shape as BoxShape3D
	if GameState.fighter_mode == GameState.FighterMode.DUAL:
		_left_ship.position = Vector3(-DUAL_OFFSET_X, 0.0, 0.0)
		_right_ship = MeshFactory.build_player_ship(Color(0.3, 1.0, 0.7))
		_right_ship.position = Vector3(DUAL_OFFSET_X, 0.0, 0.0)
		_ship_visual_root.add_child(_right_ship)
		if box != null:
			box.size = Vector3(3.4, 0.9, 1.8)
		_shield_bubble.scale = Vector3(1.55, 1.0, 1.1)
	else:
		_left_ship.position = Vector3.ZERO
		_right_ship = null
		if box != null:
			box.size = Vector3(1.6, 0.9, 1.8)
		_shield_bubble.scale = Vector3.ONE


func _on_fighter_mode_changed(_mode: int) -> void:
	_rebuild_ships()


func _on_shield_changed(count: int) -> void:
	if is_instance_valid(_shield_bubble):
		_shield_bubble.visible = count > 0


func _physics_process(delta: float) -> void:
	if is_captured or GameState.is_game_over:
		return
	_fire_cd = maxf(0.0, _fire_cd - delta)
	_roll_cd = maxf(0.0, _roll_cd - delta)
	if invuln_timer > 0.0:
		invuln_timer = maxf(0.0, invuln_timer - delta)
		_ship_visual_root.visible = fmod(invuln_timer * 18.0, 1.0) > 0.35 or invuln_timer <= 0.0
	else:
		_ship_visual_root.visible = true

	var move_x: float = Input.get_axis("move_left", "move_right")
	var move_y: float = Input.get_axis("move_down", "move_up")
	var fine_aim := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if fine_aim.length() < 0.2:
		fine_aim = Vector2.ZERO

	if Input.is_action_just_pressed("barrel_roll"):
		trigger_barrel_roll(move_x if absf(move_x) > 0.1 else 1.0)

	var roll_boost_x: float = 0.0
	if _roll_timer > 0.0:
		_roll_timer = maxf(0.0, _roll_timer - delta)
		roll_boost_x = _roll_dir * 12.0
		var prog: float = 1.0 - (_roll_timer / BARREL_ROLL_DUR)
		_ship_visual_root.rotation.z = -_roll_dir * prog * TAU
	else:
		_ship_visual_root.rotation.z = lerpf(_ship_visual_root.rotation.z, -move_x * deg_to_rad(28.0), 10.0 * delta)
	_ship_visual_root.rotation.x = lerpf(_ship_visual_root.rotation.x, move_y * deg_to_rad(16.0), 10.0 * delta)

	global_position.x = clampf(global_position.x + (move_x * SPEED_X + roll_boost_x) * delta, -PLAY_BOUND_X, PLAY_BOUND_X)
	global_position.y = clampf(global_position.y + move_y * SPEED_Y * delta, -PLAY_BOUND_Y, PLAY_BOUND_Y)
	global_position.z = 0.0

	reticle_rig.update_aim(global_position, Vector2(move_x, move_y), fine_aim)

	if Input.is_action_pressed("fire_primary") and _fire_cd <= 0.0:
		_fire_primary_volley()
	if Input.is_action_pressed("fire_lockon"):
		_locking = true
		var max_affordable: int = mini(4, int(GameState.lockon_energy / MISSILE_ENERGY_COST))
		if max_affordable > 0:
			reticle_rig.scan_lockons(get_tree().get_nodes_in_group("lockable_enemies"), max_affordable)
	elif _locking:
		_locking = false
		_release_homing_missiles()
	if Input.is_action_just_pressed("emp_pulse"):
		if GameState.spend_emp():
			SfxManager.play("emp")


func _fire_primary_volley() -> void:
	var is_rapid: bool = GameState.rapid_timer > 0.0
	_fire_cd = RAPID_FIRE_INTERVAL if is_rapid else BASE_FIRE_INTERVAL
	var speed: float = RAPID_LASER_SPEED if is_rapid else BASE_LASER_SPEED
	var candidates: Array = get_tree().get_nodes_in_group("lockable_enemies")
	var offsets: Array[Vector3] = [Vector3(-0.98, 0.0, -0.8), Vector3(0.98, 0.0, -0.8)]
	if GameState.fighter_mode == GameState.FighterMode.DUAL:
		offsets = [
			Vector3(-DUAL_OFFSET_X - 0.98, 0.0, -0.8),
			Vector3(-DUAL_OFFSET_X + 0.98, 0.0, -0.8),
			Vector3(DUAL_OFFSET_X - 0.98, 0.0, -0.8),
			Vector3(DUAL_OFFSET_X + 0.98, 0.0, -0.8),
		]
	var container: Node = get_parent()
	for off: Vector3 in offsets:
		var p: Projectile = PROJECTILE_SCENE.instantiate()
		container.add_child(p)
		var muzzle: Vector3 = global_position + off
		var dir: Vector3 = reticle_rig.compute_assisted_dir(muzzle, candidates)
		p.setup(Projectile.Kind.PLAYER_LASER, muzzle, dir, speed, 1)
	SfxManager.play("laser")


func _release_homing_missiles() -> void:
	reticle_rig.prune_locked_targets()
	var targets: Array[Node3D] = reticle_rig.locked_targets.duplicate()
	reticle_rig.clear_lockons()
	if targets.is_empty():
		return
	var container: Node = get_parent()
	var fired: int = 0
	for i: int in range(targets.size()):
		if not GameState.spend_lockon_energy(MISSILE_ENERGY_COST):
			break
		var p: Projectile = PROJECTILE_SCENE.instantiate()
		container.add_child(p)
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var launch_dir := Vector3(side * 0.35, 0.25, -1.0).normalized()
		p.setup(Projectile.Kind.HOMING_MISSILE, global_position + Vector3(side * 1.1, 0.1, -0.5), launch_dir, 95.0, 2, targets[i])
		fired += 1
	if fired > 0:
		SfxManager.play("missile")


func trigger_barrel_roll(dir_x: float) -> bool:
	if _roll_cd > 0.0 or _roll_timer > 0.0:
		return false
	_roll_dir = 1.0 if dir_x >= 0.0 else -1.0
	_roll_timer = BARREL_ROLL_DUR
	_roll_cd = BARREL_ROLL_COOLDOWN
	invuln_timer = maxf(invuln_timer, BARREL_ROLL_INVULN)
	barrel_roll_started.emit()
	return true


func grant_spawn_invulnerability(duration: float = 2.5) -> void:
	invuln_timer = maxf(invuln_timer, duration)


func apply_damage(_hit_world_x: float = 0.0) -> String:
	if invuln_timer > 0.0 or is_captured or GameState.is_game_over:
		return "ignored"
	if GameState.consume_shield():
		invuln_timer = 1.0
		SfxManager.play("hit")
		damaged.emit(GameState.lives)
		return "shield"
	if GameState.fighter_mode == GameState.FighterMode.DUAL:
		GameState.set_fighter_mode(GameState.FighterMode.SINGLE)
		invuln_timer = 1.8
		SfxManager.play("explode")
		damaged.emit(GameState.lives)
		return "downgraded_single"
	GameState.lose_life()
	invuln_timer = 2.5
	SfxManager.play("explode")
	damaged.emit(GameState.lives)
	return "life_lost"


func begin_capture(boss: Node3D) -> void:
	if is_captured or invuln_timer > 0.0 or GameState.fighter_mode == GameState.FighterMode.DUAL:
		return
	is_captured = true
	reticle_rig.clear_lockons()
	visible = false
	SfxManager.play("tractor")
	GameState.lose_life()
	captured_by_boss.emit(boss)


func respawn_single() -> void:
	is_captured = false
	visible = true
	global_position = Vector3(0.0, -2.5, 0.0)
	GameState.set_fighter_mode(GameState.FighterMode.SINGLE)
	grant_spawn_invulnerability(2.5)


func get_locked_targets() -> Array[Node3D]:
	reticle_rig.prune_locked_targets()
	return reticle_rig.locked_targets
