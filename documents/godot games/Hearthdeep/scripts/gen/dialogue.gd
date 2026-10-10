class_name Dialogue
extends RefCounted
## Everything the townsfolk say. Lines are assembled from a resident's job,
## two temperament traits, two interests, family and friends, what they love,
## and what the town has noticed lately (events, cave depth, who on the farm is
## known for what). Choices are seeded from (voice, day, talk count, player) so a
## conversation is stable within a day for each player and differs across days.
##
## Template placeholders look like {key}. A capitalized key ({A_love}, {Int})
## capitalizes the first letter of the value. Lines may start with a tag block
## like "[d10,s2]" that limits when they can be used:
##   dN  deepest floor >= N (d0 = nobody has been down yet)
##   sN  season index N      rain / snow / clear / fog  weather
##   night / day             multi / solo  household size
##   shop  the speaker keeps a shop      !role  the speaker does not have that job

const SEASON_NAMES := ["Spring", "Summer", "Autumn", "Winter"]
const SHOP_NAMES := {
	"merchant": "General Store", "smith": "Smithy", "innkeeper": "Tavern", "herbalist": "Apothecary",
	"carpenter": "Carpenter's Workshop", "angler": "Bait & Tackle", "mayor": "Town Hall",
}
const JOB_NOUN := {
	"merchant": "shopkeeper", "smith": "blacksmith", "innkeeper": "innkeeper", "herbalist": "herbalist",
	"carpenter": "carpenter", "angler": "angler", "mayor": "mayor", "farmer": "farmer", "miner": "retired miner",
	"teacher": "teacher", "musician": "musician", "scholar": "scholar", "tailor": "tailor", "beekeeper": "beekeeper",
	"baker": "baker", "courier": "courier", "painter": "painter", "guard": "watchkeeper", "child": "kid",
	"elder": "old-timer", "explorer": "explorer", "glassblower": "glassblower", "historian": "historian",
	"chef": "chef", "stargazer": "stargazer", "herder": "herder",
}
const ROLE_SMELL := {
	"merchant": "paper and spices", "smith": "coal smoke", "innkeeper": "stew and woodsmoke", "herbalist": "mint and something mysterious",
	"carpenter": "sawdust", "angler": "river water", "mayor": "ink and sealing wax", "farmer": "good soil", "miner": "rock dust",
	"teacher": "chalk", "musician": "rosin", "scholar": "old books", "tailor": "new cloth", "beekeeper": "honey",
	"baker": "fresh bread", "courier": "the open road", "painter": "linseed oil", "guard": "the night air", "child": "mud",
	"elder": "lavender", "explorer": "pine and rain", "glassblower": "hot sand", "historian": "old paper", "chef": "garlic",
	"stargazer": "cold night air", "herder": "hay",
}
const INTEREST_NOUN := {
	"fishing": "fishing", "gardening": "gardening", "metals": "metalwork", "cooking": "cooking", "brewing": "brewing",
	"history": "old history", "animals": "animals", "crafting": "making things by hand", "caves": "the caves",
	"music": "music", "stars": "the night sky", "gems": "gemstones", "baking": "baking", "books": "a good book",
	"flowers": "flowers", "exploring": "exploring", "trading": "a good trade",
}
const INTEREST_DREAM := {
	"fishing": "an angler", "gardening": "a farmer", "metals": "a blacksmith", "cooking": "a cook", "brewing": "a brewer",
	"history": "a historian", "animals": "a herder", "crafting": "a carpenter", "caves": "a cave explorer",
	"music": "a musician", "stars": "a stargazer", "gems": "a gem hunter", "baking": "a baker", "books": "a writer",
	"flowers": "a gardener", "exploring": "an explorer", "trading": "a shopkeeper",
}
const INTEREST_CATS := {
	"fishing": ["fish", "bait"], "gardening": ["crop", "seed", "herb", "sapling", "fruit"], "metals": ["ore", "bar"],
	"cooking": ["food"], "brewing": ["brew", "drink"], "history": ["curio"], "animals": ["animal"],
	"crafting": ["material", "placeable"], "caves": ["mineral", "monster"], "music": [], "stars": [],
	"gems": ["gem", "mineral"], "baking": [], "books": [], "flowers": [], "exploring": [], "trading": [],
}
const INTEREST_ITEMS := {
	"fishing": ["river_trout", "bass", "salmon", "pike", "carp", "glowfin", "moonfin", "blind_cavefish", "worm"],
	"gardening": ["turnip", "potato", "carrot", "tomato", "pumpkin", "melon", "strawberry", "blueberry", "mint", "sunpetal"],
	"metals": ["copper_bar", "iron_bar", "silver_bar", "gold_bar", "iron_ore", "silver_ore", "coal", "starmetal_bar"],
	"cooking": ["fish_stew", "veggie_soup", "pumpkin_soup", "miners_pasty", "omelette", "egg", "wild_leek", "chanterelle", "abyssal_broth"],
	"brewing": ["mint", "sageleaf", "emberroot", "sunpetal", "brew_vigor_1", "cider", "ale", "honeycomb", "brew_prospector"],
	"history": ["ancient_coin", "fossil_shell", "old_locket", "carved_figure", "rusty_key", "miners_tag", "star_map", "strange_idol", "ancient_cog"],
	"animals": ["egg", "honeycomb", "feather", "hay", "feed", "bramble_berry", "honey_cake"],
	"crafting": ["hardwood", "wood", "clay", "sap", "fiber", "iron_bar", "carved_figure", "ancient_cog"],
	"caves": ["crystal_shard", "glowcap", "cave_mushroom", "beetle_shell", "golem_core", "quartz", "blind_cavefish", "heartstone"],
	"music": ["clockwork_bird", "carved_figure", "honeycomb", "mead", "berry_wine", "feather"],
	"stars": ["moonshroom", "star_map", "quartz", "lumenfruit", "frost_crocus", "moonfin", "starfern", "starmetal_bar"],
	"gems": ["quartz", "amethyst", "topaz", "aquamarine", "ruby", "emerald", "crystal_shard", "heartstone"],
	"baking": ["wheat", "berry_pie", "fruit_tart", "honey_cake", "apple", "cherry", "campfire_bread", "egg"],
	"books": ["star_map", "soggy_letter", "old_locket", "herbal_tea", "carved_figure"],
	"flowers": ["sunpetal", "sweet_pea", "dandelion", "mossbloom", "frost_crocus", "crystalbloom", "ghostbloom"],
	"exploring": ["feather", "hazelnut", "wild_plum", "fossil_shell", "trail_mix", "ancient_coin", "glowcap", "dragon_tooth"],
	"trading": ["honeycomb", "ruby", "gold_bar", "cider", "pumpkin", "melon", "heartstone"],
}

# ======================================================================== greetings

## Per trait: four friendship tiers (0-1 hearts, 2-4, 5-7, 8-10).
const TRAIT_GREET := {
	"cheerful": [
		["Oh, hello! You're from the new farm, aren't you? Lovely to meet you!", "{Good_tod}! Welcome, welcome!", "Hello there! Isn't it nice to see a new face?"],
		["{player}! Hello again!", "Oh good, it's you, {player}! You've brightened my {tod}.", "Hello, hello! How's the farm treating you?"],
		["{player}! I was just hoping you'd stop by!", "There's my favorite farmer! Don't tell the others.", "Oh, {player}! Come here, I've got news. Well, sort of news."],
		["{player}! My day just got twice as good.", "Ah, there you are! I saved you the best part of my {tod}.", "{player}! I was telling everyone about you. Only good things, promise."],
	],
	"gruff": [
		["Hm. Farmer.", "...Yes?", "You need something?"],
		["{player}.", "Oh. You again. ...Good.", "Hm. {Greet_tod}."],
		["{player}. Good. Was hoping you'd come by. Don't make a thing of it.", "Hm. You look well. Farm's agreeing with you.", "Sit if you want. Or stand. Whatever."],
		["{player}. ...Glad you're here. There, I said it.", "Ah. My favorite pest. Come on, then.", "Hm. Saved you a seat. Don't get used to it."],
	],
	"shy": [
		["Oh! Um... hello.", "...Hi. Sorry, I didn't see you there.", "Um... {good_tod}. I don't think we've really met."],
		["Oh... hi, {player}.", "H-hello again, {player}.", "...Oh, it's you. That's good. I mean, hello."],
		["{player}! Oh... sorry, that was loud. Hi.", "...I was hoping I'd run into you, actually.", "Hi, {player}... it's nice when you visit."],
		["{player}... I'm always glad when it's you.", "Oh, {player}! I can talk normally around you now. Mostly.", "...I saved something to tell you. Give me a second to remember it."],
	],
	"curious": [
		["Oh, hello! You're from the farm, aren't you? What's it like out there?", "A new face! Where did you come from? What do you grow?", "Hello! Do you mind if I ask you about a hundred questions?"],
		["{player}! Seen anything interesting today?", "Oh, good, {player}. I've been saving questions for you.", "Hello again! What have you been up to?"],
		["{player}! Tell me everything. Start with the interesting parts.", "There you are! I've got a question I've been dying to ask.", "Oh good, {player}. My brain's been itchy all day."],
		["{player}! You always come back with the best stories.", "My favorite source of news! What did you find?", "{player}! Sit, sit. I want to hear about everything."],
	],
	"meticulous": [
		["{Good_tod}. You're the farm newcomer. Noted.", "Hello. Mind the step; it's a finger's width higher than the others.", "{Good_tod}. I don't believe we've been properly introduced."],
		["{Good_tod}, {player}. Right on time.", "Hello, {player}. I'd marked you down as likely to stop by.", "{player}. Good. Your boots are cleaner than last time. Progress."],
		["{player}. Good. I'd set aside a few minutes for you. Eleven, roughly.", "Ah, {player}. I've organized my thoughts for you.", "{Good_tod}, {player}. You look well-rested. Eight hours, I'd guess."],
		["{player}! I've cleared my schedule. Well, the next fifteen minutes of it.", "{player}. You're the one interruption I always pencil in.", "Ah, {player}. I alphabetized my spice rack and thought of you. Don't ask why."],
	],
	"adventurous": [
		["Hey there! From the new farm? Brave move, coming all the way out here.", "Ho there, stranger! Been down the caves yet?", "Hello! New in town? Best way to settle in is to go somewhere you've never been."],
		["{player}! Back from somewhere exciting?", "Hey, {player}! Where'd your boots take you today?", "There you are! Off on another adventure?"],
		["{player}! You've got that look, like you've been somewhere new.", "Hah, {player}! Tell me where you've been. I'm living through you lately.", "Hey, fellow wanderer!"],
		["{player}! When are you taking me along on one of your trips?", "My favorite trailblazer! What's the news from the edge of the map?", "{player}! If you're heading out again, I want a full report."],
	],
	"dreamy": [
		["Oh... hello. Sorry, I was miles away.", "Mm? Oh, hello there. The light's lovely {this_tod}, isn't it?", "Hello... you have a kind face, for a stranger."],
		["Oh, {player}... I was just thinking about clouds.", "Hello, {player}. Did you ever notice how the hills hum a little?", "{player}... hello. I was somewhere else for a moment."],
		["{player}! I dreamed you found something wonderful. Did you?", "Oh, it's you. Good. The day felt unfinished.", "Hello, {player}. You always arrive like a nice thought."],
		["{player}... I was hoping the wind would bring you by.", "There you are. I was writing a little poem about the farm. It's mostly about turnips.", "{player}! Sit with me a while and watch the sky do nothing."],
	],
	"practical": [
		["Hello. You're the new farmer. Good, the town needs more hands.", "{Good_tod}. Need anything? I'm short on time but long on advice.", "Hello. Can I help you with something?"],
		["{player}. Good to see you. Keeping busy?", "Hello, {player}. Getting your chores done?", "{player}. Need anything?"],
		["{player}! Good timing. I was about to take a break anyway.", "Ah, {player}. You're one of the few people who never wastes my time.", "{player}. Glad you stopped by. Got a minute?"],
		["{player}! Always time for you. Well, always ten minutes.", "There you are. I was going to come find you if you didn't turn up.", "{player}. Good. I could use someone sensible to talk to."],
	],
	"nosy": [
		["Oh! You're one of the farm folks. I've heard all about you. Well, some.", "Hello there! New, aren't you? What do you grow? Who've you met?", "Ooh, hello. Everyone's been wondering about you, you know."],
		["{player}! What's the news from the farm?", "Oh, {player}, perfect timing. Got any gossip? Any at all?", "Hello, {player}! Who've you been talking to today?"],
		["{player}! Come here, you'll want to hear this.", "There you are! I know three new things and I can only tell you two of them.", "{player}! I was about to come and find out what you've been up to."],
		["{player}! You're my favorite person to trade news with.", "Oh, finally, {player}! I've been saving the good stuff for you.", "{player}! I can tell you've got news. Out with it."],
	],
	"kind": [
		["Hello, dear. Settling in all right out on the farm?", "Oh, hello! You must be one of the new farmers. Let us know if you need anything.", "{Good_tod}. Welcome to {town}. I hope it's treating you gently."],
		["Hello, {player}. Have you eaten today?", "{player}! It's good to see you. Are you looking after yourself?", "Oh, hello, {player}. You look like you've been working hard."],
		["{player}! Come in out of the wind. How are you, really?", "There's a friendly face. Hello, {player}.", "Oh, {player}, I'm so glad to see you. Is everyone on the farm well?"],
		["{player}, dear! You always make my {tod} better.", "There you are. I was just thinking about you.", "{player}! Come here, you. How's my favorite farmer?"],
	],
	"proud": [
		["Ah. You must be the new farmer. You'll have heard of me, I expect.", "{Good_tod}. I'm {me}. People around here know the name.", "Hello. You'll find I'm the person to ask about most things."],
		["{player}. Good. Come to admire my work again?", "Ah, {player}. I've been doing excellent things today. Ask me about them.", "Hello, {player}. You've good taste in conversation partners."],
		["{player}! You're doing well, I hear. Almost as well as me.", "Ah, {player}. One of the few people in {town} who appreciates quality.", "{player}. I was just telling someone you've got real potential."],
		["{player}! My finest friend. I don't say that lightly. I don't say anything lightly.", "There you are. You're the best thing to happen to {town} since me.", "{player}! I'd boast about our friendship, but it speaks for itself."],
	],
	"anxious": [
		["Oh! Hello. Sorry, you startled me a little.", "H-hello. You're from the farm? Is it... safe out there?", "Oh, um, {good_tod}. Everything's fine. Probably."],
		["{player}! Oh, good, you're in one piece.", "Hello, {player}. Did you remember to eat? You should eat.", "Oh, {player}. Hi. Everything all right?"],
		["{player}! I was starting to worry. You're all right?", "Oh, thank goodness, it's you. I like it when it's you.", "{player}! You look well. That's a relief."],
		["{player}! Every time you come back safe, I breathe a little easier.", "There you are! I worry less once I've seen you.", "{player}... I'm so glad you're here. Truly."],
	],
	"witty": [
		["Ah, a new face! Don't worry, the rest of us are mostly harmless.", "Hello! You must be the farmer. The turnips speak highly of you.", "{Good_tod}. Fair warning: I'm the funny one. Allegedly."],
		["{player}! Still not eaten by a cave beetle, I see. Good start.", "Hello, {player}. You're looking very... agricultural.", "Ah, {player}. Come for the conversation, stay for the jokes."],
		["{player}! My favorite audience. Mostly because you laugh.", "If it isn't {player}, scourge of weeds and terror of turnips!", "{player}! I've been working on a joke. You're the test crowd."],
		["{player}! I'd say I missed you, but you'd get a big head.", "My best friend and harshest critic! How are you?", "{player}! Finally. Everyone else has heard all my material."],
	],
	"gentle": [
		["Hello. It's nice to meet you.", "{Good_tod}. Take your time, there's no hurry here.", "Oh, hello. Welcome. I hope {town} feels like home soon."],
		["Hello, {player}. It's good to see you.", "{player}. I hope your day's been kind.", "Oh, hello again. How are you?"],
		["{player}. I'm glad you came by.", "Hello, {player}. You've a peaceful way about you today.", "{player}... it's always calmer when you're around."],
		["{player}. There you are. Sit a moment with me.", "Hello, dear friend.", "{player}. Seeing you is the nicest part of my {tod}."],
	],
	"stubborn": [
		["Hm. A newcomer. We'll see if you last.", "Hello. If you're here to tell me to change something, don't.", "{Good_tod}. I'll warn you now: I'm usually right."],
		["{player}. Still here. Good. I said you would be.", "Hello, {player}. Still doing things your own way? Good. Same as me.", "{player}. You came back. I knew you would."],
		["{player}! Knew you'd come round to liking this place. I'm always right.", "{player}. You're one of the few people I'll listen to. Sometimes.", "Ah, {player}. Come to agree with me?"],
		["{player}. I don't change my mind about people, and I've decided you're the best.", "There you are. I told everyone you'd come by today. I was right.", "{player}! Stubborn as me, you are. It's why we get along."],
	],
}
const CHILD_GREET := [
	["Whoa, are you one of the farm people? Do you have a sword?", "Hi! I'm {me}. I'm not supposed to talk to strangers, but you look nice.", "Hi! Are you a grown-up or just a really tall kid?", "...Hi. Are you the new farmer? You've got dirt on your nose."],
	["{player}! Wanna see a rock I found?", "Hi, {player}! I'm on a secret mission. Don't tell.", "{player}! Did you bring anything cool?", "Oh! It's {player}! Hi hi hi!"],
	["{player}! You're my second-best friend! First is a frog.", "{player}! I was waiting for you! For like an hour!", "Hi, {player}! Guess what! No, guess!", "{player}! I learned a new word today. It's 'stalactite.' Isn't that a good one?"],
	["{player}!! You're my favorite grown-up. Don't tell my folks.", "{player}! I saved you a really good stick!", "{player}! When I grow up I'm gonna be just like you. But taller.", "{player}! I told everyone you're my best friend. Now it's official."],
]
const ELDER_GREET := [
	["Well now, a new face. Welcome, youngster.", "Hello there. Don't mind me, just watching the town go by.", "Ah, one of the farm folk. Come closer, my eyes aren't what they were."],
	["Ah, {player}. Good to see young folks about.", "{player}! Come to keep an old-timer company?", "Hello, {player}. My knees said you'd stop by."],
	["{player}! Sit, sit. I've a story you haven't heard. Probably.", "There's {player}. You brighten up an old face.", "Ah, {player}. You remind me of myself, long ago. That's a compliment."],
	["{player}. If I'd had a friend like you when I was young, oh, the trouble we'd have gotten into.", "My favorite visitor! Don't tell the others. They're all my favorite too.", "{player}, there you are. The day's better now."],
]
const WEATHER_TAG := {
	"clear": ["Fine weather for it, anyway.", "Not a cloud worth mentioning.", "Sun's out. Good for the crops."],
	"cloudy": ["Bit gray today.", "The clouds can't make up their minds.", "Nice soft light with all these clouds."],
	"rain": ["Rain's good for the fields, at least.", "Mind the puddles.", "You're soaked! Well, the crops are happy."],
	"storm": ["Some storm, isn't it?", "Listen to that thunder!", "Stay out of the open in this, all right?"],
	"fog": ["Can hardly see the end of the street in this fog.", "Fog's thick enough to slice.", "Spooky old fog, isn't it?"],
	"snow": ["Snow's settling nicely.", "Brr. Stamp your boots off.", "Everything's so quiet under the snow."],
	"night": ["Bit late to be out, isn't it?", "The lamps are lit. I love this hour.", "Quiet night, this."],
}

# ======================================================================== trait seasoning

