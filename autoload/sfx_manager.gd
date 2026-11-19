extends Node

const SAMPLE_RATE := 22050
const MAX_VOICES := 6

signal mute_changed(muted: bool)

var is_muted: bool = false

var _players: Array[AudioStreamPlayer] = []
var _bgm_player: AudioStreamPlayer = null
var _bgm_stream: AudioStreamWAV = null
var _voice_idx: int = 0
var _streams: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i: int in range(MAX_VOICES):
		var p := AudioStreamPlayer.new()
		p.volume_db = -8.0
		add_child(p)
		_players.append(p)
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.volume_db = -17.0
	add_child(_bgm_player)
	_build_presets()


func play(sfx_name: String) -> void:
	if is_muted or DisplayServer.get_name() == "headless":
		return
	if not _streams.has(sfx_name):
		return
	var p: AudioStreamPlayer = _players[_voice_idx]
	_voice_idx = (_voice_idx + 1) % _players.size()
	p.stream = _streams[sfx_name]
	p.play()


func start_bgm() -> void:
	if DisplayServer.get_name() == "headless" or not is_instance_valid(_bgm_player):
		return
	if _bgm_stream == null:
		_bgm_stream = build_bgm_stream()
	_bgm_player.stream = _bgm_stream
	_bgm_player.volume_db = -80.0 if is_muted else -17.0
	if not _bgm_player.playing:
		_bgm_player.play()


func stop_bgm() -> void:
	if is_instance_valid(_bgm_player) and _bgm_player.playing:
		_bgm_player.stop()


func set_bgm_ducked(ducked: bool) -> void:
	if not is_instance_valid(_bgm_player) or is_muted:
		return
	_bgm_player.volume_db = -25.0 if ducked else -17.0


func toggle_mute() -> void:
	is_muted = not is_muted
	if is_instance_valid(_bgm_player):
		_bgm_player.volume_db = -80.0 if is_muted else -17.0
	mute_changed.emit(is_muted)


func build_bgm_stream() -> AudioStreamWAV:
	# 16 eighth-note steps at 150 BPM (0.20s/step = 3.2s seamless retro-synthwave loop)
	var bass_notes: Array[float] = [
		110.0, 110.0, 130.81, 110.0, 146.83, 146.83, 130.81, 123.47,
		98.0, 98.0, 110.0, 123.47, 130.81, 146.83, 164.81, 130.81,
	]
	var arp_notes: Array[float] = [
		440.0, 523.25, 659.25, 523.25, 587.33, 659.25, 783.99, 659.25,
		392.0, 493.88, 587.33, 493.88, 523.25, 659.25, 783.99, 659.25,
	]
	var step_samples: int = int(SAMPLE_RATE * 0.20)
	var total: int = step_samples * bass_notes.size()
	var data := PackedByteArray()
	data.resize(total * 2)
	var bass_phase: float = 0.0
	var arp_phase: float = 0.0
	for n: int in range(bass_notes.size()):
		var bf: float = bass_notes[n]
		var af: float = arp_notes[n]
		for i: int in range(step_samples):
			var u: float = float(i) / float(maxi(1, step_samples - 1))
			bass_phase += TAU * bf / float(SAMPLE_RATE)
			arp_phase += TAU * af / float(SAMPLE_RATE)
			var bass_env: float = (1.0 - u * 0.55) * minf(1.0, u * 30.0)
			var arp_env: float = (1.0 - u * 0.80) * minf(1.0, u * 35.0)
			var saw: float = 2.0 * fmod(bass_phase / TAU, 1.0) - 1.0
			var pulse: float = 1.0 if sin(arp_phase) >= 0.0 else -1.0
			var s: float = (saw * 0.22 * bass_env) + (pulse * 0.11 * arp_env)
			var idx: int = (n * step_samples + i) * 2
			data.encode_s16(idx, clampi(int(s * 32767.0), -32768, 32767))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = total
	wav.data = data
	return wav


func _build_presets() -> void:
	_streams["laser"] = _make_sweep(980.0, 320.0, 0.09, "square", 0.35)
	_streams["lockon"] = _make_sweep(660.0, 1320.0, 0.07, "sine", 0.30)
	_streams["missile"] = _make_sweep(220.0, 620.0, 0.22, "noise_mix", 0.40)
	_streams["hit"] = _make_sweep(420.0, 180.0, 0.08, "square", 0.35)
	_streams["explode"] = _make_sweep(190.0, 45.0, 0.28, "noise", 0.55)
	_streams["boss_explode"] = _make_sweep(150.0, 30.0, 0.65, "noise", 0.70)
	_streams["tractor"] = _make_sweep(300.0, 520.0, 0.45, "wobble", 0.35)
	_streams["dock"] = _make_arpeggio([523.25, 659.25, 783.99, 1046.5], 0.09, 0.38)
	_streams["powerup"] = _make_arpeggio([440.0, 554.37, 659.25, 880.0], 0.07, 0.35)
	_streams["emp"] = _make_sweep(880.0, 60.0, 0.42, "noise_mix", 0.55)
	_streams["stage_clear"] = _make_arpeggio([392.0, 523.25, 659.25, 783.99], 0.11, 0.38)


func _make_sweep(f0: float, f1: float, duration: float, wave: String, gain: float) -> AudioStreamWAV:
	var count: int = int(SAMPLE_RATE * duration)
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase: float = 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = int(f0 * 17.0 + duration * 1000.0)
	for i: int in range(count):
		var u: float = float(i) / float(maxi(1, count - 1))
		var freq: float = lerpf(f0, f1, u)
		if wave == "wobble":
			freq += sin(u * TAU * 7.0) * 90.0
		phase += TAU * freq / float(SAMPLE_RATE)
		var env: float = (1.0 - u) * minf(1.0, u * 25.0)
		var s: float = 0.0
		match wave:
			"square":
				s = 1.0 if sin(phase) >= 0.0 else -1.0
			"noise":
				s = rng.randf_range(-1.0, 1.0)
			"noise_mix":
				s = 0.55 * sin(phase) + 0.45 * rng.randf_range(-1.0, 1.0)
			_:
				s = sin(phase)
		var sample_i16: int = clampi(int(s * env * gain * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, sample_i16)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = data
	return wav


func _make_arpeggio(freqs: Array, step_dur: float, gain: float) -> AudioStreamWAV:
	var step_samples: int = int(SAMPLE_RATE * step_dur)
	var total: int = step_samples * freqs.size()
	var data := PackedByteArray()
	data.resize(total * 2)
	var phase: float = 0.0
	for n: int in range(freqs.size()):
		var freq: float = float(freqs[n])
		for i: int in range(step_samples):
			var u: float = float(i) / float(maxi(1, step_samples - 1))
			phase += TAU * freq / float(SAMPLE_RATE)
			var env: float = (1.0 - u * 0.7) * minf(1.0, u * 20.0)
			var s: float = 0.65 * sin(phase) + 0.35 * (1.0 if sin(phase * 2.0) >= 0.0 else -1.0)
			var idx: int = (n * step_samples + i) * 2
			data.encode_s16(idx, clampi(int(s * env * gain * 32767.0), -32768, 32767))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = data
	return wav
