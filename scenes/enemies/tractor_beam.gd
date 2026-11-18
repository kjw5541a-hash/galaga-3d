class_name TractorBeam
extends Area3D

signal capture_completed(player: PlayerFighter)

const CAPTURE_DWELL := 0.65
const BEAM_RADIUS_AT_PLAYER := 2.8

var _dwell: float = 0.0
var _rings: Array[MeshInstance3D] = []
var _time: float = 0.0


func _ready() -> void:
	collision_layer = 1 << 4 # Layer 5: tractor_beam
	collision_mask = 1 << 0  # Layer 1: player
	_build_visual()


func _build_visual() -> void:
	var cone := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.45
	cm.bottom_radius = BEAM_RADIUS_AT_PLAYER
	cm.height = 15.0
	cone.mesh = cm
	cone.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	cone.position = Vector3(0.0, 0.0, 7.5)
	cone.material_override = MeshFactory.make_neon_mat(Color(0.2, 0.9, 1.0), Color(0.55, 0.3, 1.0), 2.4, 0.28)
	add_child(cone)
	for i: int in range(4):
		var mi := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.7 + float(i) * 0.45
		tm.outer_radius = tm.inner_radius + 0.14
		mi.mesh = tm
		mi.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		mi.position = Vector3(0.0, 0.0, 3.0 + float(i) * 3.0)
		mi.material_override = MeshFactory.make_neon_mat(Color(0.3, 1.0, 1.0), Color(0.65, 0.35, 1.0), 3.0, 0.75)
		add_child(mi)
		_rings.append(mi)


func _process(delta: float) -> void:
	_time += delta
	for i: int in range(_rings.size()):
		var phase: float = fmod(_time * 1.4 + float(i) * 0.25, 1.0)
		_rings[i].position.z = lerpf(1.5, 14.5, phase)
		var s: float = lerpf(0.35, 1.35, phase)
		_rings[i].scale = Vector3(s, s, 1.0)


func tick_beam(delta: float, player: PlayerFighter) -> bool:
	if not is_instance_valid(player) or player.is_captured or player.invuln_timer > 0.0:
		_dwell = maxf(0.0, _dwell - delta * 2.0)
		return false
	var lateral: float = Vector2(player.global_position.x - global_position.x, player.global_position.y - global_position.y).length()
	if lateral <= BEAM_RADIUS_AT_PLAYER and absf(player.global_position.z - (global_position.z + 14.0)) <= 4.0:
		_dwell += delta
		if _dwell >= CAPTURE_DWELL:
			_dwell = 0.0
			capture_completed.emit(player)
			return true
	else:
		_dwell = maxf(0.0, _dwell - delta * 1.5)
	return false
