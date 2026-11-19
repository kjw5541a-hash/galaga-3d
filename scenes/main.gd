extends Node3D

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player_fighter.tscn")
const FORMATION_SCENE: PackedScene = preload("res://scenes/enemies/formation_manager.tscn")
const BOSS_SCENE: PackedScene = preload("res://scenes/enemies/queen_boss.tscn")

var _camera: Camera3D
var _hud: HUD
var _world_root: Node3D
var _player: PlayerFighter = null
var _active_encounter: Node3D = null
var _depth_rings: Array[MeshInstance3D] = []
var _shake_trauma: float = 0.0
var _fov_kick: float = 0.0
var _in_run: bool = false
var _transitioning: bool = false
var _run_id: int = 0


func _ready() -> void:
	_camera = $Camera3D
	_hud = $HUD
	_world_root = $WorldRoot
	_build_environment_and_tunnel()
	_hud.start_requested.connect(_start_new_run)
	_hud.restart_requested.connect(_start_new_run)
	_hud.resume_requested.connect(_toggle_pause)
	_hud.pause_toggle_requested.connect(_toggle_pause)
	GameState.game_over_triggered.connect(_on_game_over)
	GameState.emp_triggered.connect(_on_emp_triggered)
	_hud.show_title(true)


func _on_emp_triggered() -> void:
	_shake_trauma = minf(1.0, _shake_trauma + 0.55)


func _build_environment_and_tunnel() -> void:
	# Streaming 3D starfield GPUParticles3D
	var stars := GPUParticles3D.new()
	stars.amount = 360
	stars.lifetime = 3.2
	stars.preprocess = 3.2
	stars.position = Vector3(0.0, 0.0, -175.0)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(45.0, 26.0, 4.0)
	pm.direction = Vector3(0.0, 0.0, 1.0)
	pm.spread = 0.0
	pm.initial_velocity_min = 52.0
	pm.initial_velocity_max = 88.0
	pm.gravity = Vector3.ZERO
	stars.process_material = pm
	var star_mesh := BoxMesh.new()
	star_mesh.size = Vector3(0.14, 0.14, 1.8)
	star_mesh.material = MeshFactory.make_neon_mat(Color(0.85, 0.95, 1.0), Color(0.7, 0.9, 1.0), 2.4)
	stars.draw_pass_1 = star_mesh
	add_child(stars)

	# Neon corridor depth rings for speed reference
	var ring_mat := MeshFactory.make_neon_mat(Color(0.15, 0.45, 0.95), Color(0.15, 0.5, 1.0), 1.6, 0.22)
	for i: int in range(8):
		var mi := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 22.0
		tm.outer_radius = 22.28
		mi.mesh = tm
		mi.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		mi.position = Vector3(0.0, 0.0, -20.0 - float(i) * 22.0)
		mi.material_override = ring_mat
		add_child(mi)
		_depth_rings.append(mi)


func _start_new_run() -> void:
	_run_id += 1
	get_tree().paused = false
	_clear_world()
	GameState.reset_run()
	_hud.show_title(false)
	_hud.show_pause(false)
	_hud.set_boss_bar(false)
	_player = PLAYER_SCENE.instantiate()
	_world_root.add_child(_player)
	_player.respawn_single()
	_player.damaged.connect(_on_player_damaged)
	_player.barrel_roll_started.connect(_on_barrel_roll_started)
	_player.captured_by_boss.connect(_on_player_captured)
	_in_run = true
	_transitioning = false
	_launch_stage(GameState.stage)


func _on_player_damaged(_remaining_lives: int) -> void:
	_shake_trauma = minf(1.0, _shake_trauma + 0.65)


func _on_barrel_roll_started() -> void:
	_fov_kick = 5.0


func _clear_world() -> void:
	for c: Node in _world_root.get_children():
		c.queue_free()
	_player = null
	_active_encounter = null


func _launch_stage(stage_num: int) -> void:
	for proj: Node in get_tree().get_nodes_in_group("enemy_projectiles"):
		if is_instance_valid(proj):
			proj.queue_free()
	if is_instance_valid(_active_encounter):
		_active_encounter.queue_free()
		_active_encounter = null
	var st: GameState.StageType = GameState.get_stage_type(stage_num)
	match st:
		GameState.StageType.BOSS:
			_hud.show_banner("WARNING: STAGE %d" % stage_num, "QUEEN GALAGA DREADNOUGHT", 2.4)
			var boss: QueenBoss = BOSS_SCENE.instantiate()
			_world_root.add_child(boss)
			boss.setup_boss(stage_num, _player)
			boss.boss_hp_changed.connect(func(r: float, ph: int) -> void: _hud.set_boss_bar(true, r, ph))
			boss.boss_defeated.connect(_on_boss_defeated)
			_active_encounter = boss
		GameState.StageType.CHALLENGE:
			_hud.set_boss_bar(false)
			_hud.show_banner("CHALLENGE STAGE %d" % stage_num, "DESTROY ALL 40 DRONES FOR +10,000 PERFECT", 2.4)
			var fm: FormationManager = FORMATION_SCENE.instantiate()
			_world_root.add_child(fm)
			fm.start_challenge_stage(stage_num, _player)
			fm.challenge_completed.connect(_on_challenge_completed)
			_active_encounter = fm
		_:
			_hud.set_boss_bar(false)
			_hud.show_banner("STAGE %d" % stage_num, "INTERCEPT INCOMING FORMATION", 2.0)
			var fm: FormationManager = FORMATION_SCENE.instantiate()
			_world_root.add_child(fm)
			fm.start_standard_wave(stage_num, _player)
			fm.wave_cleared.connect(_on_wave_cleared)
			_active_encounter = fm


