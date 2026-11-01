extends Node
## Every drink, bottle, glass and garnish in the game. Specs are real classic
## recipes in ml, so what you learn here works behind a real bar.

## Bottles and other things you pour from.
## kind: "rail" sits in the speed rail, "station" sits on the work station.
## Brand names are made up on purpose: no real brands in the game.
const SOURCES := {
	"white_rum": {"brand": "COAST", "name": "White Rum", "kind": "rail", "liquid": Color(0.95, 0.95, 0.92), "label": Color(0.12, 0.42, 0.65)},
	"gold_rum": {"brand": "HARBOUR", "name": "Gold Rum", "kind": "rail", "liquid": Color(0.85, 0.52, 0.12), "label": Color(0.11, 0.07, 0.04)},
	"tequila": {"brand": "BLUE AGAVE", "name": "Silver Tequila", "kind": "rail", "liquid": Color(0.9, 0.95, 0.97), "label": Color(0.05, 0.23, 0.43)},
	"gin": {"brand": "NORTHWIND", "name": "Dry Gin", "kind": "rail", "liquid": Color(0.92, 0.96, 0.94), "label": Color(0.09, 0.29, 0.24)},
	"vodka": {"brand": "VELVET", "name": "Vodka", "kind": "rail", "liquid": Color(0.94, 0.95, 0.97), "label": Color(0.48, 0.11, 0.17)},
	"bourbon": {"brand": "OLD OAK", "name": "Bourbon", "kind": "rail", "liquid": Color(0.66, 0.33, 0.1), "label": Color(0.95, 0.89, 0.76)},
	"triple_sec": {"brand": "CITRINE", "name": "Triple Sec", "kind": "rail", "liquid": Color(0.96, 0.94, 0.85), "label": Color(0.77, 0.48, 0.06)},
	"coffee_liq": {"brand": "KAAPI", "name": "Coffee Liqueur", "kind": "rail", "liquid": Color(0.16, 0.09, 0.05), "label": Color(0.89, 0.72, 0.47)},
	"lime": {"brand": "", "name": "Lime Juice", "kind": "station", "liquid": Color(0.78, 0.88, 0.45)},
	"lemon": {"brand": "", "name": "Lemon Juice", "kind": "station", "liquid": Color(0.98, 0.92, 0.55)},
	"sugar": {"brand": "", "name": "Sugar Syrup", "kind": "station", "liquid": Color(0.97, 0.95, 0.88)},
	"cranberry": {"brand": "", "name": "Cranberry", "kind": "station", "liquid": Color(0.76, 0.07, 0.18)},
	"espresso": {"brand": "", "name": "Espresso", "kind": "station", "liquid": Color(0.2, 0.11, 0.05)},
	"bitters": {"brand": "", "name": "Aromatic Bitters", "kind": "station", "liquid": Color(0.45, 0.1, 0.05)},
	"soda": {"brand": "", "name": "Soda Water", "kind": "station", "liquid": Color(0.92, 0.97, 1.0)},
	"tonic": {"brand": "", "name": "Tonic Water", "kind": "station", "liquid": Color(0.93, 0.97, 1.0)},
	# Mocktail mode swaps the speed rail for these zero-proof bottles.
	"apple": {"brand": "ORCHARD", "name": "Apple Juice", "kind": "rail", "liquid": Color(0.93, 0.78, 0.35), "label": Color(0.2, 0.45, 0.15)},
	"pineapple": {"brand": "ORCHARD", "name": "Pineapple Juice", "kind": "rail", "liquid": Color(0.98, 0.85, 0.35), "label": Color(0.75, 0.55, 0.05)},
	"grapefruit": {"brand": "ORCHARD", "name": "Grapefruit Juice", "kind": "rail", "liquid": Color(0.98, 0.7, 0.6), "label": Color(0.8, 0.3, 0.3)},
	"cucumber": {"brand": "GARDEN", "name": "Cucumber Cordial", "kind": "rail", "liquid": Color(0.8, 0.95, 0.75), "label": Color(0.15, 0.4, 0.2)},
	"white_grape": {"brand": "ORCHARD", "name": "White Grape Juice", "kind": "rail", "liquid": Color(0.95, 0.93, 0.7), "label": Color(0.4, 0.5, 0.15)},
	"black_tea": {"brand": "ASSAM", "name": "Cold Black Tea", "kind": "rail", "liquid": Color(0.55, 0.27, 0.08), "label": Color(0.9, 0.8, 0.6)},
	"orange_juice": {"brand": "ORCHARD", "name": "Orange Juice", "kind": "rail", "liquid": Color(1.0, 0.65, 0.15), "label": Color(0.85, 0.4, 0.05)},
	"vanilla": {"brand": "GARDEN", "name": "Vanilla Syrup", "kind": "rail", "liquid": Color(0.97, 0.9, 0.75), "label": Color(0.45, 0.3, 0.15)},
}

