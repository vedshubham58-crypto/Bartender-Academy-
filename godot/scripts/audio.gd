extends Node
## Sound effects and the bar's crowd ambience. All sounds are made by tools/make_sounds.py.

const LOOPS := ["pour", "shake", "crowd"]

var _sfx := {}
var _players: Array[AudioStreamPlayer] = []
var _loops := {}
var _music: AudioStreamPlayer
var _radio_timer: Timer
var _track := ""

## The bar's music, all made by tools/make_music_party.py and tools/make_music_tracks.py.
## id -> [file, name shown on the menu, volume dB]
const TRACKS := {
	"house": ["music_party", "HOUSE", -11.0],
	"tropical": ["music_tropical", "TROPICAL", -11.0],
	"disco": ["music_disco", "DISCO", -10.5],
	"lounge": ["music_lounge", "LOUNGE JAZZ", -12.5],
}
## What the MUSIC button steps through.
const STYLES := ["radio", "house", "tropical", "disco", "lounge", "off"]
## Each bar's own sound, first on the radio there.
const VENUE_TRACK := {"rooftop": "house", "beach": "tropical", "hotel": "disco", "speakeasy": "lounge"}
## How many times a track plays before the radio moves on.
const RADIO_PLAYS := 2
## Music sits on its own bus, a bit under the effects, and dips further while the
## player pours, shakes or muddles (and briefly after a result sound), so the
## effects never fight the music.
const MUSIC_BUS_DB := -4.0
const MUSIC_DUCK_DB := -9.0
const DUCK_AFTER_SFX := 1.2
const DUCK_SOUNDS := ["good", "bad", "tip", "muddle", "pour", "shake", "ice", "clink"]
var _music_bus := -1
var _duck_left := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for n in ["clink", "ice", "pour", "shake", "tip", "click", "good", "bad", "slide", "muddle", "crowd"]:
		# Loops restart from the finished signal below instead of WAV loop points:
		# hand-set loop points crashed the Android audio thread on some phones.
		_sfx[n] = load("res://audio/%s.wav" % n)
	for k in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	for n in LOOPS:
		var p := AudioStreamPlayer.new()
		p.stream = _sfx[n]
		p.finished.connect(p.play)
		add_child(p)
		_loops[n] = p
	_music_bus = AudioServer.get_bus_index("Music")
	if _music_bus == -1:
		AudioServer.add_bus()
		_music_bus = AudioServer.bus_count - 1
		AudioServer.set_bus_name(_music_bus, "Music")
		AudioServer.set_bus_send(_music_bus, "Master")
	AudioServer.set_bus_volume_db(_music_bus, MUSIC_BUS_DB)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)
	_radio_timer = Timer.new()
	_radio_timer.one_shot = true
	_radio_timer.timeout.connect(_next_on_radio)
	add_child(_radio_timer)
	call_deferred("start_music")


func play(name: String, volume_db := 0.0, pitch := 1.0) -> void:
	if not Save.sound:
		return
	for p in _players:
		if not p.playing:
			p.stream = _sfx[name]
			p.volume_db = volume_db
			p.pitch_scale = pitch
			p.play()
			if name in DUCK_SOUNDS:
				_duck_left = maxf(_duck_left, minf(p.stream.get_length() / pitch, 2.0) + DUCK_AFTER_SFX * 0.5)
			return


## Smoothly dips the music while effects are playing.
func _process(delta: float) -> void:
	if _music_bus == -1:
		return
	if _loops["pour"].playing or _loops["shake"].playing:
		_duck_left = DUCK_AFTER_SFX
	else:
		_duck_left = maxf(_duck_left - delta, 0.0)
	var busy := _duck_left > 0.0
	var target := MUSIC_BUS_DB + (MUSIC_DUCK_DB if busy else 0.0)
	var cur := AudioServer.get_bus_volume_db(_music_bus)
	# fast dip (~0.15 s), slower recovery (~0.8 s)
	var speed := 60.0 if target < cur else 11.0
	AudioServer.set_bus_volume_db(_music_bus, move_toward(cur, target, speed * delta))


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


## Music on or off, separate from the sound effects.
func set_music(on: bool) -> void:
	Save.music = on
	Save.save()
	start_music()


## The MUSIC button: radio -> each track -> off -> radio.
func next_style() -> void:
	var i := STYLES.find(Save.music_style if Save.music else "off")
	var nxt: String = STYLES[(i + 1) % STYLES.size()]
	Save.music = nxt != "off"
	if Save.music:
		Save.music_style = nxt
	Save.save()
	start_music()


## Menu label for the music button.
func style_name() -> String:
	if not Save.music:
		return "OFF"
	if Save.music_style == "radio":
		return "RADIO"
	return TRACKS.get(Save.music_style, ["", "RADIO"])[1]


## (Re)starts the music for the current setting and bar.
func start_music() -> void:
	_radio_timer.stop()
	if not Save.music:
		_music.stop()
		_track = ""
		return
	if Save.music_style == "radio" or not TRACKS.has(Save.music_style):
		_play_track(VENUE_TRACK.get(Save.venue, "house") if _track == "" else _track, true)
	else:
		_play_track(Save.music_style, false)


func _play_track(id: String, radio: bool) -> void:
	var stream: AudioStreamOggVorbis = load("res://audio/%s.ogg" % TRACKS[id][0])
	stream.loop = true
	if _track != id or not _music.playing:
		_music.stream = stream
		_music.volume_db = TRACKS[id][2]
		_music.play()
	_track = id
	if radio:
		_radio_timer.start(stream.get_length() * RADIO_PLAYS)


## Radio: fade the current track out and the next one in.
func _next_on_radio() -> void:
	if not Save.music or Save.music_style != "radio":
		return
	var ids := TRACKS.keys()
	var nxt: String = ids[(ids.find(_track) + 1) % ids.size()]
	var tw := create_tween()
	tw.tween_property(_music, "volume_db", -40.0, 1.5)
	tw.tween_callback(func():
		_track = ""
		_play_track(nxt, true)
		var to: float = _music.volume_db
		_music.volume_db = -40.0
		create_tween().tween_property(_music, "volume_db", to, 1.5))


## Silences the game while a full-screen ad plays.
func duck(on: bool) -> void:
	AudioServer.set_bus_mute(0, on)
