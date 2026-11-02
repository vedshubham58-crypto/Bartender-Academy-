extends Node
## Player progress, kept in user://save.json.

const PATH := "user://save.json"

var coins := 0
var unlocked := 3 ## how many drinks (from the start of Recipes.DRINKS) are open
var made := {} ## drink id -> times served
var best := {} ## drink id -> best stars
var shifts := 0
var birth_year := 0 ## 0 = not asked yet
var mocktail := false
var bartender := "" ## "david" or "louise"; "" = not chosen yet
var sound := true
var music := true
var asked_notify := false
var best_score := 0 ## best shift score, for the NEW BEST! on the score card


func _ready() -> void:
	load_game()


func is_adult() -> bool:
	return birth_year > 0 and Time.get_date_dict_from_system().year - birth_year >= 18


## Under-18 players always get mocktail mode.
func mocktail_locked() -> bool:
	return birth_year > 0 and not is_adult()


## A drink you've made well a few times hides its answers on the ticket.
func learned(id: String) -> bool:
	return made.get(id, 0) >= 3 and best.get(id, 0.0) >= 2.5


func record(id: String, stars: float) -> void:
	made[id] = made.get(id, 0) + 1
	best[id] = maxf(best.get(id, 0.0), stars)


func load_game() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(data) != TYPE_DICTIONARY:
		return
	coins = int(data.get("coins", 0))
	unlocked = int(data.get("unlocked", 3))
	made = data.get("made", {})
	best = data.get("best", {})
	shifts = int(data.get("shifts", 0))
	birth_year = int(data.get("birth_year", 0))
	mocktail = bool(data.get("mocktail", false))
	sound = bool(data.get("sound", true))
	music = bool(data.get("music", true))
	best_score = int(data.get("best_score", 0))
	asked_notify = bool(data.get("asked_notify", false))
	bartender = str(data.get("bartender", ""))
	if mocktail_locked():
		mocktail = true


func save() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({
		"coins": coins, "unlocked": unlocked, "made": made, "best": best, "shifts": shifts,
		"birth_year": birth_year, "mocktail": mocktail, "sound": sound, "music": music, "best_score": best_score, "asked_notify": asked_notify, "bartender": bartender,
	}))
