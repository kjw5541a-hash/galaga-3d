class_name Projectile
extends Area3D

enum Kind { PLAYER_LASER, HOMING_MISSILE, ENEMY_ORB }

const TURN_RATE := 7.5
const MAX_LIFETIME := 4.0

var kind: Kind = Kind.PLAYER_LASER
var velocity: Vector3 = Vector3(0.0, 0.0, -120.0)
var damage: int = 1
var homing_target: Node3D = null
var _speed: float = 120.0
var _age: float = 0.0
var _visual: Node3D = null


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)


func setup(p_kind: Kind, origin: Vector3, dir: Vector3, speed: float, p_damage: int = 1, p_target: Node3D = null) -> void:
	kind = p_kind
	_speed = speed
	damage = p_damage
	homing_target = p_target
	global_position = origin
	var n_dir: Vector3 = dir.normalized() if dir.length_squared() > 0.0001 else Vector3(0.0, 0.0, -1.0)
	velocity = n_dir * _speed
	_configure_layers()
	_rebuild_visual()


func _configure_layers() -> void:
	if kind == Kind.ENEMY_ORB:
		collision_layer = 1 << 3 # Layer 4: enemy_projectile
		collision_mask = 1 << 0  # Layer 1: player
		add_to_group("enemy_projectiles")
	else:
		collision_layer = 1 << 1 # Layer 2: player_projectile
		collision_mask = 1 << 2  # Layer 3: enemy
		add_to_group("player_projectiles")


func _rebuild_visual() -> void:
	if is_instance_valid(_visual):
		_visual.queue_free()
	_visual = MeshFactory.build_projectile_mesh(kind)
	add_child(_visual)


func _physics_process(delta: float) -> void:
	step_motion(delta)


func step_motion(delta: float) -> void:
	_age += delta
	if _age >= MAX_LIFETIME or global_position.z < -175.0 or global_position.z > 22.0:
		queue_free()
		return
	if kind == Kind.HOMING_MISSILE:
		if homing_target != null and not is_instance_valid(homing_target):
			homing_target = null
		if homing_target != null:
			var desired: Vector3 = (homing_target.global_position - global_position).normalized()
			var cur_dir: Vector3 = velocity.normalized()
			var next_dir: Vector3 = cur_dir.lerp(desired, clampf(TURN_RATE * delta, 0.0, 1.0)).normalized()
			velocity = next_dir * _speed
	global_position += velocity * delta
	if velocity.length_squared() > 0.01 and is_inside_tree():
		var dir_n: Vector3 = velocity.normalized()
		if absf(dir_n.dot(Vector3.UP)) < 0.99:
			look_at(global_position + dir_n, Vector3.UP)


func _on_area_entered(area: Area3D) -> void:
	if kind != Kind.ENEMY_ORB and area.has_method("take_damage"):
		area.call("take_damage", damage, kind == Kind.HOMING_MISSILE)
		if kind == Kind.PLAYER_LASER:
			GameState.add_lockon_energy(6.0)
		queue_free()


func _on_body_entered(body: Node3D) -> void:
	if kind == Kind.ENEMY_ORB and body.has_method("apply_damage"):
		body.call("apply_damage", global_position.x)
		queue_free()
