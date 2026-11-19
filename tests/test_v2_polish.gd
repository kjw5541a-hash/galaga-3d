extends RefCounted


func run(tree: SceneTree) -> void:
	var t := TestAssert.new()
	var gs: Node = tree.root.get_node("GameState")
	var sfx: Node = tree.root.get_node("SfxManager")
	gs.reset_run()

	# 1. VfxBurst spawns shards/ring and auto-frees after duration
	var burst: VfxBurst = VfxBurst.spawn(tree.root, Vector3(1.0, 2.0, -20.0), Color(1.0, 0.5, 0.1), 1.2, 6, 0.4)
	t.is_true(is_instance_valid(burst) and burst.get_child_count() >= 7, "VfxBurst spawns shards + shockwave ring")
	burst.step_vfx(0.2)
	t.is_true(not burst.is_queued_for_deletion(), "VfxBurst stays alive mid-duration")
	burst.step_vfx(0.25)
	t.is_true(burst.is_queued_for_deletion(), "VfxBurst auto-frees once duration elapses")

	# 2. QueenBoss sweeping cannon beam + part_destroyed signal + cleanup on cannon kill
	var player: PlayerFighter = load("res://scenes/player/player_fighter.tscn").instantiate()
	tree.root.add_child(player)
	player.global_position = Vector3(0.0, 0.0, 0.0)
	player.invuln_timer = 0.0
	var boss: QueenBoss = load("res://scenes/enemies/queen_boss.tscn").instantiate()
	tree.root.add_child(boss)
	boss.setup_boss(5, player)
	boss.set("_entering", false)
	boss.global_position = Vector3(0.0, 1.5, -55.0)
	var part_hits := {"count": 0}
	boss.boss_part_destroyed.connect(func(_pos: Vector3) -> void: part_hits["count"] += 1)

	boss.start_sweeping_laser()
	t.is_true(boss.is_cannon_beam_active(), "QueenBoss sweeping laser activates")
	# Advance past 0.45s telegraph into sweep crossing X=0
	var lives_before: int = gs.lives
	for _i: int in range(18):
		boss._physics_process(0.05)
	t.is_true(gs.lives < lives_before, "sweeping cannon laser damages player crossing beam path")

	# Destroying left cannon immediately clears active sweep beam and emits boss_part_destroyed
	boss.start_sweeping_laser()
	t.is_true(boss.is_cannon_beam_active(), "second sweeping laser active before cannon break")
	boss.apply_part_damage("cannon", boss.left_hp)
	t.is_true(not boss.is_cannon_beam_active(), "destroying cannon immediately cancels sweeping beam")
	t.eq(part_hits["count"], 1, "destroying cannon emits boss_part_destroyed")
	boss.queue_free()
	player.queue_free()

	# 3. Main hit-stop safely restores Engine.time_scale on game over / new run
	var main_inst: Node = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main_inst)
	main_inst.call("_start_new_run")
	main_inst.call("trigger_hitstop", 0.06)
	t.is_true(Engine.time_scale < 0.5, "hit-stop slows Engine.time_scale")
	main_inst.call("_on_game_over")
	t.approx(Engine.time_scale, 1.0, 0.001, "game over restores Engine.time_scale to 1.0")
	main_inst.queue_free()

	# 4. SfxManager procedural BGM stream + mute toggle
	var bgm: AudioStreamWAV = sfx.call("build_bgm_stream")
	t.is_true(bgm != null and bgm.data.size() > 1000, "SfxManager builds non-empty BGM WAV")
	t.eq(bgm.loop_mode, AudioStreamWAV.LOOP_FORWARD, "BGM WAV configured for forward loop")
	var muted_start: bool = sfx.get("is_muted")
	sfx.call("toggle_mute")
	t.eq(sfx.get("is_muted"), not muted_start, "toggle_mute flips mute state")
	sfx.call("toggle_mute")
	t.eq(sfx.get("is_muted"), muted_start, "second toggle_mute restores state")

	t.finish(tree, "test_v2_polish")
