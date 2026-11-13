extends Node

## Central audio service. All sounds are generated locally at runtime, so the
## game has no remote audio dependency and remains playable offline.
const SAMPLE_RATE := 22050
const SETTINGS_PATH := "user://audio_settings.cfg"
const EFFECT_POOL_SIZE := 4

var music_enabled := true
var ambient_enabled := true
var sfx_enabled := true
var master_volume := 0.8
var music_volume := 0.42
var ambient_volume := 0.24
var sfx_volume := 0.72
var audio_ready := false

var _music_player: AudioStreamPlayer
var _ambient_player: AudioStreamPlayer
var _effect_players: Array[AudioStreamPlayer] = []
var _effect_streams: Dictionary = {}
var _next_effect_player := 0


func _ready() -> void:
	_load_settings()
	_build_players()
	_build_local_audio_library()
	_connect_game_events()
	_apply_volumes()
	audio_ready = true
	if music_enabled:
		_music_player.play()
	if ambient_enabled:
		_ambient_player.play()


func _build_players() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.bus = "Master"
	add_child(_music_player)

	_ambient_player = AudioStreamPlayer.new()
	_ambient_player.name = "AmbientPlayer"
	_ambient_player.bus = "Master"
	add_child(_ambient_player)

	for index in range(EFFECT_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.name = "EffectPlayer%d" % index
		player.bus = "Master"
		add_child(player)
		_effect_players.append(player)


func _build_local_audio_library() -> void:
	_music_player.stream = _generate_stream("music", 12.0, true)
	_ambient_player.stream = _generate_stream("ambient", 10.0, true)
	_effect_streams = {
		"ui_click": _generate_stream("ui_click", 0.10, false),
		"construction_start": _generate_stream("construction_start", 0.34, false),
		"construction_complete": _generate_stream("construction_complete", 0.72, false),
		"collect": _generate_stream("collect", 0.38, false),
		"reward": _generate_stream("reward", 0.92, false),
		"error": _generate_stream("error", 0.24, false)
	}


func _generate_stream(kind: String, duration: float, should_loop: bool) -> AudioStreamWAV:
	var sample_count := maxi(1, roundi(SAMPLE_RATE * duration))
	var pcm := PackedByteArray()
	pcm.resize(sample_count * 2)
	for sample_index in range(sample_count):
		var time := float(sample_index) / float(SAMPLE_RATE)
		var value := 0.0
		match kind:
			"music":
				var chord_index := int(floor(time / 3.0)) % 4
				var chord_sets := [
					[130.81, 164.81, 196.00],
					[110.00, 146.83, 174.61],
					[87.31, 130.81, 164.81],
					[98.00, 146.83, 196.00]
				]
				var chord: Array = chord_sets[chord_index]
				var swell := 0.72 + 0.28 * sin(TAU * time / 12.0)
				value = (sin(TAU * float(chord[0]) * time) * 0.34
					+ sin(TAU * float(chord[1]) * time) * 0.22
					+ sin(TAU * float(chord[2]) * time) * 0.16) * swell * 0.12
				var melody_notes := [261.63, 293.66, 329.63, 392.00, 349.23, 329.63, 293.66, 261.63]
				var note_step := int(floor(time * 1.333)) % melody_notes.size()
				var note_phase := fmod(time, 0.75)
				var note_envelope := exp(-note_phase * 3.8)
				value += sin(TAU * float(melody_notes[note_step]) * time) * note_envelope * 0.035
			"ambient":
				var slow_wind := sin(TAU * 0.11 * time) * 0.45 + sin(TAU * 0.17 * time + 1.2) * 0.25
				var airy_tone := sin(TAU * 392.0 * time) * 0.12 + sin(TAU * 523.25 * time) * 0.08
				value = (slow_wind * 0.55 + airy_tone) * 0.055
			"ui_click":
				value = sin(TAU * lerpf(1050.0, 720.0, time / duration) * time) * (1.0 - time / duration) * 0.20
			"construction_start":
				var envelope := maxf(0.0, 1.0 - time / duration)
				value = (sin(TAU * 180.0 * time) * 0.55 + sin(TAU * 270.0 * time) * 0.25) * envelope * 0.28
			"construction_complete":
				var notes := [523.25, 659.25, 783.99]
				var note_index := mini(2, int(floor(time / 0.20)))
				var local_time := fmod(time, 0.20)
				value = sin(TAU * float(notes[note_index]) * time) * exp(-local_time * 5.0) * 0.24
			"collect":
				value = (sin(TAU * 880.0 * time) + sin(TAU * 1174.66 * time) * 0.45) * exp(-time * 8.0) * 0.18
			"reward":
				var reward_notes := [523.25, 659.25, 783.99, 1046.50]
				var reward_index := mini(3, int(floor(time / 0.20)))
				value = sin(TAU * float(reward_notes[reward_index]) * time) * exp(-fmod(time, 0.20) * 3.2) * 0.22
			"error":
				value = (sin(TAU * 220.0 * time) + sin(TAU * 164.81 * time) * 0.4) * (1.0 - time / duration) * 0.18
		var fade := 1.0
		if not should_loop and kind not in ["music", "ambient"]:
			fade = minf(1.0, time * 45.0) * minf(1.0, (duration - time) * 18.0)
		pcm.encode_s16(sample_index * 2, roundi(clampf(value * fade, -1.0, 1.0) * 32767.0))

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = pcm
	if should_loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = sample_count
	return stream


func _connect_game_events() -> void:
	_connect_signal(BuildManager, "construction_started", _on_construction_started)
	_connect_signal(BuildManager, "construction_finished", _on_construction_finished)
	_connect_signal(ProductionManager, "item_produced", _on_item_produced)
	_connect_signal(EconomyManager, "transaction_completed", _on_transaction_completed)
	_connect_signal(GameManager, "level_up_rewarded", _on_level_up_rewarded)
	_connect_signal(AchievementManager, "achievement_unlocked", _on_achievement_unlocked)


func _connect_signal(source: Object, signal_name: StringName, callback: Callable) -> void:
	if source == null or not source.has_signal(signal_name):
		return
	if not source.is_connected(signal_name, callback):
		source.connect(signal_name, callback)


func _apply_volumes() -> void:
	var master_bus := AudioServer.get_bus_index("Master")
	if master_bus >= 0:
		AudioServer.set_bus_mute(master_bus, master_volume <= 0.001)
		AudioServer.set_bus_volume_db(master_bus, linear_to_db(maxf(master_volume, 0.001)))
	if is_instance_valid(_music_player):
		_music_player.volume_db = linear_to_db(maxf(music_volume, 0.001))
	if is_instance_valid(_ambient_player):
		_ambient_player.volume_db = linear_to_db(maxf(ambient_volume, 0.001))
	for player in _effect_players:
		player.volume_db = linear_to_db(maxf(sfx_volume, 0.001))


func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	_apply_volumes()
	_save_settings()


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_apply_volumes()
	_save_settings()


func set_ambient_volume(value: float) -> void:
	ambient_volume = clampf(value, 0.0, 1.0)
	_apply_volumes()
	_save_settings()


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_apply_volumes()
	_save_settings()


func set_music_enabled(enabled: bool) -> void:
	music_enabled = enabled
	if is_instance_valid(_music_player):
		if enabled and not _music_player.playing:
			_music_player.play()
		elif not enabled:
			_music_player.stop()
	_save_settings()


func set_ambient_enabled(enabled: bool) -> void:
	ambient_enabled = enabled
	if is_instance_valid(_ambient_player):
		if enabled and not _ambient_player.playing:
			_ambient_player.play()
		elif not enabled:
			_ambient_player.stop()
	_save_settings()


func set_sfx_enabled(enabled: bool) -> void:
	sfx_enabled = enabled
	_save_settings()


func play_ui_click() -> void:
	_play_effect("ui_click")


func play_error() -> void:
	_play_effect("error")


func _play_effect(effect_id: String) -> void:
	if not sfx_enabled or not _effect_streams.has(effect_id) or _effect_players.is_empty():
		return
	var player := _effect_players[_next_effect_player]
	_next_effect_player = (_next_effect_player + 1) % _effect_players.size()
	player.stop()
	player.stream = _effect_streams[effect_id]
	player.volume_db = linear_to_db(maxf(sfx_volume, 0.001))
	player.play()


func _on_construction_started(_building_id: String) -> void:
	_play_effect("construction_start")


func _on_construction_finished(_building_id: String) -> void:
	_play_effect("construction_complete")


func _on_item_produced(_item_id: String, _amount: int) -> void:
	_play_effect("collect")


func _on_transaction_completed(transaction_type: String, _amount: int) -> void:
	if transaction_type == "simoleons_gain":
		_play_effect("collect")


func _on_level_up_rewarded(_new_level: int, _simoleons: int, _keys: int) -> void:
	_play_effect("reward")


func _on_achievement_unlocked(_id: String, _title: String, _simoleons: int, _xp: int) -> void:
	_play_effect("reward")


func is_audio_ready() -> bool:
	return audio_ready and is_instance_valid(_music_player) and is_instance_valid(_ambient_player) and _effect_streams.size() == 6


func get_audio_status() -> Dictionary:
	return {
		"ready": is_audio_ready(),
		"music_enabled": music_enabled,
		"ambient_enabled": ambient_enabled,
		"sfx_enabled": sfx_enabled,
		"music_stream": _music_player.stream if is_instance_valid(_music_player) else null,
		"ambient_stream": _ambient_player.stream if is_instance_valid(_ambient_player) else null,
		"effect_count": _effect_streams.size()
	}


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	music_enabled = bool(config.get_value("audio", "music_enabled", music_enabled))
	ambient_enabled = bool(config.get_value("audio", "ambient_enabled", ambient_enabled))
	sfx_enabled = bool(config.get_value("audio", "sfx_enabled", sfx_enabled))
	master_volume = clampf(float(config.get_value("audio", "master_volume", master_volume)), 0.0, 1.0)
	music_volume = clampf(float(config.get_value("audio", "music_volume", music_volume)), 0.0, 1.0)
	ambient_volume = clampf(float(config.get_value("audio", "ambient_volume", ambient_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(config.get_value("audio", "sfx_volume", sfx_volume)), 0.0, 1.0)


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "music_enabled", music_enabled)
	config.set_value("audio", "ambient_enabled", ambient_enabled)
	config.set_value("audio", "sfx_enabled", sfx_enabled)
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "ambient_volume", ambient_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	var error := config.save(SETTINGS_PATH)
	if error != OK:
		push_warning("Audio settings could not be saved: %s" % error)
