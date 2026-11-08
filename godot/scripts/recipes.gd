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
	"brandy": {"brand": "MAISON REY", "name": "Brandy", "kind": "rail", "liquid": Color(0.6, 0.3, 0.1), "label": Color(0.35, 0.08, 0.1)},
	"triple_sec": {"brand": "CITRINE", "name": "Triple Sec", "kind": "rail", "liquid": Color(0.96, 0.94, 0.85), "label": Color(0.77, 0.48, 0.06)},
	"coffee_liq": {"brand": "KAAPI", "name": "Coffee Liqueur", "kind": "rail", "liquid": Color(0.16, 0.09, 0.05), "label": Color(0.89, 0.72, 0.47)},
	"red_bitter": {"brand": "FIAMMA", "name": "Red Bitter", "kind": "rail", "liquid": Color(0.85, 0.12, 0.1), "label": Color(0.95, 0.9, 0.8)},
	"sweet_vermouth": {"brand": "VALLE", "name": "Sweet Vermouth", "kind": "rail", "liquid": Color(0.45, 0.12, 0.08), "label": Color(0.75, 0.6, 0.3)},
	"dry_vermouth": {"brand": "VALLE", "name": "Dry Vermouth", "kind": "rail", "liquid": Color(0.95, 0.94, 0.82), "label": Color(0.2, 0.35, 0.3)},
	"lime": {"brand": "", "name": "Lime Juice", "kind": "station", "liquid": Color(0.78, 0.88, 0.45)},
	"lemon": {"brand": "", "name": "Lemon Juice", "kind": "station", "liquid": Color(0.98, 0.92, 0.55)},
	"sugar": {"brand": "", "name": "Sugar Syrup", "kind": "station", "liquid": Color(0.97, 0.95, 0.88)},
	"honey": {"brand": "", "name": "Honey Syrup", "kind": "station", "liquid": Color(0.95, 0.72, 0.25)},
	"grenadine": {"brand": "", "name": "Grenadine", "kind": "station", "liquid": Color(0.75, 0.05, 0.12)},
	"cranberry": {"brand": "", "name": "Cranberry", "kind": "station", "liquid": Color(0.76, 0.07, 0.18)},
	"orange_juice": {"brand": "", "name": "Orange Juice", "kind": "station", "liquid": Color(1.0, 0.65, 0.15)},
	"pineapple_juice": {"brand": "", "name": "Pineapple Juice", "kind": "station", "liquid": Color(0.98, 0.85, 0.35)},
	"peach_puree": {"brand": "", "name": "Peach Puree", "kind": "station", "liquid": Color(1.0, 0.75, 0.55)},
	"coconut_cream": {"brand": "", "name": "Coconut Cream", "kind": "station", "liquid": Color(0.98, 0.97, 0.93)},
	"cream": {"brand": "", "name": "Cream", "kind": "station", "liquid": Color(0.99, 0.97, 0.9)},
	"espresso": {"brand": "", "name": "Espresso", "kind": "station", "liquid": Color(0.2, 0.11, 0.05)},
	"bitters": {"brand": "", "name": "Aromatic Bitters", "kind": "station", "liquid": Color(0.45, 0.1, 0.05)},
	"soda": {"brand": "", "name": "Soda Water", "kind": "station", "liquid": Color(0.92, 0.97, 1.0)},
	"tonic": {"brand": "", "name": "Tonic Water", "kind": "station", "liquid": Color(0.93, 0.97, 1.0)},
	"ginger_beer": {"brand": "", "name": "Ginger Beer", "kind": "station", "liquid": Color(0.93, 0.85, 0.6)},
	"cola": {"brand": "", "name": "Cola", "kind": "station", "liquid": Color(0.22, 0.1, 0.05)},
	"sparkling": {"brand": "", "name": "Sparkling Wine", "kind": "station", "liquid": Color(0.97, 0.93, 0.7)},
	# Mocktail mode swaps the speed rail for these zero-proof bottles.
	"apple": {"brand": "ORCHARD", "name": "Apple Juice", "kind": "rail", "liquid": Color(0.93, 0.78, 0.35), "label": Color(0.2, 0.45, 0.15)},
	"mango": {"brand": "ORCHARD", "name": "Mango Nectar", "kind": "rail", "liquid": Color(1.0, 0.7, 0.2), "label": Color(0.75, 0.55, 0.05)},
	"grapefruit": {"brand": "ORCHARD", "name": "Grapefruit Juice", "kind": "rail", "liquid": Color(0.98, 0.7, 0.6), "label": Color(0.8, 0.3, 0.3)},
	"cucumber": {"brand": "GARDEN", "name": "Cucumber Cordial", "kind": "rail", "liquid": Color(0.8, 0.95, 0.75), "label": Color(0.15, 0.4, 0.2)},
	"white_grape": {"brand": "ORCHARD", "name": "White Grape Juice", "kind": "rail", "liquid": Color(0.95, 0.93, 0.7), "label": Color(0.4, 0.5, 0.15)},
	"black_tea": {"brand": "ASSAM", "name": "Cold Black Tea", "kind": "rail", "liquid": Color(0.55, 0.27, 0.08), "label": Color(0.9, 0.8, 0.6)},
	"apricot": {"brand": "ORCHARD", "name": "Apricot Nectar", "kind": "rail", "liquid": Color(1.0, 0.68, 0.3), "label": Color(0.6, 0.3, 0.1)},
	"orange_cordial": {"brand": "GARDEN", "name": "Orange Cordial", "kind": "rail", "liquid": Color(1.0, 0.6, 0.15), "label": Color(0.85, 0.4, 0.05)},
	"vanilla": {"brand": "GARDEN", "name": "Vanilla Syrup", "kind": "rail", "liquid": Color(0.97, 0.9, 0.75), "label": Color(0.45, 0.3, 0.15)},
	"blood_orange": {"brand": "GARDEN", "name": "Blood Orange Cordial", "kind": "rail", "liquid": Color(0.85, 0.2, 0.12), "label": Color(0.3, 0.05, 0.05)},
	"hibiscus": {"brand": "GARDEN", "name": "Hibiscus Tea", "kind": "rail", "liquid": Color(0.55, 0.08, 0.15), "label": Color(0.9, 0.75, 0.8)},
	"elderflower": {"brand": "GARDEN", "name": "Elderflower Cordial", "kind": "rail", "liquid": Color(0.96, 0.95, 0.8), "label": Color(0.35, 0.45, 0.3)},
}