## Spirit -> zero-proof swap used in mocktail mode.
const MOCKTAIL_SWAP := {
	"white_rum": "apple", "gold_rum": "pineapple", "tequila": "grapefruit", "gin": "cucumber",
	"vodka": "white_grape", "bourbon": "black_tea", "triple_sec": "orange_juice", "coffee_liq": "vanilla",
}

## Speed rail order, left to right.
const RAIL := ["white_rum", "tequila", "gin", "vodka", "bourbon", "triple_sec", "coffee_liq", "gold_rum"]
## Things on the work station, left to right on the right-hand board.
const STATION := ["lime", "lemon", "sugar", "cranberry", "soda", "tonic", "bitters", "espresso"]

const GLASSES := {
	"highball": {"name": "Highball", "ml": 300},
	"rocks": {"name": "Rocks", "ml": 250},
	"coupe": {"name": "Coupe", "ml": 180},
	"martini": {"name": "Martini", "ml": 180},
}
const ICE := {"cubes": "Cubes", "crushed": "Crushed", "big": "Big cube"}
const GARNISH := {
	"lime_wheel": "Lime wheel", "mint_sprig": "Mint sprig", "orange_twist": "Orange twist",
	"cherry": "Cherry", "coffee_beans": "3 coffee beans",
}
const RIMS := {"salt": "Salt rim", "sugar": "Sugar rim", "none": "No rim"}

