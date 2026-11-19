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
var _hitstop_end_usec: int = 0
var _last_boss_pos: Vector3 = Vector3(0.0, 1.5, -55.0)


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


func _exit_tree() -> void:
	_clear_hitstop()


func trigger_hitstop(duration: float = 0.055) -> void:
	if duration <= 0.0 or get_tree().paused:
		return
	var target_end: int = Time.get_ticks_usec() + int(duration * 1000000.0)
	_hitstop_end_usec = maxi(_hitstop_end_usec, target_end)
	Engine.time_scale = 0.08


func _clear_hitstop() -> void:
	_hitstop_end_usec = 0
	Engine.time_scale = 1.0


func _on_emp_triggered() -> void:
	_shake_trauma = minf(1.0, _shake_trauma + 0.55)
	var origin: Vector3 = _player.global_position if is_instance_valid(_player) else Vector3.ZERO
	VfxBurst.spawn_shockwave(_world_root, origin, Color(0.68, 0.32, 1.0), 22.0, 0.55)


func _build_environment_and_tunnel() -> void:
	# Peripheral 3D starfield (hollow ring outside combat corridor, below glow threshold)
	var stars := GPUParticles3D.new()
	stars.amount = 180
	stars.lifetime = 3.8
	stars.preprocess = 3.8
	stars.position = Vector3(0.0, 0.0, -175.0)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3(0.0, 0.0, 1.0)
	pm.emission_ring_height = 12.0
	pm.emission_ring_radius = 70.0
	pm.emission_ring_inner_radius = 24.0
	pm.direction = Vector3(0.0, 0.0, 1.0)
	pm.spread = 0.0
	pm.initial_velocity_min = 38.0
	pm.initial_velocity_max = 60.0
	pm.gravity = Vector3.ZERO
	stars.process_material = pm
	var star_mesh := BoxMesh.new()
	star_mesh.size = Vector3(0.055, 0.055, 1.2)
	var star_mat := StandardMaterial3D.new()
	star_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	star_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	star_mat.albedo_color = Color(0.42, 0.56, 0.82, 0.56)
	star_mesh.material = star_mat
	stars.draw_pass_1 = star_mesh
	add_child(stars)

	# Subtle outer corridor depth rings (below glow threshold so enemies stay foreground focus)
	var ring_mat := MeshFactory.make_neon_mat(Color(0.10, 0.24, 0.55), Color(0.10, 0.28, 0.62), 0.42, 0.14)
	for i: int in range(8):
		var mi := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 27.5
		tm.outer_radius = 27.72
		mi.mesh = tm
		mi.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		mi.position = Vector3(0.0, 0.0, -20.0 - float(i) * 22.0)
		mi.material_override = ring_mat
		add_child(mi)
		_depth_rings.append(mi)


func _start_new_run() -> void:
	_run_id += 1
	_clear_hitstop()
	get_tree().paused = false
	_clear_world()
	GameState.reset_run()
	SfxManager.start_bgm()
	SfxManager.set_bgm_ducked(false)
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
	trigger_hitstop(0.045)
	if is_instance_valid(_player):
		VfxBurst.spawn(_world_root, _player.global_position, Color(1.0, 0.45, 0.2), 1.35, 8, 0.38)


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
			boss.boss_part_destroyed.connect(_on_boss_part_destroyed)
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


func _on_boss_part_destroyed(world_pos: Vector3) -> void:
	_last_boss_pos = world_pos
	_shake_trauma = minf(1.0, _shake_trauma + 0.65)
	trigger_hitstop(0.055)


func _on_boss_defeated(award: int) -> void:
	if _transitioning or GameState.is_game_over:
		return
	_transitioning = true
	var run_token: int = _run_id
	if is_instance_valid(_active_encounter):
		_last_boss_pos = _active_encounter.global_position
	_shake_trauma = 1.0
	trigger_hitstop(0.085)
	_hud.set_boss_bar(false)
	_hud.show_banner("DREADNOUGHT DESTROYED", "+%d  |  SHIELD RECHARGED" % award, 3.0)
	var offsets: Array[Vector3] = [
		Vector3(-4.5, 1.5, 2.0),
		Vector3(4.5, -1.2, 2.0),
		Vector3(0.0, 2.2, 3.0),
	]
	for off: Vector3 in offsets:
		await get_tree().create_timer(0.28, false).timeout
		if run_token != _run_id or GameState.is_game_over or not _in_run:
			return
		_shake_trauma = minf(1.0, _shake_trauma + 0.45)
		VfxBurst.spawn(_world_root, _last_boss_pos + off, Color(1.0, 0.42, 0.16), 2.6, 10, 0.55)
		SfxManager.play("explode")
	await get_tree().create_timer(2.3, false).timeout
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
	_clear_hitstop()
	SfxManager.stop_bgm()
	_in_run = false
	_hud.set_boss_bar(false)
	_hud.show_game_over(GameState.score, GameState.high_score)


func _toggle_pause() -> void:
	if not _in_run or GameState.is_game_over:
		return
	var next_pause: bool = not get_tree().paused
	if next_pause:
		_clear_hitstop()
	get_tree().paused = next_pause
	SfxManager.set_bgm_ducked(next_pause)
	_hud.show_pause(next_pause)


func _process(delta: float) -> void:
	if _hitstop_end_usec > 0 and Time.get_ticks_usec() >= _hitstop_end_usec:
		_clear_hitstop()
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
	var desired := Vector3(p.x * 0.30, p.y * 0.55 + 2.4, 12.5)
	_camera.global_position = _camera.global_position.lerp(desired, clampf(6.0 * delta, 0.0, 1.0))
	if _shake_trauma > 0.0:
		var amp: float = _shake_trauma * _shake_trauma * 0.65
		_camera.global_position += Vector3(randf_range(-amp, amp), randf_range(-amp, amp), 0.0)
		_shake_trauma = maxf(0.0, _shake_trauma - delta * 2.2)
	_fov_kick = lerpf(_fov_kick, 0.0, clampf(6.0 * delta, 0.0, 1.0))
	_camera.fov = 60.0 + _fov_kick
	_camera.look_at(Vector3(p.x * 0.18, p.y * 0.30, -35.0), Vector3.UP)
