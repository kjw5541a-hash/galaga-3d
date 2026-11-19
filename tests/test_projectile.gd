extends RefCounted


func run(tree: SceneTree) -> void:
	var t := TestAssert.new()

	# MeshFactory builds distinct procedural low-poly rigs without external assets
	var ship: Node3D = MeshFactory.build_player_ship()
	t.is_true(ship.get_child_count() >= 3, "player ship has fuselage + wings")
	ship.free()

	var boss_mesh: Node3D = MeshFactory.build_enemy_mesh(2, true)
	t.is_true(boss_mesh.get_child_count() >= 2, "boss mesh has body + wings")
	boss_mesh.free()

	# Laser moves forward along -Z
	var proj_scene: PackedScene = load("res://scenes/player/projectile.tscn")
	var laser: Projectile = proj_scene.instantiate()
	tree.root.add_child(laser)
	laser.setup(Projectile.Kind.PLAYER_LASER, Vector3.ZERO, Vector3(0, 0, -1), 120.0, 1)
	laser.step_motion(0.5)
	t.approx(laser.global_position.z, -60.0, 0.1, "laser advances -Z")
	laser.queue_free()

	# Homing missile steers toward live target, then safely continues when target is freed mid-flight
	var dummy := Node3D.new()
	tree.root.add_child(dummy)
	dummy.global_position = Vector3(10.0, 5.0, -40.0)
	var missile: Projectile = proj_scene.instantiate()
	tree.root.add_child(missile)
	missile.setup(Projectile.Kind.HOMING_MISSILE, Vector3.ZERO, Vector3(0, 0, -1), 95.0, 2, dummy)
	missile.step_motion(0.1)
	t.is_true(missile.velocity.x > 0.5, "missile steers toward target +X")
	var prev_vel: Vector3 = missile.velocity
	dummy.free()
	missile.step_motion(0.1)
	t.is_true(missile.homing_target == null, "freed target cleared safely")
	t.approx(missile.velocity.normalized().dot(prev_vel.normalized()), 1.0, 0.01, "missile keeps heading after target freed")
	missile.queue_free()

	t.finish(tree, "test_projectile")