const PREFIX := {
	"cheerful": ["Oh! ", "Ha! ", "Ooh! "], "gruff": ["Hm. ", "Right. ", "Listen. "],
	"shy": ["Um... ", "Oh, um... ", "..."], "curious": ["Oh! ", "Hey! ", "Hmm! "],
	"meticulous": ["Ahem. ", "Right. ", "Now then. "], "adventurous": ["Hah! ", "Hey! ", "Oh, listen! "],
	"dreamy": ["Mm... ", "Oh... ", "Hmm... "], "practical": ["Right. ", "So. ", "Well. "],
	"nosy": ["Ooh! ", "Psst. ", "Between us... "], "kind": ["Ah. ", "Oh! ", "Well now. "],
	"proud": ["Ahem. ", "Well. ", "Ha. "], "anxious": ["Oh! ", "Um... ", "Oh dear. "],
	"witty": ["Ha! ", "Okay, okay. ", "Right, so. "], "gentle": ["Mm. ", "Ah. ", "Oh. "],
	"stubborn": ["Hmph. ", "Look. ", "Well. "],
}
const SUFFIX := {
	"cheerful": [" Isn't that wonderful?", " Makes me smile just thinking about it!", " Ha! I love this town."],
	"gruff": [" Anyway.", " That's all.", " Hm."],
	"shy": [" ...Sorry, I'm rambling.", " ...If that makes sense.", " ...Um. That's all."],
	"curious": [" I wonder why that is.", " There's always more to find out, isn't there?", " What do you think?"],
	"meticulous": [" I've written it all down.", " I keep notes on these things.", " I've made a note of it."],
	"adventurous": [" Life's too short to stay home!", " That's what keeps things exciting.", " Makes me itch to go somewhere."],
	"dreamy": [" ...Funny, the things that stay with you.", " ...Hm? Sorry. I drifted off for a second.", " ...Sorry, where was I?"],
	"practical": [" Simple as that.", " That's how I see it, anyway.", " Anyway. Back to work soon."],
	"nosy": [" Not that I'm keeping track.", " ...You didn't hear it from me.", " Have you heard anything about that?"],
	"kind": [" Take care of yourself, all right?", " It's nice to have someone to tell.", " You're always welcome here, you know."],
	"proud": [" I know these things.", " Naturally.", " You heard it from me first."],
	"anxious": [" ...Sorry. I worry.", " Please be careful out there.", " I hope that's all right."],
	"witty": [" Don't quote me.", " I'll be here all week.", " Write that down. Or don't."],
	"gentle": [" It's nice to share these things.", " It's a small thing, but it matters to me.", " I find that comforting."],
	"stubborn": [" And that's that.", " Don't argue with me on this.", " Nobody'll convince me otherwise."],
}
## Each trait's own take on whatever interest {int} came up.
const TRAIT_TAKE := {
	"cheerful": ["Nothing makes my day like {int}. Well, nothing except visitors!", "If you ever want to talk about {int}, I've got all day. Truly. All of it."],
	"gruff": ["Don't talk much. But {int}... that, I like.", "{Int}. Keeps me out of trouble."],
	"shy": ["I don't usually tell people, but... I really love {int}.", "...When it comes to {int}, I forget to be nervous."],
	"curious": ["Every time I learn something about {int}, I end up with two new questions.", "Do you know much about {int}? I'm always hunting for someone to compare notes with."],
	"meticulous": ["I keep detailed notes on {int}. Forty-one pages so far, all cross-referenced.", "With {int}, it's all in the details. Most people skip the details. I don't."],
	"adventurous": ["I'd go a long way for {int}. Down a cave, up a cliff, across a river. Happily.", "Life's better with a bit of risk in it. Same goes for {int}."],
	"dreamy": ["Sometimes I think about {int} so long the sun moves without me.", "I dreamed about {int} again last night. It was lovely. There was a boat."],
	"practical": ["I like {int} because it's useful. I don't trust hobbies that aren't.", "People overcomplicate {int}. Do the work, mind the details, done."],
	"nosy": ["You'd be surprised who in {town} secretly loves {int}. I know. I always know.", "Everyone in {town} has an opinion on {int}. I've collected most of them."],
	"kind": ["I love sharing {int} with people. Everything's better with company.", "If you ever want to learn about {int}, come find me. I'd love to show you."],
	"proud": ["Nobody in {town} knows more about {int} than me. Ask anyone. They'll say me.", "When it comes to {int}, I'm quite accomplished, if I do say so myself. And I do."],
	"anxious": ["Nothing calms my nerves like {int}. Usually. Unless something goes wrong.", "I love {int}, but I always worry I'm doing it wrong."],
	"witty": ["My love of {int} is the only thing I've been consistent about. Ask my dishes. They're not done.", "They say you can't love {int} too much. I'm testing that theory, personally."],
	"gentle": ["There's a quiet sort of happiness in {int}, isn't there?", "When the day gets loud, I turn to {int}."],
	"stubborn": ["People tell me I spend too much time on {int}. People are wrong.", "I've got my own way of going about {int}, and I'm not changing it for anyone."],
}

# ======================================================================== interests

const INTEREST_LINES := {
	"fishing": {
		"s": ["The river's got a rhythm to it. Learn it, and the trout practically introduce themselves.",
			"Best bait's a plain old worm. Fancy lures are for showing off.",
			"[s2] Salmon run the river in autumn. If you're not out there at dawn, you're doing it wrong.",
			"[s3] Ice on the river means icefish. Cold fingers, warm heart.",
			"[rain] Rain like this brings the Rain Eels up after dark. Wet and dark, that's how they like it.",
			"[night] Night fishing's a different world. Moonfin come up to the surface like little lanterns.",
			"Ponds are for patience, rivers are for reflexes, and lakes are for long naps with a rod in your hand.",
			"I once lost a pike so big I still dream about it. It took my hat, too. Long story.",
			"A fish tank by the window is the best furniture there is. Fight me. Gently."],
		"q": ["Have you tried the lake yet? The bass there are bigger than they have any right to be.",
			"[d1] Do the cave pools really have fish with no eyes? I've heard stories but never seen one.",
			"[d5] You've been down past floor {deep}. Any water down there? Any fish?",
			"[d8] Is it true there are fish down deep that glow? Glowfin, someone called them. I'd love to see one.",
			"[d12] I heard the crystal pools have minnows you can see right through. Have you cast a line there?",
			"[d16] Floor {deep}... are there fish living down among the mushrooms? There must be, right?",
			"[d20] Someone said there are pools of lava way down. Surely nothing swims in lava. ...Does it?",
			"[d0] Have you fished the caves yet? I hear there are pools down there nobody's cast a line in for years.",
			"What's the biggest thing you've caught so far? Be honest. Okay, exaggerate a little."],
	},
	"gardening": {
		"s": ["[s0] Spring's for turnips, potatoes and carrots. Get them in early and you'll eat well all season.",
			"[s1] Summer's melon weather. Nothing tastes better than a melon you grew yourself.",
			"[s2] Pumpkins in autumn! Plant them early, they take their sweet time.",
			"[s3] Winter's hard on gardens. Frostleek's about the only crop stubborn enough to grow.",
			"Water every day, even when you're tired. Plants don't accept excuses.",
			"Strawberries keep producing once they're up. Patience pays out in berries.",
			"Mint spreads like gossip. Plant it in a corner and it'll own the yard by summer.",
			"[rain] Smell that? There's nothing like good soil after rain.",
			"I talk to my seedlings. They don't talk back, which is restful."],
		"q": ["What are you growing out on the farm right now? Anything I'd be jealous of?",
			"[d1] Does anything grow underground? Mushrooms, I suppose... but anything else?",
			"[d5] Is it true there's moss down there that glows? I'd love a cutting for my windowsill.",
			"[d14] If you find strange seeds or bulbs deep down, would you show me? Some cave plants grow up here, you know.",
			"Have you tried a sprinkler yet? It feels like cheating, but the good kind.",
			"Do you rotate your crops, or just plant whatever looks fun? Both are valid. One is more valid."],
	},
	"metals": {
		"s": ["Copper's honest. Iron's stubborn. Silver's moody. Gold is just showing off.",
			"Three ore and a lump of coal in the furnace and out comes a bar. Never gets old.",
			"There's nothing like the ring of a good hammer on a hot bar. Sounds like a bell for hard work.",
			"Upgrade your tools when you can. A good pickaxe does half the work for you.",
			"Copper sits near the surface. The good stuff hides deeper, as good stuff does.",
			"I've heard of a metal called starmetal. Purple, they say, and light as a promise."],
		"q": ["Found any decent ore lately? Copper, iron... anything shinier?",
			"[d5] How's the iron down past the first waystone? Rich seams, or just stone and bats?",
			"[d10] You've reached floor {deep}. Is there silver down there? There must be silver.",
			"[d20] Floor {deep}... anyone who gets that deep has seen gold. Have you?",
			"[d0] Haven't been down the mines yet? The first floors are full of copper. Easy pickings, even for a rusty pick.",
			"What are your tools made of these days? Don't say rusty. Please don't say rusty."],
	},
	"cooking": {
		"s": ["A fish stew is just a fish, a potato and some vegetables. And love. Mostly the fish, though.",
			"Miner's Pasty: potato, carrot, wheat for the crust. Keeps you going all day underground.",
			"A campfire can cook more than you'd think. Bread, skewers, roasted roots...",
			"An omelette is the best way to make one egg feel like a feast.",
			"[!herbalist] Good food is the best tonic. Don't let the herbalist hear me say that.",
			"[s2] Pumpkin soup season! Thick enough to stand a spoon in.",
			"[s3] Winter calls for something warm. Stew, chowder, anything in a bowl."],
		"q": ["Have you been cooking on the farm? What's your best dish?",
			"[d1] Do you eat properly underground? Please tell me you bring real food down there.",
			"[d10] Is it true some cave mushrooms are good eating? I'd love to cook with them.",
			"What do you eat on a long day out? Trail mix? You deserve better than trail mix.",
			"If you find any new ingredients in the caves, would you bring them by? I want to experiment."],
	},
	"brewing": {
		"s": ["Every ingredient carries essences. Vigor, earth, tide, lumen... toss them in the kettle and see what they become.",
			"Mint gives you zephyr, a quick step. Sageleaf gives you ward. The kettle does the rest.",
			"Three apples in a kettle make cider. Simple joys are the best ones.",
			"A good Glowbrew lights your way underground better than a dozen torches.",
			"Every brewer makes a murky mess now and then. It's a rite of passage.",
			"Honeycomb and more honeycomb makes mead. Most delicious arithmetic I know."],
		"q": ["Have you got a brewing kettle yet? It's the most fun you can have with leftovers.",
			"[d5] Found anything down there that hums or glows? Those make the strangest brews.",
			"[d10] Do you bring up crystal shards? Lumen and ward in one little rock. Perfect for the kettle.",
			"What's the strangest thing you've ever put in a kettle? Mine was a beetle shell. Don't ask.",
			"Do you mix your essences? Tide with a bit of lumen, I'm told, gets the deep fish biting."],
	},
	"history": {
		"s": ["{town} wasn't always this small. When the mines were open, this street was full of miners every morning.",
			"Folks used to find miner's tags in the river. Little tin tags with a name and a floor number.",
			"There's an old story about six friends with six lanterns who went deeper than anyone. Nobody agrees on how it ends.",
			"Every ancient coin in these hills has the same face on it. Nobody knows whose.",
			"The waystones in the caves are older than the town. Older than the mines. Someone put them there.",
			"History isn't just old things. It's things that happened to people. That's why it matters."],
		"q": ["Have you found anything old down there? Coins, carvings, anything with writing on it?",
			"[d10] Are there carvings deep in the caves? I've heard rumors about carvings.",
			"[d25] Floor {deep}... someone said there are halls down there. Built halls. Is that true?",
			"[d1] If you find any old notes in the caves, would you tell me what they say?",
			"Do you ever wonder who lived here before {town}? I do. Constantly."],
	},
	"animals": {
		"s": ["Chickens are smarter than they look. Not by much, but by some.",
			"A happy hen lays every day. Keep the feed trough full and talk to them nicely.",
			"Bees know more about this valley than we do. They visit every flower in it.",
			"Even cave creatures are just animals trying to get by. Well, most of them.",
			"[snow] Animals get cozy in the snow. Extra hay, and they'll forgive you anything."],
		"q": ["Have you got any chickens yet? Every farm needs at least one bossy hen.",
			"[d1] What are the bats like down there? Big? Friendly? Big and friendly?",
			"[d5] Have you met the shellback beetles? I'd love to see one up close. From a distance.",
			"[d8] Do the slimes have faces? I've always wondered if slimes have faces.",
			"Do you name your animals? You should. They work harder with a name."],
	},
	"crafting": {
		"s": ["A workbench is where ideas turn into furniture.",
			"Hardwood takes longer to work, but it'll outlast the both of us.",
			"Fiber, wood and a bit of patience. That's half of everything in this town.",
			"Every chair in {town} has a story. Most of them involve a splinter.",
			"Never go underground without a stack of torches. Wood and coal, that's all it takes."],
		"q": ["What have you been building on the farm? Fences? Sheds? A throne?",
			"[d5] Is the old mine timber any good down there? That wood's been seasoning for a hundred years.",
			"[d20] Somebody told me there are cogs and machine parts deep down. Who'd build machines in a cave?",
			"Have you got a proper workbench yet? Everything starts with a workbench."],
	},
	"caves": {
		"s": ["Waystones every five floors. Touch one and it remembers you. Clever stones.",
			"Bats are a nuisance, burrowers are worse, and slimes are just rude.",
			"Always carry an escape rope. Always. Even if you're only 'popping down.'",
			"Shellbacks are hard as stone from the front. Get them to charge a wall, then hit them where they're soft.",
			"Past the tenth floor the walls start to sparkle. Crystal hollows, the old miners called them."],
		"q": ["[d0] Have you been down the caves yet? The first few floors are gentle enough. Mostly.",
			"[d1] How far down have you been? Floor {deep}? That's a fine start.",
			"[d10] Floor {deep}! Did you see the crystal hollows? Are they as bright as the stories say?",
			"[d15] What's it like in the fungal depths? Is the air really thick with spores?",
			"[d20] The ember rift... is it warm down there? Warm like a hearthstone, I've heard.",
			"[d25] You've been past floor 25? Then you've seen the ancient halls. What did you find?"],
	},
	"music": {
		"s": ["Everyone in {town} hums. Listen at the market, it's a whole choir if you're patient.",
			"A song is just a story that decided to be prettier.",
			"I've been working on a tune about the river. It's mostly the river's idea.",
			"The old miners had work songs to keep time with their picks. I'm trying to remember all the verses."],
		"q": ["Do you sing while you work? You should. Plants love a bit of off-key humming.",
			"[d5] Is it true the waystones hum? What note? I need to know the note.",
			"[d10] Do the crystals ring when you tap them? I want to build an instrument out of them.",
			"What does the farm sound like at night? Crickets? Chickens? Snoring?"],
	},
	"stars": {
		"s": ["[night] Look up. That's the Kettle, there, and the Lantern just beside it.",
			"Clear nights are for stargazing. Cloudy nights are for complaining about it.",
			"Every star has a name somewhere. I'm working through them.",
			"Moonshrooms only come up under a night sky. Even mushrooms want a look at the stars.",
			"Old star maps from these parts don't match the sky. Either the stars moved, or the mapmaker was a romantic."],
		"q": ["Do you ever look up when you're walking home late? You should. It's free.",
			"[d5] Is there anything down there that looks like stars? Glowing moss, crystals, anything?",
			"[d15] They say deep enough down, the ceiling glows like a night sky. Have you seen it?",
			"Have you ever found a star map? I'd give a great deal to see an old one."],
	},
	"gems": {
		"s": ["Quartz is the friendliest gem. Amethyst is the prettiest. Ruby is the proudest.",
			"Every gem holds a little essence. Rubies carry vigor, emeralds carry verdant. Brewers love them.",
			"[!smith] A geode's a promise you can hold. The smith can crack them open for you.",
			"Rough gems look like nothing much. That's how you know they're worth something."],
		"q": ["Found any gems lately? Even quartz counts. Quartz always counts.",
			"[d5] Are there gems in the walls down there? Little glints of color?",
			"[d10] Have you seen the crystal chambers? Are the crystals really bigger than a house?",
			"[d20] Floor {deep}... the deep rock must be full of rubies. Have you found one?",
			"[d0] When you go down, keep an eye on the walls. A little sparkle usually means something good."],
	},
	"baking": {
		"s": ["Bread is just wheat that believed in itself.",
			"Honey cake: honeycomb, wheat and an egg. Simple. Glorious. Gone in minutes.",
			"A good berry pie should stain your fingers for a day.",
			"[s0] Cherries in spring! Cherry tart season can't come fast enough.",
			"[s2] Apples in autumn mean pies, and pies mean happiness. It's a simple system.",
			"You can tell the mood of {town} by how fast the bread sells. Everyone's been cheerful lately."],
		"q": ["Do you bake on the farm? Even campfire bread counts. Especially campfire bread.",
			"Are you growing any wheat? Every farm should have a corner of wheat.",
			"[d1] What do you take down the caves to eat? Tell me it's a pasty. It should be a pasty.",
			"Have you ever had a honey cake still warm? No? We need to fix that."],
	},
	"books": {
		"s": ["I'm on my third read of a book about river stones. It gets better every time.",
			"A book is a conversation with someone who isn't in the room.",
			"I found a soggy letter in the river once. I've read it so often I've filled in the missing words.",
			"[rain] Reading by lamplight while it rains. That's the good life."],
		"q": ["Do you have time to read on the farm? You should make time.",
			"[d1] Have you found any writing down in the caves? Old notes, scraps, anything?",
			"[d10] Someone told me the old explorers left notes all through the caves. Have you found any?",
			"If you ever find an old journal, would you let me read it? I'll be very careful with it."],
	},
	"flowers": {
		"s": ["Sunpetals turn to follow you if you walk around them slowly. Try it.",
			"Sweet peas smell best just before rain.",
			"Frost crocuses push up right through the snow. Bravest little flowers there are.",
			"[s0] Dandelions everywhere this time of year. People call them weeds. I call them optimists.",
			"A jar of wildflowers can fix almost any mood."],
		"q": ["Do you have any flowers on the farm? Even one pot helps.",
			"[d5] Do flowers grow in the caves? Something must bloom down there in the moss.",
			"[d10] I heard about a flower made of crystal, deep down. Is that real? Please say it's real.",
			"[d15] There's said to be a pale flower that blooms in the dark. A ghostbloom. Have you seen one?"],
	},
	"exploring": {
		"s": ["Every path has a bend you haven't seen around yet. That's my whole philosophy.",
			"I walked the whole ridge once, sunup to sundown. Found three ponds and a very confused goat.",
			"A good explorer brings rope, food and a friend. Actually, the friend first.",
			"Some of the best spots around {town} aren't on any map. That's what makes them good."],
		"q": ["Found any hidden places lately? Ponds, groves, anything?",
			"[d0] When are you going to try the caves? Everyone goes eventually.",
			"[d5] What's the strangest thing you've seen down there so far?",
			"[d15] Floor {deep}! What's it like that far down? Tell me everything.",
			"Have you walked out past the edge of the valley? I always wonder what's over the next hill."],
	},
	"trading": {
		"s": ["Buy low, sell honest. That's the whole trick.",
			"Gold bars, rubies, honeycomb. Some things always sell.",
			"The trick to a good trade is that both people walk away smiling.",
			"Melons and pumpkins fetch a fine price, if you can carry them."],
		"q": ["Found anything worth selling lately? I've an eye for value.",
			"[d10] What's the most valuable thing you've pulled out of the caves so far?",
			"How's the farm doing, money-wise? Don't be shy, numbers are my favorite gossip."],
	},
}
const KID_INTEREST := {
	"fishing": ["I caught a fish THIS big! Okay, this big. Okay, it was a boot.", "Do fish sleep? With their eyes open? That's so creepy and so cool."],
	"gardening": ["I planted a bean in a cup. It's my bean. Nobody touch my bean.", "Do carrots know they're carrots?"],
	"metals": ["The smithy is SO loud. I love it. Clang clang clang!", "I found a shiny rock. Is it gold? It's gold, isn't it."],
	"cooking": ["I made soup! It was mud. But it was good mud.", "When I'm big I'm gonna cook pie for breakfast every single day."],
	"brewing": ["I made a potion! It was juice and a leaf. I feel faster, though.", "If you drink a glowing potion, do YOU glow? I need to know."],
	"history": ["I found an old coin in the dirt! I think it's a pirate coin. There's no sea here, but still.", "Were there dinosaurs here before the town? There were, right?"],
	"animals": ["I'm teaching a chicken to come when I call it. It doesn't yet. But it will.", "If I had a pet slime I'd call it Wobbles."],
	"crafting": ["I'm building a fort out of sticks. It's got two rooms and a secret room.", "I made a boat out of bark. It floated for a whole second!"],
	"caves": ["I bet there's treasure in the caves. And a dragon. A small, nice dragon.", "Are the caves scary? Be honest. Okay, don't be honest."],
	"music": ["I can play a song on a leaf! Listen! ...Okay, it's mostly spit.", "I made up a song about the well. It's got eleven verses."],
	"stars": ["I counted all the stars last night. There's at least a hundred.", "Do you think stars are just really far-away lanterns?"],
	"gems": ["I'm collecting shiny rocks. I have eleven. Four are glass.", "If I find a ruby I'm gonna wear it on my nose."],
	"baking": ["I helped make bread! I mostly ate the dough. That counts.", "When I grow up I'm gonna have a bakery that only sells pie."],
	"books": ["I'm reading a book about a fish who goes on an adventure. It's the best book ever written.", "I can read big words now. Like 'shellback.' And 'definitely.'"],
	"flowers": ["I picked you a flower! ...I dropped it. Imagine a flower.", "If you blow on a dandelion you get a wish. I've used up about a hundred."],
	"exploring": ["I went all the way to the big rock by myself! Don't tell.", "I'm making a map of the whole town. I'm up to the well."],
	"trading": ["I traded my spoon for a marble. Best deal ever.", "I'll sell you this pebble for one coin. It's a very good pebble."],
}

