extends Node
## Ads. On a phone they come from the NeonAds Android plugin (AdMob). Anywhere
## else there are no ads: interstitials are skipped and rewards are just given.

## Real ad units only in the Google Play build (export preset "Android Store", feature
## "store"). Test APKs keep Google's test units, so tapping ads while testing is safe.
const STORE := {
	"interstitial": "ca-app-pub-3684983257311025/9983191325",
	"rewarded": "ca-app-pub-3684983257311025/3617305550",
	"banner": "ca-app-pub-3684983257311025/5265217114",
}
const TEST := {
	"interstitial": "ca-app-pub-3940256099942544/1033173712",
	"rewarded": "ca-app-pub-3940256099942544/5224354917",
	"banner": "ca-app-pub-3940256099942544/6300978111",
}
var _units: Dictionary = STORE if OS.has_feature("store") else TEST
var INTERSTITIAL_ID: String = _units.interstitial
var REWARDED_ID: String = _units.rewarded
var BANNER_ID: String = _units.banner

var _ads: Object
var _after_interstitial := Callable()
var _on_reward := Callable()
var _after_rewarded := Callable()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if Engine.has_singleton("NeonAds"):
		_ads = Engine.get_singleton("NeonAds")
		_ads.interstitial_closed.connect(_interstitial_closed)
		_ads.rewarded_closed.connect(_rewarded_closed)
		_ads.start(INTERSTITIAL_ID, REWARDED_ID)
	schedule_reminders()


var banner_on := false


## A small banner ad: along the bottom on the menu and score card, along the top
## edge during a shift (where it covers only sky, not the bar).
func show_banner(top := false) -> void:
	banner_on = true
	# (no has_method check: Android plugin methods don't show up in has_method)
	if _ads:
		_ads.showBanner(BANNER_ID, top)


func hide_banner() -> void:
	banner_on = false
	if _ads:
		_ads.hideBanner()


## True where the law asks for a way to change ad consent (UK, EEA, some US states).
func privacy_options_required() -> bool:
	return _ads != null and _ads.isPrivacyOptionsRequired()


## Google Play's rating card over the game (Google decides if and how often it shows).
func request_review() -> void:
	if _ads:
		_ads.requestReview()


## Opens Google's consent form so the player can change their ad choices.
func show_privacy_options() -> void:
	if _ads:
		_ads.showPrivacyOptions()


## Whether a reward video can be shown right now.
func rewarded_ready() -> bool:
	return _ads == null or _ads.isRewardedReady()


## Shows a full-screen ad if one is loaded, then calls [param done] either way.
func show_interstitial(done: Callable) -> void:
	if _ads and _ads.showInterstitial():
		_after_interstitial = done
		Audio.duck(true)
	else:
		done.call()


## Shows a reward video. [param reward] runs only if it was watched to the end;
## [param done] runs afterwards either way.
func show_rewarded(reward: Callable, done := Callable()) -> void:
	if _ads == null:
		reward.call()
		if done.is_valid():
			done.call()
		return
	if _ads.showRewarded():
		_on_reward = reward
		_after_rewarded = done
		Audio.duck(true)
	elif done.is_valid():
		done.call()


func _interstitial_closed() -> void:
	Audio.duck(false)
	var f := _after_interstitial
	_after_interstitial = Callable()
	if f.is_valid():
		f.call()


func _rewarded_closed(earned: bool) -> void:
	Audio.duck(false)
	if earned and _on_reward.is_valid():
		_on_reward.call()
	var f := _after_rewarded
	_on_reward = Callable()
	_after_rewarded = Callable()
	if f.is_valid():
		f.call()


# ------------------------------------------------------------------ reminders
# The game sets its own reminder notifications on the phone (no server). One a day
# at 7 pm for the next 3 days; they are re-set each time the game is opened or put
# away, so a player who stops playing gets 3 reminders and then no more.

const REMINDER_HOUR := 19


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		schedule_reminders()


## Asks once (Android 13+) for permission to show notifications.
func ask_notifications() -> void:
	if _ads:
		_ads.requestNotificationPermission()


func schedule_reminders() -> void:
	if _ads == null:
		return
	var pool: Array = Recipes.DRINKS.slice(0, maxi(1, Save.unlocked))
	var special: String = Recipes.drink_name(pool[randi() % pool.size()])
	var titles := PackedStringArray([
		"Your bar opens tonight 🍸",
		"Guests are waiting at the bar",
		"Your shaker misses you",
	])
	var bodies := PackedStringArray([
		"Tonight's special: %s. Can you get 3 stars?" % special,
		"Beat your best score of %d in a 90-second shift." % Save.best_score if Save.best_score > 0 else "A quick 90-second shift is waiting for you.",
		"%d recipes are still locked. Come and learn the next one!" % maxi(0, Recipes.DRINKS.size() - Save.unlocked) if Save.unlocked < Recipes.DRINKS.size() else "Can you make every drink from memory?",
	])
	_ads.scheduleReminders(titles, bodies, REMINDER_HOUR)