func _on_wave_cleared() -> void:
	if _transitioning or GameState.is_game_over:
		return
	_transitioning = true
	var run_token: int = _run_id
	SfxManager.play("stage_clear")
	_hud.show_banner("STAGE %d CLEAR" % GameState.stage, "PREPARING NEXT WAVE", 2.0)
	await get_tree().create_timer(2.2, false).timeout
	if run_token == _run_id and not GameState.is_game_over and _in_run:
		GameState.advance_stage()
		_transitioning = false
		_launch_stage(GameState.stage)


func _on_challenge_completed(hits: int, total: int, wave_bonuses: int, perfect_bonus: int) -> void:
	if _transitioning or GameState.is_game_over:
		return
	_transitioning = true
	var run_token: int = _run_id
	SfxManager.play("stage_clear")
	var sub: String = "HITS %d/%d  |  WAVE +%d  |  PERFECT +%d" % [hits, total, wave_bonuses, perfect_bonus]
	_hud.show_banner("CHALLENGE COMPLETE", sub, 3.0)
	await get_tree().create_timer(3.2, false).timeout
	if run_token == _run_id and not GameState.is_game_over and _in_run:
		GameState.advance_stage()
		_transitioning = false
		_launch_stage(GameState.stage)


func _on_boss_defeated(award: int) -> void:
	if _transitioning or GameState.is_game_over:
		return
	_transitioning = true
	var run_token: int = _run_id
	_shake_trauma = 1.0
	_hud.set_boss_bar(false)
	_hud.show_banner("DREADNOUGHT DESTROYED", "+%d  |  SHIELD RECHARGED" % award, 3.0)
	await get_tree().create_timer(3.2, false).timeout
	if run_token == _run_id and not GameState.is_game_over and _in_run:
		GameState.advance_stage()
		_transitioning = false
		_launch_stage(GameState.stage)


func _on_player_captured(_boss: Node3D) -> void:
	_shake_trauma = 0.8
	if GameState.is_game_over:
		return
	var run_token: int = _run_id
	_hud.show_banner("FIGHTER CAPTURED!", "DESTROY BOSS WHILE DIVING TO RESCUE", 2.2)
	await get_tree().create_timer(1.5, false).timeout
	if run_token == _run_id and is_instance_valid(_player) and not GameState.is_game_over:
		_player.respawn_single()


func _on_game_over() -> void:
	_in_run = false
	_hud.set_boss_bar(false)
	_hud.show_game_over(GameState.score, GameState.high_score)


func _toggle_pause() -> void:
	if not _in_run or GameState.is_game_over:
		return
	var next_pause: bool = not get_tree().paused
	get_tree().paused = next_pause
	_hud.show_pause(next_pause)


func _process(delta: float) -> void:
	# Scroll neon corridor depth rings
	for ring: MeshInstance3D in _depth_rings:
		ring.position.z += 58.0 * delta
		if ring.position.z > 16.0:
			ring.position.z -= 176.0

	if not _in_run or get_tree().paused:
		return

	GameState.tick_timers(delta)
	_update_camera(delta)
	if is_instance_valid(_player):
		_hud.update_lockon_brackets(_camera, _player.get_locked_targets())


func _update_camera(delta: float) -> void:
	if not is_instance_valid(_player):
		return
	var p: Vector3 = _player.global_position
	var desired := Vector3(p.x * 0.25, p.y * 0.20 + 3.2, 12.5)
	_camera.global_position = _camera.global_position.lerp(desired, clampf(6.0 * delta, 0.0, 1.0))
	if _shake_trauma > 0.0:
		var amp: float = _shake_trauma * _shake_trauma * 0.65
		_camera.global_position += Vector3(randf_range(-amp, amp), randf_range(-amp, amp), 0.0)
		_shake_trauma = maxf(0.0, _shake_trauma - delta * 2.2)
	_fov_kick = lerpf(_fov_kick, 0.0, clampf(6.0 * delta, 0.0, 1.0))
	_camera.fov = 60.0 + _fov_kick
	_camera.look_at(Vector3(p.x * 0.15, p.y * 0.10, -35.0), Vector3.UP)