## Step types: glass, rim, muddle, pour(src, ml), dash(src, n), top(src), ice, shake, stir, strain, garnish.
## Order of the list = the order you unlock them.
const DRINKS := [
	{
		"id": "gin_tonic", "name": "Gin & Tonic", "price": 30, "glass": "highball", "method": "Build",
		"about": "The simplest highball, and a great first drink. Lots of ice keeps it cold and fizzy.",
		"steps": [
			{"t": "glass", "v": "highball"}, {"t": "ice", "v": "cubes"}, {"t": "pour", "src": "gin", "ml": 50},
			{"t": "top", "src": "tonic"}, {"t": "garnish", "v": "lime_wheel"},
		],
		"home": ["Fill a tall glass to the top with ice.", "Pour 50 ml gin (use a shot glass: 1 shot is about 30 ml).", "Top up slowly with cold tonic, pouring down the side to keep the fizz.", "Squeeze in a lime wedge or add a lime wheel."],
		"mocktail": "Cucumber Tonic",
	},
	{
		"id": "daiquiri", "name": "Daiquiri", "price": 40, "glass": "coupe", "method": "Shake",
		"about": "The classic sour: 2 parts spirit, 1 part sour, a little sweet. Shake hard and serve straight up.",
		"steps": [
			{"t": "glass", "v": "coupe"}, {"t": "pour", "src": "white_rum", "ml": 50}, {"t": "pour", "src": "lime", "ml": 25},
			{"t": "pour", "src": "sugar", "ml": 15}, {"t": "ice", "v": "cubes"}, {"t": "shake"}, {"t": "strain"},
			{"t": "garnish", "v": "lime_wheel"},
		],
		"home": ["Chill a small glass in the freezer.", "In a jar add 50 ml white rum, 25 ml fresh lime juice and 15 ml sugar syrup (sugar dissolved 1:1 in hot water).", "Fill the jar with ice, close it and shake hard for 10 seconds.", "Strain through a tea strainer into the cold glass."],
		"mocktail": "Apple Lime Cooler",
	},
	{
		"id": "mojito", "name": "Mojito", "price": 45, "glass": "highball", "method": "Muddle & build",
		"about": "Press the mint gently to release its oil. Crushed ice and a soda top make it long and fresh.",
		"steps": [
			{"t": "glass", "v": "highball"}, {"t": "muddle"}, {"t": "pour", "src": "white_rum", "ml": 50},
			{"t": "pour", "src": "lime", "ml": 25}, {"t": "pour", "src": "sugar", "ml": 15}, {"t": "ice", "v": "crushed"},
			{"t": "top", "src": "soda"}, {"t": "garnish", "v": "mint_sprig"},
		],
		"home": ["Put 8 to 10 mint leaves and 2 lime wedges in a tall glass.", "Press them gently with a spoon handle. Don't shred the mint.", "Add 50 ml white rum, 25 ml lime juice and 15 ml sugar syrup.", "Fill with crushed ice (ice in a towel, hit with a rolling pin), top with soda and stir once.", "Slap a mint sprig between your hands and put it on top."],
		"mocktail": "Virgin Mojito",
	},
	{
		"id": "old_fashioned", "name": "Old Fashioned", "price": 55, "glass": "rocks", "method": "Stir",
		"about": "Spirit, sugar, bitters, ice. Stirring chills it without bubbles, so it stays silky.",
		"steps": [
			{"t": "glass", "v": "rocks"}, {"t": "pour", "src": "sugar", "ml": 10}, {"t": "dash", "src": "bitters", "n": 2},
			{"t": "pour", "src": "bourbon", "ml": 50}, {"t": "ice", "v": "big"}, {"t": "stir"},
			{"t": "garnish", "v": "orange_twist"},
		],
		"home": ["In a short glass add 10 ml sugar syrup and 2 dashes of bitters.", "Add 50 ml bourbon.", "Add one big ice cube (freeze water in a small box) and stir for 20 to 30 seconds.", "Squeeze a strip of orange peel over the drink, then drop it in."],
		"mocktail": "Smoked Tea Fashioned",
	},
	{
		"id": "whisky_sour", "name": "Whisky Sour", "price": 50, "glass": "rocks", "method": "Shake",
		"about": "A sour served on the rocks. Lemon instead of lime, and a cherry on top.",
		"steps": [
			{"t": "glass", "v": "rocks"}, {"t": "pour", "src": "bourbon", "ml": 50}, {"t": "pour", "src": "lemon", "ml": 25},
			{"t": "pour", "src": "sugar", "ml": 20}, {"t": "ice", "v": "cubes"}, {"t": "shake"}, {"t": "strain"},
			{"t": "garnish", "v": "cherry"},
		],
		"home": ["In a jar add 50 ml bourbon, 25 ml lemon juice and 20 ml sugar syrup.", "Add ice, close and shake hard for 10 seconds.", "Strain into a short glass full of fresh ice.", "Top with a cocktail cherry."],
		"mocktail": "Ginger Tea Sour",
	},
	{
		"id": "margarita", "name": "Margarita", "price": 55, "glass": "coupe", "method": "Shake",
		"about": "Tequila, orange liqueur and lime. The salt rim makes the citrus pop.",
		"steps": [
			{"t": "glass", "v": "coupe"}, {"t": "rim", "v": "salt"}, {"t": "pour", "src": "tequila", "ml": 50},
			{"t": "pour", "src": "triple_sec", "ml": 20}, {"t": "pour", "src": "lime", "ml": 25}, {"t": "ice", "v": "cubes"},
			{"t": "shake"}, {"t": "strain"}, {"t": "garnish", "v": "lime_wheel"},
		],
		"home": ["Run a lime wedge round the rim of a glass and dip it in salt.", "In a jar add 50 ml tequila, 20 ml orange liqueur and 25 ml lime juice.", "Add ice, shake hard for 10 seconds and strain into the glass.", "Add a lime wheel."],
		"mocktail": "Salty Grapefruit Cooler",
	},
	{
		"id": "cosmopolitan", "name": "Cosmopolitan", "price": 55, "glass": "martini", "method": "Shake",
		"about": "Vodka, orange liqueur, cranberry and lime, shaken and served in a martini glass.",
		"steps": [
			{"t": "glass", "v": "martini"}, {"t": "pour", "src": "vodka", "ml": 40}, {"t": "pour", "src": "triple_sec", "ml": 15},
			{"t": "pour", "src": "cranberry", "ml": 30}, {"t": "pour", "src": "lime", "ml": 15}, {"t": "ice", "v": "cubes"},
			{"t": "shake"}, {"t": "strain"}, {"t": "garnish", "v": "orange_twist"},
		],
		"home": ["Chill a stemmed glass.", "In a jar add 40 ml vodka, 15 ml orange liqueur, 30 ml cranberry juice and 15 ml lime juice.", "Add ice, shake hard and strain into the glass.", "Squeeze an orange peel over the top."],
		"mocktail": "Cranberry Grape Cosmo",
	},
	{
		"id": "espresso_martini", "name": "Espresso Martini", "price": 60, "glass": "coupe", "method": "Shake hard",
		"about": "Fresh hot espresso shaken very hard gives the thick foam on top.",
		"steps": [
			{"t": "glass", "v": "coupe"}, {"t": "pour", "src": "vodka", "ml": 50}, {"t": "pour", "src": "coffee_liq", "ml": 20},
			{"t": "pour", "src": "espresso", "ml": 30}, {"t": "pour", "src": "sugar", "ml": 10}, {"t": "ice", "v": "cubes"},
			{"t": "shake"}, {"t": "strain"}, {"t": "garnish", "v": "coffee_beans"},
		],
		"home": ["Make a fresh espresso (or 30 ml very strong coffee).", "In a jar add 50 ml vodka, 20 ml coffee liqueur, the coffee and 10 ml sugar syrup.", "Fill with ice and shake as hard as you can for 15 seconds.", "Strain into a chilled glass and float 3 coffee beans on the foam."],
		"mocktail": "Vanilla Cold Brew Shake",
	},
]


