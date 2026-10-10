class_name Lore
extends RefCounted
## Notes left behind by the Lantern Company, a group of six friends who went
## down long before the players did. Found on remains, in camps and in the water.

const NOTES := [
	{"title": "A Page, Water-Stained", "text": "Day one. Six of us, six lanterns, enough bread for a week if Tobin doesn't get to it first. Marguerite says we're only going to look. We are absolutely not only going to look."},
	{"title": "Lantern Company Ledger", "text": "Copper by the cartload on the first floors. Edda wants to turn back and sell it. Corin wants to keep going. We compromised: Corin carried the copper."},
	{"title": "Note Pinned Under a Rock", "text": "Found a little pool here with pale fish that have no eyes. Tobin caught one with a bit of cheese. We cooked it on the shovel. Best meal of the trip."},
	{"title": "Marguerite's Sketch", "text": "Drew the tall stones near the fifth floor. They hum when you touch them and the hum follows you home. Corin calls them waystones. He names everything."},
	{"title": "Soggy Diary Page", "text": "The moss down here glows when it's happy. I don't know how I know it's happy. I just do."},
	{"title": "Torn Map Corner", "text": "...lake on the eighth floor. Plank crossing on the west side, mind the third board. Edda fell in. Edda says she did not fall in, she 'went in on purpose to check the depth.'"},
	{"title": "A Letter Never Sent", "text": "Dear Mother. The crystals on the twelfth floor are bigger than the house. We are fine. Tobin is fine. Nobody has been bitten by anything. Please don't read the next letter."},
	{"title": "The Next Letter", "text": "Tobin was bitten by something. He is fine. He wants it known that it was a very large beetle and that he hit it first."},
	{"title": "Edda's Field Notes", "text": "The mushrooms past fifteen will make you see colors if you lick them. Do not lick them. (Corin licked them.)"},
	{"title": "Brewing Scrawl", "text": "Glowcap and a pinch of crystal dust in the kettle makes a drink that lights the whole cavern for an hour. Marguerite calls it 'lamp oil.' We are all a little bit glowing."},
	{"title": "Corin's Count", "text": "Floor nineteen. Ran out of bread on seventeen. Ran out of jokes on eighteen. Still have plenty of rope. Rope is not very filling."},
	{"title": "Wax-Sealed Note", "text": "Below the fungus there is heat. The rock is warm like a hearthstone left by the fire. Edda thinks something is alive down there. I think something is asleep."},
	{"title": "Scorched Page", "text": "The Ember Rift. Rivers of fire. Tobin is fishing in the lava. I can't stop him and frankly I want to see what he catches."},
	{"title": "Tobin's Proudest Moment", "text": "IT WAS AN EEL. A FIRE EEL. I HAVE SEEN WONDERS. Write that down, Marguerite. — T."},
	{"title": "Halls Beyond", "text": "Past twenty-five there are halls. Somebody built them. Pillars, carvings of people holding lanterns. Like us. Every carving is of six people."},
	{"title": "Carving Rubbing", "text": "The carvings show the six tending something round and bright, the way you'd tend a fire through a long winter. They aren't guarding it. They're keeping it warm."},
	{"title": "Marguerite, Near the End", "text": "We found the heart of it. It's warm and slow and it beats once a minute. The Heartstones are pieces it sheds, like a tree drops seeds. It is not ours to take. But it gave us one anyway."},
	{"title": "The Last Page", "text": "We are going home. We will plant what we found and build a house and tell nobody, and maybe in fifty years someone else will come and do this all again. If that's you: go back for the people you came with. And bring more bread. — The Lantern Company"},
	{"title": "Miner's Tag Tied to a Note", "text": "Shift three, floor two. If you find this, the iron is behind the cracked wall to the north. Tell Agnes I'm late for supper."},
	{"title": "Child's Drawing", "text": "A crayon drawing of a fish with legs walking out of a cave, and six stick figures waving at it. Someone has written 'TRUE' underneath."},
	{"title": "Recipe Scrap", "text": "Miner's Pasty: potato, carrot, a bit of wheat for the crust. Mother said it keeps you going for a whole shift. She was right, as she always is."},
	{"title": "Faded Warning", "text": "SHELLBACKS: hard as stone from the front. Get them to charge a wall, then hit them where they're soft. They hate that."},
	{"title": "Soggy Postcard", "text": "Greetings from the lake! The pike are enormous. Wish you were here. Actually, glad you're not, a pike took my hat."},
	{"title": "Fisher's Scribble", "text": "The quiet pool past the ridge. Fish there with gold and white patterns. Only one I've ever caught. Never told a soul where it is. You found this, so I suppose now you know."},
]

static func note(i: int) -> Dictionary:
	return NOTES[posmod(i, NOTES.size())]

## Cave notes are spread through the depths in story order.
static func cave_note_for_floor(f: int, variant: int) -> int:
	var story := 18
	var idx: int = clamp(int(float(f - 1) / 30.0 * story), 0, story - 1)
	if variant % 3 == 2:
		return 18 + (f + variant) % 4
	return idx

static func surface_note(variant: int) -> int:
	return [2, 4, 19, 22, 23, 20][posmod(variant, 6)]
