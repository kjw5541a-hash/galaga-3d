extends RefCounted


func run(tree: SceneTree) -> void:
	var t := TestAssert.new()
	var gs: Node = tree.root.get_node("GameState")
	gs.reset_run()

	var player: PlayerFighter = load("res://scenes/player/player_fighter.tscn").instantiate()
	tree.root.add_child(player)

	var fm: FormationManager = load("res://scenes/enemies/formation_manager.tscn").instantiate()
	tree.root.add_child(fm)
	fm.start_standard_wave(1, player)

	# Review Focus #2: Tractor beam preconditions
	fm.tractor_cooldown = 0.0
	t.is_true(fm.can_start_tractor_beam(), "tractor allowed when SINGLE, no capture, cd=0")
	gs.set_fighter_mode(gs.FighterMode.DUAL)
	t.is_true(not fm.can_start_tractor_beam(), "tractor blocked when DUAL")
	gs.set_fighter_mode(gs.FighterMode.SINGLE)

	var boss1: EnemyUnit = load("res://scenes/enemies/enemy_unit.tscn").instantiate()
	var boss2: EnemyUnit = load("res://scenes/enemies/enemy_unit.tscn").instantiate()
	tree.root.add_child(boss1)
	tree.root.add_child(boss2)
	boss1.setup_unit(EnemyUnit.Archetype.BOSS_GALAGA, 0, 0, 0, Vector3(-3, 5, -50), player)
	boss2.setup_unit(EnemyUnit.Archetype.BOSS_GALAGA, 0, 1, 0, Vector3(3, 5, -50), player)
	boss1.state = EnemyUnit.State.FORMATION
	boss2.state = EnemyUnit.State.FORMATION
	t.is_true(fm.try_trigger_tractor_beam(boss1), "first boss acquires tractor slot")
	t.is_true(not fm.try_trigger_tractor_beam(boss2), "second concurrent boss rejected")
	boss1.queue_free()
	boss2.queue_free()

	# Review Focus #5: Challenge Stage with 39 destroyed + 1 escaped still finishes cleanly (no perfect bonus)
	var fm2: FormationManager = load("res://scenes/enemies/formation_manager.tscn").instantiate()
	tree.root.add_child(fm2)
	var summary := {"done": false, "hits": 0, "wb": 0, "pb": 0}
	fm2.challenge_completed.connect(func(h: int, _tot: int, wb: int, pb: int) -> void:
		summary["done"] = true
		summary["hits"] = h
		summary["wb"] = wb
		summary["pb"] = pb
	)
	fm2.start_challenge_stage(3, player)
	for w: int in range(5):
		for k: int in range(8):
			var destroyed_flag: bool = not (w == 4 and k == 7)
			fm2.report_challenge_outcome(w, destroyed_flag)
	t.is_true(summary["done"], "challenge finishes when destroyed+escaped == 40")
	t.eq(summary["hits"], 39, "39 hits recorded")
	t.eq(summary["wb"], 4000, "4 full waves cleared -> +4000")
	t.eq(summary["pb"], 0, "no perfect bonus at 39/40")

	# Perfect 40/40 awards +5000 wave bonuses + 10000 perfect bonus
	var fm3: FormationManager = load("res://scenes/enemies/formation_manager.tscn").instantiate()
	tree.root.add_child(fm3)
	var perfect := {"pb": 0, "wb": 0}
	fm3.challenge_completed.connect(func(_h: int, _tot: int, wb: int, pb: int) -> void:
		perfect["wb"] = wb
		perfect["pb"] = pb
	)
	fm3.start_challenge_stage(3, player)
	for w: int in range(5):
		for k: int in range(8):
			fm3.report_challenge_outcome(w, true)
	t.eq(perfect["wb"], 5000, "5 full waves cleared -> +5000")
	t.eq(perfect["pb"], 10000, "40/40 awards +10000 perfect bonus")

	fm.queue_free()
	fm2.queue_free()
	fm3.queue_free()
	player.queue_free()
	t.finish(tree, "test_formation_manager")
