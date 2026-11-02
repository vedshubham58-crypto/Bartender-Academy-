extends Node
## Sound effects and the bar's crowd ambience. All sounds are made by tools/make_sounds.py.

const LOOPS := ["pour", "shake", "crowd"]

var _sfx := {}
var _players: Array[AudioStreamPlayer] = []
var _loops := {}
var _music: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for n in ["clink", "ice", "pour", "shake", "tip", "click", "good", "bad", "slide", "muddle", "crowd"]:
		var s: AudioStreamWAV = load("res://audio/%s.wav" % n)
		if n in LOOPS:
			s = s.duplicate()
			s.loop_mode = AudioStreamWAV.LOOP_FORWARD
			s.loop_begin = 0
			s.loop_end = s.data.size() / 2
		_sfx[n] = s
	for k in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	for n in LOOPS:
		var p := AudioStreamPlayer.new()
		p.stream = _sfx[n]
		add_child(p)
		_loops[n] = p
	# upbeat house music, made by tools/make_music_party.py, loops forever under everything
	_music = AudioStreamPlayer.new()
	var m: AudioStreamOggVorbis = load("res://audio/music_party.ogg")
	m.loop = true
	_music.stream = m
	_music.volume_db = -11.0
	add_child(_music)
	if Save.sound and Save.music and not _music.playing:
		_music.play()


func play(name: String, volume_db := 0.0, pitch := 1.0) -> void:
	if not Save.sound:
		return
	for p in _players:
		if not p.playing:
			p.stream = _sfx[name]
			p.volume_db = volume_db
			p.pitch_scale = pitch
			p.play()
			return


## Starts or stops a looping sound (pour, shake, crowd).
func loop(name: String, on: bool, volume_db := 0.0) -> void:
	var p: AudioStreamPlayer = _loops[name]
	p.volume_db = volume_db
	if on and Save.sound:
		if not p.playing:
			p.play()
	else:
		p.stop()


func set_sound(on: bool) -> void:
	Save.sound = on
	Save.save()
	if not on:
		for p in _loops.values():
			p.stop()
		_music.stop()
	elif Save.music and not _music.playing:
		_music.play()


## Music on or off, separate from the sound effects.
func set_music(on: bool) -> void:
	Save.music = on
	Save.save()
	if on and Save.sound:
		if not _music.playing:
			_music.play()
	else:
		_music.stop()


## Silences the game while a full-screen ad plays.
func duck(on: bool) -> void:
	AudioServer.set_bus_mute(0, on)
