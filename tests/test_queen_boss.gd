extends RefCounted


func run(tree: SceneTree) -> void:
	var t := TestAssert.new()
	var gs: Node = tree.root.get_node("GameState")
	gs.reset_run()

	var player: PlayerFighter = load("res://scenes/player/player_fighter.tscn").instantiate()
	tree.root.add_child(player)

	var boss: QueenBoss = load("res://scenes/enemies/queen_boss.tscn").instantiate()
	tree.root.add_child(boss)
	var defeated := {"flag": false, "award": 0}
	boss.boss_defeated.connect(func(award: int) -> void:
		defeated["flag"] = true
		defeated["award"] = award
	)
	boss.setup_boss(5, player)

	# Stage 5 HP: flanks = 18 + 10 = 28, core = 40 + 20 = 60
	t.eq(boss.left_hp, 28, "stage 5 left cannon HP = 28")
	t.eq(boss.right_hp, 28, "stage 5 right hangar HP = 28")
	t.eq(boss.core_hp, 60, "stage 5 core HP = 60")
	t.eq(boss.phase, 1, "starts in phase 1")

	# Core takes 50% damage while flanks live
	var dealt_p1: int = boss.apply_part_damage("core", 10)
	t.eq(dealt_p1, 5, "armored core takes 50% damage")
	t.eq(boss.core_hp, 55, "core HP reduced by 5")

	# Destroying both flanks exposes Phase 2 (100% damage)
	boss.apply_part_damage("cannon", 28)
	t.eq(boss.phase, 1, "still phase 1 while hangar lives")
	boss.apply_part_damage("hangar", 28)
	t.eq(boss.phase, 2, "phase 2 activates once both flanks destroyed")

	var dealt_p2: int = boss.apply_part_damage("core", 10)
	t.eq(dealt_p2, 10, "exposed core takes 100% damage")
	boss.apply_part_damage("core", 45)
	t.is_true(defeated["flag"], "boss defeated emitted")
	t.eq(defeated["award"], 5000, "stage 5 victory award = 5000")
	t.eq(gs.shield_count, 1, "boss defeat grants +1 shield")

	player.queue_free()
	t.finish(tree, "test_queen_boss")
