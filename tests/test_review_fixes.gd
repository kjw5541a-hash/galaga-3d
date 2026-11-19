extends RefCounted


func run(tree: SceneTree) -> void:
	var t := TestAssert.new()
	var gs: Node = tree.root.get_node("GameState")
	gs.reset_run()

	# 1. Critical #1: ReticleRig horizontal aim leads RIGHT when moving right
	var player: PlayerFighter = load("res://scenes/player/player_fighter.tscn").instantiate()
	tree.root.add_child(player)
	player.global_position = Vector3.ZERO
	player.reticle_rig.update_aim(Vector3.ZERO, Vector2(1.0, 0.0), Vector2.ZERO)
	t.is_true(player.reticle_rig.get_far_reticle_world().x > 0.5, "moving right aims reticle right (+X)")

	# 2. Critical #2: QueenBoss Phase 1 armor halves 1-dmg primary lasers (50% DPS)
	var boss: QueenBoss = load("res://scenes/enemies/queen_boss.tscn").instantiate()
	tree.root.add_child(boss)
	boss.setup_boss(5, player)
	var hp_before: int = boss.core_hp
	var d1: int = boss.apply_part_damage("core", 1)
	var d2: int = boss.apply_part_damage("core", 1)
	t.eq(d1 + d2, 1, "two 1-dmg lasers in Phase 1 deal 1 total damage")
	t.eq(boss.core_hp, hp_before - 1, "Phase 1 core HP reduced by 1 after two 1-dmg hits")

	# 3. Critical #3: QueenBoss drones are parented to boss (cleaned up with boss) and marked one_shot_dive
	boss._launch_drone_squad()
	var child_drones: int = 0
	var one_shot_ok: bool = true
	for c: Node in boss.get_children():
		if c is EnemyUnit:
			child_drones += 1
			if not (c as EnemyUnit).one_shot_dive:
				one_shot_ok = false
	t.eq(child_drones, 3, "boss drones parented under QueenBoss")
	t.is_true(one_shot_ok, "boss drones marked one_shot_dive")

	# 4. Important #5: Dead BossPartArea and EnemyUnit immediately leave lockable_enemies
	boss.apply_part_damage("cannon", 28)
	var cannon_still_lockable: bool = false
	for node: Node in tree.get_nodes_in_group("lockable_enemies"):
		if node is QueenBoss.BossPartArea and (node as QueenBoss.BossPartArea).part_name == "cannon":
			cannon_still_lockable = true
	t.is_true(not cannon_still_lockable, "destroyed cannon immediately removed from lockable_enemies")
	boss.queue_free()

	var enemy_scene: PackedScene = load("res://scenes/enemies/enemy_unit.tscn")
	var zako: EnemyUnit = enemy_scene.instantiate()
	tree.root.add_child(zako)
	zako.setup_unit(EnemyUnit.Archetype.ZAKO, 3, 0, 0, Vector3(0, 0, -45), player)
	zako.take_damage(1)
	t.is_true(not zako.is_in_group("lockable_enemies"), "dead EnemyUnit immediately removed from lockable_enemies")

	# 5. Important #4: FormationManager waits for _captured_unit before emitting wave_cleared
	var fm: FormationManager = load("res://scenes/enemies/formation_manager.tscn").instantiate()
	tree.root.add_child(fm)
	fm.start_standard_wave(1, player)
	var sq: Array = fm.get("_spawn_queue")
	sq.clear()
	var cap: EnemyUnit = enemy_scene.instantiate()
	fm.add_child(cap)
	cap.setup_unit(EnemyUnit.Archetype.CAPTURED_FIGHTER, 0, 0, 0, Vector3(0, 0, -20), player)
	cap.state = EnemyUnit.State.RESCUED_DOCKING
	fm.set("_captured_unit", cap)
	var cleared := {"flag": false}
	fm.wave_cleared.connect(func() -> void: cleared["flag"] = true)
	fm._physics_process(0.016)
	t.is_true(not cleared["flag"], "wave_cleared waits while rescued ship is docking")
	cap.complete_rescue_dock()
	fm._physics_process(0.016)
	t.is_true(cleared["flag"], "wave_cleared emits once captured ship finishes docking")
	fm.queue_free()

	# 6. Important #6: EnemyUnit skips RESCUED_DOCKING when GameState.is_game_over
	gs.reset_run()
	gs.is_game_over = true
	var cap_go: EnemyUnit = enemy_scene.instantiate()
	tree.root.add_child(cap_go)
	cap_go.setup_unit(EnemyUnit.Archetype.CAPTURED_FIGHTER, 0, 0, 0, Vector3(1.25, 0, 0), player)
	cap_go.state = EnemyUnit.State.RESCUED_DOCKING
	cap_go._physics_process(0.016)
	t.eq(gs.fighter_mode, gs.FighterMode.SINGLE, "rescue dock blocked during game over")
	cap_go.queue_free()

	player.queue_free()
	t.finish(tree, "test_review_fixes")
