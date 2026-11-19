extends RefCounted


func run(tree: SceneTree) -> void:
	var t := TestAssert.new()
	var gs: Node = tree.root.get_node("GameState")
	gs.reset_run()

	var player_scene: PackedScene = load("res://scenes/player/player_fighter.tscn")
	var player: PlayerFighter = player_scene.instantiate()
	tree.root.add_child(player)
	player.invuln_timer = 0.0

	# Atomic damage priority: SHIELD -> DUAL downgrade -> LIFE lost, and invuln blocks same-tick stack
	gs.set_fighter_mode(gs.FighterMode.DUAL)
	gs.grant_powerup(gs.PowerupType.SHIELD)
	t.eq(player.apply_damage(0.0), "shield", "first hit consumes shield")
	t.eq(gs.shield_count, 0, "shield decremented")
	t.eq(player.apply_damage(0.0), "ignored", "invuln blocks overlapping bullet in same tick")

	player.invuln_timer = 0.0
	t.eq(player.apply_damage(1.0), "downgraded_single", "dual hit downgrades to single without life loss")
	t.eq(gs.fighter_mode, gs.FighterMode.SINGLE, "fighter mode now SINGLE")
	t.eq(gs.lives, 3, "no life lost on dual downgrade")
	t.is_true(player.invuln_timer >= 1.7, "dual downgrade grants 1.8s invuln")

	player.invuln_timer = 0.0
	t.eq(player.apply_damage(0.0), "life_lost", "single hit loses 1 life")
	t.eq(gs.lives, 2, "lives decremented to 2")

	# Barrel roll cooldown & invuln
	player.invuln_timer = 0.0
	t.is_true(player.trigger_barrel_roll(1.0), "barrel roll starts")
	t.is_true(player.invuln_timer >= 0.30, "barrel roll grants 0.32s invuln")
	t.is_true(not player.trigger_barrel_roll(1.0), "barrel roll respects 1.5s cooldown")

	# Reticle lock-on cap (<= 4) & freed-node pruning
	var dummies: Array[Node3D] = []
	for i: int in range(6):
		var d := Node3D.new()
		tree.root.add_child(d)
		d.global_position = Vector3(float(i - 2) * 0.6, 0.0, -45.0)
		dummies.append(d)
	player.global_position = Vector3.ZERO
	player.reticle_rig.update_aim(Vector3.ZERO, Vector2.ZERO, Vector2.ZERO)
	var locked: Array[Node3D] = player.reticle_rig.scan_lockons(dummies, 4)
	t.eq(locked.size(), 4, "lock-on capped at 4 targets")
	dummies[0].free()
	player.reticle_rig.prune_locked_targets()
	t.eq(player.reticle_rig.locked_targets.size(), 3, "freed target pruned safely")
	for d: Node3D in dummies:
		if is_instance_valid(d):
			d.free()
	player.queue_free()

	t.finish(tree, "test_player_fighter")
