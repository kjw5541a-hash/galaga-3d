extends RefCounted


func run(tree: SceneTree) -> void:
	var t := TestAssert.new()
	var gs: Node = tree.root.get_node("GameState")
	var sfx: Node = tree.root.get_node("SfxManager")

	var tmp_path := "user://test_galaga3d_save.cfg"
	gs.set("save_path", tmp_path)
	var abs_tmp: String = ProjectSettings.globalize_path(tmp_path)
	if FileAccess.file_exists(tmp_path):
		DirAccess.remove_absolute(abs_tmp)

	# 1. Missing save file loads gracefully without crashing
	gs.set("high_score", 0)
	gs.set("best_stage", 1)
	var load_missing_err: Error = gs.call("load_profile")
	t.is_true(load_missing_err != OK, "missing save returns non-OK gracefully")
	t.eq(gs.get("high_score"), 0, "default high_score preserved on missing file")

	# 2. Save & reload high_score, best_stage, and muted audio preference
	gs.reset_run()
	gs.add_score(12340)
	gs.advance_stage()
	gs.advance_stage()
	t.eq(gs.get("best_stage"), 3, "advance_stage tracks best_stage")
	sfx.set("is_muted", true)
	t.eq(gs.call("save_profile"), OK, "save_profile writes config file")

	gs.set("high_score", 0)
	gs.set("best_stage", 1)
	sfx.set("is_muted", false)
	t.eq(gs.call("load_profile"), OK, "load_profile restores saved config")
	t.eq(gs.get("high_score"), 12340, "high_score restored from disk")
	t.eq(gs.get("best_stage"), 3, "best_stage restored from disk")
	t.eq(sfx.get("is_muted"), true, "mute preference restored from disk")

	# 3. Accuracy math & per-run reset behavior
	gs.reset_run()
	t.approx(gs.call("get_accuracy_pct"), 0.0, 0.01, "0/0 shots yields 0% accuracy")
	gs.call("record_shot_fired", 4)
	gs.call("record_shot_hit", 3)
	gs.call("record_enemy_destroyed", 2)
	t.approx(gs.call("get_accuracy_pct"), 75.0, 0.01, "3/4 shots yields 75% accuracy")
	gs.call("record_shot_hit", 5)
	t.approx(gs.call("get_accuracy_pct"), 100.0, 0.01, "accuracy clamps at 100%")
	t.eq(gs.get("enemies_destroyed"), 2, "enemies_destroyed tracked")

	gs.reset_run()
	t.eq(gs.get("shots_fired"), 0, "reset_run clears shots_fired")
	t.eq(gs.get("shots_hit"), 0, "reset_run clears shots_hit")
	t.eq(gs.get("enemies_destroyed"), 0, "reset_run clears enemies_destroyed")
	t.eq(gs.get("high_score"), 12340, "reset_run preserves high_score")
	t.eq(gs.get("best_stage"), 3, "reset_run preserves best_stage")

	# 4. HUD game over screen shows classic hit-miss ratio summary
	gs.call("record_shot_fired", 10)
	gs.call("record_shot_hit", 6)
	gs.call("record_enemy_destroyed", 5)
	var hud: HUD = load("res://scenes/ui/hud.tscn").instantiate()
	tree.root.add_child(hud)
	hud.show_game_over(5000, 12340)
	var hint_txt: String = (hud.get("_overlay_hint") as Label).text
	t.is_true(hint_txt.contains("60.0%"), "game over summary displays hit-miss ratio")
	t.is_true(hint_txt.contains("SHOTS 10"), "game over summary displays shots fired")
	hud.queue_free()

	# Cleanup temp file & restore default state
	if FileAccess.file_exists(tmp_path):
		DirAccess.remove_absolute(abs_tmp)
	sfx.set("is_muted", false)
	gs.set("save_path", gs.get("DEFAULT_SAVE_PATH"))

	t.finish(tree, "test_persistence_and_stats")