# ======================================================================== jobs

const JOB_LINES := {
	"merchant": ["Stock comes in every morning. If you need seeds, I've got them. If I don't, I'll find them.",
		"Business at the {shop} has been brisk. Something about new farmers buying everything in sight.",
		"People think a shopkeeper just sells things. Mostly I listen. Everyone tells the shopkeeper everything.",
		"[s3] Winter's slow at the store. Good time to count stock and drink tea.",
		"[s0] Seed season! I've been up since dawn unpacking turnip seeds."],
	"smith": ["The forge has been hot since dawn. Bring me bars and I'll make you better tools.",
		"A sharp pick is a happy pick. Bring yours by when it's dull.",
		"I'll crack a geode for anyone who asks. Never know what's inside. That's the fun.",
		"Copper, iron, gold, starmetal. Every tool tier is a story about how deep someone went.",
		"My arms are tired, my apron's scorched and I wouldn't trade it for anything."],
	"innkeeper": ["The tavern's busiest after dark. Miners used to fill every seat; now it's farmers. I like farmers.",
		"I hear everything at the tavern. Mostly about fish that got away.",
		"Hearth Ale's the house favorite. Hops and wheat, brewed with care.",
		"A warm meal and a warm seat. That's all an inn has to be.",
		"Someone left a single sock on the bar last night. Just one. I have questions."],
	"herbalist": ["The Apothecary smells like mint and something I spilled three years ago.",
		"Every herb has a purpose. Even the ones that smell like feet.",
		"Bring me sageleaf and I'll teach you about ward. Bring me emberroot and I'll teach you about burns.",
		"Half my work is patching up people who went down the caves without a tonic. Bring tonics.",
		"Brewing is just cooking with ambition."],
	"carpenter": ["My workbench is full of half-finished chairs. They'll be whole chairs someday.",
		"Every building in {town} has at least one of my nails in it.",
		"Measure twice, cut once, apologize to the tree.",
		"Sawdust in my hair, sawdust in my tea. It's a good life.",
		"Fences, chests, a sturdy shed. If it's wood, I can help."],
	"angler": ["The shop smells like worms and river water, and I love it.",
		"Sold three rods today. Either everyone's fishing, or everyone's breaking rods.",
		"A bamboo rod's fine to start. But a better rod widens the catch zone, and that's the difference between a good day and a story.",
		"People ask where the best fishing is. I say 'wherever you are.' Then I fish the good spot myself.",
		"Deluxe bait brings rarer bites. Worms bring more bites. Pick your mood."],
	"mayor": ["The request board's been busy. People here like asking for help, and they like helping even more.",
		"Every community project brings {town} a little closer to what it could be.",
		"Paperwork, ribbon-cutting, settling an argument about a fence. A mayor's work is never glamorous.",
		"If you see a note on the board you can help with, take it. It means more than you'd think.",
		"I keep a list of everything this town needs. It gets shorter every season, thanks to you lot."],
	"farmer": ["Up before the sun, in bed after it. Farming's the best kind of tired.",
		"Turnips don't care about fence lines. Mine keep wandering into the neighbor's row.",
		"Rain on the right day is worth more than gold.",
		"Tried a new row spacing this season. The neighbors laughed. Now they're asking questions."],
	"miner": ["Forty years swinging a pick. My shoulders still wake up before I do.",
		"We used to sing on the way down the shaft. Kept the dark from feeling so big.",
		"The mines closed when I was young-ish. But the caves never closed, did they?",
		"I can still tell iron from stone by the sound. Clink, not clunk."],
	"teacher": ["Taught the kids about the caves today. Now every one of them wants to be an explorer.",
		"The schoolroom's quiet. Too quiet. Someone's planning something.",
		"I asked the kids what they want to be. One said 'a fish.' Full marks.",
		"Every kid in {town} can name the seasons, the seven essences and at least three kinds of beetle."],
	"musician": ["[night] I'm playing at the tavern later. Come if you like songs about rivers. That's all of them.",
		"I tune my fiddle every morning. The fiddle tunes me back a little.",
		"Wrote a new verse about the farm. It rhymes 'turnip' with 'learn it.' I'm proud of that.",
		"A town without music is just houses. {town} is not just houses."],
	"scholar": ["I'm cataloguing every kind of stone in the valley. Only a few hundred to go.",
		"The old mining records are full of floor numbers and complaints about lunch.",
		"Knowledge is like ore. You dig, you sift, you smelt it down into something useful.",
		"I've a theory about the waystones. It's very long. Remind me when you've got an hour."],
	"tailor": ["Mended four coats, two hats and a very sad scarecrow this week.",
		"Cave work is hard on clothes. Bring me your torn sleeves; I'll make them like new.",
		"Every stitch is a small promise that something will hold together.",
		"I'm designing a cap with a lantern hook. For the explorers. Very practical, very stylish."],
	"beekeeper": ["The bees were busy this morning. When they're busy, I'm happy.",
		"Bee houses near flowers make the best honeycomb. The bees are very particular.",
		"Got stung twice today. That's the bees saying hello. Firmly.",
		"[rain] Bees don't like rain. Neither do I, honestly. We have that in common."],
	"baker": ["Up at four for the bread. The town wakes to the smell, and that's my favorite thing.",
		"Flour in my hair, flour on my shoes, flour in places flour shouldn't be.",
		"Pies sell out by noon. Honey cakes by ten. Bread never sells out, because I bake enough. Mostly.",
		"Made campfire bread in the oven today. Purists were outraged. It was delicious."],
	"courier": ["Delivered eleven parcels today. One was a single turnip. I don't ask questions.",
		"I know every shortcut in {town}. Even the ones through people's gardens. Especially those.",
		"Letters, parcels, gossip. I carry it all. The gossip's the heaviest.",
		"My boots have been resoled four times this year. Worth it."],
	"painter": ["I keep trying to paint the light over the farm at dusk. It changes before I finish.",
		"Every color I need is somewhere in this valley. The trick is finding it.",
		"I painted the town hall last week. The picture, not the building. The mayor was disappointed.",
		"[s2] Autumn is a painter's season. Everything's gold and rust and orange."],
	"guard": ["I keep an eye on the cave road. Mostly I watch people go down hopeful and come up tired.",
		"Quiet night last night. Just an owl and a very determined fox.",
		"If anyone's late coming back from the caves, I'm the first to know. And the first to worry.",
		"Watchkeeping's mostly walking slowly and nodding at people. I'm very good at nodding."],
	"elder": ["Retirement suits me. I sit, I watch, I tell people how it used to be.",
		"I've seen {town} grow up, shrink down and grow up again. It's growing now. I like that.",
		"My knees predict the weather better than any almanac."],
	"explorer": ["I've walked a lot of valleys. This one has the deepest caves I've ever seen.",
		"Old explorers never retire. We just explore closer to home.",
		"I came to {town} for the caves and stayed for the bread.",
		"Every map I make is wrong within a year. That's how you know the world is alive."],
	"glassblower": ["Sand, heat and breath. Glass is the closest thing to magic I know.",
		"I want to blow a lamp that glows on its own. Glowcap juice in the glass, maybe?",
		"Crystal from the caves takes heat differently than sand. I'm still learning its moods.",
		"Broke three bottles this morning. Made one perfect one. That's a good day."],
	"historian": ["I'm writing a history of {town}. You're in it, by the way. Chapter twelve.",
		"The founders came for the mines. The people who stayed came for each other.",
		"Every old object has a story. My job is to listen to it.",
		"There's a gap in the town records, right where the Lantern Company would be. Curious, isn't it?"],
	"chef": ["I've cooked in a dozen towns. The produce here is the best I've worked with. Don't tell the others.",
		"A traveling chef learns one thing: everyone's grandparents made it better.",
		"I'm working on a broth that needs ingredients from the very deepest caves. Ambitious, I know.",
		"Fresh vegetables, fresh fish, a hot pan. The rest is just showing off."],
	"stargazer": ["I sleep in the day and work at night. The neighbors think I'm a very sleepy owl.",
		"Charted a new star last night. Probably. It might have been a firefly.",
		"The skies over {town} are as clear as anywhere I've been. That's why I came.",
		"[night] These are my working hours. Look up, the sky's wide awake."],
	"herder": ["Counted the flock this morning. One extra. Still don't know whose it is.",
		"Animals tell you everything if you're patient. Mostly they tell you they're hungry.",
		"Hay, water, a kind word. That's herding in a nutshell.",
		"The hills around {town} are perfect for grazing. Soft grass, good views."],
}

# ======================================================================== children and elders

const CHILD_LINES := [
	"Do you have a sword? Can I hold it? I won't swing it. Much.",
	"I'm gonna be a cave explorer when I grow up. Or a baker. Or a cave baker.",
	"I found a beetle this morning and named it Captain. It escaped. Captain is free now.",
	"Is it true there are fish with no eyes in the caves? How do they find the worms?",
	"My folks say I can't go in the caves till I'm bigger. I'm getting bigger every day, though.",
	"I can whistle with two fingers! Watch! ...Okay, I can almost whistle.",
	"[d10] Did you really go to floor {deep}? That's like... a hundred floors!",
	"[d1] Did you fight a bat? Did it bite you? Did you bite it back?",
	"[d0] Have you been in the caves? I bet there's a dragon down there. A little one.",
	"[snow] I made a snow-farmer! It's got a carrot nose and a turnip hat.",
	"[rain] I've been jumping in puddles all day. The big one by the well is the best.",
	"We're playing Lantern Company. I'm the one who carries the bread.",
	"Do grown-ups get to stay up as late as they want? Every night? Wow.",
	"I've got a secret hideout. It's behind the... wait, no. Nice try.",
	"Can chickens swim? I need to know for a reason.",
	"Do slimes taste like jelly? Asking for a friend. The friend is me.",
	"[night] I'm not supposed to be out this late. Don't tell. Pinky promise?",
	"I can count all the way to the deepest floor! Probably. Nobody knows how deep it goes.",
	"My teacher says the waystones are really old. Older than everybody's grandparents, even.",
	"If you find a gem, can I hold it? Just for a second? I'll give it back. Probably.",
	"I drew a picture of you. You're the one with the giant turnip.",
	"[s1] It's summer! Summer means no school and all the berries.",
	"[s3] I'm building a snow fort. It's for defending against beetles.",
	"[s2] I found the biggest leaf in the whole town. I'm keeping it forever. Or until it crumbles.",
	"When I'm big, I'm gonna go all the way to the bottom of the caves and say hi to whatever's there.",
	"I'm not scared of bats. I'm scared of the dark, a little. But not bats.",
	"Did you know worms have five hearts? My teacher said. Or maybe it was four. Lots, anyway.",
	"I found a feather that's half blue! It's probably from a magic bird. Or a regular bird.",
	"I had a dream that our whole house was a turnip. It was a nice dream.",
	"I'm practicing my scary face for when I meet a slime. Rawr! ...Was that scary?",
	"Everyone says the old bridge is haunted. I've been on it eleven times. Nothing yet.",
	"[d5] Is it true the waystones hum? I hum back at things. Maybe they'd like me.",
	"[rain] My boots are full of water. On purpose. It's a science experiment.",
	"[clear] It's too sunny to go inside. I've decided. I'm a grass person now.",
	"[fog] In the fog I can sneak up on anyone. I snuck up on you. Did you notice? No? Good.",
	"I'm saving up for a fishing rod. I've got three coins and a button.",
	"If you could be any animal, I'd be a bat. Upside down all day. No chores.",
	"I tried to dig to the caves from my backyard. I found a potato. It wasn't mine.",
	"I know where the ducks sleep. I'm not telling. It's a duck secret.",
	"When I grow up I'm going to have a farm with a hundred chickens and one very big dog.",
]
const ELDER_LINES := [
	"When I was young, the mine carts ran day and night. You could hear them rattling from my bedroom window.",
	"My folks used to whisper about the Lantern Company. Six friends, six lanterns. They went deeper than anyone, then came home and never said a word.",
	"They say the Lantern Company left notes all through the caves. If you find one, I'd love to hear it read aloud.",
	"In my day, a miner's pasty and a cup of tea got you through a twelve-hour shift.",
	"The old mine bell used to ring at shift change. Haven't heard it in years. I still listen for it.",
	"Nobody knows what the Lantern Company brought back up. Some say a stone that was warm, like it had a heartbeat. Some say just bread crumbs.",
	"We used to say 'mind the third board' when crossing anything rickety. Nobody remembers why. It's just what you say.",
	"This town was bigger once. Then smaller. Now it's growing again, and that's thanks to folks like you.",
	"[s3] I remember when the river froze solid and we skated all the way to the old mill.",
	"Every miner carried a tin tag with a name and a floor. If you find one down there, bring it home. Someone will remember.",
	"[d10] Floor {deep}! In my day, the bravest miners stopped at ten. The Lantern Company didn't, mind you.",
	"[d25] The ancient halls... the old folks swore they were real. I'm glad someone's finally seen them.",
	"I've outlived three cats, two roofs and one very stubborn plum tree. And I'm still here, telling stories.",
	"Young people rush. Old people dawdle. The trick is to do both, at the right times.",
	"There was a fishing spot my folks never told anyone about. A quiet pool past the ridge. I'm still looking for it.",
	"One of the Lantern Company was called Tobin, I'm sure of it. Tobin ate all the bread. That's the bit everyone remembers.",
	"We had a saying in the mines: go back for the people you came with. Remember that down there.",
	"My first pickaxe was so rusty it squeaked. My second was copper. I cried. Happy tears.",
	"[d0] Nobody's been down the caves in years. It'll be good to hear the old echoes again.",
	"The Lantern Company had a fisher who'd cast a line anywhere. Even into fire, if you believe the stories.",
]

# ======================================================================== family & friends

const SPOUSE_LINES := [
	"{rel} came home smelling of {rel_smell} again. I'd know that smell anywhere. It means home.",
	"{rel} and I have been together long enough to finish each other's sandwiches. Sentences. Both.",
	"I keep trying to surprise {rel} with {a_rel_love}. One of these days I'll manage it.",
	"{rel} spent all last night talking about {rel_int}. I nodded in the right places. Mostly.",
	"Don't tell {rel}, but I think nobody in {town} works harder.",
	"{rel} burned the porridge this morning and called it 'toasted.' I love that about them.",
	"We argued about whose turn it was to do the dishes. {rel} won by doing them. Sneaky.",
	"If you ever want to make {rel} smile, bring {a_rel_love}. Trust me on that.",
]
const KID_LINES := [
	"{rel} wants to be {rel_dream} when they grow up. Last week it was a frog.",
	"{rel} asked me how deep the caves go. I said 'deeper than bedtime.' It didn't work.",
	"{rel} brought home a beetle in a jar and named it after me. I'm choosing to be flattered.",
	"I caught {rel} digging a 'mine' in the garden. Got about a foot down. I was a little proud.",
	"Has {rel} been pestering you? They think you farm folk are the most exciting thing in {town}.",
	"{rel} ate three helpings at supper, then asked what was for dessert. Growing, I suppose.",
]
const ADULT_CHILD_LINES := [
	"{rel} works too hard. I tell them so. They tell me I did too. Fair.",
	"{rel} grew up into a fine {rel_job}. I take some of the credit. Most of it, really.",
	"{rel} still drops by every evening to check on me. I pretend I don't need it.",
	"If you see {rel}, tell them to eat something. A parent never stops saying that.",
]
const PARENT_FROM_KID := [
	"{rel} says I can't go in the caves till I'm taller. I've been stretching every morning.",
	"{rel} makes the best supper in the whole town. Better than the tavern, even.",
	"{rel} is {a_rel_job}! That's the coolest job there is. Probably.",
	"{rel} told me to stop bringing frogs inside. I'm bringing them in quieter now.",
	"When I grow up I'm gonna be {a_rel_job} like {rel}. Or a dragon.",
]
const PARENT_ELDER := [
	"{rel} still tells the old mining stories at supper. I know them by heart, and I still listen.",
	"{rel} swears their knees can predict rain. They're right more often than I'd like.",
	"{rel} taught me everything I know about {rel_int}. Well, nearly everything.",
]
const SIBLING_LINES := [
	"{rel} and I used to race to the river every morning. {rel} still claims to have won every time. Lies.",
	"Growing up with {rel} was like living with a very loud, very kind storm.",
	"{rel} borrowed my good boots again. I'll see them by winter, maybe.",
	"If {rel} tells you stories about me as a kid, they're exaggerated. Except the one with the goat.",
	"{rel} is supposedly the sensible one. I've seen them eat soup with a fork.",
	"Bring {rel} {a_rel_love} sometime. You'll make a friend for life.",
]
const GRANDPARENT_LINES := [
	"{rel} knows a story about the Lantern Company. It's different every time. That's the best part.",
	"{rel} gives me sweets when nobody's looking. Everybody's looking. {rel} does it anyway.",
	"{rel} says in the old days the whole town worked in the mines. Even the cats. I don't believe the cats part.",
	"{rel} has a secret fishing spot. I'm gonna find it. I've got a map. I drew it myself.",
]
const GRANDKID_LINES := [
	"{rel} asked if I'd ever seen a cave beetle. I said one the size of a wheelbarrow. That was a fib. Bread box, more like.",
	"{rel} wants a Lantern Company story every night. I make up a new bit each time. Don't tell.",
	"My grandkid {rel} is going to be {rel_dream} someday. Mark my words.",
	"{rel} brought me a 'treasure' today. It was a pebble. It's on my mantel now, in pride of place.",
]
const FRIEND_LINES := [
	"{rel} and I have tea together most evenings. We mostly sit quietly. It's the best kind of friendship.",
	"Have you met {rel}? The {rel_job}? Good sort. Tell them I said so.",
	"{rel} lent me a ladder three years ago. I still have it. We both know. We don't talk about it.",
	"{rel} is always going on about {rel_int}. I've learned more than I ever meant to.",
	"If you're ever after a gift for {rel}, {a_rel_love} would make their whole season.",
	"I'd trust {rel} with anything. Even my last slice of pie.",
	"{rel} came by yesterday smelling of {rel_smell}. Always a good sign; means they've been working.",
]
const KID_FRIEND_LINES := [
	"{rel} dared me to touch the cave entrance. I touched it TWICE.",
	"{rel} and me have a club. You can't join. ...Okay, maybe you can join.",
	"{rel} says they saw a slime in the well. I think {rel} made it up. I checked anyway.",
	"Me and {rel} are building a raft. It sinks, but it sinks slowly. That's progress.",
]
const RIVAL_LINES := [
	"{rel} thinks they know everything about {int}. They know some things. Hardly everything.",
	"Don't mention {rel} to me. ...Fine, mention them. What are they up to? Not that I care.",
	"{rel} and I have argued about the right way to stack firewood for eleven years. I'm winning.",
	"Saw {rel} at the market this morning. We nodded at each other. Very coldly. Very politely.",
	"If {rel} says anything about me, it's lies. Flattering lies, hopefully, but lies.",
	"I'll admit, and only to you, that {rel} is good at what they do. Don't you dare repeat that.",
]
const GOSSIP_LINES := [
	"Between you and me, {other} has a soft spot for {a_other_love}. You didn't hear it from me.",
	"Have you noticed {other} has been extra cheerful lately? Something's going on. I'll find out.",
	"{other} told me a secret yesterday. I won't say what. ...It's about {other_int}.",
	"I saw {other} heading for the river at dawn. With a basket. Interesting.",
	"Did you know {other} once wanted to be {other_dream}? I know everything.",
	"{other} the {other_job} has been humming all week. Humming! I need to know why.",
]

