class_name MeshFactory
extends RefCounted


static func make_neon_mat(albedo: Color, emission: Color, emission_energy: float = 2.0, transparency_alpha: float = 1.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(albedo.r, albedo.g, albedo.b, transparency_alpha)
	mat.metallic = 0.35
	mat.roughness = 0.25
	mat.emission_enabled = true
	mat.emission = emission
	mat.emission_energy_multiplier = emission_energy
	if transparency_alpha < 0.99:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


static func _add_box(parent: Node3D, size: Vector3, pos: Vector3, mat: StandardMaterial3D, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi


static func _add_prism(parent: Node3D, size: Vector3, pos: Vector3, mat: StandardMaterial3D, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := PrismMesh.new()
	m.size = size
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi


static func build_player_ship(tint: Color = Color(0.15, 0.9, 1.0)) -> Node3D:
	var root := Node3D.new()
	var hull_mat := make_neon_mat(Color(0.92, 0.95, 1.0), tint * 0.35, 0.8)
	var trim_mat := make_neon_mat(tint, tint, 2.4)
	var engine_mat := make_neon_mat(Color(1.0, 0.45, 0.15), Color(1.0, 0.45, 0.15), 3.2)

	# Forward nose cone & fuselage
	_add_prism(root, Vector3(0.75, 1.8, 0.55), Vector3(0.0, 0.0, -0.35), hull_mat, Vector3(-90.0, 0.0, 0.0))
	# Swept delta wings
	_add_box(root, Vector3(2.1, 0.12, 0.85), Vector3(0.0, -0.08, 0.25), hull_mat)
	# Twin neon wingtip laser cannons
	_add_box(root, Vector3(0.16, 0.18, 1.15), Vector3(-0.98, 0.02, -0.15), trim_mat)
	_add_box(root, Vector3(0.16, 0.18, 1.15), Vector3(0.98, 0.02, -0.15), trim_mat)
	# Cockpit & thruster glow
	_add_box(root, Vector3(0.36, 0.22, 0.65), Vector3(0.0, 0.22, -0.05), trim_mat)
	_add_box(root, Vector3(0.45, 0.22, 0.25), Vector3(0.0, -0.02, 0.72), engine_mat)
	return root


static func build_enemy_mesh(archetype: int, damaged_boss: bool = false) -> Node3D:
	var root := Node3D.new()
	match archetype:
		0: # Zako (Bee) - Neon Amber
			var body := make_neon_mat(Color(0.15, 0.15, 0.22), Color(0.1, 0.15, 0.3), 0.7)
			var accent := make_neon_mat(Color(1.0, 0.72, 0.0), Color(1.0, 0.72, 0.0), 2.3)
			_add_prism(root, Vector3(1.1, 1.5, 0.8), Vector3(0, 0, 0), body, Vector3(90.0, 0, 0))
			_add_box(root, Vector3(1.85, 0.14, 0.65), Vector3(0, 0.1, -0.1), accent)
			_add_box(root, Vector3(0.45, 0.3, 0.45), Vector3(0, 0.2, 0.35), accent)
		1: # Goei (Butterfly) - Neon Magenta
			var body := make_neon_mat(Color(0.2, 0.1, 0.25), Color(0.5, 0.1, 0.4), 1.0)
			var wing := make_neon_mat(Color(1.0, 0.18, 0.53), Color(1.0, 0.18, 0.53), 2.5)
			_add_box(root, Vector3(0.65, 0.55, 1.3), Vector3(0, 0, 0), body)
			_add_prism(root, Vector3(1.3, 1.1, 0.16), Vector3(-0.95, 0.1, 0), wing, Vector3(0, 0, 75.0))
			_add_prism(root, Vector3(1.3, 1.1, 0.16), Vector3(0.95, 0.1, 0), wing, Vector3(0, 0, -75.0))
		2: # Boss Galaga - Neon Green -> Electric Blue at 1 HP
			var c: Color = Color(0.0, 0.83, 1.0) if damaged_boss else Color(0.22, 1.0, 0.08)
			var armor := make_neon_mat(c, c, 2.4)
			var crown := make_neon_mat(Color(1.0, 0.85, 0.15), Color(1.0, 0.85, 0.15), 2.8)
			_add_box(root, Vector3(1.4, 0.9, 1.6), Vector3(0, 0, 0), armor)
			_add_box(root, Vector3(2.8, 0.22, 0.95), Vector3(0, 0.15, -0.15), armor)
			_add_prism(root, Vector3(0.9, 0.75, 0.7), Vector3(0, 0.65, 0.15), crown)
		_: # Captured Red Fighter
			return build_player_ship(Color(1.0, 0.15, 0.22))
	return root


static func build_boss_module(kind: String) -> Node3D:
	var root := Node3D.new()
	match kind:
		"core":
			var armor := make_neon_mat(Color(0.2, 0.5, 1.0), Color(0.15, 0.7, 1.0), 2.2)
			var crystal := make_neon_mat(Color(1.0, 0.12, 0.28), Color(1.0, 0.12, 0.28), 3.4)
			_add_box(root, Vector3(7.5, 4.0, 5.5), Vector3.ZERO, armor)
			_add_prism(root, Vector3(4.5, 3.5, 4.5), Vector3(0, 0.2, 2.4), crystal, Vector3(90.0, 0, 0))
		"cannon":
			var body := make_neon_mat(Color(0.15, 0.95, 0.85), Color(0.15, 0.95, 0.85), 2.4)
			_add_box(root, Vector3(3.2, 2.2, 4.2), Vector3.ZERO, body)
			_add_box(root, Vector3(0.8, 0.8, 3.0), Vector3(0, -0.2, 2.6), body)
		_: # hangar
			var body := make_neon_mat(Color(1.0, 0.35, 0.75), Color(1.0, 0.35, 0.75), 2.3)
			_add_box(root, Vector3(3.6, 2.4, 4.4), Vector3.ZERO, body)
			_add_box(root, Vector3(2.2, 1.0, 0.6), Vector3(0, -0.3, 2.3), make_neon_mat(Color(1.0, 0.75, 0.1), Color(1.0, 0.75, 0.1), 3.0))
	return root


static func build_projectile_mesh(kind: int) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	match kind:
		0: # PLAYER_LASER
			var m := BoxMesh.new()
			m.size = Vector3(0.16, 0.16, 2.2)
			mi.mesh = m
			mi.material_override = make_neon_mat(Color(0.3, 1.0, 1.0), Color(0.3, 1.0, 1.0), 3.5)
		1: # HOMING_MISSILE
			var m := PrismMesh.new()
			m.size = Vector3(0.45, 1.3, 0.45)
			mi.mesh = m
			mi.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
			mi.material_override = make_neon_mat(Color(1.0, 0.55, 0.1), Color(1.0, 0.55, 0.1), 3.6)
		_: # ENEMY_ORB
			var m := SphereMesh.new()
			m.radius = 0.42
			m.height = 0.84
			mi.mesh = m
			mi.material_override = make_neon_mat(Color(1.0, 0.2, 0.35), Color(1.0, 0.2, 0.35), 3.4)
	return mi


static func build_capsule_mesh(kind: int) -> Node3D:
	var root := Node3D.new()
	var colors: Array[Color] = [
		Color(0.1, 0.95, 1.0),  # SHIELD
		Color(1.0, 0.55, 0.05), # RAPID
		Color(0.75, 0.25, 1.0), # EMP
	]
	var c: Color = colors[clampi(kind, 0, colors.size() - 1)]
	var mat := make_neon_mat(c, c, 3.0)
	var cap := MeshInstance3D.new()
	var m := CapsuleMesh.new()
	m.radius = 0.45
	m.height = 1.4
	cap.mesh = m
	cap.material_override = mat
	root.add_child(cap)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.72
	tm.outer_radius = 0.90
	ring.mesh = tm
	ring.material_override = make_neon_mat(c, c, 2.2, 0.65)
	root.add_child(ring)
	return root