## Spirit -> zero-proof swap used in mocktail mode.
const MOCKTAIL_SWAP := {
	"white_rum": "apple", "gold_rum": "mango", "tequila": "grapefruit", "gin": "cucumber",
	"vodka": "white_grape", "bourbon": "black_tea", "brandy": "apricot", "triple_sec": "orange_cordial",
	"coffee_liq": "vanilla", "red_bitter": "blood_orange", "sweet_vermouth": "hibiscus", "dry_vermouth": "elderflower",
	"sparkling": "soda",
}

## Speed rail order, left to right.
const RAIL := ["white_rum", "gold_rum", "tequila", "gin", "vodka", "bourbon", "brandy", "triple_sec", "coffee_liq", "red_bitter", "sweet_vermouth", "dry_vermouth"]
## Things on the work station, left to right on the right-hand board.
const STATION := [
	"lime", "lemon", "sugar", "honey", "grenadine", "bitters",
	"cranberry", "orange_juice", "pineapple_juice", "peach_puree", "coconut_cream", "cream",
	"soda", "tonic", "ginger_beer", "cola", "sparkling", "espresso",
]

const GLASSES := {
	"highball": {"name": "Highball", "ml": 300},
	"rocks": {"name": "Rocks", "ml": 250},
	"coupe": {"name": "Coupe", "ml": 180},
	"martini": {"name": "Martini", "ml": 180},
	"flute": {"name": "Flute", "ml": 170},
	"mug": {"name": "Copper mug", "ml": 400},
}
const ICE := {"cubes": "Cubes", "crushed": "Crushed", "big": "Big cube"}
const GARNISH := {
	"lime_wheel": "Lime wheel", "lemon_wheel": "Lemon wheel", "orange_wheel": "Orange wheel",
	"orange_twist": "Orange twist", "lemon_twist": "Lemon twist", "mint_sprig": "Mint sprig",
	"cherry": "Cherry", "olive": "Olive", "pineapple_wedge": "Pineapple wedge", "coffee_beans": "3 coffee beans",
}
const RIMS := {"salt": "Salt rim", "sugar": "Sugar rim", "none": "No rim"}