# ======================================================================== the wider world

const DEPTH_LINES := {
	0: ["Nobody from the farm's been down the caves yet, have they? No rush. They've waited this long.",
		"The caves will still be there when you're ready. Take a lantern and a friend."],
	1: ["Floor {deep}, I hear. The upper floors are copper country, good for finding your footing.",
		"Heard you've been poking around the first floors. Mind the bats. They're more startled than mean.",
		"Next waystone's at floor {next_way}, isn't it? Good thing to aim for."],
	5: ["Made it past the first waystone, I hear! They say it hums when you touch it.",
		"Floor {deep}! The mossy grottos are down around there, aren't they? Green and glowing, I'm told.",
		"Next waystone's at floor {next_way}, isn't it? Good thing to aim for."],
	10: ["Floor {deep}! That's crystal country. Is it true the walls sparkle like frost?",
		"Past the tenth floor? The old miners rarely went that far. Look at you lot."],
	15: ["Floor {deep}... that's the fungal depths, isn't it? Mind the spore spitters.",
		"Folks are saying the farm's been all the way down to floor {deep}. That's mushroom country."],
	20: ["Floor {deep}! The ember rift! Is the rock really warm down there?",
		"Floor {deep}, they say. Down where the stone glows red. I can hardly picture it."],
	25: ["Floor {deep}... the ancient halls. Somebody built those, you know. Long, long ago.",
		"You've been where the old stories end. Floor {deep}. What's it like?"],
}
const DEPTH_ANXIOUS := ["Floor {deep}? Oh, my nerves. Do you take enough bandages?",
	"Every time I hear 'floor {deep}' my stomach does a little flip. Please be careful.",
	"Floor {deep}. That's very deep. That's very, very deep. Do you have escape rope? Take two."]
const DEPTH_BOLD := ["Floor {deep}! I'd give my boots to see it. Well, I'd need my boots. I'd give my hat.",
	"Floor {deep}, now that's living! Next time, go one deeper for me."]

const EVENT_FRAMES := ["Did you hear? {ev}.", "I heard {ev}.", "Word around {town} is that {ev}.", "Is it true {ev}?",
	"Everyone at the tavern's saying {ev}."]
const EVENT_FRAMES_YOU := ["I heard {ev}!", "Is it true {ev}?", "Word is {ev}. Well done!", "So I hear {ev}. The whole town's talking."]
const KID_EVENT_FRAMES := ["Did you hear? {ev}! Whoa.", "Everybody's saying {ev}. I wanna do that when I'm big!", "Is it true {ev}? That's SO cool!"]
const KID_EVENT_YOU := ["Is it true {ev}? You're SO cool!", "Everybody says {ev}! Can I come next time?"]
const EVENT_REACT := {
	"place": ["New places! The valley's bigger than any of us thought.", "I'll have to go and see it myself someday.", "I love that the map keeps getting bigger."],
	"find": ["What a find!", "The things you folks turn up...", "I'd love to see it sometime."],
	"cave": ["That's deeper than most of us have ever been.", "The whole town's proud. Nervous, but proud.", "Floor by floor, eh? Steady does it."],
	"fish": ["The anglers will be green with envy.", "I'd love to hear how big it was. Then hear it again, bigger.", "That's a story worth telling at the tavern."],
	"farm": ["The farm's really coming along, isn't it?", "Good harvests make for a happy town.", "Fresh produce! My kitchen's grateful."],
	"brew": ["A new brew! I'd love to know what went in the kettle.", "I hope it tastes better than it smells. They usually don't.", "Kettles bubbling all over that farm, I hear."],
	"rescue": ["That's what friends are for.", "Go back for the people you came with. That's the old rule.", "I'm so glad everyone came home."],
	"people": ["{town} keeps growing. I like it.", "New neighbors! I'll have to say hello.", "More faces at the tavern. Good."],
	"trade": ["Good trade's the heart of a town.", "Business is booming!", "Everyone wins, I hope."],
	"project": ["{town} looks better every season.", "Proud of this town. Proud of all of you.", "It's lovely to see the place come together."],
	"recipe": ["Now I'm hungry.", "Save me a plate next time!", "A new recipe! That kitchen's never boring."],
}
const EVENT_SEASON := ["Another season already! Where does the time go?", "Seasons go quicker when you're busy, don't they?",
	"New season, new crops, same old {town}. I like it that way."]
const EVENT_FOUNDING := ["Feels like only yesterday you lot moved onto that farm.", "Remember when the farm was all weeds? Look at it now."]

const IDENTITY_OTHER := {
	"farmer": ["Folks say {who} has the greenest thumb in the valley.", "If you want to know when to plant, ask {who}. Everyone does now.", "Saw {who} out in the fields at dawn again. Those rows are the straightest in the valley."],
	"angler": ["Folks say if you want to know about fish, ask {who}.", "Saw {who} at the river again. I think the fish know them by name now.", "[!angler] The angler at the shop says {who} buys more bait than the rest of {town} put together."],
	"miner": ["{who} came through town covered in rock dust again. A miner through and through.", "[!smith] The smith says {who} brings in more ore than anyone.", "You can hear {who}'s pickaxe from the cave mouth, they say. Steady as a clock."],
	"brewer": ["{who}'s kettle is the talk of the town. Smells wonderful. Mostly.", "If you need a tonic, everyone says ask {who}.", "[!herbalist] Even the herbalist asks {who} about brewing now. Don't tell the herbalist I said so."],
	"cook": ["I hear {who} cooks for the whole farm. Lucky farm.", "{who}'s cooking is getting a reputation. A good one.", "Something smelled wonderful from the farm last night. {who} again, I'd bet."],
	"explorer": ["{who} always seems to be just back from somewhere nobody's been.", "If there's a new pond or path out there, {who} probably found it first.", "{who} knows the valley better than the old maps do, these days."],
	"fighter": ["{who} keeps the others safe down there, I hear. Good to have someone like that.", "They say {who} isn't afraid of anything that crawls. I'm afraid of everything that crawls."],
	"decorator": ["Have you seen how {who} has done up the farmhouse? Lovely.", "{who} has an eye for a cozy room. Everyone says so."],
}
const IDENTITY_YOU := {
	"farmer": ["You're the one with the tidy rows, aren't you? People notice.", "Folks have started asking you about crops, haven't they? That's how you know."],
	"angler": ["You smell faintly of river. Don't take it the wrong way. It's how the anglers know you're one of them.", "Folks say you can't walk past water without casting a line. I believe it."],
	"miner": ["You've got miner's hands now. Calloused in all the right places.", "[!smith] The smith says you bring in more ore than anyone. That's a compliment, coming from the smith."],
	"brewer": ["You're the brewer out there, aren't you? Your sleeves smell like mint and something mysterious.", "Everyone says your kettle's the best in the valley. No pressure."],
	"cook": ["Everyone says you're the cook of the household. Is that true? Can I come for supper?", "I hear the farm eats well, and it's your doing."],
	"explorer": ["You're the one always wandering off the map, aren't you? Good. Someone has to.", "Found anywhere new lately? You always seem to."],
	"fighter": ["People say you're the one who goes in first when there's trouble. Brave. Be careful, too.", "You've got that look of someone who's faced down a few beetles."],
	"decorator": ["I hear you've made the farmhouse lovely. You've got an eye for it.", "Folks say your place is the coziest in the valley. I'd love to see it."],
}

const SEASON_LINES := [
	["Spring at last. Everything smells green again.", "[rain] Spring rain. The crops will shoot up overnight.", "Planting season! Half the town's got dirt under their nails.", "The cherry trees are thinking about blossoming. Any day now."],
	["Summer days are so long you could do two days' work in one. Not that I do.", "Good weather for melons and sitting in the shade.", "The river's warm enough to wade in. Barely.", "[night] Summer nights are for staying up too late and not regretting it."],
	["Autumn's here. Harvest, pumpkins and woodsmoke.", "The salmon are running. You can almost hear the anglers getting excited.", "The leaves are turning. {town} looks like it's been dipped in honey.", "Time to put up jars and stack firewood."],
	["Winter's quiet. A good time for stews and long stories.", "The farm must be sleepy this time of year. Frostleek's about the only thing that'll grow.", "Cold enough to see your breath. Stay warm out there.", "Winter makes the tavern fuller and the evenings longer. Not a bad trade."],
]
const WEATHER_LINES := {
	"clear": ["Not a cloud anywhere. Your crops must be loving this.", "Beautiful day for it. Whatever 'it' happens to be.", "Sun on my face and nowhere to be. Well, somewhere to be, but slowly."],
	"cloudy": ["Cloudy days are the best for fishing. The fish can't see you coming.", "Gray sky, soft light. Good thinking weather.", "The clouds keep threatening rain and not following through."],
	"rain": ["At least you don't have to water the crops today.", "Rain's drumming on every roof in {town}. I find it soothing.", "Rain Eels come up on rainy nights. The anglers will be out tonight, mark my words."],
	"storm": ["Listen to that thunder! Stay out of the open, all right?", "The caves are probably the driest place in the valley today. Strange thought.", "Storms make the tavern cozy. Everyone crowds in and tells stories."],
	"fog": ["Fog like this, you could walk right past your own house.", "The fog makes {town} feel like it's floating.", "Careful on the river path in this fog. The bank gets slippery."],
	"snow": ["Snow muffles everything. The whole town sounds like it's whispering.", "Fresh snow! The footprints tell you who's been visiting who.", "Mind the ice by the well. I've seen three people slip already."],
	"night": ["The town's so quiet once the lamps are lit.", "Nights like this, I like to sit by the window and watch the lamps.", "Shouldn't you be asleep? Then again, so should I."],
}
const PROJECT_LINES := {
	"Mend the Old Bridge": ["Walking over the mended bridge still feels like a small miracle. Thank you for that.", "The old bridge doesn't creak anymore. I almost miss it. Almost."],
	"Market Stalls": ["The market stalls are lovely. I bought three things I didn't need yesterday.", "Market day feels like a festival now, with the new stalls."],
	"Welcome Cottages": ["The welcome cottages mean new neighbors. {town} feels alive again.", "Someone new moved into the welcome cottages. I've already said hello twice."],
	"Lamplighter's Posts": ["The new lamp posts make the walk home so much nicer.", "I love the lamps at dusk. The whole street glows."],
	"Expedition Lodge": ["The expedition lodge is full of maps and muddy boots. Exactly as it should be.", "Everyone's been gathering at the lodge to swap cave stories."],
}
const PROJECT_GENERIC := ["The '{project}' project was a fine bit of work. {town}'s better for it.", "Since the '{project}' project, the whole town's been in better spirits.",
	"I still can't believe we pulled off the '{project}' project. Well, you did, mostly."]
const REQUEST_HINT := {
	"deliver": ["I've put a note on the board. I could use {count_item}, if you've any to spare.", "If you've got {count_item} lying around, check the board. I'm asking."],
	"fish": ["I've been craving {a_item} something terrible. There's a note on the board, if you're fishing anyway.", "My note's on the board: {a_item}. Any angler will do. You'll do nicely."],
	"fetch": ["I dropped my {item} somewhere around floor {floor}. It's silly, but it matters to me. The note's on the board.", "If you're down near floor {floor}, keep an eye out for my {item}? I wrote it all on the board."],
	"slay": ["There've been too many {enemy_pl} around floor {floor}. I put up a note, in case anyone's handy with a weapon.", "Those {enemy_pl} near floor {floor} are getting bold. My note's on the board."],
	"explore": ["I've always wanted to know what {place} is like. If you go, would you tell me? I pinned a note.", "There's a note of mine on the board about {place}. I just want to hear what it's like."],
	"brew": ["I could really use {a_item}. My note's on the board, if you're brewing anyway.", "Kettle-folk wanted! I'm after {a_item}. It's on the board."],
}
const LOVE_LINES := [
	"If you ever find {a_love}, I'd trade a week of bread for it.",
	"You know what would make my whole season? {A_love}. Just saying.",
	"I've had my heart set on {a_love} for ages. Never seem to come across any.",
	"{Love}. That's my weakness. Everyone has one, and that's mine.",
	"Some people like gold. Some like flowers. Give me {a_love} and I'm happy for a month.",
]
const LIKE_LINES := [
	"I'm partial to {a_like}, if you're ever wondering what to bring by.",
	"Funny, {a_like} always cheers me up. Don't know why.",
	"Nothing fancy makes me happy. {A_like}, a quiet evening. Simple things.",
]
const KID_LOVE_LINES := [
	"If you find {a_love}, can I have it? Please? I'll trade you my second-best rock.",
	"I want {a_love} more than anything. More than staying up late. Almost.",
]
const HOUSEHOLD_LINES := [
	"[multi] How many of you are on that farm now? {pc}? It must be lively out there.",
	"[multi] You farm folk look out for each other. I like seeing that.",
	"[solo] Running that whole farm by yourself? I'm tired just thinking about it.",
]
const CLOSERS := [
	"How's the farm coming along, anyway?",
	"[multi] Are the others on the farm keeping well?",
	"Anyway, I won't keep you. Unless you want to be kept.",
	"Come by again soon, won't you?",
	"Have you eaten? You look like you could use a proper meal.",
	"What's growing in your fields these days?",
	"[d1] Bring me back a story from the caves next time.",
	"[shop] Stop by the {shop} sometime. I'll show you around.",
]

# ======================================================================== repeat visits

const AGAIN_GENERIC := ["Oh, hello again.", "Back so soon?", "{player}! Twice in one day.", "Forget something?", "Oh, it's you again. Good.",
	"Hello again, {player}.", "Ah, you're back.", "Missed me already?", "Oh! Hello again. Did you need something?"]
const AGAIN_TRAIT := {
	"cheerful": ["{player}! Again! Lucky me!", "Oh, hello again! Twice the fun!"], "gruff": ["Hm. Back.", "You again. Fine."],
	"shy": ["Oh... hi again.", "...Hello again. I don't mind. Really."],
	"curious": ["Back already? Find something?", "Oh good, you're back. I thought of another question."],
	"meticulous": ["Hello again. That's visit number {n} today.", "Back again. I'd allowed for that."],
	"adventurous": ["Back from the next adventure already?", "Back so quick? Did the road turn you around?"],
	"dreamy": ["Oh... you again. Like a nice song stuck in my head.", "Hello again... or is it still the first time? Never mind."],
	"practical": ["Back? Need something?", "Hello again. Something I can do?"], "nosy": ["Back again? What did I miss?", "Ooh, back already? Something happen?"],
	"kind": ["Hello again, dear.", "Oh, it's you again. Come in, come in."],
	"proud": ["Back for more of my wisdom? Understandable.", "Back again. People usually are, with me."],
	"anxious": ["Oh! Is everything all right? You're back.", "Back already? Did something happen? No? Oh, good."],
	"witty": ["You again! People will talk. I'll make sure of it.", "Back for the second show? Same jokes, I'm afraid."],
	"gentle": ["Hello again. It's nice to see you twice.", "Oh, welcome back."],
	"stubborn": ["Back? I haven't changed my mind, if that's why.", "Hm. You're back. I knew you would be."],
}
const STILL_GENERIC := ["Still here? Not that I mind.", "You must really like talking to me. I'll take it.", "Back again! I'm running out of things to say, you know.",
	"Hello again, again.", "We should just get you a chair here.", "I think I've told you everything I know today. Try me tomorrow.",
	"At this point we're practically neighbors. Well, we are neighbors.", "You know, there's a whole town out there. But I'm flattered.",
	"I've got nothing new, I'm afraid. Come back tomorrow and I'll have gossip."]
const STILL_TRAIT := {
	"cheerful": ["Hello again!! This is turning into a lovely day.", "You again! Best day ever, honestly."],
	"gruff": ["Again? ...Fine. Sit.", "Hm. Still here. Suppose you're good company."],
	"shy": ["Oh... hi again. I've run out of words, I think.", "...You can stay. I just don't have anything to say. Sorry."],
	"curious": ["Back again? Did you find something new since last time?", "Every time you come back, I hope you've got a story. Do you?"],
	"meticulous": ["That's {n} conversations today. A personal record.", "Visit {n}. I'll need a bigger notebook."],
	"adventurous": ["Shouldn't you be off somewhere exciting?", "Go on, the day's wasting! Go find something!"],
	"dreamy": ["Oh... are you a dream? You keep appearing.", "Mm. You again. Like the tide."],
	"practical": ["Shouldn't you be working? ...Don't say it. So should I.", "We've covered everything. Twice. Go on, get some work done."],
	"nosy": ["Back again? Something on your mind? You can tell me.", "You keep coming back. Is something going on? Tell me everything."],
	"kind": ["Always happy to see you, however many times.", "Come back as often as you like, dear."],
	"proud": ["Can't get enough of me. Understandable.", "I have that effect on people."],
	"anxious": ["Is everything all right? You keep coming back. Not that I mind!", "You're back again. Is it the caves? Did something happen? Oh, nothing? Good."],
	"witty": ["At this rate I'll have to start charging admission.", "If you come back once more, I'm putting you on the payroll."],
	"gentle": ["Hello again. Stay as long as you like.", "There's always room for you here."],
	"stubborn": ["I already told you everything. ...Fine, one more thing. No, I forgot it.", "You can keep coming back. I'll keep saying the same things."],
}
const KID_AGAIN := ["{player}! You came back!", "Again? Cool!", "Did you bring something this time?", "Hi again! I'm still on my mission.", "You're back! Wanna hear a joke? I forgot it."]
const KID_STILL := ["You're still here? Wanna play tag? You're it!", "I'm busy. Secret mission. ...Okay, I'm not busy.", "Are you following me? That's what I do to other people!",
	"You talk to me more than my teacher does. And my teacher talks a LOT.", "Shh! I'm hiding. ...From nobody. It's practice."]

# ======================================================================== gifts

