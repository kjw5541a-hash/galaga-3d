class_name PowerupCapsule
extends Area3D

const DRIFT_SPEED := 18.0
const MAGNET_RADIUS := 3.5

var kind: GameState.PowerupType = GameState.PowerupType.SHIELD
var _player: PlayerFighter = null
var _collected: bool = false


func _ready() -> void:
	collision_layer = 1 << 5 # Layer 6: pickup
	collision_mask = 1 << 0  # Layer 1: player
	body_entered.connect(_on_body_entered)


func setup(p_kind: GameState.PowerupType, origin: Vector3, p_player: PlayerFighter) -> void:
	kind = p_kind
	global_position = origin
	_player = p_player
	add_child(MeshFactory.build_capsule_mesh(kind))


func _physics_process(delta: float) -> void:
	rotation.y += delta * 2.8
	global_position.z += DRIFT_SPEED * delta
	if is_instance_valid(_player) and not _player.is_captured:
		var dist: float = global_position.distance_to(_player.global_position)
		if dist <= MAGNET_RADIUS:
			global_position = global_position.lerp(_player.global_position, clampf(8.0 * delta, 0.0, 1.0))
	if global_position.z > 14.0:
		queue_free()


func _on_body_entered(body: Node3D) -> void:
	if _collected:
		return
	if body is PlayerFighter and not (body as PlayerFighter).is_captured:
		_collected = true
		GameState.grant_powerup(kind)
		SfxManager.play("powerup")
		queue_free()
