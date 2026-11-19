class_name VfxBurst
extends Node3D

var _shards: Array[MeshInstance3D] = []
var _vels: Array[Vector3] = []
var _ring: MeshInstance3D = null
var _ring_mat: StandardMaterial3D = null
var _elapsed: float = 0.0
var _duration: float = 0.42
var _max_ring_scale: float = 3.2


static func spawn(
	parent: Node,
	world_pos: Vector3,
	color: Color,
	radius_scale: float = 1.0,
	shard_count: int = 8,
	duration: float = 0.42
) -> VfxBurst:
	var burst := VfxBurst.new()
	burst._duration = maxf(0.08, duration)
	burst._max_ring_scale = 3.4 * radius_scale
	parent.add_child(burst)
	burst.global_position = world_pos
	burst._build(color, radius_scale, shard_count)
	return burst


static func spawn_shockwave(
	parent: Node,
	world_pos: Vector3,
	color: Color,
	max_radius: float = 22.0,
	duration: float = 0.55
) -> VfxBurst:
	var burst := VfxBurst.new()
	burst._duration = maxf(0.1, duration)
	burst._max_ring_scale = max_radius
	parent.add_child(burst)
	burst.global_position = world_pos
	burst._build(color, 1.0, 0)
	return burst


func _build(color: Color, radius_scale: float, shard_count: int) -> void:
	var shard_mat := MeshFactory.make_neon_mat(color, color, 2.0)
	var shard_mesh := BoxMesh.new()
	shard_mesh.size = Vector3(0.24, 0.24, 0.48) * radius_scale
	for i: int in range(shard_count):
		var mi := MeshInstance3D.new()
		mi.mesh = shard_mesh
		mi.material_override = shard_mat
		var ang: float = (TAU * float(i)) / float(maxi(1, shard_count))
		var elev: float = -0.35 + 0.7 * float((i * 3) % 4) / 3.0
		var dir := Vector3(cos(ang), sin(ang) * 0.8 + elev, sin(ang * 2.0) * 0.45).normalized()
		add_child(mi)
		_shards.append(mi)
		_vels.append(dir * (9.5 * radius_scale))

	_ring = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.72
	tm.outer_radius = 0.94
	_ring.mesh = tm
	_ring.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	_ring_mat = MeshFactory.make_neon_mat(color, color, 2.1, 0.85)
	_ring.material_override = _ring_mat
	_ring.scale = Vector3(0.25, 0.25, 0.25)
	add_child(_ring)


func _process(delta: float) -> void:
	step_vfx(delta)


func step_vfx(delta: float) -> void:
	_elapsed += delta
	var u: float = clampf(_elapsed / _duration, 0.0, 1.0)
	var shard_scale: float = maxf(0.01, 1.0 - u)
	for i: int in range(_shards.size()):
		var mi: MeshInstance3D = _shards[i]
		mi.position += _vels[i] * delta * (1.0 - u * 0.45)
		mi.rotation += Vector3(6.0, 8.0, 5.0) * delta
		mi.scale = Vector3.ONE * shard_scale
	if is_instance_valid(_ring):
		var rs: float = lerpf(0.25, _max_ring_scale, 1.0 - pow(1.0 - u, 2.0))
		_ring.scale = Vector3(rs, rs, rs)
		if _ring_mat != null:
			_ring_mat.albedo_color.a = (1.0 - u) * 0.85
			_ring_mat.emission_energy_multiplier = (1.0 - u) * 2.1
	if _elapsed >= _duration:
		queue_free()