func drink(id: String) -> Dictionary:
	for d in DRINKS:
		if d.id == id:
			return d
	return {}


func index_of(id: String) -> int:
	for i in DRINKS.size():
		if DRINKS[i].id == id:
			return i
	return -1


## The source id actually used, after the mocktail swap.
func src(id: String) -> String:
	if Save.mocktail and MOCKTAIL_SWAP.has(id):
		return MOCKTAIL_SWAP[id]
	return id


func src_name(id: String) -> String:
	var s: Dictionary = SOURCES[src(id)]
	return s.name


func drink_name(d: Dictionary) -> String:
	return d.mocktail if Save.mocktail else d.name


## Rail bottles for the current mode.
func rail() -> Array:
	var out := []
	for id in RAIL:
		out.append(src(id))
	return out


## Short line describing one step, for tickets and the Bar Book.
## [param hint] false hides the answer (used once a drink is learned).
func step_text(s: Dictionary, hint := true) -> String:
	match s.t:
		"glass":
			return ("%s glass" % GLASSES[s.v].name) if hint else "Pick the glass"
		"rim":
			return RIMS[s.v] if hint else "Rim the glass"
		"muddle":
			return "Muddle mint + lime"
		"pour":
			return ("%s · %d ml" % [src_name(s.src), s.ml]) if hint else ("%s · ? ml" % src_name(s.src))
		"dash":
			return "%s · %d dashes" % [src_name(s.src), s.n]
		"top":
			return "Top with %s" % src_name(s.src)
		"ice":
			return ("Ice: %s" % ICE[s.v].to_lower()) if hint else "Add ice"
		"shake":
			return "Shake hard"
		"stir":
			return "Stir until cold"
		"strain":
			return "Strain into the glass"
		"garnish":
			return GARNISH[s.v] if hint else "Garnish"
	return s.t


## True if the recipe is built in a shaker tin (pours go into the tin first).
func uses_tin(d: Dictionary) -> bool:
	for s in d.steps:
		if s.t == "shake":
			return true
	return false


## Stars for one drink from its mistakes and pour errors (in ml). Pure, so tests can check it.
static func stars_for(mistakes: int, pour_errors: Array) -> float:
	var s := 3.0 - mistakes
	for e in pour_errors:
		var a: float = absf(e)
		if a > 12.0:
			s -= 1.0
		elif a > 6.0:
			s -= 0.5
	return clampf(s, 1.0, 3.0)


static func is_perfect(err_ml: float) -> bool:
	return absf(err_ml) <= 2.5