const GIFT_TRAIT := {
	"love": {
		"cheerful": ["{A_item}! Oh, I LOVE this! You're wonderful!", "For me? {Item}? This is the best day!"],
		"gruff": ["...{Item}. That's... hm. Thank you. Really.", "Hm. {Item}. You remembered. ...Good."],
		"shy": ["Oh... {item}... for me? I don't know what to say... thank you so much.", "...You found {a_item}. I... I'll treasure it."],
		"curious": ["{A_item}! Where did you find it? How? Tell me everything!", "Oh, {item}! I've always wanted to study {them} up close."],
		"meticulous": ["{A_item}. In excellent condition, too. I'll keep it somewhere very particular.", "{Item}! I've had this on my list for a long time. I can finally tick it off."],
		"adventurous": ["{A_item}! Now THAT'S a gift with a story behind it!", "You brought me {a_item}? You legend!"],
		"dreamy": ["{A_item}... it's like something out of a dream. Thank you.", "Oh... {item}. I'd hoped, but I never thought..."],
		"practical": ["{A_item}. Now that's a gift I'll actually treasure. Thank you, truly.", "{Item}. Exactly what I'd have picked myself. Well done."],
		"nosy": ["{A_item}! How did you know? Who told you? ...Never mind, I love it!", "Ooh, {item}! Wait till everyone hears about this."],
		"kind": ["Oh, {player}... {a_item}. You're too good to me.", "{A_item}! You shouldn't have. But I'm so glad you did."],
		"proud": ["{A_item}. Finally, someone with taste worthy of mine. Thank you.", "{Item}! A gift fit for someone of my standing. I'm touched."],
		"anxious": ["{A_item}?! Oh, I hope it wasn't dangerous to get. Thank you so, so much.", "For me? {Item}? I don't deserve... no, I'm keeping it. Thank you!"],
		"witty": ["{A_item}! Okay, you can stay. Forever, if you like.", "Is it my birthday? It feels like my birthday. {Item}!"],
		"gentle": ["{A_item}... oh, how lovely. Thank you, {player}.", "{Item}. This means a great deal to me."],
		"stubborn": ["{A_item}. I always said nobody would bring me one. I was wrong. I'm never wrong. Thank you.", "Hm! {Item}! Well. You've won me over. Don't tell anyone."],
	},
	"like": {
		"cheerful": ["Oh, {item}! How nice! Thank you!"], "gruff": ["{Item}. Useful. Thanks."],
		"shy": ["Oh... {item}. That's nice of you. Thank you."], "curious": ["{Item}! I like these. Where did you find {them}?"],
		"meticulous": ["{A_item}. Good quality. I'll put {them} to proper use."], "adventurous": ["Nice, {item}! Thanks, friend."],
		"dreamy": ["Mm, {item}... thank you, that's sweet."], "practical": ["{Item}. Good choice. Thank you."],
		"nosy": ["Ooh, {item}! Thank you. Where'd you get {them}?"], "kind": ["Thank you, {player}. {Item}, how lovely."],
		"proud": ["{Item}. A respectable gift. Thank you."], "anxious": ["Oh! {Item}. Thank you, really. You didn't have to!"],
		"witty": ["{Item}! My favorite kind of present: the kind I like."], "gentle": ["{Item}. Thank you, {player}. That's kind."],
		"stubborn": ["{Item}, eh? ...All right, I like {them}. Thank you."],
	},
	"neutral": {
		"gruff": ["Hm. {Item}. Thanks."], "shy": ["Oh... thank you. That's kind."], "witty": ["{A_item}! I'll... find a place for {them}. Thank you!"],
		"practical": ["{Item}. I'm sure I'll find a use for {them}. Thanks."], "proud": ["{Item}. How thoughtful. I'll add it to my collection of things."],
		"cheerful": ["Ooh, a present! Thank you!"], "anxious": ["Oh! For me? Thank you, you didn't need to!"],
		"nosy": ["{Item}? Interesting choice. Thank you! What made you think of me?"], "kind": ["That's very sweet of you, {player}. Thank you."],
	},
	"dislike": {
		"gruff": ["...{Item}. No. Thanks, though."], "shy": ["Oh... {item}. Um. Thank you..."], "proud": ["{Item}? Oh. Well. It's the thought that counts, I'm told."],
		"witty": ["{Item}! Just what I... didn't need. Kidding! Mostly."], "practical": ["I won't lie, {item}'s not for me. Still, thank you."],
		"kind": ["Oh, {item}. That's thoughtful of you. It's... not really my thing, but thank you."], "stubborn": ["{Item}. No. Absolutely not. ...But thank you for thinking of me."],
		"cheerful": ["Oh! {Item}. Ha... well, it's the thought that counts!"], "anxious": ["Oh, um... {item}. Thank you. Sorry. I mean thank you."],
	},
}
const GIFT_GENERIC := {
	"love": ["{A_item}! Oh, this is perfect. Thank you so much.", "You remembered! {Item} is my absolute favorite."],
	"like": ["Oh, {item}! Thank you, I like these.", "{A_item}! That's very kind of you."],
	"neutral": ["Oh, {a_item}. Thank you.", "For me? That's kind. Thank you.", "{Item}? Well, thank you, {player}."],
	"dislike": ["Oh... {a_item}. That's... thoughtful. Thank you.", "Hm. {Item} isn't really my thing. But thank you for thinking of me."],
}
const GIFT_REASON := {
	"love": ["Anything to do with {int} makes my heart sing.", "You know how I feel about {int}."],
	"like": ["You know I've a soft spot for {int}.", "Anything to do with {int} suits me fine."],
}
const DISLIKE_REASON := {
	"junk": "I'm not sure what I'd do with it, honestly.", "fish": "I've never been able to stand the smell of fish, I'm afraid.",
	"monster": "Is that from a cave creature? It's still a bit... gooey.", "mushroom": "Mushrooms and I have never gotten along.",
	"ore": "Raw ore's not much use to me, I'm afraid.", "bait": "Is it... wriggling?",
}
const KID_GIFT := {
	"love": ["WHOA! {A_item}! Is it really for me? Best. Day. Ever!", "{A_item}!! I'm gonna keep it forever! Under my pillow!"],
	"like": ["Cool! {A_item}! Thanks!", "Ooh, {item}! Thank you!"],
	"neutral": ["Oh. Um. Thanks! What's it for?", "{A_item}? Okay! Thank you!"],
	"dislike": ["Ew. ...I mean, thank you.", "{A_item}? Do I have to keep it?"],
}
const BDAY_GIFT := {
	"love": "On my birthday, too! ", "like": "A birthday present! ", "neutral": "You remembered my birthday! ", "dislike": "Well, you remembered my birthday, and that's what matters. ",
}

# ======================================================================== identification

const IDENT_KNOW := {
	"material": ["That's {a_item}. Good for building; the workbench will turn it into all sorts of things."],
	"ore": ["That's {a_item}! Smelt three with a lump of coal in a furnace and you'll get a bar. Better tools start there."],
	"bar": ["{A_item}, nicely refined. Bring bars to the smithy and they become better tools."],
	"mineral": ["That's {a_item}. Hold it to your ear. Hear that hum? That's essence. Brewers and smiths both want these."],
	"gem": ["{A_item}! A gem like that carries essence for the kettle, and it'd make a lovely gift for the right person."],
	"crop": ["{A_item}! Good eating, good selling, and better still in a stew."],
	"herb": ["That's {a_item}. It carries strong essence, so it's a fine thing to toss in the brewing kettle. You can grow it, too."],
	"seed": ["That's {a_item}. Plant {them} on the farm, water every day, and you'll see sprouts soon."],
	"fruit": ["That's {a_item}. Lovely raw, better in a tart."],
	"sapling": ["{A_item}. Plant it on the farm and give it time; it'll be bearing fruit before long."],
	"forage": ["That's {a_item}. Wild-grown and free. Good eating, good cooking, and worth a try in the kettle."],
	"mushroom": ["That's {a_item}. Good on a skewer or in a stew, and the kettle likes its essence."],
	"fish": ["{A_item}! Grill it, stew it, or show it off. Some folks keep the rare ones in a fish tank."],
	"monster": ["That's {a_item}, from one of the cave creatures. Creature parts carry strong essence. The kettle loves them."],
	"brew": ["That's {a_item}. Drink it when you need it; the effect wears off after a while, so time it well."],
	"food": ["That's {a_item}. Eat it to get your strength back. Good food will carry you through a long day underground."],
	"drink": ["That's {a_item}. A fine drink, and a good way to warm up after a long day."],
	"curio": ["That's {a_item}. Old, and it's seen things. Put it on a display stand, or ask around; someone in town might treasure it."],
	"junk": ["That's... {a_item}. Honestly? It's junk. But somebody lost it once, so it has a story."],
	"bait": ["That's {a_item}. Bait! Put it on your line and the fish will come running. Swimming."],
	"tool": ["That's {a_item}. Good tools do half the work for you."],
	"weapon": ["That's {a_item}. Good gear makes the caves a lot friendlier."],
	"gear": ["That's {a_item}. Wear {them}; good gear makes the caves a lot friendlier."],
	"ammo": ["That's {a_item}. You'll want a bow for those."],
	"placeable": ["That's {a_item}. Set it down at home or on the farm and see how it fits."],
	"consumable": ["That's {a_item}. Keep a couple in your pack. You'll be glad you did."],
	"animal": ["That's {a_item}. Farm goods like that make the best cooking ingredients."],
	"quest": ["That's {a_item}... I'd bet someone in town has been missing that. Ask around."],
}
const IDENT_PRE := {
	"cheerful": "Oh, I know this one! ", "gruff": "Hm. Know this one. ", "shy": "Oh! I... actually know this one. ",
	"curious": "Ooh, let me see! Yes! ", "meticulous": "Let me be precise. ", "adventurous": "Ha! Seen plenty of these. ",
	"dreamy": "Oh, how pretty... yes. ", "practical": "Right. ", "nosy": "Ooh, where'd you get this? Never mind. ",
	"kind": "Let's have a look, dear. ", "proud": "Easy. This is my field. ", "anxious": "Oh! Careful with it. ",
	"witty": "Ah, a quiz! ", "gentle": "Ah, let me see. ", "stubborn": "I know exactly what this is. ",
}
const IDENT_CHEER := ["Good find, by the way.", "Hang on to {them}; you'll find a use.", "Not a bad find at all!", "You've a good eye."]
const REDIRECT_WHO := {
	"fish": "the angler at the Bait & Tackle", "bait": "the angler at the Bait & Tackle",
	"ore": "the smith", "bar": "the smith", "mineral": "the smith", "gem": "the smith", "tool": "the smith", "weapon": "the smith", "gear": "the smith", "ammo": "the smith",
	"herb": "the herbalist at the Apothecary", "brew": "the herbalist at the Apothecary", "mushroom": "the herbalist at the Apothecary", "monster": "the herbalist at the Apothecary", "forage": "the herbalist at the Apothecary",
	"crop": "the shopkeeper at the General Store", "seed": "the shopkeeper at the General Store", "sapling": "the shopkeeper at the General Store", "fruit": "the shopkeeper at the General Store", "animal": "the shopkeeper at the General Store",
	"food": "the innkeeper at the Tavern", "drink": "the innkeeper at the Tavern",
	"material": "the carpenter", "placeable": "the carpenter",
	"curio": "the mayor at the Town Hall", "junk": "the mayor at the Town Hall", "quest": "the mayor at the Town Hall",
}
const REDIRECT_ROLE := {
	"the angler at the Bait & Tackle": "angler", "the smith": "smith", "the herbalist at the Apothecary": "herbalist",
	"the shopkeeper at the General Store": "merchant", "the innkeeper at the Tavern": "innkeeper", "the carpenter": "carpenter",
	"the mayor at the Town Hall": "mayor",
}
const IDENT_DONT := {
	"cheerful": "Ooh, no idea! But {who} would know, I bet!", "gruff": "Don't know. Ask {who}.", "shy": "Um... I'm not sure. Maybe {who}?",
	"curious": "I don't know! Will you ask {who} and come tell me what they say?", "meticulous": "Not my area, and I'd rather not guess. Ask {who}.",
	"adventurous": "Never seen one! {Who} might know, though.", "dreamy": "Mm... it looks like a secret. {Who} might know its name.",
	"practical": "Not my field. Try {who}.", "nosy": "No idea, but now I'm dying to know too. Ask {who}, then come straight back!",
	"kind": "I'm sorry, I don't know. {Who} should be able to help you.", "proud": "It's not my field, and I'm excellent in my field. Ask {who}.",
	"anxious": "I don't know... is it safe? Maybe ask {who}.", "witty": "If I guessed, I'd guess wrong. {Who}'s your best bet.",
	"gentle": "I'm not sure, I'm afraid. {Who} would know.", "stubborn": "I don't know, and I won't pretend I do. Ask {who}.",
}
const IDENT_DONT_GENERIC := ["Hm, no idea. Try {who}.", "That's beyond me, I'm afraid. {Who} would know."]

# ======================================================================== shops

const SHOP_GREET := {
	"merchant": ["Welcome to the {shop}! Seeds, supplies, a little of everything.", "Come in, come in. Fresh stock this morning.",
		"Looking for something in particular? If I don't have it, I'll know who does.", "[s0] Spring seeds are in! Get them early.",
		"[s3] Winter stock's thin, but I've got what keeps a farm running."],
	"smith": ["Welcome to the {shop}. Mind the sparks.", "Need an upgrade? Bring bars and I'll make it happen.", "The forge is hot. What are we making today?",
		"Got a geode? I'll crack it for you."],
	"innkeeper": ["Welcome to the {shop}! Pull up a stool.", "Hungry? Thirsty? Both? Good.", "[rain] Come in out of the rain! What'll it be?",
		"[night] The evening crowd's settling in. Find a seat.", "[snow] Shake the snow off and get by the fire. What'll it be?"],
	"herbalist": ["Welcome to the {shop}. Careful, that jar bites. ...Kidding. Mostly.", "Need tonics for the caves? You've come to the right place.",
		"Seeds for the herb garden, tonics for the road. Have a look."],
	"carpenter": ["Welcome to the workshop. Watch the sawdust.", "Need furniture? Materials? A sturdy fence?", "Building something? I can help with that."],
	"angler": ["Welcome to the {shop}! Rods, bait and stories. The stories are free.", "Fish biting today? Let's get you set up.",
		"Need bait? Worms are fresh. Well, they're alive.", "[rain] Rain's out, eels are up. Need bait?"],
	"mayor": ["Welcome to the Town Hall. The request board's just there, and the projects ledger is open.", "Come to see what the town needs? There's always something.",
		"Ah, good. Let's talk about what {town} could become."],
}
const SHOP_TAG := {
	"cheerful": "So glad you're here!", "gruff": "Don't touch the hot stuff.", "shy": "...Take your time.", "curious": "Tell me what you're working on!",
	"meticulous": "Everything's labeled. Please put things back where you found them.", "adventurous": "Gearing up for something big?",
	"dreamy": "Browse as long as you like.", "practical": "Let me know what you need.", "nosy": "So, what are you buying it for?",
	"kind": "Take whatever time you need, dear.", "proud": "Finest goods in the valley, naturally.", "anxious": "Careful with the shelves, they wobble.",
	"witty": "No refunds on bad decisions.", "gentle": "No hurry at all.", "stubborn": "And no haggling. I mean it.",
}
const SHOP_FRIEND := ["Always good to see you, {player}.", "My favorite customer! Don't tell the others.", "Ah, {player}! Come in, come in."]
const SHOP_CLOSED := {
	"merchant": ["[night] We're closed for the night. Come back in the morning!", "Closed right now, I'm afraid. Restocking. Come back later!"],
	"smith": ["[night] The forge is cold for the night. Come back tomorrow.", "Closed for now. Even the forge needs a rest."],
	"innkeeper": ["We're not open just yet. Kitchen's still warming up.", "[night] Closing up for the night. Off to bed with you!"],
	"herbalist": ["The Apothecary's closed. Herbs need their rest too.", "[night] Closed for the night. If it's urgent, drink water and sleep."],
	"carpenter": ["Workshop's closed. Sawdust is settling.", "[night] Closed for the night. Tools are put away and I'm not getting them out again."],
	"angler": ["Shop's closed. I'm probably fishing.", "[night] Closed for the night. The worms are sleeping."],
	"mayor": ["The Town Hall's closed. The request board's still out front, though.", "[night] Closed for the night. Even mayors sleep. Occasionally."],
}
const CLOSED_TRAIT := {
	"gruff": "Closed. Come back later.", "shy": "Oh... we're closed, sorry... maybe later?", "witty": "Closed! The sign's not just decorative.",
	"meticulous": "We're closed. Opening hours are posted. Precisely.", "kind": "Sorry, dear, we're closed. Come back later and I'll look after you.",
	"anxious": "Oh, no, we're closed! I'm sorry! Please come back!", "stubborn": "Closed means closed. Come back later.",
}

# ======================================================================== requests

const ROLE_REASON := {
	"merchant": "to restock the shelves", "smith": "for a commission at the forge", "innkeeper": "for tonight's stew pot",
	"herbalist": "for a batch of tonics", "carpenter": "for a job at the workshop", "angler": "to restock the shop",
	"mayor": "for a town project", "farmer": "for the fields", "teacher": "for a lesson with the kids",
	"musician": "for a song. It's a long story", "scholar": "for my research", "tailor": "for a commission",
	"beekeeper": "for the hives", "baker": "for the morning bake", "courier": "for a delivery that's running late",
	"painter": "for a new painting", "guard": "for the watch post", "child": "for a SECRET project", "elder": "for an old family recipe",
	"miner": "for old times' sake", "explorer": "for my next trip", "glassblower": "for the kiln", "historian": "for the archive",
	"chef": "for a new dish", "stargazer": "for my observations", "herder": "for the flock",
}
const REQ_TEXT := {
	"deliver": ["Wanted: {count_item}, {reason}. Will pay fairly and say thank you twice.",
		"Could anyone spare {count_item}? I need {them} {reason}.",
		"Looking for {count_item}, {reason}. Bring {them} by whenever you can."],
	"fish": ["Wanted: {count_item}, as fresh as you can manage. I've been dreaming about it all week.",
		"Any anglers out there? I'm after {count_item}.",
		"Fisherfolk! I'd be ever so grateful for {count_item}."],
	"fetch": ["I lost my {item} somewhere around floor {floor}. It's not worth much to anyone else, but it's worth everything to me.",
		"Dropped my {item} on floor {floor}. At least, I think it was {floor}. If you find it, I'll owe you forever.",
		"Somewhere near floor {floor} there's {a_item} that belongs to me. Please bring it home."],
	"slay": ["There are too many {enemy_pl} around floor {floor} lately. Could someone thin them out?",
		"Notice: the {enemy_pl} near floor {floor} are getting bold. Anyone handy with a weapon, please help.",
		"Would someone deal with the {enemy_pl} around floor {floor}? I keep hearing stories and I don't like them."],
	"explore": ["I've always wondered about {place}. Would someone go and see it, then come tell me all about it?",
		"Has anyone been to {place}? Please go and look, then tell me what's there. Every detail!",
		"Wanted: one brave soul to visit {place} and describe it to me over tea."],
	"brew": ["In need of {count_item}. My own kettle's been sulking.",
		"Wanted: {count_item}, fresh from the kettle, please.",
		"Could a kind brewer make me {count_item}? I'll repay you in gratitude and baked goods."],
}
const KID_REQ := {
	"deliver": "I need {count_item} for a SECRET project. Don't tell my folks.", "fish": "Can someone catch me {count_item}? I want to see one up close!!",
	"fetch": "I lost my {item} on floor {floor}. I wasn't supposed to be there. PLEASE find it.", "slay": "There are too many {enemy_pl} near floor {floor}. Please beat them up. Nicely.",
	"explore": "What's {place} like? Somebody go look and tell me EVERYTHING.", "brew": "I want {count_item}! I promise I won't drink it all at once.",
}
const REQ_SIGN := {
	"cheerful": "Thank you so much! — {me}", "gruff": "— {me}", "shy": "...Thank you. — {me}", "curious": "Tell me how it goes! — {me}",
	"meticulous": "— {me}. P.S. Please knock twice.", "adventurous": "Cheers! — {me}", "dreamy": "— {me}, with hope",
	"practical": "— {me}. Payment on delivery.", "nosy": "— {me}. P.S. Bring news, too.", "kind": "With warm thanks, {me}",
	"proud": "— {me} {last}", "anxious": "— {me}. Please be careful!", "witty": "— {me}. No pressure. (Some pressure.)",
	"gentle": "— {me}, with thanks", "stubborn": "— {me}. Don't bring the wrong one.",
}
const REQ_THANKS := {
	"deliver": ["{Count_item}, just as I asked. Thank you, {player}!", "You brought {them}! That's a weight off my mind."],
	"fish": ["{A_item}! Oh, look at it. Thank you!", "A fine catch. Thank you, {player}. Supper's sorted."],
	"fetch": ["My {item}! You found it! I thought it was gone for good.", "Oh... my {item}. I can't tell you what this means to me."],
	"slay": ["Things have gone quiet around floor {floor}, I hear. That's your doing. Thank you.", "No more stories about {enemy_pl} at the tavern. Thank you!"],
	"explore": ["So {place} is real! Thank you for going. I'll be thinking about it for days.", "You went to {place} just because I asked? Thank you. I can almost picture it now."],
	"brew": ["{A_item}, fresh from the kettle! Thank you!", "That's exactly the brew I needed. Thank you, {player}."],
}
const THANKS_TRAIT := {
	"cheerful": "You're a star!", "gruff": "Owe you one.", "shy": "...I really mean it.", "curious": "Now tell me how you did it!",
	"meticulous": "I'll mark the note as done.", "adventurous": "Next round's on me!", "dreamy": "It feels like a wish come true.",
	"practical": "Here's your reward. Fair's fair.", "nosy": "I'm telling everyone it was you.", "kind": "Bless you, truly.",
	"proud": "I knew I'd chosen the right person.", "anxious": "And you're all right? Not hurt? Good.", "witty": "I'd hug you, but I'm told that's a lot.",
	"gentle": "Thank you, from the bottom of my heart.", "stubborn": "I said someone would do it. I was right.",
}

# ======================================================================== wishes, milestones, birthdays