## Step types: glass, rim, muddle, pour(src, ml), dash(src, n), top(src), ice, shake, stir, strain, garnish,
## layer(src, ml, sink?) poured gently over a spoon so it floats (or sinks), blend, flame (flamed orange peel).
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
		"id": "cuba_libre", "name": "Cuba Libre", "price": 35, "glass": "highball", "method": "Build",
		"about": "Rum and cola with a squeeze of lime. Cheap, quick and loved everywhere.",
		"steps": [
			{"t": "glass", "v": "highball"}, {"t": "ice", "v": "cubes"}, {"t": "pour", "src": "white_rum", "ml": 50},
			{"t": "pour", "src": "lime", "ml": 10}, {"t": "top", "src": "cola"}, {"t": "garnish", "v": "lime_wheel"},
		],
		"home": ["Fill a tall glass with ice.", "Add 50 ml white rum and 10 ml lime juice.", "Top with cold cola and stir once.", "Add a lime wheel."],
		"mocktail": "Apple Cola Fizz",
	},
	{
		"id": "screwdriver", "name": "Screwdriver", "price": 30, "glass": "highball", "method": "Build",
		"about": "Vodka and orange juice. Two ingredients, so fresh juice matters.",
		"steps": [
			{"t": "glass", "v": "highball"}, {"t": "ice", "v": "cubes"}, {"t": "pour", "src": "vodka", "ml": 50},
			{"t": "top", "src": "orange_juice"}, {"t": "garnish", "v": "orange_wheel"},
		],
		"home": ["Fill a tall glass with ice.", "Add 50 ml vodka.", "Top with fresh orange juice and stir.", "Add an orange wheel."],
		"mocktail": "Grape Orange Cooler",
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
		"id": "vodka_tonic", "name": "Vodka Tonic", "price": 30, "glass": "highball", "method": "Build",
		"about": "Clean and crisp. Lots of ice, cold tonic, lime.",
		"steps": [
			{"t": "glass", "v": "highball"}, {"t": "ice", "v": "cubes"}, {"t": "pour", "src": "vodka", "ml": 50},
			{"t": "top", "src": "tonic"}, {"t": "garnish", "v": "lime_wheel"},
		],
		"home": ["Fill a tall glass with ice.", "Add 50 ml vodka.", "Top with tonic, pouring down the side.", "Add a lime wheel."],
		"mocktail": "Grape Tonic",
	},
	{
		"id": "moscow_mule", "name": "Moscow Mule", "price": 45, "glass": "mug", "method": "Build",
		"about": "Vodka, lime and spicy ginger beer, served ice cold in a copper mug.",
		"steps": [
			{"t": "glass", "v": "mug"}, {"t": "ice", "v": "cubes"}, {"t": "pour", "src": "vodka", "ml": 50},
			{"t": "pour", "src": "lime", "ml": 15}, {"t": "top", "src": "ginger_beer"}, {"t": "garnish", "v": "lime_wheel"},
		],
		"home": ["Fill a mug or tall glass with ice.", "Add 50 ml vodka and 15 ml lime juice.", "Top with ginger beer.", "Add a lime wheel."],
		"mocktail": "Grape Ginger Mule",
	},
	{
		"id": "old_fashioned", "name": "Old Fashioned", "price": 55, "glass": "rocks", "method": "Stir",
		"about": "Spirit, sugar, bitters, ice. Stirring chills it without bubbles, so it stays silky.",
		"steps": [
			{"t": "glass", "v": "rocks"}, {"t": "pour", "src": "sugar", "ml": 10}, {"t": "dash", "src": "bitters", "n": 2},
			{"t": "pour", "src": "bourbon", "ml": 50}, {"t": "ice", "v": "big"}, {"t": "stir"},
			{"t": "flame"}, {"t": "garnish", "v": "orange_twist"},
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
		"id": "cape_codder", "name": "Cape Codder", "price": 35, "glass": "highball", "method": "Build",
		"about": "Vodka and cranberry with lime. Tart and easy.",
		"steps": [
			{"t": "glass", "v": "highball"}, {"t": "ice", "v": "cubes"}, {"t": "pour", "src": "vodka", "ml": 45},
			{"t": "top", "src": "cranberry"}, {"t": "garnish", "v": "lime_wheel"},
		],
		"home": ["Fill a tall glass with ice.", "Add 45 ml vodka.", "Top with cranberry juice.", "Add a lime wheel."],
		"mocktail": "Cranberry Grape Cooler",
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
		"id": "tom_collins", "name": "Tom Collins", "price": 45, "glass": "highball", "method": "Shake & top",
		"about": "Gin sour lengthened with soda. Tall, fresh and fizzy.",
		"steps": [
			{"t": "glass", "v": "highball"}, {"t": "pour", "src": "gin", "ml": 50}, {"t": "pour", "src": "lemon", "ml": 25},
			{"t": "pour", "src": "sugar", "ml": 15}, {"t": "ice", "v": "cubes"}, {"t": "shake"},
			{"t": "strain"}, {"t": "top", "src": "soda"}, {"t": "garnish", "v": "lemon_wheel"},
		],
		"home": ["Shake 50 ml gin, 25 ml lemon juice and 15 ml sugar syrup with ice.", "Strain into a tall glass full of ice.", "Top with soda.", "Add a lemon wheel."],
		"mocktail": "Cucumber Collins",
	},
	{
		"id": "americano", "name": "Americano", "price": 40, "glass": "highball", "method": "Build",
		"about": "Bitter red aperitivo and sweet vermouth stretched with soda. Light and bitter-sweet.",
		"steps": [
			{"t": "glass", "v": "highball"}, {"t": "ice", "v": "cubes"}, {"t": "pour", "src": "red_bitter", "ml": 30},
			{"t": "pour", "src": "sweet_vermouth", "ml": 30}, {"t": "top", "src": "soda"}, {"t": "garnish", "v": "orange_wheel"},
		],
		"home": ["Fill a tall glass with ice.", "Add 30 ml red bitter aperitivo and 30 ml sweet vermouth.", "Top with soda.", "Add an orange wheel."],
		"mocktail": "Hibiscus Americano",
	},
	{
		"id": "cosmopolitan", "name": "Cosmopolitan", "price": 55, "glass": "martini", "method": "Shake",
		"about": "Vodka, orange liqueur, cranberry and lime, shaken and served in a martini glass.",
		"steps": [
			{"t": "glass", "v": "martini"}, {"t": "pour", "src": "vodka", "ml": 40}, {"t": "pour", "src": "triple_sec", "ml": 15},
			{"t": "pour", "src": "cranberry", "ml": 30}, {"t": "pour", "src": "lime", "ml": 15}, {"t": "ice", "v": "cubes"},
			{"t": "shake"}, {"t": "strain"}, {"t": "flame"}, {"t": "garnish", "v": "orange_twist"},
		],
		"home": ["Chill a stemmed glass.", "In a jar add 40 ml vodka, 15 ml orange liqueur, 30 ml cranberry juice and 15 ml lime juice.", "Add ice, shake hard and strain into the glass.", "Squeeze an orange peel over the top (bartenders squeeze it through a lit match for a flash of flame; take care)."],
		"mocktail": "Cranberry Grape Cosmo",
	},
	{
		"id": "gimlet", "name": "Gimlet", "price": 45, "glass": "coupe", "method": "Shake",
		"about": "Gin and lime, sweetened just a little. Sharp and clean.",
		"steps": [
			{"t": "glass", "v": "coupe"}, {"t": "pour", "src": "gin", "ml": 60}, {"t": "pour", "src": "lime", "ml": 20},
			{"t": "pour", "src": "sugar", "ml": 15}, {"t": "ice", "v": "cubes"}, {"t": "shake"},
			{"t": "strain"}, {"t": "garnish", "v": "lime_wheel"},
		],
		"home": ["Shake 60 ml gin, 20 ml lime juice and 15 ml sugar syrup with ice.", "Strain into a chilled glass.", "Add a lime wheel."],
		"mocktail": "Cucumber Gimlet",
	},
	{
		"id": "mimosa", "name": "Mimosa", "price": 40, "glass": "flute", "method": "Build",
		"about": "Orange juice and sparkling wine. A brunch favourite.",
		"steps": [
			{"t": "glass", "v": "flute"}, {"t": "pour", "src": "orange_juice", "ml": 75}, {"t": "top", "src": "sparkling"},
			{"t": "garnish", "v": "orange_twist"},
		],
		"home": ["Pour 75 ml cold orange juice into a flute.", "Top slowly with cold sparkling wine.", "Add an orange twist."],
		"mocktail": "Sparkling Orange",
	},
	{
		"id": "bourbon_highball", "name": "Bourbon Highball", "price": 35, "glass": "highball", "method": "Build",
		"about": "Whisky and soda. Very cold and very bubbly is the whole trick.",
		"steps": [
			{"t": "glass", "v": "highball"}, {"t": "ice", "v": "cubes"}, {"t": "pour", "src": "bourbon", "ml": 45},
			{"t": "top", "src": "soda"}, {"t": "garnish", "v": "lemon_twist"},
		],
		"home": ["Fill a tall glass with ice and stir to chill it.", "Add 45 ml bourbon.", "Top with cold soda, pouring gently.", "Squeeze a lemon peel over the top."],
		"mocktail": "Tea Highball",
	},
	{
		"id": "negroni", "name": "Negroni", "price": 55, "glass": "rocks", "method": "Stir",
		"about": "Equal parts gin, red bitter and sweet vermouth. Bitter, sweet and strong.",
		"steps": [
			{"t": "glass", "v": "rocks"}, {"t": "pour", "src": "gin", "ml": 30}, {"t": "pour", "src": "red_bitter", "ml": 30},
			{"t": "pour", "src": "sweet_vermouth", "ml": 30}, {"t": "ice", "v": "big"}, {"t": "stir"},
			{"t": "garnish", "v": "orange_twist"},
		],
		"home": ["In a short glass add 30 ml gin, 30 ml red bitter aperitivo and 30 ml sweet vermouth.", "Add a big ice cube and stir for 20 seconds.", "Add an orange twist."],
		"mocktail": "Hibiscus Negroni Zero",
	},
	{
		"id": "tequila_sunrise", "name": "Tequila Sunrise", "price": 45, "glass": "highball", "method": "Build",
		"about": "Grenadine poured last sinks to the bottom to make the sunrise colours.",
		"steps": [
			{"t": "glass", "v": "highball"}, {"t": "ice", "v": "cubes"}, {"t": "pour", "src": "tequila", "ml": 45},
			{"t": "top", "src": "orange_juice"}, {"t": "layer", "src": "grenadine", "ml": 15, "sink": true}, {"t": "garnish", "v": "orange_wheel"},
		],
		"home": ["Fill a tall glass with ice.", "Add 45 ml tequila and top with orange juice.", "Slowly pour 15 ml grenadine down the side. Don't stir.", "Add an orange wheel."],
		"mocktail": "Sunrise Cooler",
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
	{
		"id": "bees_knees", "name": "Bee's Knees", "price": 50, "glass": "coupe", "method": "Shake",
		"about": "Gin sour sweetened with honey instead of sugar.",
		"steps": [
			{"t": "glass", "v": "coupe"}, {"t": "pour", "src": "gin", "ml": 50}, {"t": "pour", "src": "honey", "ml": 20},
			{"t": "pour", "src": "lemon", "ml": 20}, {"t": "ice", "v": "cubes"}, {"t": "shake"},
			{"t": "strain"}, {"t": "garnish", "v": "lemon_twist"},
		],
		"home": ["Mix honey 2:1 with warm water to make honey syrup.", "Shake 50 ml gin, 20 ml honey syrup and 20 ml lemon juice with ice.", "Strain into a chilled glass.", "Add a lemon twist."],
		"mocktail": "Honey Cucumber Sour",
	},
	{
		"id": "rum_buck", "name": "Rum Buck", "price": 40, "glass": "highball", "method": "Build",
		"about": "A 'buck' is spirit, citrus and ginger beer. This one uses gold rum.",
		"steps": [
			{"t": "glass", "v": "highball"}, {"t": "ice", "v": "cubes"}, {"t": "pour", "src": "gold_rum", "ml": 50},
			{"t": "pour", "src": "lime", "ml": 15}, {"t": "top", "src": "ginger_beer"}, {"t": "garnish", "v": "lime_wheel"},
		],
		"home": ["Fill a tall glass with ice.", "Add 50 ml gold rum and 15 ml lime juice.", "Top with ginger beer.", "Add a lime wheel."],
		"mocktail": "Mango Ginger Buck",
	},
	{
		"id": "spritz", "name": "Spritz", "price": 50, "glass": "highball", "method": "Build",
		"about": "The Italian aperitivo: 3 parts sparkling wine, 2 parts bitter, 1 part soda.",
		"steps": [
			{"t": "glass", "v": "highball"}, {"t": "ice", "v": "cubes"}, {"t": "pour", "src": "sparkling", "ml": 90},
			{"t": "pour", "src": "red_bitter", "ml": 60}, {"t": "top", "src": "soda"}, {"t": "garnish", "v": "orange_wheel"},
		],
		"home": ["Fill a big glass with ice.", "Add 90 ml sparkling wine, then 60 ml red bitter aperitivo.", "Add a splash of soda.", "Add an orange slice."],
		"mocktail": "Blood Orange Spritz",
	},
	{
		"id": "kamikaze", "name": "Kamikaze", "price": 40, "glass": "martini", "method": "Shake",
		"about": "Equal-ish vodka, orange liqueur and lime. A sour served straight up.",
		"steps": [
			{"t": "glass", "v": "martini"}, {"t": "pour", "src": "vodka", "ml": 40}, {"t": "pour", "src": "triple_sec", "ml": 20},
			{"t": "pour", "src": "lime", "ml": 20}, {"t": "ice", "v": "cubes"}, {"t": "shake"},
			{"t": "strain"}, {"t": "garnish", "v": "lime_wheel"},
		],
		"home": ["Shake 40 ml vodka, 20 ml orange liqueur and 20 ml lime juice with ice.", "Strain into a chilled glass.", "Add a lime wheel."],
		"mocktail": "Orange Lime Zinger",
	},
	{
		"id": "gold_rush", "name": "Gold Rush", "price": 50, "glass": "rocks", "method": "Shake",
		"about": "Bourbon, honey and lemon: a modern classic whisky sour.",
		"steps": [
			{"t": "glass", "v": "rocks"}, {"t": "pour", "src": "bourbon", "ml": 50}, {"t": "pour", "src": "honey", "ml": 20},
			{"t": "pour", "src": "lemon", "ml": 20}, {"t": "ice", "v": "cubes"}, {"t": "shake"},
			{"t": "strain"}, {"t": "garnish", "v": "lemon_twist"},
		],
		"home": ["Shake 50 ml bourbon, 20 ml honey syrup and 20 ml lemon juice with ice.", "Strain into a short glass over fresh ice.", "Add a lemon twist."],
		"mocktail": "Honey Tea Sour",
	},
	{
		"id": "mexican_mule", "name": "Mexican Mule", "price": 45, "glass": "mug", "method": "Build",
		"about": "The Moscow Mule made with tequila instead of vodka.",
		"steps": [
			{"t": "glass", "v": "mug"}, {"t": "ice", "v": "cubes"}, {"t": "pour", "src": "tequila", "ml": 50},
			{"t": "pour", "src": "lime", "ml": 15}, {"t": "top", "src": "ginger_beer"}, {"t": "garnish", "v": "lime_wheel"},
		],
		"home": ["Fill a mug with ice.", "Add 50 ml tequila and 15 ml lime juice.", "Top with ginger beer.", "Add a lime wheel."],
		"mocktail": "Grapefruit Ginger Mule",
	},
	{
		"id": "bay_breeze", "name": "Bay Breeze", "price": 40, "glass": "highball", "method": "Build",
		"about": "Vodka with cranberry and pineapple juice. Fruity and pink.",
		"steps": [
			{"t": "glass", "v": "highball"}, {"t": "ice", "v": "cubes"}, {"t": "pour", "src": "vodka", "ml": 40},
			{"t": "pour", "src": "cranberry", "ml": 60}, {"t": "top", "src": "pineapple_juice"}, {"t": "garnish", "v": "pineapple_wedge"},
		],
		"home": ["Fill a tall glass with ice.", "Add 40 ml vodka and 60 ml cranberry juice.", "Top with pineapple juice.", "Add a pineapple wedge."],
		"mocktail": "Bay Breeze Zero",
	},
	{
		"id": "white_russian", "name": "White Russian", "price": 45, "glass": "rocks", "method": "Build",
		"about": "Vodka and coffee liqueur with cream floated on top.",
		"steps": [
			{"t": "glass", "v": "rocks"}, {"t": "ice", "v": "cubes"}, {"t": "pour", "src": "vodka", "ml": 50},
			{"t": "pour", "src": "coffee_liq", "ml": 20}, {"t": "layer", "src": "cream", "ml": 30},
		],
		"home": ["Fill a short glass with ice.", "Add 50 ml vodka and 20 ml coffee liqueur.", "Pour 30 ml cream slowly over the back of a spoon so it floats."],
		"mocktail": "Vanilla Cream Cooler",
	},
	{
		"id": "sidecar", "name": "Sidecar", "price": 55, "glass": "coupe", "method": "Shake",
		"about": "Brandy, orange liqueur and lemon, with a sugar rim. A 1920s Paris classic.",
		"steps": [
			{"t": "glass", "v": "coupe"}, {"t": "rim", "v": "sugar"}, {"t": "pour", "src": "brandy", "ml": 50},
			{"t": "pour", "src": "triple_sec", "ml": 20}, {"t": "pour", "src": "lemon", "ml": 20}, {"t": "ice", "v": "cubes"},
			{"t": "shake"}, {"t": "strain"}, {"t": "garnish", "v": "orange_twist"},
		],
		"home": ["Sugar the rim of a glass.", "Shake 50 ml brandy, 20 ml orange liqueur and 20 ml lemon juice with ice.", "Strain into the glass.", "Add an orange twist."],
		"mocktail": "Apricot Sidecar",
	},
	{
		"id": "boulevardier", "name": "Boulevardier", "price": 60, "glass": "rocks", "method": "Stir",
		"about": "A Negroni made with bourbon instead of gin. Richer and warmer.",
		"steps": [
			{"t": "glass", "v": "rocks"}, {"t": "pour", "src": "bourbon", "ml": 45}, {"t": "pour", "src": "red_bitter", "ml": 30},
			{"t": "pour", "src": "sweet_vermouth", "ml": 30}, {"t": "ice", "v": "big"}, {"t": "stir"},
			{"t": "garnish", "v": "orange_twist"},
		],
		"home": ["In a short glass add 45 ml bourbon, 30 ml red bitter and 30 ml sweet vermouth.", "Add a big ice cube and stir for 20 seconds.", "Add an orange twist."],
		"mocktail": "Tea Boulevardier",
	},
	{
		"id": "lemon_drop", "name": "Lemon Drop", "price": 45, "glass": "martini", "method": "Shake",
		"about": "Sweet and sour, like the candy. The sugar rim balances the lemon.",
		"steps": [
			{"t": "glass", "v": "martini"}, {"t": "rim", "v": "sugar"}, {"t": "pour", "src": "vodka", "ml": 50},
			{"t": "pour", "src": "triple_sec", "ml": 20}, {"t": "pour", "src": "lemon", "ml": 25}, {"t": "pour", "src": "sugar", "ml": 10},
			{"t": "ice", "v": "cubes"}, {"t": "shake"}, {"t": "strain"},
			{"t": "garnish", "v": "lemon_twist"},
		],
		"home": ["Wet the rim of a glass with lemon and dip it in sugar.", "Shake 50 ml vodka, 20 ml orange liqueur, 25 ml lemon juice and 10 ml sugar syrup with ice.", "Strain into the glass.", "Add a lemon twist."],
		"mocktail": "Lemon Drop Zero",
	},
	{
		"id": "bellini", "name": "Bellini", "price": 45, "glass": "flute", "method": "Build",
		"about": "White peach puree topped with sparkling wine. Pour slowly so it doesn't foam over.",
		"steps": [
			{"t": "glass", "v": "flute"}, {"t": "pour", "src": "peach_puree", "ml": 50}, {"t": "top", "src": "sparkling"},
		],
		"home": ["Pour 50 ml peach puree into a flute.", "Top slowly with cold sparkling wine, stirring gently."],
		"mocktail": "Peach Fizz",
	},
	{
		"id": "black_russian", "name": "Black Russian", "price": 40, "glass": "rocks", "method": "Build",
		"about": "Vodka and coffee liqueur on ice. Dark, sweet and simple.",
		"steps": [
			{"t": "glass", "v": "rocks"}, {"t": "ice", "v": "big"}, {"t": "pour", "src": "vodka", "ml": 50},
			{"t": "pour", "src": "coffee_liq", "ml": 20}, {"t": "stir"},
		],
		"home": ["Put a big ice cube in a short glass.", "Add 50 ml vodka and 20 ml coffee liqueur.", "Stir for 10 seconds."],
		"mocktail": "Vanilla Cold Brew",
	},
	{
		"id": "french_75", "name": "French 75", "price": 60, "glass": "flute", "method": "Shake & top",
		"about": "A gin sour topped with sparkling wine. Elegant and strong.",
		"steps": [
			{"t": "glass", "v": "flute"}, {"t": "pour", "src": "gin", "ml": 30}, {"t": "pour", "src": "lemon", "ml": 15},
			{"t": "pour", "src": "sugar", "ml": 15}, {"t": "ice", "v": "cubes"}, {"t": "shake"},
			{"t": "strain"}, {"t": "top", "src": "sparkling"}, {"t": "garnish", "v": "lemon_twist"},
		],
		"home": ["Shake 30 ml gin, 15 ml lemon juice and 15 ml sugar syrup with ice.", "Strain into a flute.", "Top with cold sparkling wine.", "Add a lemon twist."],
		"mocktail": "French Cucumber Fizz",
	},
	{
		"id": "manhattan", "name": "Manhattan", "price": 60, "glass": "martini", "method": "Stir & strain",
		"about": "Whisky, sweet vermouth and bitters, stirred and served straight up with a cherry.",
		"steps": [
			{"t": "glass", "v": "martini"}, {"t": "pour", "src": "bourbon", "ml": 50}, {"t": "pour", "src": "sweet_vermouth", "ml": 20},
			{"t": "dash", "src": "bitters", "n": 2}, {"t": "ice", "v": "cubes"}, {"t": "stir"},
			{"t": "strain"}, {"t": "garnish", "v": "cherry"},
		],
		"home": ["In a jar add 50 ml bourbon, 20 ml sweet vermouth and 2 dashes of bitters.", "Add ice and stir for 30 seconds.", "Strain into a chilled glass.", "Add a cherry."],
		"mocktail": "Tea Manhattan",
	},
	{
		"id": "gin_fizz", "name": "Gin Fizz", "price": 45, "glass": "highball", "method": "Shake & top",
		"about": "Like a Collins with no ice in the glass, so it's short, sharp and fizzy.",
		"steps": [
			{"t": "glass", "v": "highball"}, {"t": "pour", "src": "gin", "ml": 50}, {"t": "pour", "src": "lemon", "ml": 25},
			{"t": "pour", "src": "sugar", "ml": 15}, {"t": "ice", "v": "cubes"}, {"t": "shake"},
			{"t": "strain"}, {"t": "top", "src": "soda"}, {"t": "garnish", "v": "lemon_twist"},
		],
		"home": ["Shake 50 ml gin, 25 ml lemon juice and 15 ml sugar syrup hard with ice.", "Strain into a glass with no ice.", "Top with soda.", "Add a lemon twist."],
		"mocktail": "Cucumber Fizz",
	},
	{
		"id": "pina_colada", "name": "Piña Colada", "price": 55, "glass": "highball", "method": "Blend",
		"about": "Rum, coconut and pineapple. Creamy, sweet and tropical.",
		"steps": [
			{"t": "glass", "v": "highball"}, {"t": "pour", "src": "white_rum", "ml": 50}, {"t": "pour", "src": "coconut_cream", "ml": 30},
			{"t": "pour", "src": "pineapple_juice", "ml": 90}, {"t": "ice", "v": "crushed"}, {"t": "blend"},
			{"t": "garnish", "v": "pineapple_wedge"},
		],
		"home": ["Put 50 ml white rum, 30 ml coconut cream and 90 ml pineapple juice in a blender.", "Add a cup of crushed ice and blend until smooth.", "Pour into a tall glass and add a pineapple wedge."],
		"mocktail": "Virgin Colada",
	},
	{
		"id": "rum_old_fashioned", "name": "Rum Old Fashioned", "price": 55, "glass": "rocks", "method": "Stir",
		"about": "The Old Fashioned with gold rum. A little sweeter and fruitier.",
		"steps": [
			{"t": "glass", "v": "rocks"}, {"t": "pour", "src": "sugar", "ml": 10}, {"t": "dash", "src": "bitters", "n": 2},
			{"t": "pour", "src": "gold_rum", "ml": 50}, {"t": "ice", "v": "big"}, {"t": "stir"},
			{"t": "garnish", "v": "orange_twist"},
		],
		"home": ["In a short glass add 10 ml sugar syrup and 2 dashes of bitters.", "Add 50 ml gold rum.", "Add a big ice cube and stir for 20 seconds.", "Add an orange twist."],
		"mocktail": "Mango Fashioned",
	},
	{
		"id": "planters_punch", "name": "Planter's Punch", "price": 50, "glass": "highball", "method": "Build",
		"about": "A rum punch: sour, sweet, strong and fruity.",
		"steps": [
			{"t": "glass", "v": "highball"}, {"t": "ice", "v": "cubes"}, {"t": "pour", "src": "gold_rum", "ml": 45},
			{"t": "pour", "src": "orange_juice", "ml": 35}, {"t": "pour", "src": "pineapple_juice", "ml": 35}, {"t": "pour", "src": "lime", "ml": 15},
			{"t": "pour", "src": "grenadine", "ml": 10}, {"t": "garnish", "v": "pineapple_wedge"},
		],
		"home": ["Fill a tall glass with ice.", "Add 45 ml gold rum, 35 ml orange juice, 35 ml pineapple juice, 15 ml lime juice and 10 ml grenadine.", "Stir well.", "Add a pineapple wedge."],
		"mocktail": "Mango Punch",
	},
	{
		"id": "dry_martini", "name": "Dry Martini", "price": 60, "glass": "martini", "method": "Stir & strain",
		"about": "Gin and a little dry vermouth, stirred very cold. Olive or lemon twist.",
		"steps": [
			{"t": "glass", "v": "martini"}, {"t": "pour", "src": "gin", "ml": 60}, {"t": "pour", "src": "dry_vermouth", "ml": 10},
			{"t": "ice", "v": "cubes"}, {"t": "stir"}, {"t": "strain"},
			{"t": "garnish", "v": "olive"},
		],
		"home": ["Chill a martini glass in the freezer.", "Stir 60 ml gin and 10 ml dry vermouth with lots of ice for 30 seconds.", "Strain into the cold glass.", "Add an olive."],
		"mocktail": "Elderflower Martini Zero",
	},
	{
		"id": "long_island", "name": "Long Island Iced Tea", "price": 70, "glass": "highball", "method": "Build",
		"about": "Five spirits, lemon and cola. Tastes like iced tea, but it's very strong.",
		"steps": [
			{"t": "glass", "v": "highball"}, {"t": "ice", "v": "cubes"}, {"t": "pour", "src": "vodka", "ml": 15},
			{"t": "pour", "src": "gin", "ml": 15}, {"t": "pour", "src": "white_rum", "ml": 15}, {"t": "pour", "src": "tequila", "ml": 15},
			{"t": "pour", "src": "triple_sec", "ml": 15}, {"t": "pour", "src": "lemon", "ml": 25}, {"t": "pour", "src": "sugar", "ml": 15},
			{"t": "top", "src": "cola"}, {"t": "garnish", "v": "lemon_wheel"},
		],
		"home": ["Fill a tall glass with ice.", "Add 15 ml each of vodka, gin, white rum, tequila and orange liqueur.", "Add 25 ml lemon juice and 15 ml sugar syrup.", "Top with cola and add a lemon wheel."],
		"mocktail": "Long Island Iced (Zero) Tea",
	},
	{
		"id": "frozen_margarita", "name": "Frozen Margarita", "price": 60, "glass": "coupe", "method": "Blend",
		"about": "A margarita blended with crushed ice until it's smooth like a slushie.",
		"steps": [
			{"t": "glass", "v": "coupe"}, {"t": "rim", "v": "salt"}, {"t": "pour", "src": "tequila", "ml": 50},
			{"t": "pour", "src": "triple_sec", "ml": 20}, {"t": "pour", "src": "lime", "ml": 25}, {"t": "pour", "src": "sugar", "ml": 10},
			{"t": "ice", "v": "crushed"}, {"t": "blend"}, {"t": "garnish", "v": "lime_wheel"},
		],
		"home": ["Salt the rim of a wide glass.", "Put 50 ml tequila, 20 ml orange liqueur, 25 ml lime juice and 10 ml sugar syrup in a blender.", "Add a cup of crushed ice and blend until smooth.", "Pour into the glass and add a lime wheel."],
		"mocktail": "Frozen Grapefruit Rita",
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
		"layer":
			var how := "Sink" if s.get("sink", false) else "Float"
			return ("%s %s · %d ml" % [how, src_name(s.src), s.ml]) if hint else ("%s %s · ? ml" % [how, src_name(s.src)])
		"blend":
			return "Blend until smooth"
		"flame":
			return "Flame the orange peel"
	return s.t


## True if the recipe is built in a shaker tin (pours go into the tin first).
func uses_tin(d: Dictionary) -> bool:
	for s in d.steps:
		if s.t == "shake" or s.t == "strain" or s.t == "blend":
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


## Guests sometimes ask for a drink their way. Returns a copy of [param d] with the change made
## and a "request" line for the order bubble, or [param d] itself when nothing fits.
## [param pick] chooses between the requests that fit (tests pass it; the game passes randi()).
func with_request(d: Dictionary, pick: int) -> Dictionary:
	var fits := []
	for k in d.steps.size():
		var s: Dictionary = d.steps[k]
		if s.t == "pour" and s.src in ["sugar", "honey"] and s.ml >= 10:
			fits.append([k, "Less sweet, please", "half the syrup", int(s.ml / 2)])
		if s.t == "pour" and s.src in ["lime", "lemon"] and s.ml >= 15 and s.ml <= 30:
			fits.append([k, "A bit more sour, please", "5 ml more %s" % ("lime" if s.src == "lime" else "lemon"), s.ml + 5])
	if fits.is_empty():
		return d
	var f: Array = fits[pick % fits.size()]
	var c: Dictionary = d.duplicate(true)
	c.steps[f[0]].ml = f[3]
	c.request = f[1]
	c.req_note = f[2]
	return c
