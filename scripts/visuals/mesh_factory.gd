class_name MeshFactory
extends RefCounted


static func make_neon_mat(albedo: Color, emission: Color, emission_energy: float = 1.6, transparency_alpha: float = 1.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(albedo.r, albedo.g, albedo.b, transparency_alpha)
	mat.metallic = 0.35
	mat.roughness = 0.28
	mat.emission_enabled = emission_energy > 0.001
	mat.emission = emission
	mat.emission_energy_multiplier = emission_energy
	if transparency_alpha < 0.99:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


static func make_hull_mat(albedo: Color, metallic: float = 0.58, roughness: float = 0.34, rim_strength: float = 0.65, subtle_emit: float = 0.06) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = albedo
	mat.metallic = metallic
	mat.roughness = roughness
	mat.rim_enabled = true
	mat.rim = rim_strength
	mat.rim_tint = 0.45
	if subtle_emit > 0.0:
		mat.emission_enabled = true
		mat.emission = albedo
		mat.emission_energy_multiplier = subtle_emit
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
	var hull_mat := make_hull_mat(Color(0.76, 0.83, 0.92), 0.55, 0.32, 0.75, 0.05)
	var dark_mat := make_hull_mat(Color(0.16, 0.21, 0.30), 0.68, 0.36, 0.55, 0.03)
	var canopy_mat := make_hull_mat(tint.lerp(Color(0.05, 0.12, 0.22), 0.55), 0.85, 0.14, 0.85, 0.18)
	var trim_mat := make_neon_mat(tint, tint, 1.65)
	var engine_mat := make_neon_mat(Color(1.0, 0.52, 0.18), Color(1.0, 0.45, 0.12), 2.1)

	# Forward nose cone & shaded fuselage spine
	_add_prism(root, Vector3(0.76, 1.85, 0.56), Vector3(0.0, 0.02, -0.35), hull_mat, Vector3(-90.0, 0.0, 0.0))
	_add_box(root, Vector3(0.62, 0.36, 1.05), Vector3(0.0, -0.04, 0.35), dark_mat)
	# Swept angled delta wings (dihedral bevel catches key & rim light)
	_add_box(root, Vector3(1.18, 0.12, 0.82), Vector3(-0.66, -0.10, 0.24), hull_mat, Vector3(0.0, 14.0, -10.0))
	_add_box(root, Vector3(1.18, 0.12, 0.82), Vector3(0.66, -0.10, 0.24), hull_mat, Vector3(0.0, -14.0, 10.0))
	# Twin angled vertical stabilizers
	_add_prism(root, Vector3(0.14, 0.55, 0.65), Vector3(-0.48, 0.22, 0.48), dark_mat, Vector3(0.0, 0.0, 14.0))
	_add_prism(root, Vector3(0.14, 0.55, 0.65), Vector3(0.48, 0.22, 0.48), dark_mat, Vector3(0.0, 0.0, -14.0))
	# Wingtip cannon housings + thin neon barrel accents
	_add_box(root, Vector3(0.20, 0.20, 0.92), Vector3(-1.02, -0.02, -0.02), dark_mat)
	_add_box(root, Vector3(0.20, 0.20, 0.92), Vector3(1.02, -0.02, -0.02), dark_mat)
	_add_box(root, Vector3(0.09, 0.09, 0.72), Vector3(-1.02, 0.05, -0.38), trim_mat)
	_add_box(root, Vector3(0.09, 0.09, 0.72), Vector3(1.02, 0.05, -0.38), trim_mat)
	# Cockpit & twin thruster cores
	_add_prism(root, Vector3(0.38, 0.72, 0.26), Vector3(0.0, 0.24, -0.08), canopy_mat, Vector3(-82.0, 0.0, 0.0))
	_add_box(root, Vector3(0.22, 0.16, 0.18), Vector3(-0.18, -0.04, 0.88), engine_mat)
	_add_box(root, Vector3(0.22, 0.16, 0.18), Vector3(0.18, -0.04, 0.88), engine_mat)
	return root


static func build_enemy_mesh(archetype: int, damaged_boss: bool = false) -> Node3D:
	if archetype != 0 and archetype != 1 and archetype != 2:
		return build_player_ship(Color(1.0, 0.18, 0.24))
	var root := Node3D.new()
	match archetype:
		0: # Zako (Bee) - Shaded bronze-gold armor + amber neon accents
			var hull := make_hull_mat(Color(0.26, 0.28, 0.38), 0.62, 0.34, 0.75, 0.08)
			var gold := make_hull_mat(Color(0.95, 0.68, 0.12), 0.58, 0.28, 0.85, 0.16)
			var glow := make_neon_mat(Color(1.0, 0.78, 0.18), Color(1.0, 0.68, 0.05), 1.65)
			_add_prism(root, Vector3(1.25, 1.75, 0.95), Vector3(0.0, 0.0, 0.0), hull, Vector3(90.0, 0.0, 0.0))
			_add_box(root, Vector3(1.15, 0.22, 0.78), Vector3(-0.78, 0.16, -0.05), gold, Vector3(0.0, -14.0, 16.0))
			_add_box(root, Vector3(1.15, 0.22, 0.78), Vector3(0.78, 0.16, -0.05), gold, Vector3(0.0, 14.0, -16.0))
			_add_box(root, Vector3(0.65, 0.42, 0.55), Vector3(0.0, 0.22, 0.38), gold)
			_add_box(root, Vector3(0.24, 0.18, 0.24), Vector3(-0.24, 0.24, 0.62), glow)
			_add_box(root, Vector3(0.24, 0.18, 0.24), Vector3(0.24, 0.24, 0.62), glow)
		1: # Goei (Butterfly) - Shaded dark plum hull + sculpted magenta wings + neon strips
			var body := make_hull_mat(Color(0.24, 0.14, 0.32), 0.65, 0.34, 0.75, 0.08)
			var wing := make_hull_mat(Color(0.86, 0.20, 0.54), 0.52, 0.30, 0.85, 0.16)
			var trim := make_neon_mat(Color(1.0, 0.28, 0.68), Color(1.0, 0.18, 0.58), 1.7)
			_add_box(root, Vector3(0.76, 0.64, 1.48), Vector3(0.0, 0.0, 0.0), body)
			_add_prism(root, Vector3(1.45, 1.25, 0.22), Vector3(-1.05, 0.20, 0.05), wing, Vector3(10.0, 12.0, 72.0))
			_add_prism(root, Vector3(1.45, 1.25, 0.22), Vector3(1.05, 0.20, 0.05), wing, Vector3(10.0, -12.0, -72.0))
			_add_box(root, Vector3(0.85, 0.16, 0.55), Vector3(-0.78, -0.24, -0.10), wing, Vector3(0.0, 0.0, -24.0))
			_add_box(root, Vector3(0.85, 0.16, 0.55), Vector3(0.78, -0.24, -0.10), wing, Vector3(0.0, 0.0, 24.0))
			_add_box(root, Vector3(0.46, 0.18, 0.22), Vector3(0.0, 0.16, 0.72), trim)
		2: # Boss Galaga - Sculpted emerald/blue armored dreadnought + gold crown + reactor glow
			var armor_col: Color = Color(0.14, 0.68, 0.92) if damaged_boss else Color(0.22, 0.82, 0.24)
			var accent_col: Color = Color(0.18, 0.88, 1.0) if damaged_boss else Color(0.28, 1.0, 0.24)
			var core := make_hull_mat(Color(0.16, 0.22, 0.28), 0.72, 0.30, 0.75, 0.06)
			var armor := make_hull_mat(armor_col, 0.56, 0.28, 0.85, 0.14)
			var crown := make_hull_mat(Color(0.95, 0.76, 0.18), 0.70, 0.24, 0.85, 0.16)
			var glow := make_neon_mat(accent_col, accent_col, 1.75)
			_add_box(root, Vector3(1.55, 1.05, 1.75), Vector3(0.0, 0.0, 0.0), core)
			_add_box(root, Vector3(1.35, 0.32, 1.10), Vector3(-1.18, 0.16, -0.05), armor, Vector3(0.0, -10.0, 14.0))
			_add_box(root, Vector3(1.35, 0.32, 1.10), Vector3(1.18, 0.16, -0.05), armor, Vector3(0.0, 10.0, -14.0))
			_add_prism(root, Vector3(1.05, 0.85, 0.78), Vector3(0.0, 0.78, 0.18), crown)
			_add_box(root, Vector3(0.68, 0.32, 0.24), Vector3(0.0, 0.08, 0.88), glow)
			_add_box(root, Vector3(0.20, 0.22, 0.92), Vector3(-1.68, 0.28, 0.10), glow)
			_add_box(root, Vector3(0.20, 0.22, 0.92), Vector3(1.68, 0.28, 0.10), glow)
	return root


static func build_boss_module(kind: String) -> Node3D:
	var root := Node3D.new()
	match kind:
		"core":
			var dark_hull := make_hull_mat(Color(0.16, 0.22, 0.34), 0.72, 0.32, 0.80, 0.06)
			var plate := make_hull_mat(Color(0.28, 0.44, 0.72), 0.64, 0.28, 0.85, 0.10)
			var rib := make_neon_mat(Color(0.20, 0.85, 1.0), Color(0.15, 0.80, 1.0), 1.55)
			var crystal := make_neon_mat(Color(1.0, 0.18, 0.34), Color(1.0, 0.14, 0.30), 2.0)
			_add_box(root, Vector3(7.4, 3.8, 5.4), Vector3.ZERO, dark_hull)
			_add_box(root, Vector3(6.8, 0.85, 4.8), Vector3(0.0, 2.05, -0.15), plate)
			_add_box(root, Vector3(6.8, 0.85, 4.8), Vector3(0.0, -2.05, -0.15), plate)
			_add_box(root, Vector3(1.2, 3.4, 4.6), Vector3(-3.3, 0.0, 0.45), plate, Vector3(0.0, 12.0, 0.0))
			_add_box(root, Vector3(1.2, 3.4, 4.6), Vector3(3.3, 0.0, 0.45), plate, Vector3(0.0, -12.0, 0.0))
			_add_box(root, Vector3(0.24, 3.1, 0.28), Vector3(-2.35, 0.0, 2.75), rib)
			_add_box(root, Vector3(0.24, 3.1, 0.28), Vector3(2.35, 0.0, 2.75), rib)
			var core_crystal := _add_prism(root, Vector3(3.2, 2.6, 2.8), Vector3(0.0, 0.0, 2.55), crystal, Vector3(90.0, 0.0, 0.0))
			core_crystal.name = "CoreCrystal"
		"cannon":
			var hull := make_hull_mat(Color(0.15, 0.28, 0.36), 0.70, 0.30, 0.85, 0.08)
			var trim := make_hull_mat(Color(0.24, 0.62, 0.68), 0.62, 0.26, 0.85, 0.12)
			var muzzle := make_neon_mat(Color(0.22, 0.98, 0.92), Color(0.18, 0.95, 0.90), 1.85)
			_add_box(root, Vector3(3.3, 2.2, 4.4), Vector3.ZERO, hull)
			_add_box(root, Vector3(2.6, 0.55, 3.6), Vector3(0.0, 1.22, 0.15), trim)
			_add_box(root, Vector3(0.95, 0.95, 3.1), Vector3(0.0, -0.15, 2.75), hull)
			_add_box(root, Vector3(0.55, 0.55, 0.55), Vector3(0.0, -0.15, 4.35), muzzle)
			_add_box(root, Vector3(1.15, 0.18, 0.22), Vector3(0.0, 0.62, 2.25), muzzle)
		_: # hangar
			var hull := make_hull_mat(Color(0.26, 0.16, 0.32), 0.68, 0.32, 0.85, 0.08)
			var plate := make_hull_mat(Color(0.68, 0.24, 0.50), 0.58, 0.28, 0.85, 0.12)
			var bay := make_neon_mat(Color(1.0, 0.74, 0.18), Color(1.0, 0.68, 0.12), 1.85)
			_add_box(root, Vector3(3.7, 2.4, 4.5), Vector3.ZERO, hull)
			_add_box(root, Vector3(3.2, 0.55, 3.8), Vector3(0.0, 1.32, 0.1), plate)
			_add_box(root, Vector3(3.2, 0.45, 3.8), Vector3(0.0, -1.25, 0.1), plate)
			_add_box(root, Vector3(2.1, 0.85, 0.45), Vector3(0.0, -0.15, 2.35), bay)
	return root


static func build_projectile_mesh(kind: int) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	match kind:
		0: # PLAYER_LASER
			var m := BoxMesh.new()
			m.size = Vector3(0.14, 0.14, 2.1)
			mi.mesh = m
			mi.material_override = make_neon_mat(Color(0.35, 1.0, 1.0), Color(0.25, 0.95, 1.0), 2.0)
		1: # HOMING_MISSILE
			var m := PrismMesh.new()
			m.size = Vector3(0.45, 1.3, 0.45)
			mi.mesh = m
			mi.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
			mi.material_override = make_neon_mat(Color(1.0, 0.6, 0.14), Color(1.0, 0.52, 0.08), 2.1)
		_: # ENEMY_ORB
			var m := SphereMesh.new()
			m.radius = 0.36
			m.height = 0.72
			mi.mesh = m
			mi.material_override = make_neon_mat(Color(1.0, 0.28, 0.38), Color(1.0, 0.18, 0.32), 1.85)
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