const WISH_GENERIC := [
	"Can I tell you something? I've always wanted {a_wish}. Ever since I was small. Silly, isn't it?",
	"I've never told anyone this, but... I've always dreamed of having {a_wish}. Just to hold it, once.",
	"You know what I'd give almost anything for? {A_wish}. I've wanted one since I first heard of it.",
]
const WISH_TRAIT := {
	"gruff": "Don't laugh. ...Always wanted {a_wish}. There. Said it.", "shy": "...Promise you won't tell? I've always dreamed of having {a_wish}.",
	"proud": "I have nearly everything a person could want. Except {a_wish}. That one's eluded me.",
	"meticulous": "There's one thing on my list I've never been able to cross off: {a_wish}.",
	"dreamy": "Some nights I dream about {a_wish}. Just holding it. Isn't that silly?",
	"practical": "If I'm honest, there's one thing I've always wanted: {a_wish}. Not practical at all, I know.",
	"witty": "My one great wish? {A_wish}. Well, that and a nap. But mostly {wish}.",
	"anxious": "I've always wanted {a_wish}... but please don't do anything dangerous for it. Promise?",
	"adventurous": "Want to know my big dream? {A_wish}. I'd go to the bottom of the world for it, if my knees agreed.",
	"curious": "I've read about {wish} a hundred times and never seen one. I'd give anything to.",
	"nosy": "Here's a secret nobody in {town} knows: I've always wanted {a_wish}. Now you know. Keep it.",
	"stubborn": "Everyone says I'll never get {a_wish}. I've decided I will.",
	"kind": "I've never asked anyone for much. But I've always hoped, someday, for {a_wish}.",
	"cheerful": "Ooh, you want to know my biggest wish? {A_wish}! Just thinking about it makes me grin.",
	"gentle": "There's one thing I've always quietly hoped for. {A_wish}. It's all right if it never happens.",
}
const WISH_REASON := {
	"Ridge Koi": "They say it lives in exactly one pond in the whole world.", "Starfern": "Every essence at once, they say. Nobody here has ever seen one.",
	"Starmetal Bar": "Purple metal, light as a promise. Imagine working it.", "Abyssal Broth": "A dish made from the very deepest places. Nobody's sure it should be eaten.",
	"Prospector's Lamp Oil": "A brew that makes ore glow through the dark. The old miners swore by it.", "Strange Idol": "Heavy and always cold, the stories say. I want to know who made it.",
	"Honey Cake": "My folks made one every birthday. Nobody's made me one since.", "Ancient Cog": "Machined by someone, long ago, for something. I want to know what.",
	"Heartstone": "They say it's warm, and it beats like a heart.", "Clockwork Bird": "A little bird that still sings when it's wound. Can you imagine?",
	"Lumenfruit": "A fruit that glows. From a pale tree that grows in the deep.", "Emerald": "Green as spring, and full of verdant essence.",
	"Star Map": "An old one, with the constellations all wrong. Or all old.", "Crystalbloom": "A flower made of crystal. It sounds like a fairy tale.",
	"Enormous Tooth": "From something enormous, deep down. What, though?",
}
const WISH_DONE := [
	"{A_wish}... you found it. You actually found it. Thank you. I'll never forget this.",
	"Is that... {a_wish}? For me? I've waited my whole life for this moment. Thank you.",
	"Oh, my friend. {A_wish}. I don't have the words. I'm going to cry. Happy tears, I promise.",
]
const WISH_DONE_TRAIT := {
	"gruff": "...{A_wish}. I... hm. Give me a moment. Thank you. Truly.", "proud": "{A_wish}. I'm rarely speechless. I'm speechless. Thank you.",
	"meticulous": "{A_wish}. I can finally cross it off. I'm going to frame the list.", "witty": "{A_wish}! I take back every joke I've ever made. Well, most of them.",
	"stubborn": "I said I'd have {a_wish} one day. I was right. Because of you. Thank you.", "shy": "...{A_wish}. For me. I... thank you. Thank you so much.",
}
const HEART_GIFT := [
	["Here, I want you to have this. {Gift}. It's nothing much, but I thought of you.", "Take this. {Gift}. Call it a thank-you for being friendly.", "I've got something for you. {Gift}. Go on, take it."],
	["I've been meaning to give you this. {Gift}. You've been a good friend to me.", "Wait, before you go. Here: {gift}. I wanted you to have it.", "This is for you. {Gift}. Don't make a fuss, just take it."],
	["This is {gift}. It means something to me, and I want you to have it.", "I don't give this to just anyone. {Gift}. You're not just anyone.", "Here. {Gift}. I've been saving it for someone who'd appreciate it."],
	["Here... take this. {Gift}. There's nobody I'd rather give it to.", "You're one of my dearest friends, you know. Here: {gift}. From the heart.", "I want you to have {gift}. Think of me now and then."],
]
const HEART_GIFT_TRAIT := {
	"gruff": "Here. {Gift}. Don't make it weird.", "shy": "...This is for you. {Gift}. I hope you like it...",
	"meticulous": "I've prepared this for you: {gift}. I checked it twice.", "proud": "Behold: {gift}. Only the finest for my friends.",
	"witty": "I got you {gift}. No, it's not a joke. This time.", "nosy": "I asked around about what you'd like. Here: {gift}.",
	"anxious": "I hope this is all right... {gift}. You can say if it's not!", "dreamy": "I found this and it felt like it was yours already. {Gift}.",
	"practical": "This'll be useful. {Gift}. Don't argue.", "stubborn": "You're taking {gift}, and I won't hear otherwise.",
}
const KID_HEART_GIFT := ["I got you something! It's {gift}! I didn't steal it. I asked first.", "Here! {Gift}! Because you're my best grown-up friend!"]
const BDAY_TRAIT := {
	"cheerful": "It's my birthday today! I'm trying not to make a fuss. I'm failing!", "gruff": "Birthday. Don't sing.",
	"shy": "...It's my birthday, actually. You're the first person I've told today.", "curious": "It's my birthday! Do you think a year feels longer when you're younger? I've been wondering.",
	"meticulous": "Today I'm exactly one year older. I checked.", "adventurous": "Birthday today! Another year, another adventure.",
	"dreamy": "Another trip around the sun... It's my birthday, you know.", "practical": "It's my birthday. Nothing fancy. A good meal will do.",
	"nosy": "It's my birthday! Has anyone said anything to you? Any surprises planned? You can tell me.", "kind": "It's my birthday today! But never mind me, how are you?",
	"proud": "It's my birthday. You may congratulate me.", "anxious": "It's my birthday... I hope nobody's planned a surprise. I'm terrible with surprises.",
	"witty": "It's my birthday. One year closer to being a wise old legend.", "gentle": "It's my birthday today. A quiet one, I hope. Those are the best.",
	"stubborn": "It's my birthday, and I'm not a day older. I've decided.",
}
const BDAY_GENERIC := ["It's my birthday today! It's nice to see a friendly face.", "Guess what day it is? My birthday!"]

# ======================================================================== goodbyes & newcomers

const BYE_TRAIT := {
	"cheerful": ["Bye now! Come back soon!", "See you, {player}! Have a lovely {tod}!"], "gruff": ["Hm. Go on, then.", "Right. Off you go."],
	"shy": ["Oh... bye. Thanks for talking to me.", "...See you. I hope."], "curious": ["Come back and tell me what you find!", "Bye! Bring me a good story next time."],
	"meticulous": ["Until next time. I'll make a note of our chat.", "Goodbye. Check your pockets; don't leave anything behind."],
	"adventurous": ["Off you go! Adventure won't find itself.", "See you out there, {player}!"],
	"dreamy": ["Bye... I'll think of you when the clouds go by.", "Mm, goodbye. Walk slowly; the world's nicer that way."],
	"practical": ["Right, back to work. Good seeing you.", "See you. Don't forget to water the crops."],
	"nosy": ["Bye! Tell me if you hear anything good.", "See you! And remember, I want all the news."],
	"kind": ["Take care of yourself, {player}.", "Bye, dear. Eat something warm tonight."],
	"proud": ["Farewell. You may tell people you spoke with me.", "Goodbye, {player}. It was a pleasure. For you, I expect."],
	"anxious": ["Bye! Be careful! Please!", "Go safely, all right? I'll worry otherwise. I'll worry anyway."],
	"witty": ["Off you go. Try not to fall in any rivers. Or do, it's funny.", "Bye! Same time tomorrow? I'll work on new material."],
	"gentle": ["Goodbye, {player}. Go gently.", "Until next time. Be well."],
	"stubborn": ["Bye. And whatever it was, I was right.", "Go on. And come back. I insist."],
}
const BYE_TIME := {
	"morning": ["Have a good morning out there!", "Enjoy the rest of your morning."], "afternoon": ["Enjoy the rest of your afternoon.", "Have a good afternoon, {player}."],
	"evening": ["Have a good evening, {player}.", "Enjoy your evening."], "night": ["Get some sleep, {player}.", "Mind the dark on the way home."],
}
const KID_BYE := ["Bye! Bring me something cool next time!", "See ya! I'm gonna go dig a hole!", "Bye, {player}! Don't get eaten by a slime!"]
const NEWCOMER_OPEN := {
	"cheerful": "Hello, hello! You must be from the farm. I'm {me} {last}, newest face in {town}!",
	"gruff": "Name's {me}. Just moved in. {A_job}.",
	"shy": "Oh... hi. I'm {me}. I only just moved here, so... I don't really know anyone yet.",
	"curious": "Hello! I'm {me} {last}. Just arrived. You're from the farm? I have so many questions.",
	"meticulous": "{Good_tod}. {me} {last}. I've only just arrived; still unpacking box fourteen of twenty-two.",
	"adventurous": "Hey there! {me} {last}. Just rolled into {town} with a pack and a plan. Mostly a pack.",
	"dreamy": "Oh, hello... I'm {me}. I've just moved here. Everything still feels a little like a dream.",
	"practical": "Hello. {me} {last}. New in town, {a_job} by trade. Pleased to meet you.",
	"nosy": "Ooh, one of the farmers! I'm {me}, just moved in. I've heard all sorts about you. Good sorts!",
	"kind": "Hello there! I'm {me}. I've just moved to {town}, and it's lovely to meet a friendly face.",
	"proud": "Ah, hello. I'm {me} {last}. Perhaps you've heard of me? No? You will.",
	"anxious": "Oh! Hello. I'm {me}. I'm new. Is everyone here always this friendly? It's nice. I'm nervous.",
	"witty": "Hello! I'm {me}, the new neighbor. I come with references. Mostly from old neighbors who were glad to see me go.",
	"gentle": "Hello. I'm {me}. I've only just arrived in {town}, but I think I'll be happy here.",
	"stubborn": "I'm {me} {last}. Just moved in. And I'm staying, whatever anyone says.",
}
const NEWCOMER_REASON := {
	"explorer": "I heard the caves here go deeper than anywhere in the region. I couldn't stay away.",
	"glassblower": "Word is there's crystal in those caves that sings when you heat it. I had to see.",
	"historian": "There's history under this town. Literally. I'm here to write it down.",
	"chef": "I'd heard the produce out here was wonderful. I'd heard right.",
	"stargazer": "The skies here are the clearest I've ever seen. I set up my telescope the first night.",
	"herder": "The hills around here are perfect grazing. My animals agreed before I did.",
	"painter": "The light here is extraordinary. I've been painting since the moment I arrived.",
	"musician": "The tavern needed music. I needed a tavern. It worked out.",
}
const NEWCOMER_PROJECT := {
	"Welcome Cottages": "The welcome cottages made it easy to say yes.", "Expedition Lodge": "The new expedition lodge sealed the deal.",
	"Market Stalls": "The market stalls told me this was a town on the up.", "Mend the Old Bridge": "Someone mended the old bridge, so I could actually get here.",
	"Lamplighter's Posts": "I saw the lamp posts glowing from the road and thought, that looks like home.",
}

# ======================================================================== public API

## One conversation: 1-3 lines shown one after another.
static func talk(npc: Dictionary, ctx: Dictionary) -> Array:
	var tc: int = _int(ctx.get("talk_count", 0))
	var r := _rng(npc, ctx, 101)
	var S := _subs(npc, ctx, r)
	var kid := str(npc.get("age", "")) == "child"
	var out: Array = []
	if tc >= 3:
		var still: Array = KID_STILL if kid else STILL_GENERIC
		var t := _pick(r, still)
		var tr := _main_trait(npc, r)
		if not kid and STILL_TRAIT.has(tr) and r.randf() < 0.55:
			t = _pick(r, STILL_TRAIT[tr])
		out.append(_fill(t, S))
		return out
	var avoid := {}
	for k in tc:
		var c2 := ctx.duplicate()
		c2["talk_count"] = k
		avoid[_body(npc, c2, avoid)] = true
	var body := _body(npc, ctx, avoid)
	var is_bday := tc == 0 and bool(ctx.get("birthday_today", false))
	if tc == 0:
		out.append(_greeting(npc, ctx, r, S))
		if body != "":
			out.append(body if is_bday else _flavor(body, npc, r, S))
		var tier := _tier(ctx)
		var extra_chance := 0.22 + 0.06 * tier
		if r.randf() < extra_chance:
			avoid[body] = true
			var extra := _extra_line(npc, ctx, r, S, avoid)
			if extra != "":
				out.append(extra)
	else:
		var again: Array = KID_AGAIN if kid else AGAIN_GENERIC
		var g := _pick(r, again)
		var tr2 := _main_trait(npc, r)
		if not kid and AGAIN_TRAIT.has(tr2) and r.randf() < 0.5:
			g = _pick(r, AGAIN_TRAIT[tr2])
		out.append(_fill(g, S))
		if body != "" and r.randf() < 0.85:
			out.append(_flavor(body, npc, r, S))
	return out

static func gift_reaction(npc: Dictionary, item_id: String, ctx: Dictionary) -> Dictionary:
	var level := _gift_level(npc, item_id)
	var r := _rng(npc, ctx, ("gift:" + item_id).hash())
	var S := _subs(npc, ctx, r)
	var nm := _item_name(item_id)
	S["item"] = nm if nm != "" else "this"
	S["a_item"] = _a(nm) if nm != "" else "this"
	S["them"] = _them(nm)
	var matched := _interest_match(npc, item_id)
	if matched != "":
		S["int"] = INTEREST_NOUN.get(matched, matched)
	var text := ""
	if str(npc.get("age", "")) == "child":
		text = _pick(r, KID_GIFT[level])
	else:
		var tr := _main_trait(npc, r)
		var by_trait: Dictionary = GIFT_TRAIT[level]
		if by_trait.has(tr) and r.randf() < 0.75:
			text = _pick(r, by_trait[tr])
		else:
			text = _pick(r, GIFT_GENERIC[level])
		if (level == "love" or level == "like") and matched != "" and r.randf() < 0.6:
			text += " " + _pick(r, GIFT_REASON[level])
		elif level == "dislike" and r.randf() < 0.5:
			var cat := _item_cat(item_id)
			if DISLIKE_REASON.has(cat):
				text += " " + str(DISLIKE_REASON[cat])
	if bool(ctx.get("birthday_today", false)):
		text = str(BDAY_GIFT.get(level, "")) + text
	return {"level": level, "text": _fill(text, S)}

## The player asks "what is this?" about an unidentified item.
static func identify_reply(npc: Dictionary, item_id: String, knows: bool) -> String:
	var r := RandomNumberGenerator.new()
	r.seed = ("%d|ident|%s" % [_int(npc.get("voice_seed", 0)), item_id]).hash()
	var S := _subs(npc, {}, r)
	var nm := _item_name(item_id)
	S["item"] = nm if nm != "" else "this"
	S["a_item"] = _a(nm) if nm != "" else "this"
	S["them"] = _them(nm)
	var cat := _item_cat(item_id)
	var kid := str(npc.get("age", "")) == "child"
	var tr := _main_trait(npc, r)
	if knows:
		var lines: Array = IDENT_KNOW.get(cat, ["That's {a_item}. Hang on to {them}; there's always a use for something like that."])
		var t := _pick(r, lines)
		if cat == "fruit" and item_id == "apple":
			t += " Three in a kettle make cider, too."
		var ess := _essence_names(item_id)
		if ess != "" and not (cat in ["brew", "herb", "mineral", "monster"]):
			t += " It carries a bit of %s essence." % ess
		if kid:
			t = "Ooh, I know! " + t
		elif IDENT_PRE.has(tr) and r.randf() < 0.6 and t.length() < 150:
			t = str(IDENT_PRE[tr]) + t
		if r.randf() < 0.5 and t.length() < 160:
			t += " " + _pick(r, IDENT_CHEER)
		return _fill(t, S)
	var who: String = REDIRECT_WHO.get(cat, "the mayor at the Town Hall")
	if str(REDIRECT_ROLE.get(who, "")) == str(npc.get("role", "")):
		who = "someone who's been deeper in the caves than me" if cat in ["mineral", "gem", "monster", "curio"] else "the folks at the Town Hall"
	S["who"] = who
	if kid:
		return _fill("I dunno! It looks cool, though. Ask a grown-up. Like {who}.", S)
	var t2 := _pick(r, IDENT_DONT_GENERIC)
	if IDENT_DONT.has(tr) and r.randf() < 0.75:
		t2 = str(IDENT_DONT[tr])
	return _fill(t2, S)

static func shop_greeting(npc: Dictionary, ctx: Dictionary) -> String:
	var r := _rng(npc, ctx, 202)
	var S := _subs(npc, ctx, r)
	var role := str(npc.get("role", ""))
	var lines := _avail(SHOP_GREET.get(role, ["Welcome! Have a look around."]), ctx, npc)
	var t := _pick(r, lines)
	var hearts := _int(ctx.get("hearts", 0))
	if hearts >= 6 and r.randf() < 0.45:
		t = _pick(r, SHOP_FRIEND) + " " + t
	var tr := _main_trait(npc, r)
	if SHOP_TAG.has(tr) and r.randf() < 0.4:
		t += " " + str(SHOP_TAG[tr])
	return _fill(t, S)

static func shop_closed(npc: Dictionary, ctx: Dictionary) -> String:
	var r := _rng(npc, ctx, 203)
	var S := _subs(npc, ctx, r)
	var tr := _main_trait(npc, r)
	if CLOSED_TRAIT.has(tr) and r.randf() < 0.45:
		return _fill(str(CLOSED_TRAIT[tr]), S)
	var role := str(npc.get("role", ""))
	var lines := _avail(SHOP_CLOSED.get(role, ["We're closed right now. Come back later!"]), ctx, npc)
	if lines.is_empty():
		lines = ["We're closed right now. Come back later!"]
	return _fill(_pick(r, lines), S)

## A note pinned on the town request board, in the resident's voice.
static func request_text(npc: Dictionary, req: Dictionary) -> String:
	var r := RandomNumberGenerator.new()
	r.seed = ("%d|req|%s|%s" % [_int(npc.get("voice_seed", 0)), str(req.get("type", "")), str(req.get("item", ""))]).hash()
	var S := _subs(npc, {}, r)
	_req_subs(req, S)
	S["reason"] = str(ROLE_REASON.get(str(npc.get("role", "")), "for something I'm working on"))
	var typ := str(req.get("type", "deliver"))
	var body := ""
	if str(npc.get("age", "")) == "child":
		body = str(KID_REQ.get(typ, KID_REQ["deliver"]))
		return _fill(body + " — {me}", S)
	body = _pick(r, REQ_TEXT.get(typ, REQ_TEXT["deliver"]))
	var tr := _main_trait(npc, r)
	var sign: String = REQ_SIGN.get(tr, "— {me}")
	return _fill(body + " " + sign, S)

static func request_thanks(npc: Dictionary, req: Dictionary, ctx: Dictionary) -> String:
	var r := _rng(npc, ctx, ("thanks:" + str(req.get("type", ""))).hash())
	var S := _subs(npc, ctx, r)
	_req_subs(req, S)
	var typ := str(req.get("type", "deliver"))
	var t := _pick(r, REQ_THANKS.get(typ, ["You did it! Thank you, {player}. I mean it."]))
	if str(npc.get("age", "")) == "child":
		t = _pick(r, ["You did it!! Thank you thank you thank you!", "WOW! You're the best, {player}!", "Yes! I knew you could do it! You're the best!"])
		return _fill(t, S)
	var tr := _main_trait(npc, r)
	if THANKS_TRAIT.has(tr) and r.randf() < 0.7:
		t += " " + str(THANKS_TRAIT[tr])
	return _fill(t, S)

