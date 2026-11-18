extends RefCounted


func run(tree: SceneTree) -> void:
	var t := TestAssert.new()
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	t.is_true(main_scene != null, "main.tscn loads cleanly")
	if main_scene == null:
		t.finish(tree, "run_headless_checks")
		return
	var main_inst: Node = main_scene.instantiate()
	tree.root.add_child(main_inst)
	main_inst.call("_start_new_run")
	t.is_true(main_inst.get("_player") != null, "new run spawns PlayerFighter")
	t.is_true(main_inst.get("_active_encounter") != null, "stage 1 spawns FormationManager")
	main_inst.call("_launch_stage", 3)
	var ch_enc: Node = main_inst.get("_active_encounter")
	t.is_true(ch_enc is FormationManager and (ch_enc as FormationManager).is_challenge, "stage 3 launches Challenge Stage")
	main_inst.call("_launch_stage", 5)
	t.is_true(main_inst.get("_active_encounter") is QueenBoss, "stage 5 launches QueenBoss")
	main_inst.queue_free()
	t.finish(tree, "run_headless_checks")
