extends Node
## Toca efeitos sonoros (pool de players), ambiente do cerrado e música.
## Os arquivos .wav ficam em res://assets/audio (gerados por tools/gen_audio.py).

const AUDIO_DIR := "res://assets/audio/"
const POOL_SIZE := 14

var _streams: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _ambience: AudioStreamPlayer
var _music: AudioStreamPlayer
var _last_play: Dictionary = {}
var _quitting := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus("SFX")
	_ensure_bus("Ambience")
	_ensure_bus("Music")
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	_ambience = AudioStreamPlayer.new()
	_ambience.bus = "Ambience"
	add_child(_ambience)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)
	Settings.apply_audio()
	get_tree().auto_accept_quit = false


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")


func _get_stream(sound: String) -> AudioStream:
	if _streams.has(sound):
		return _streams[sound]
	var path := AUDIO_DIR + sound + ".wav"
	var stream: AudioStream = null
	if ResourceLoader.exists(path):
		stream = load(path)
	_streams[sound] = stream
	return stream


## Toca um som. `variants` > 1 sorteia entre nome_1..nome_N.
func play(sound: String, volume_db: float = 0.0, pitch: float = 1.0, pitch_jitter: float = 0.0,
		variants: int = 0, min_interval: float = 0.0) -> void:
	if _quitting:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if min_interval > 0.0 and now - float(_last_play.get(sound, -100.0)) < min_interval:
		return
	_last_play[sound] = now
	var key := sound
	if variants > 0:
		key = "%s_%d" % [sound, randi_range(1, variants)]
	var stream := _get_stream(key)
	if stream == null:
		return
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = maxf(0.05, pitch + randf_range(-pitch_jitter, pitch_jitter))
	p.play()


func start_ambience() -> void:
	var s := _get_stream("amb_cerrado")
	if s == null or (_ambience.playing and _ambience.stream == s):
		return
	_make_loop(s)
	_ambience.stream = s
	_ambience.volume_db = -6.0
	_ambience.play()


func start_music() -> void:
	var s := _get_stream("music_violao")
	if s == null or (_music.playing and _music.stream == s):
		return
	_make_loop(s)
	_music.stream = s
	_music.volume_db = -9.0
	_music.play()


func _make_loop(s: AudioStream) -> void:
	var wav := s as AudioStreamWAV
	if wav == null:
		return
	if wav.loop_mode == AudioStreamWAV.LOOP_DISABLED:
		wav.loop_begin = 0
		wav.loop_end = int(wav.get_length() * float(wav.mix_rate))
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD


func set_music_duck(amount: float) -> void:
	if _music:
		_music.volume_db = lerpf(-9.0, -20.0, clampf(amount, 0.0, 1.0))


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_game()


## Fecha o jogo parando os sons antes (o mixer precisa de alguns quadros para
## soltá-los; assim o Godot não acusa recursos presos ao sair).
func quit_game() -> void:
	if _quitting:
		return
	_quitting = true
	_release_all()
	for _i in 4:
		await get_tree().process_frame
	await get_tree().create_timer(0.08, true, false, true).timeout
	get_tree().quit()


func _release_all() -> void:
	for p in _pool:
		p.stop()
		p.stream = null
	for p in [_ambience, _music]:
		if p:
			p.stop()
			p.stream = null
	_streams.clear()


func _exit_tree() -> void:
	_release_all()
