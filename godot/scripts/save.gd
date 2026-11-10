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
var bartender := "" ## "remy" (Leo) or "louise" (Mia); "" = not chosen yet
var sound := true
var music := true
var asked_notify := false
var best_score := 0 ## best shift score, for the NEW BEST! on the score card
var owned: Array = ["tools_steel", "lights_warm"] ## shop items bought
var tool_skin := "steel"
var light_theme := "warm"
var boosts := {} ## one-shift boosts waiting: "patience" / "tips" -> true
var review_asked: Array = [] ## shift counts at which Google's rating card was offered
var gift_day := "" ## the last day ("YYYY-MM-DD", phone's local date) the daily tips jar was opened
var day_streak := 0 ## days in a row the tips jar was opened
var challenge_day := "" ## the last day the daily challenge was done

## Tips jar coins for day 1..7 of a streak; day 8 starts the week again.
const GIFTS := [20, 30, 40, 50, 70, 90, 150]
const CHALLENGE_COINS := 100


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


## Local date as "YYYY-MM-DD", [param days_ago] days back.
static func day_key(days_ago := 0) -> String:
	var bias: int = int(Time.get_time_zone_from_system().get("bias", 0))
	return Time.get_date_string_from_unix_time(int(Time.get_unix_time_from_system()) + bias * 60 - days_ago * 86400)


func gift_waiting() -> bool:
	return gift_day != day_key()


## The streak day the jar will count when opened today (1 if a day was missed).
func next_streak() -> int:
	return day_streak + 1 if gift_day == day_key(1) else 1


func gift_coins(day: int) -> int:
	return GIFTS[(maxi(day, 1) - 1) % GIFTS.size()]


## Opens today's tips jar: returns the coins added (0 if already opened today).
func open_gift() -> int:
	if not gift_waiting():
		return 0
	day_streak = next_streak()
	gift_day = day_key()
	var c := gift_coins(day_streak)
	coins += c
	save()
	return c


## Today's challenge drink: the same for the whole day, picked from the open recipes.
func challenge_drink() -> Dictionary:
	var pool: Array = Recipes.DRINKS.slice(0, maxi(1, unlocked))
	return pool[absi(day_key().hash()) % pool.size()]


func challenge_done() -> bool:
	return challenge_day == day_key()


## Marks today's challenge done if [param id] with [param stars] meets it; returns the coins won.
func try_challenge(id: String, stars: float) -> int:
	if challenge_done() or stars < 3.0 or id != challenge_drink().id:
		return 0
	challenge_day = day_key()
	coins += CHALLENGE_COINS
	return CHALLENGE_COINS


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
	owned = data.get("owned", owned)
	tool_skin = str(data.get("tool_skin", "steel"))
	light_theme = str(data.get("light_theme", "warm"))
	boosts = data.get("boosts", {})
	review_asked = data.get("review_asked", []).map(func(x): return int(x))
	gift_day = str(data.get("gift_day", ""))
	day_streak = int(data.get("day_streak", 0))
	challenge_day = str(data.get("challenge_day", ""))
	if mocktail_locked():
		mocktail = true


func save() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({
		"coins": coins, "unlocked": unlocked, "made": made, "best": best, "shifts": shifts,
		"birth_year": birth_year, "mocktail": mocktail, "sound": sound, "music": music, "best_score": best_score, "asked_notify": asked_notify, "bartender": bartender,
		"owned": owned, "tool_skin": tool_skin, "light_theme": light_theme, "boosts": boosts,
		"review_asked": review_asked, "gift_day": gift_day, "day_streak": day_streak, "challenge_day": challenge_day,
	}))
