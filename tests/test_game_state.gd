extends RefCounted


func run(tree: SceneTree) -> void:
	var t := TestAssert.new()
	var gs: Node = tree.root.get_node("GameState")
	gs.reset_run()

	# Stage cadence: % 5 -> BOSS, else % 3 -> CHALLENGE, else STANDARD
	t.eq(gs.get_stage_type(1), gs.StageType.STANDARD, "stage 1 standard")
	t.eq(gs.get_stage_type(2), gs.StageType.STANDARD, "stage 2 standard")
	t.eq(gs.get_stage_type(3), gs.StageType.CHALLENGE, "stage 3 challenge")
	t.eq(gs.get_stage_type(4), gs.StageType.STANDARD, "stage 4 standard")
	t.eq(gs.get_stage_type(5), gs.StageType.BOSS, "stage 5 boss")
	t.eq(gs.get_stage_type(6), gs.StageType.CHALLENGE, "stage 6 challenge")
	t.eq(gs.get_stage_type(10), gs.StageType.BOSS, "stage 10 boss")
	t.eq(gs.get_stage_type(15), gs.StageType.BOSS, "stage 15 boss overrides challenge")

	# Extra life at 20,000 and 90,000 (+70,000)
	t.eq(gs.lives, 3, "initial lives")
	gs.add_score(19900)
	t.eq(gs.lives, 3, "no extra life before 20k")
	gs.add_score(100)
	t.eq(gs.lives, 4, "extra life at 20k")
	gs.add_score(70000)
	t.eq(gs.lives, 5, "extra life at 90k")

	# Powerups & energy clamping
	gs.grant_powerup(gs.PowerupType.SHIELD)
	gs.grant_powerup(gs.PowerupType.SHIELD)
	t.eq(gs.shield_count, 1, "single mode shield cap is 1")
	gs.set_fighter_mode(gs.FighterMode.DUAL)
	gs.grant_powerup(gs.PowerupType.SHIELD)
	t.eq(gs.shield_count, 2, "dual mode shield cap is 2")
	gs.grant_powerup(gs.PowerupType.EMP)
	gs.grant_powerup(gs.PowerupType.EMP)
	gs.grant_powerup(gs.PowerupType.EMP)
	t.eq(gs.emp_charges, 2, "emp cap is 2")
	t.is_true(gs.spend_emp(), "spend emp 1")
	t.eq(gs.emp_charges, 1, "emp remaining 1")
	gs.grant_powerup(gs.PowerupType.RAPID)
	t.approx(gs.rapid_timer, 15.0, 0.01, "rapid starts at 15s")
	gs.tick_timers(5.0)
	t.approx(gs.rapid_timer, 10.0, 0.01, "rapid decays")

	# Wave scaling & splines
	t.approx(gs.get_wave_speed_mult(1), 1.0, 0.001, "stage 1 speed mult")
	t.approx(gs.get_wave_speed_mult(20), 1.8, 0.001, "speed mult caps at 1.8")
	t.eq(gs.get_max_divers(1), 2, "stage 1 max divers")
	t.eq(gs.get_max_divers(10), 5, "max divers caps at 5")

	var slot: Vector3 = WavePatterns.get_formation_slot_local(0, 0)
	t.is_true(slot.z < -40.0 and slot.z > -60.0, "formation slot in front depth band")
	var start_pt: Vector3 = WavePatterns.sample_entry_path(0, 0.0)
	t.is_true(start_pt.z <= -130.0, "entry starts in deep space")
	var ch_end: Vector3 = WavePatterns.sample_challenge_path(0, 1.0)
	t.is_true(ch_end.z >= 10.0, "challenge path exits past player")

	t.finish(tree, "test_game_state")