static func wish_text(npc: Dictionary, item_name: String) -> String:
	var r := RandomNumberGenerator.new()
	r.seed = ("%d|wish|%s" % [_int(npc.get("voice_seed", 0)), item_name]).hash()
	var S := _subs(npc, {}, r)
	var nm := item_name if item_name != "" else "something from the deep caves"
	S["wish"] = nm
	S["a_wish"] = _a(nm) if item_name != "" else nm
	var tr := _main_trait(npc, r)
	var t := _pick(r, WISH_GENERIC)
	if WISH_TRAIT.has(tr) and r.randf() < 0.65:
		t = str(WISH_TRAIT[tr])
	if WISH_REASON.has(item_name) and r.randf() < 0.75:
		t += " " + str(WISH_REASON[item_name])
	return _fill(t, S)

static func wish_fulfilled(npc: Dictionary, item_name: String) -> String:
	var r := RandomNumberGenerator.new()
	r.seed = ("%d|wishdone|%s" % [_int(npc.get("voice_seed", 0)), item_name]).hash()
	var S := _subs(npc, {}, r)
	S["wish"] = item_name if item_name != "" else "this"
	S["a_wish"] = _a(item_name) if item_name != "" else "this"
	var tr := _main_trait(npc, r)
	var t := _pick(r, WISH_DONE)
	if WISH_DONE_TRAIT.has(tr) and r.randf() < 0.6:
		t = str(WISH_DONE_TRAIT[tr])
	return _fill(t, S)

## The resident gives the player something at a friendship milestone (2, 4, 6, 8 hearts).
static func heart_gift_text(npc: Dictionary, hearts: int, gift_name: String) -> String:
	var r := RandomNumberGenerator.new()
	r.seed = ("%d|heart|%d" % [_int(npc.get("voice_seed", 0)), hearts]).hash()
	var S := _subs(npc, {"hearts": hearts}, r)
	S["gift"] = _gift_phrase(gift_name)
	if str(npc.get("age", "")) == "child":
		return _fill(_pick(r, KID_HEART_GIFT), S)
	var band := 0
	if hearts >= 8:
		band = 3
	elif hearts >= 6:
		band = 2
	elif hearts >= 4:
		band = 1
	var t := _pick(r, HEART_GIFT[band])
	var tr := _main_trait(npc, r)
	if HEART_GIFT_TRAIT.has(tr) and r.randf() < 0.4:
		t = str(HEART_GIFT_TRAIT[tr])
	return _fill(t, S)

## The resident mentions that today is their birthday.
static func birthday_line(npc: Dictionary, ctx: Dictionary) -> String:
	var r := _rng(npc, ctx, 404)
	var S := _subs(npc, ctx, r)
	var age := str(npc.get("age", ""))
	var t := ""
	if age == "child":
		t = _pick(r, ["IT'S MY BIRTHDAY! I'm practically a grown-up now!", "Guess what? It's my birthday! I'm gonna eat cake for every meal!"])
	elif age == "elder" and r.randf() < 0.5:
		t = _pick(r, ["Another birthday. I've stopped counting. The cake hasn't.", "It's my birthday. At my age, every one's a little victory."])
	else:
		var tr := _main_trait(npc, r)
		t = str(BDAY_TRAIT.get(tr, _pick(r, BDAY_GENERIC)))
	if _int(ctx.get("hearts", 0)) >= 5 and age != "child":
		t += " " + _pick(r, ["I'm glad you came by today of all days.", "Seeing you is a fine present already.", "Having friends like you is the best part of getting older."])
	return _fill(t, S)

static func goodbye(npc: Dictionary, ctx: Dictionary) -> String:
	var r := _rng(npc, ctx, 505)
	var S := _subs(npc, ctx, r)
	if str(npc.get("age", "")) == "child":
		return _fill(_pick(r, KID_BYE), S)
	var tr := _main_trait(npc, r)
	var t := ""
	if BYE_TRAIT.has(tr) and r.randf() < 0.65:
		t = _pick(r, BYE_TRAIT[tr])
	else:
		t = _pick(r, BYE_TIME.get(str(S["tod"]), BYE_TIME["afternoon"]))
	if _int(ctx.get("deepest", 0)) > 0 and r.randf() < 0.2 and (tr == "anxious" or tr == "kind" or tr == "gentle"):
		t += " And careful down in the caves."
	return _fill(t, S)

## First meeting with someone who has just moved to town.
static func newcomer_intro(npc: Dictionary, ctx: Dictionary) -> String:
	var r := _rng(npc, ctx, 606)
	var S := _subs(npc, ctx, r)
	var tr := _main_trait(npc, r)
	var t := str(NEWCOMER_OPEN.get(tr, "Hello! I'm {me} {last}. I've only just moved to {town}."))
	var role := str(npc.get("role", ""))
	var projects := _arr(ctx.get("projects_done", []))
	var proj_line := ""
	if not projects.is_empty():
		var p := str(projects[r.randi() % projects.size()])
		proj_line = str(NEWCOMER_PROJECT.get(p, "When I heard about the '%s' project, I knew this town was going places." % p))
	if NEWCOMER_REASON.has(role) and (proj_line == "" or r.randf() < 0.6):
		t += " " + str(NEWCOMER_REASON[role])
	elif proj_line != "":
		t += " " + proj_line
	else:
		t += " {town} seemed like the right place to start fresh."
	return _fill(t, S)

# ======================================================================== conversation internals

static func _greeting(npc: Dictionary, ctx: Dictionary, r: RandomNumberGenerator, S: Dictionary) -> String:
	var tier := _tier(ctx)
	var age := str(npc.get("age", ""))
	var g := ""
	if age == "child":
		g = _pick(r, CHILD_GREET[tier])
	elif age == "elder" and r.randf() < 0.4:
		g = _pick(r, ELDER_GREET[tier])
	else:
		var tr := _main_trait(npc, r)
		var sets: Array = TRAIT_GREET.get(tr, TRAIT_GREET["kind"])
		g = _pick(r, sets[tier])
	if r.randf() < 0.4 and age != "child":
		var w := str(ctx.get("weather", "clear"))
		if bool(ctx.get("is_night", false)) and (w == "clear" or w == "cloudy" or r.randf() < 0.5):
			w = "night"
		var tags: Array = WEATHER_TAG.get(w, [])
		if not tags.is_empty() and g.length() < 110:
			g += " " + _pick(r, tags)
	return _fill(g, S)

## The substantive line of a conversation (unflavored). Deterministic for a given ctx and avoid set.
static func _body(npc: Dictionary, ctx: Dictionary, avoid: Dictionary) -> String:
	var tc: int = _int(ctx.get("talk_count", 0))
	if tc == 0 and bool(ctx.get("birthday_today", false)):
		return birthday_line(npc, ctx)
	var r := _rng(npc, ctx, 7)
	var S := _subs(npc, ctx, r)
	var opts := _categories(npc, ctx, tc)
	var terse := _has_trait(npc, "gruff")
	for attempt in 10:
		var key := _weighted(r, opts)
		var line := _make_line(key, npc, ctx, r, S, terse)
		if line != "" and not avoid.has(line):
			return line
	var fallback := _avail(SEASON_LINES[_season(ctx)], ctx, npc)
	for t in fallback:
		var f := _fill(str(t), S)
		if not avoid.has(f):
			return f
	return ""

static func _categories(npc: Dictionary, ctx: Dictionary, tc: int) -> Array:
	var o: Array = []
	var age := str(npc.get("age", ""))
	var first := tc == 0
	var interests := _arr(npc.get("interests", []))
	if age == "child":
		o.append(["child", 30])
		if not interests.is_empty():
			o.append(["interest", 22])
		if not _relatives(npc, ctx).is_empty():
			o.append(["family", 12])
		if not _people_ids(ctx, _arr(npc.get("friends", []))).is_empty():
			o.append(["friend", 8])
		o.append(["depth", 8])
		if not _arr(npc.get("loves", [])).is_empty():
			o.append(["love", 6])
		if not _arr(ctx.get("events", [])).is_empty():
			o.append(["event", 8])
		if not _dict(ctx.get("request", {})).is_empty():
			o.append(["request", 40 if first else 5])
		return o
	if age == "elder" or str(npc.get("role", "")) == "miner":
		o.append(["elder", 20])
	if not interests.is_empty():
		o.append(["interest", 34 if first else 26])
		if age != "child" and not _arr(npc.get("traits", [])).is_empty():
			o.append(["take", 7])
	if age != "child" and JOB_LINES.has(str(npc.get("role", ""))):
		o.append(["job", 14 if first else 8])
	if not _relatives(npc, ctx).is_empty():
		o.append(["family", 13 if first else 7])
	if not _people_ids(ctx, _arr(npc.get("friends", []))).is_empty():
		o.append(["friend", 7])
	if str(npc.get("rival", "")) != "" and not _person(ctx, str(npc.get("rival", ""))).is_empty():
		o.append(["rival", 5])
	if not _arr(ctx.get("events", [])).is_empty():
		o.append(["event", 12 if first else 8])
	o.append(["depth", 7])
	if not _dict(ctx.get("identities", {})).is_empty():
		o.append(["identity", 7])
	o.append(["season", 6])
	o.append(["weather", 5])
	if not _dict(ctx.get("request", {})).is_empty():
		o.append(["request", 40 if first else 5])
	if not _arr(ctx.get("projects_done", [])).is_empty():
		o.append(["project", 6])
	if not _arr(npc.get("loves", [])).is_empty() or not _arr(npc.get("likes", [])).is_empty():
		o.append(["love", 6 if first else 9])
	if _has_trait(npc, "nosy") and _dict(ctx.get("people", {})).size() > 2:
		o.append(["gossip", 12])
	if _int(ctx.get("player_count", 1)) >= 1 and age != "child":
		o.append(["household", 2])
	return o

static func _make_line(key: String, npc: Dictionary, ctx: Dictionary, r: RandomNumberGenerator, S: Dictionary, terse: bool) -> String:
	var age := str(npc.get("age", ""))
	match key:
		"child":
			return _fill(_choose(r, _avail(CHILD_LINES, ctx, npc), terse), S)
		"elder":
			return _fill(_choose(r, _avail(ELDER_LINES, ctx, npc), terse), S)
		"interest":
			var ints := _arr(npc.get("interests", []))
			var it := str(ints[r.randi() % ints.size()])
			S["int"] = INTEREST_NOUN.get(it, it)
			if age == "child":
				return _fill(_pick(r, KID_INTEREST.get(it, CHILD_LINES)), S)
			var block: Dictionary = INTEREST_LINES.get(it, {})
			if block.is_empty():
				return ""
			var pool: Array = block["q"] if r.randf() < 0.45 else block["s"]
			return _fill(_choose(r, _avail(pool, ctx, npc), terse), S)
		"take":
			var ints2 := _arr(npc.get("interests", []))
			var it2 := str(ints2[r.randi() % ints2.size()])
			S["int"] = INTEREST_NOUN.get(it2, it2)
			var tr := str(_arr(npc.get("traits", []))[r.randi() % _arr(npc.get("traits", [])).size()])
			return _fill(_pick(r, TRAIT_TAKE.get(tr, [])), S)
		"job":
			return _fill(_choose(r, _avail(JOB_LINES.get(str(npc.get("role", "")), []), ctx, npc), terse), S)
		"family":
			return _family_line(npc, ctx, r, S)
		"friend":
			var fids := _people_ids(ctx, _arr(npc.get("friends", [])))
			if fids.is_empty():
				return ""
			var f := _person(ctx, str(fids[r.randi() % fids.size()]))
			_rel_subs(f, S, r)
			var pool2: Array = KID_FRIEND_LINES if (age == "child" and str(f.get("age", "")) == "child") else FRIEND_LINES
			if age == "child" and pool2 == FRIEND_LINES:
				return ""
			return _fill(_choose(r, pool2, terse), S)
		"rival":
			var rv := _person(ctx, str(npc.get("rival", "")))
			if rv.is_empty():
				return ""
			_rel_subs(rv, S, r)
			var ints3 := _arr(npc.get("interests", []))
			if not ints3.is_empty():
				S["int"] = INTEREST_NOUN.get(str(ints3[0]), str(ints3[0]))
			else:
				S["int"] = "everything"
			return _fill(_choose(r, RIVAL_LINES, terse), S)
		"event":
			return _event_line(npc, ctx, r, S)
		"depth":
			return _depth_line(npc, ctx, r, S)
		"identity":
			return _identity_line(npc, ctx, r, S)
		"season":
			return _fill(_choose(r, _avail(SEASON_LINES[_season(ctx)], ctx, npc), terse), S)
		"weather":
			var w := str(ctx.get("weather", "clear"))
			if bool(ctx.get("is_night", false)) and r.randf() < 0.5:
				w = "night"
			return _fill(_pick(r, WEATHER_LINES.get(w, WEATHER_LINES["clear"])), S)
		"request":
			var req := _dict(ctx.get("request", {}))
			if req.is_empty():
				return ""
			_req_subs(req, S)
			var typ := str(req.get("type", "deliver"))
			var line := _pick(r, REQUEST_HINT.get(typ, REQUEST_HINT["deliver"]))
			if age == "child":
				line = "I put a note on the board! " + ("Can you get me {count_item}?" if typ in ["deliver", "fish", "brew"] else "It's really important!")
			return _fill(line, S)
		"project":
			var projects := _arr(ctx.get("projects_done", []))
			var p := str(projects[r.randi() % projects.size()])
			S["project"] = p
			return _fill(_pick(r, PROJECT_LINES.get(p, PROJECT_GENERIC)), S)
		"love":
			if str(S.get("love", "")) != "" and (str(S.get("like", "")) == "" or r.randf() < 0.6):
				return _fill(_pick(r, KID_LOVE_LINES if age == "child" else LOVE_LINES), S)
			if str(S.get("like", "")) != "" and age != "child":
				return _fill(_pick(r, LIKE_LINES), S)
			return ""
		"gossip":
			return _gossip_line(npc, ctx, r, S)
		"household":
			return _fill(_pick(r, _avail(HOUSEHOLD_LINES, ctx, npc)), S)
	return ""

## A short optional third line on a first visit: a trait take, a love hint or a friendly question.
static func _extra_line(npc: Dictionary, ctx: Dictionary, r: RandomNumberGenerator, S: Dictionary, avoid: Dictionary) -> String:
	var age := str(npc.get("age", ""))
	for attempt in 4:
		var roll := r.randf()
		var t := ""
		if age == "child":
			t = _fill(_pick(r, _avail(CHILD_LINES, ctx, npc)), S)
		elif roll < 0.35 and not _arr(npc.get("interests", [])).is_empty():
			t = _make_line("take", npc, ctx, r, S, false)
		elif roll < 0.55:
			t = _make_line("love", npc, ctx, r, S, false)
		else:
			t = _fill(_pick(r, _avail(CLOSERS, ctx, npc)), S)
		if t != "" and not avoid.has(t):
			return t
	return ""

static func _flavor(line: String, npc: Dictionary, r: RandomNumberGenerator, S: Dictionary) -> String:
	var traits := _arr(npc.get("traits", []))
	if traits.is_empty() or line == "":
		return line
	var t0 := str(traits[0])
	var t1 := str(traits[1]) if traits.size() > 1 else t0
	var roll := r.randf()
	if str(npc.get("age", "")) == "child" and roll >= 0.25:
		return line
	var pre := ""
	var suf := ""
	if roll < 0.3:
		pre = _pick(r, PREFIX.get(t0, []))
		if line.begins_with("...") and pre.ends_with("..."):
			pre = ""
		if line.begins_with("Oh") and pre.begins_with("Oh"):
			pre = ""
	elif roll < 0.6 and not line.ends_with("?") and line.length() < 150:
		suf = _pick(r, SUFFIX.get(t1, []))
	return _fill(pre + line + suf, S)

static func _family_line(npc: Dictionary, ctx: Dictionary, r: RandomNumberGenerator, S: Dictionary) -> String:
	var rels := _relatives(npc, ctx)
	if rels.is_empty():
		return ""
	var pick: Array = rels[r.randi() % rels.size()]
	var kind := str(pick[0])
	var p: Dictionary = pick[1]
	_rel_subs(p, S, r)
	var age := str(npc.get("age", ""))
	var pool: Array = []
	match kind:
		"spouse":
			pool = SPOUSE_LINES
		"children":
			pool = KID_LINES if str(p.get("age", "")) == "child" else ADULT_CHILD_LINES
		"parents":
			pool = PARENT_FROM_KID if age == "child" else PARENT_ELDER
		"sibling":
			pool = SIBLING_LINES
		"grandparent":
			pool = GRANDPARENT_LINES
		"grandchildren":
			pool = GRANDKID_LINES
	if pool.is_empty():
		return ""
	return _fill(_pick(r, pool), S)

static func _relatives(npc: Dictionary, ctx: Dictionary) -> Array:
	var out: Array = []
	var fam := _dict(npc.get("family", {}))
	for k in ["spouse", "sibling", "grandparent"]:
		if fam.has(k):
			var p := _person(ctx, str(fam[k]))
			if not p.is_empty():
				out.append([k, p])
	for k2 in ["children", "parents", "grandchildren"]:
		for id in _arr(fam.get(k2, [])):
			var q := _person(ctx, str(id))
			if not q.is_empty():
				out.append([k2, q])
	return out

static func _rel_subs(p: Dictionary, S: Dictionary, _r: RandomNumberGenerator) -> void:
	S["rel"] = _first(p)
	var role := str(p.get("role", ""))
	S["rel_job"] = JOB_NOUN.get(role, "neighbor")
	S["a_rel_job"] = _a(str(S["rel_job"]))
	S["rel_smell"] = ROLE_SMELL.get(role, "woodsmoke")
	var ints := _arr(p.get("interests", []))
	var it := str(ints[0]) if not ints.is_empty() else ""
	S["rel_int"] = INTEREST_NOUN.get(it, "this and that")
	S["rel_dream"] = INTEREST_DREAM.get(it, "an explorer")
	var loves := _arr(p.get("loves", []))
	if loves.is_empty():
		loves = _arr(p.get("likes", []))
	var lv := _item_name(str(loves[0])) if not loves.is_empty() else "a good meal"
	S["a_rel_love"] = _a(lv) if not loves.is_empty() else lv

static func _gossip_line(npc: Dictionary, ctx: Dictionary, r: RandomNumberGenerator, S: Dictionary) -> String:
	var people := _dict(ctx.get("people", {}))
	var ids: Array = []
	var me := str(npc.get("id", ""))
	for id in people.keys():
		if str(id) != me and people[id] is Dictionary:
			ids.append(id)
	if ids.is_empty():
		return ""
	ids.sort()
	var o: Dictionary = people[ids[r.randi() % ids.size()]]
	S["other"] = _first(o)
	S["other_job"] = JOB_NOUN.get(str(o.get("role", "")), "neighbor")
	var ints := _arr(o.get("interests", []))
	var it := str(ints[0]) if not ints.is_empty() else ""
	S["other_int"] = INTEREST_NOUN.get(it, "something or other")
	S["other_dream"] = INTEREST_DREAM.get(it, "a sailor")
	var loves := _arr(o.get("loves", []))
	var t := _pick(r, GOSSIP_LINES)
	if loves.is_empty():
		if t.find("{a_other_love}") != -1:
			t = GOSSIP_LINES[1]
	else:
		S["a_other_love"] = _a(_item_name(str(loves[0])))
	return _fill(t, S)

