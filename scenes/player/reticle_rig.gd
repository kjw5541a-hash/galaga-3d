class_name ReticleRig
extends Node3D

const NEAR_Z := -22.0
const FAR_Z := -50.0
const AIM_MAGNET_RADIUS := 1.8
const LOCKON_CONE_RADIUS := 4.5
const MAX_LEAD_RAD := deg_to_rad(4.0)

var locked_targets: Array[Node3D] = []
var _near_mesh: MeshInstance3D
var _far_mesh: MeshInstance3D
var _aim_dir: Vector3 = Vector3(0.0, 0.0, -1.0)
var _ship_origin: Vector3 = Vector3.ZERO


func _ready() -> void:
	_near_mesh = _make_ring(0.85, 0.98, Color(0.2, 1.0, 0.9))
	_far_mesh = _make_ring(0.45, 0.56, Color(1.0, 0.9, 0.25))
	add_child(_near_mesh)
	add_child(_far_mesh)


func _make_ring(inner_r: float, outer_r: float, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = inner_r
	tm.outer_radius = outer_r
	mi.mesh = tm
	mi.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	mi.material_override = MeshFactory.make_neon_mat(col, col, 2.8, 0.85)
	return mi


func update_aim(ship_pos: Vector3, move_vec: Vector2, fine_aim: Vector2) -> void:
	_ship_origin = ship_pos
	var yaw: float = clampf((move_vec.x * 0.55 + fine_aim.x) * MAX_LEAD_RAD, -MAX_LEAD_RAD, MAX_LEAD_RAD)
	var pitch: float = clampf((move_vec.y * 0.55 - fine_aim.y) * MAX_LEAD_RAD, -MAX_LEAD_RAD, MAX_LEAD_RAD)
	_aim_dir = Vector3(sin(yaw), sin(pitch), -1.0).normalized()
	if is_instance_valid(_near_mesh):
		_near_mesh.global_position = _project_at_z(NEAR_Z)
	if is_instance_valid(_far_mesh):
		_far_mesh.global_position = _project_at_z(FAR_Z)


func _project_at_z(target_z: float) -> Vector3:
	var t: float = (target_z - _ship_origin.z) / minf(-0.001, _aim_dir.z)
	return _ship_origin + _aim_dir * t


func get_far_reticle_world() -> Vector3:
	return _project_at_z(FAR_Z)


func compute_assisted_dir(muzzle_world: Vector3, candidates: Array) -> Vector3:
	var best_pos: Vector3 = get_far_reticle_world()
	var best_dist: float = AIM_MAGNET_RADIUS
	for c: Variant in candidates:
		if not is_instance_valid(c) or not (c is Node3D):
			continue
		var node: Node3D = c as Node3D
		if node.global_position.z >= muzzle_world.z - 2.0:
			continue
		var ray_pt: Vector3 = _project_at_z(node.global_position.z)
		var lateral: float = Vector2(node.global_position.x - ray_pt.x, node.global_position.y - ray_pt.y).length()
		if lateral < best_dist:
			best_dist = lateral
			best_pos = node.global_position
	return (best_pos - muzzle_world).normalized()


func prune_locked_targets() -> void:
	var alive: Array[Node3D] = []
	for t_node: Node3D in locked_targets:
		if is_instance_valid(t_node):
			alive.append(t_node)
	locked_targets = alive


func scan_lockons(candidates: Array, max_locks: int = 4) -> Array[Node3D]:
	prune_locked_targets()
	if locked_targets.size() >= max_locks:
		return locked_targets
	var scored: Array[Dictionary] = []
	for c: Variant in candidates:
		if not is_instance_valid(c) or not (c is Node3D):
			continue
		var node: Node3D = c as Node3D
		if locked_targets.has(node):
			continue
		if node.global_position.z >= -2.0 or node.global_position.z < -120.0:
			continue
		var ray_pt: Vector3 = _project_at_z(node.global_position.z)
		var lateral: float = Vector2(node.global_position.x - ray_pt.x, node.global_position.y - ray_pt.y).length()
		if lateral <= LOCKON_CONE_RADIUS:
			var priority: float = lateral
			if node.has_method("is_high_priority_lock") and node.call("is_high_priority_lock"):
				priority -= 2.5
			scored.append({"node": node, "score": priority})
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["score"]) < float(b["score"]))
	for item: Dictionary in scored:
		if locked_targets.size() >= max_locks:
			break
		locked_targets.append(item["node"] as Node3D)
		SfxManager.play("lockon")
	return locked_targets


func clear_lockons() -> void:
	locked_targets.clear()
