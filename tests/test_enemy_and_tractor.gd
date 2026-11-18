extends RefCounted


func run(tree: SceneTree) -> void:
	var t := TestAssert.new()
	var gs: Node = tree.root.get_node("GameState")
	gs.reset_run()

	var player: PlayerFighter = load("res://scenes/player/player_fighter.tscn").instantiate()
	tree.root.add_child(player)
	player.invuln_timer = 0.0
	player.global_position = Vector3(0.0, 0.0, 0.0)

	# 1. TractorBeam requires 0.65s dwell & ignores invulnerable player
	var beam: TractorBeam = load("res://scenes/enemies/tractor_beam.tscn").instantiate()
	tree.root.add_child(beam)
	beam.global_position = Vector3(0.0, 0.0, -14.0)
	player.invuln_timer = 1.0
	t.is_true(not beam.tick_beam(0.8, player), "invulnerable player cannot be captured")
	player.invuln_timer = 0.0
	t.is_true(not beam.tick_beam(0.4, player), "0.4s not enough for capture")
	t.is_true(beam.tick_beam(0.3, player), "0.7s inside beam triggers capture")
	beam.queue_free()

	# 2. Boss destroyed while DIVING -> captured fighter enters RESCUED_DOCKING -> DUAL upgrade (+1000)
	var enemy_scene: PackedScene = load("res://scenes/enemies/enemy_unit.tscn")
	var boss_dive: EnemyUnit = enemy_scene.instantiate()
	var cap1: EnemyUnit = enemy_scene.instantiate()
	tree.root.add_child(boss_dive)
	tree.root.add_child(cap1)
	boss_dive.setup_unit(EnemyUnit.Archetype.BOSS_GALAGA, 0, 0, 0, Vector3(0, 5, -50), player)
	cap1.setup_unit(EnemyUnit.Archetype.CAPTURED_FIGHTER, 0, 0, 0, Vector3(0, 7, -50), player)
	boss_dive.attach_captured_fighter(cap1)
	boss_dive.state = EnemyUnit.State.DIVING
	boss_dive.take_damage(1)
	t.eq(boss_dive.hp, 1, "boss takes 1st hit, survives with 1 HP")
	boss_dive.take_damage(1)
	t.eq(cap1.state, EnemyUnit.State.RESCUED_DOCKING, "diving boss kill rescues captured ship")
	cap1.complete_rescue_dock()
	t.eq(gs.fighter_mode, gs.FighterMode.DUAL, "rescue dock upgrades to DUAL fighter")

	# 3. Boss destroyed while IN_FORMATION -> captured fighter turns CAPTURED_HOSTILE (no DUAL upgrade)
	gs.set_fighter_mode(gs.FighterMode.SINGLE)
	var boss_form: EnemyUnit = enemy_scene.instantiate()
	var cap2: EnemyUnit = enemy_scene.instantiate()
	tree.root.add_child(boss_form)
	tree.root.add_child(cap2)
	boss_form.setup_unit(EnemyUnit.Archetype.BOSS_GALAGA, 0, 1, 0, Vector3(3, 5, -50), player)
	cap2.setup_unit(EnemyUnit.Archetype.CAPTURED_FIGHTER, 0, 1, 0, Vector3(3, 7, -50), player)
	boss_form.attach_captured_fighter(cap2)
	boss_form.state = EnemyUnit.State.FORMATION
	boss_form.take_damage(2)
	t.eq(cap2.state, EnemyUnit.State.CAPTURED_HOSTILE, "formation boss kill turns captured ship hostile")
	t.eq(gs.fighter_mode, gs.FighterMode.SINGLE, "formation kill does NOT grant DUAL")

	# 4. Direct friendly fire on captured ship destroys it cleanly without crashing boss
	var boss_ff: EnemyUnit = enemy_scene.instantiate()
	var cap3: EnemyUnit = enemy_scene.instantiate()
	tree.root.add_child(boss_ff)
	tree.root.add_child(cap3)
	boss_ff.setup_unit(EnemyUnit.Archetype.BOSS_GALAGA, 0, 2, 0, Vector3(-3, 5, -50), player)
	cap3.setup_unit(EnemyUnit.Archetype.CAPTURED_FIGHTER, 0, 2, 0, Vector3(-3, 7, -50), player)
	boss_ff.attach_captured_fighter(cap3)
	cap3.take_damage(1)
	boss_ff.state = EnemyUnit.State.DIVING
	boss_ff.take_damage(2)
	t.eq(gs.fighter_mode, gs.FighterMode.SINGLE, "shot captured ship cannot grant DUAL")

	cap2.queue_free()
	player.queue_free()
	t.finish(tree, "test_enemy_and_tractor")