static func _event_line(npc: Dictionary, ctx: Dictionary, r: RandomNumberGenerator, S: Dictionary) -> String:
	var evs := _arr(ctx.get("events", []))
	var day := _int(ctx.get("day", 0))
	var valid: Array = []
	for e in evs:
		if e is Dictionary and str(e.get("s", "")).strip_edges() != "":
			valid.append(e)
	if valid.is_empty():
		return ""
	# newest first (simple insertion sort; keeps original order on ties)
	var sorted: Array = []
	for e in valid:
		var i := 0
		while i < sorted.size() and _int(sorted[i].get("d", 0)) >= _int(e.get("d", 0)):
			i += 1
		sorted.insert(i, e)
	var recent: Array = []
	for e in sorted:
		if _int(e.get("d", 0)) >= day - 10:
			recent.append(e)
	if recent.is_empty():
		recent = sorted.slice(0, 2)
	recent = recent.slice(0, 4)
	var ev: Dictionary = recent[r.randi() % recent.size()]
	var kind := str(ev.get("k", ""))
	var kid := str(npc.get("age", "")) == "child"
	if kid and (kind == "season" or kind == "founding"):
		return ""
	if kind == "season":
		return _fill(_pick(r, EVENT_SEASON), S)
	if kind == "founding":
		return _fill(_pick(r, EVENT_FOUNDING), S)
	var s := str(ev.get("s", "")).strip_edges()
	while s.ends_with(".") or s.ends_with("!"):
		s = s.left(s.length() - 1)
	var player := str(ctx.get("player", ""))
	var frame := ""
	if player != "" and s.begins_with(player + " "):
		S["ev"] = "you " + s.substr(player.length() + 1)
		frame = _pick(r, KID_EVENT_YOU if kid else EVENT_FRAMES_YOU)
	else:
		S["ev"] = _lower_lead(s)
		frame = _pick(r, KID_EVENT_FRAMES if kid else EVENT_FRAMES)
	if kid:
		return _fill(frame, S)
	var react := _pick(r, EVENT_REACT.get(kind, EVENT_REACT["find"]))
	if frame.ends_with("?") and kind == "rescue":
		react = "I'm so glad everyone came home."
	return _fill(frame + " " + react, S)

static func _depth_line(npc: Dictionary, ctx: Dictionary, r: RandomNumberGenerator, S: Dictionary) -> String:
	var d := _int(ctx.get("deepest", 0))
	if str(npc.get("age", "")) == "child":
		return _fill(_pick(r, _avail(["[d0] Nobody's been to the bottom of the caves. I'm gonna be first. After you, maybe.",
			"[d1] How deep did you go? Floor {deep}? Did you see a monster? Was it THIS big?",
			"[d10] Floor {deep}! My friends don't believe me that you went that deep. Tell them!"], ctx, npc)), S)
	if d > 0 and _has_trait(npc, "anxious") and r.randf() < 0.6:
		return _fill(_pick(r, DEPTH_ANXIOUS), S)
	if d > 0 and _has_trait(npc, "adventurous") and r.randf() < 0.6:
		return _fill(_pick(r, DEPTH_BOLD), S)
	var band := 0
	for b in [25, 20, 15, 10, 5, 1]:
		if d >= b:
			band = b
			break
	return _fill(_pick(r, DEPTH_LINES[band]), S)

static func _identity_line(npc: Dictionary, ctx: Dictionary, r: RandomNumberGenerator, S: Dictionary) -> String:
	var ids := _dict(ctx.get("identities", {}))
	var keys: Array = []
	for k in ids.keys():
		if IDENTITY_OTHER.has(str(k)) and str(ids[k]) != "":
			keys.append(str(k))
	if keys.is_empty():
		return ""
	keys.sort()
	var k2: String = keys[r.randi() % keys.size()]
	var who := str(ids[k2])
	S["who"] = who
	if who == str(ctx.get("player", "")):
		return _fill(_pick(r, _avail(IDENTITY_YOU[k2], ctx, npc)), S)
	return _fill(_pick(r, _avail(IDENTITY_OTHER[k2], ctx, npc)), S)

static func _req_subs(req: Dictionary, S: Dictionary) -> void:
	var id := str(req.get("item", ""))
	var nm := str(req.get("item_name", ""))
	if nm == "":
		nm = _item_name(id) if id != "" else "something"
	var n: int = maxi(1, _int(req.get("count", 1)))
	S["item"] = nm
	S["a_item"] = _a(nm)
	S["count_item"] = _count_phrase(nm, n)
	S["them"] = _them(nm, n)
	S["floor"] = str(maxi(1, _int(req.get("floor", 1))))
	var enemy := str(req.get("enemy", ""))
	S["enemy_pl"] = _enemy_plural(enemy if enemy != "" else "creature")
	var place := str(req.get("place", ""))
	S["place"] = place if place != "" else "the far side of the valley"

static func _gift_level(npc: Dictionary, item_id: String) -> String:
	if _arr(npc.get("loves", [])).has(item_id):
		return "love"
	if _arr(npc.get("likes", [])).has(item_id) or _interest_match(npc, item_id) != "":
		return "like"
	var cat := _item_cat(item_id)
	if cat != "" and _arr(npc.get("dislikes", [])).has(cat):
		return "dislike"
	return "neutral"

## Which of the resident's interests (if any) this item speaks to.
static func _interest_match(npc: Dictionary, item_id: String) -> String:
	if item_id == "":
		return ""
	var cat := _item_cat(item_id)
	var nm := _item_name(item_id).to_lower()
	for it in _arr(npc.get("interests", [])):
		var i := str(it)
		if _arr(INTEREST_ITEMS.get(i, [])).has(item_id):
			return i
		if cat != "" and _arr(INTEREST_CATS.get(i, [])).has(cat):
			return i
		var kw: Array = []
		match i:
			"baking":
				kw = ["pie", "cake", "bread", "tart", "pasty"]
			"flowers":
				kw = ["bloom", "petal", "sweet pea", "dandelion", "crocus", "lily"]
			"stars":
				kw = ["star", "moon", "lumen"]
			"books":
				kw = ["map", "letter", "journal"]
			"caves":
				kw = ["cave", "glow", "crystal"]
			"cooking":
				kw = ["stew", "soup", "broth", "curry"]
		for w in kw:
			if nm.find(str(w)) != -1:
				return i
	return ""

# ======================================================================== text helpers

static func _rng(npc: Dictionary, ctx: Dictionary, salt: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	var key := "%d|%d|%d|%s|%d" % [_int(npc.get("voice_seed", 0)), _int(ctx.get("day", 0)), _int(ctx.get("talk_count", 0)), str(ctx.get("player", "")), salt]
	r.seed = key.hash()
	return r

static func _subs(npc: Dictionary, ctx: Dictionary, r: RandomNumberGenerator) -> Dictionary:
	var S := {}
	S["me"] = _first(npc) if _first(npc) != "" else "a neighbor"
	S["last"] = str(npc.get("last", ""))
	var pl := str(ctx.get("player", ""))
	S["player"] = pl if pl != "" else "friend"
	var town := str(ctx.get("town", ""))
	S["town"] = town if town != "" else "our town"
	var season := _season(ctx)
	var sn := str(ctx.get("season_name", ""))
	S["season"] = sn if sn != "" else SEASON_NAMES[season]
	var hour := _int(ctx.get("hour", 12))
	var tod := "afternoon"
	if bool(ctx.get("is_night", false)) or hour >= 21 or hour < 5:
		tod = "night"
	elif hour < 12:
		tod = "morning"
	elif hour >= 17:
		tod = "evening"
	S["tod"] = tod
	S["good_tod"] = "good evening" if tod == "night" else "good " + tod
	S["this_tod"] = "tonight" if tod == "night" else "this " + tod
	S["greet_tod"] = {"morning": "Morning", "afternoon": "Afternoon", "evening": "Evening", "night": "Evening"}[tod]
	var d := _int(ctx.get("deepest", 0))
	S["deep"] = str(d)
	S["next_way"] = str((int(d / 5.0) + 1) * 5)
	var loves := _arr(npc.get("loves", []))
	S["love"] = _item_name(str(loves[0])) if not loves.is_empty() else ""
	S["a_love"] = _a(str(S["love"])) if not loves.is_empty() else ""
	var likes := _arr(npc.get("likes", []))
	S["like"] = _item_name(str(likes[r.randi() % likes.size()])) if not likes.is_empty() else ""
	S["a_like"] = _a(str(S["like"])) if not likes.is_empty() else ""
	var ints := _arr(npc.get("interests", []))
	S["int"] = INTEREST_NOUN.get(str(ints[0]), "") if not ints.is_empty() else "the little things"
	var role := str(npc.get("role", ""))
	S["job"] = JOB_NOUN.get(role, "neighbor")
	S["a_job"] = _a(str(S["job"]))
	S["shop"] = SHOP_NAMES.get(role, "")
	S["n"] = str(_int(ctx.get("talk_count", 0)) + 1)
	S["pc"] = str(maxi(1, _int(ctx.get("player_count", 1))))
	return S

## Fills {key} placeholders. "{Key}" capitalizes the value of "key". Unknown keys vanish.
static func _fill(t: String, S: Dictionary) -> String:
	if t.find("{") == -1:
		return _tidy(t)
	var out := ""
	var i := 0
	var n := t.length()
	while i < n:
		var c := t[i]
		if c == "{":
			var j := t.find("}", i)
			if j > i:
				out += _lookup(t.substr(i + 1, j - i - 1), S)
				i = j + 1
				continue
		out += c
		i += 1
	return _tidy(out)

static func _lookup(key: String, S: Dictionary) -> String:
	if S.has(key):
		return str(S[key])
	if key.length() > 0:
		var lk := key[0].to_lower() + key.substr(1)
		if S.has(lk):
			return _cap(str(S[lk]))
	return ""

static func _tidy(s: String) -> String:
	var t := s.strip_edges()
	while t.find("  ") != -1:
		t = t.replace("  ", " ")
	t = t.replace(" ...", "\u0001").replace(" .", ".").replace(" ,", ",").replace(" ?", "?").replace(" !", "!").replace(",.", ".").replace("\u0001", " ...")
	# capitalize the first letter and the first letter after ". ", "! " or "? " (not after an ellipsis)
	var out := ""
	var cap_next := true
	var n := t.length()
	for i in n:
		var c := t[i]
		if cap_next:
			if c.to_upper() != c.to_lower():
				c = c.to_upper()
				cap_next = false
			elif c != " " and c != "'" and c != "(":
				cap_next = false
		out += c
		if c == "!" or c == "?" or c == ".":
			var nxt := t[i + 1] if i + 1 < n else ""
			var prev := t[i - 1] if i > 0 else ""
			if c == "." and (prev == "." or nxt == "."):
				continue
			if nxt == " ":
				cap_next = true
	return out

static func _cap(s: String) -> String:
	if s == "":
		return s
	return s[0].to_upper() + s.substr(1)

static func _lower_lead(s: String) -> String:
	for w in ["The ", "A ", "An ", "Some ", "Someone ", "Something ", "Somebody ", "Everyone ", "Everybody ", "Two ", "Three ", "Our ", "Your ", "This ", "That "]:
		if s.begins_with(w):
			return s[0].to_lower() + s.substr(1)
	return s

static func _pick(r: RandomNumberGenerator, arr: Array) -> String:
	if arr.is_empty():
		return ""
	return str(arr[r.randi() % arr.size()])

## Like _pick, but terse speakers prefer short lines.
static func _choose(r: RandomNumberGenerator, arr: Array, terse: bool) -> String:
	var t := _pick(r, arr)
	if terse:
		for k in 3:
			if t.length() <= 95:
				break
			t = _pick(r, arr)
	return t

static func _weighted(r: RandomNumberGenerator, opts: Array) -> String:
	var total := 0.0
	for o in opts:
		total += float(o[1])
	if total <= 0.0:
		return ""
	var x := r.randf() * total
	for o in opts:
		x -= float(o[1])
		if x <= 0.0:
			return str(o[0])
	return str(opts[opts.size() - 1][0])

## Filters tagged lines ("[d5,s2] text") by context. Tagged lines that apply count double.
static func _avail(arr: Array, ctx: Dictionary, npc: Dictionary) -> Array:
	var out: Array = []
	for t in arr:
		var s := str(t)
		if s.begins_with("["):
			var j := s.find("]")
			if j == -1:
				continue
			if not _tags_ok(s.substr(1, j - 1), ctx, npc):
				continue
			s = s.substr(j + 1).strip_edges()
			out.append(s)
		out.append(s)
	return out

static func _tags_ok(tags: String, ctx: Dictionary, npc: Dictionary) -> bool:
	var deep := _int(ctx.get("deepest", 0))
	var w := str(ctx.get("weather", "clear"))
	var night := bool(ctx.get("is_night", false))
	var pc := _int(ctx.get("player_count", 1))
	for tg0 in tags.split(","):
		var tg := str(tg0).strip_edges()
		if tg.length() > 1 and tg[0] == "d" and tg.substr(1).is_valid_int():
			var need := tg.substr(1).to_int()
			if need == 0:
				if deep != 0:
					return false
			elif deep < need:
				return false
		elif tg.length() > 1 and tg[0] == "s" and tg.substr(1).is_valid_int():
			if _season(ctx) != tg.substr(1).to_int():
				return false
		elif tg.begins_with("!"):
			if str(npc.get("role", "")) == tg.substr(1):
				return false
		else:
			match tg:
				"rain":
					if w != "rain" and w != "storm":
						return false
				"snow", "clear", "fog", "cloudy", "storm":
					if w != tg:
						return false
				"night":
					if not night:
						return false
				"day":
					if night:
						return false
				"multi":
					if pc < 2:
						return false
				"solo":
					if pc != 1:
						return false
				"shop":
					if not SHOP_NAMES.has(str(npc.get("role", ""))):
						return false
	return true

static func _tier(ctx: Dictionary) -> int:
	var h := _int(ctx.get("hearts", 0))
	if h >= 8:
		return 3
	if h >= 5:
		return 2
	if h >= 2:
		return 1
	return 0

static func _season(ctx: Dictionary) -> int:
	return clampi(_int(ctx.get("season", 0)), 0, 3)

static func _main_trait(npc: Dictionary, r: RandomNumberGenerator) -> String:
	var traits := _arr(npc.get("traits", []))
	if traits.is_empty():
		return ""
	if traits.size() > 1 and r.randf() < 0.35:
		return str(traits[1])
	return str(traits[0])

static func _has_trait(npc: Dictionary, t: String) -> bool:
	return _arr(npc.get("traits", [])).has(t)

static func _first(p: Dictionary) -> String:
	var f := str(p.get("first", ""))
	if f == "":
		var full := str(p.get("name", ""))
		f = full.split(" ")[0] if full != "" else ""
	return f

static func _person(ctx: Dictionary, id: String) -> Dictionary:
	if id == "":
		return {}
	var people := _dict(ctx.get("people", {}))
	var p = people.get(id, null)
	if p is Dictionary:
		return p
	return {}

static func _people_ids(ctx: Dictionary, ids: Array) -> Array:
	var out: Array = []
	for id in ids:
		if not _person(ctx, str(id)).is_empty():
			out.append(str(id))
	return out

static func _int(v) -> int:
	if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_BOOL:
		return int(v)
	if typeof(v) == TYPE_STRING and str(v).is_valid_int():
		return str(v).to_int()
	return 0

static func _arr(v) -> Array:
	if v is Array:
		return v
	if v is PackedStringArray:
		return Array(v)
	return []

static func _dict(v) -> Dictionary:
	if v is Dictionary:
		return v
	return {}

# ======================================================================== item helpers

static func _db() -> Object:
	var ml := Engine.get_main_loop()
	if ml is SceneTree:
		return (ml as SceneTree).root.get_node_or_null("Items")
	return null

static func _item_name(id: String) -> String:
	if id == "":
		return ""
	var db = _db()
	if db != null and db.has_method("has") and db.has(id):
		var d: Dictionary = db.def(id)
		return str(d.get("name", id.capitalize()))
	return id.capitalize()

static func _item_cat(id: String) -> String:
	var db = _db()
	if id != "" and db != null and db.has_method("has") and db.has(id):
		return str(db.cat_of(id))
	return ""

static func _essence_names(id: String) -> String:
	var db = _db()
	if id == "" or db == null or not db.has_method("has") or not db.has(id):
		return ""
	var ess: Dictionary = db.essences_of(id)
	var names: Array = []
	for e in ess.keys():
		names.append(str(e).capitalize())
	if names.is_empty() or names.size() > 2:
		return ""
	return " and ".join(PackedStringArray(names))

const MASS_WORDS := ["Wood", "Hardwood", "Stone", "Fiber", "Clay", "Coal", "Sap", "Flint", "Hay", "Feed", "Wheat", "Hops", "Corn",
	"Mint", "Sageleaf", "Stonewort", "Silverreed", "Deepmoss", "Ore", "Gel", "Weed", "Driftwood", "Honey", "Herbs"]
const CONTAINER := {
	"Soup": "bowl", "Stew": "bowl", "Broth": "bowl", "Chowder": "bowl", "Curry": "bowl", "Bread": "loaf", "Mix": "bag",
	"Ale": "mug", "Mead": "mug", "Tea": "cup", "Cider": "bottle", "Wine": "bottle", "Draught": "bottle", "Tonic": "bottle",
	"Glowbrew": "bottle", "Elixir": "bottle", "Brew": "bottle", "Oil": "bottle", "Water": "bottle", "Glow": "bottle",
	"Cordial": "bottle", "Boots": "pair",
}
const SAME_PLURAL := ["Trout", "Bass", "Carp", "Pike", "Salmon", "Koi", "Perch", "Sturgeon", "Chub", "Loach", "Sheep", "Deer"]

static func _last_word(nm: String) -> String:
	var parts := nm.strip_edges().split(" ")
	return parts[parts.size() - 1] if parts.size() > 0 else nm

## "it" or "them" for an item name and count ("10 Wood" is still "it").
static func _them(nm: String, n: int = 1) -> String:
	var lw := _last_word(nm)
	if lw in MASS_WORDS and not _is_plural(nm):
		return "it"
	return "them" if (n > 1 or _is_plural(nm)) else "it"

static func _is_plural(nm: String) -> bool:
	var lw := _last_word(nm)
	if lw in MASS_WORDS or CONTAINER.has(lw) or lw in SAME_PLURAL:
		return lw in ["Herbs", "Hops", "Boots"]
	if lw.ends_with("ies"):
		return true
	return lw.ends_with("s") and not lw.ends_with("ss") and not lw.ends_with("us") and lw.length() > 3

## "a Turnip", "an Old Locket", "some Wood", "a bowl of Fish Stew".
static func _a(nm: String) -> String:
	if nm == "":
		return ""
	var lw := _last_word(nm)
	if CONTAINER.has(lw):
		return "a %s of %s" % [CONTAINER[lw], nm]
	if lw in MASS_WORDS or _is_plural(nm):
		return "some " + nm
	var c := nm[0].to_lower()
	if c in ["a", "e", "i", "o", "u"]:
		return "an " + nm
	return "a " + nm

## "3 Turnips", "2 bowls of Fish Stew", "10 Wood", "a Pike".
static func _count_phrase(nm: String, n: int) -> String:
	if n <= 1:
		return _a(nm)
	var lw := _last_word(nm)
	if CONTAINER.has(lw):
		var c: String = CONTAINER[lw]
		var cp := "loaves" if c == "loaf" else c + "s"
		return "%d %s of %s" % [n, cp, nm]
	if lw in MASS_WORDS or _is_plural(nm) or lw in SAME_PLURAL or lw.ends_with("fish"):
		return "%d %s" % [n, nm]
	var head := nm.substr(0, nm.length() - lw.length())
	return "%d %s%s" % [n, head, _plural_word(lw)]

static func _plural_word(w: String) -> String:
	if w == "Tooth":
		return "Teeth"
	if w.ends_with("y") and w.length() > 1 and not (w[w.length() - 2] in ["a", "e", "i", "o", "u"]):
		return w.left(w.length() - 1) + "ies"
	if w.ends_with("ch") or w.ends_with("sh") or w.ends_with("x") or w.ends_with("s"):
		return w + "es"
	return w + "s"

static func _enemy_plural(e: String) -> String:
	var t := e.strip_edges().to_lower()
	if t == "":
		return "creatures"
	if t.ends_with("s"):
		return t
	if t.ends_with("y") and t.length() > 1 and not (t[t.length() - 2] in ["a", "e", "i", "o", "u"]):
		return t.left(t.length() - 1) + "ies"
	return t + "s"

## "my recipe for Fish Stew" for recipes, otherwise the item with an article.
static func _gift_phrase(g: String) -> String:
	var t := g.strip_edges()
	if t == "":
		return "a little something"
	var low := t.to_lower()
	if low.begins_with("recipe:"):
		return "my recipe for " + t.substr(7).strip_edges()
	if low.begins_with("recipe for "):
		return "my " + t[0].to_lower() + t.substr(1)
	if low.ends_with(" recipe"):
		return "my recipe for " + t.left(t.length() - 7).strip_edges()
	return _a(t)
