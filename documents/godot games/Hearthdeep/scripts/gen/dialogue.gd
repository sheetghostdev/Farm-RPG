class_name Dialogue
extends RefCounted
## Temporary stub; replaced by the procedural dialogue module.

static func talk(npc: Dictionary, ctx: Dictionary) -> Array:
	return ["Hello there, %s." % ctx.get("player", "friend"), "Lovely %s weather." % ctx.get("weather", "")]

static func gift_reaction(npc: Dictionary, item_id: String, ctx: Dictionary) -> Dictionary:
	var lvl := "neutral"
	if npc.get("loves", []).has(item_id):
		lvl = "love"
	elif npc.get("likes", []).has(item_id):
		lvl = "like"
	return {"level": lvl, "text": "Oh! A %s. Thank you." % Items.def(item_id)["name"]}

static func identify_reply(npc: Dictionary, item_id: String, knows: bool) -> String:
	return "That's %s." % Items.def(item_id)["name"] if knows else "No idea, sorry."

static func shop_greeting(npc: Dictionary, ctx: Dictionary) -> String:
	return "Have a look."

static func shop_closed(npc: Dictionary, ctx: Dictionary) -> String:
	return "%s's shop is closed right now." % npc.get("first", "The")

static func request_text(npc: Dictionary, req: Dictionary) -> String:
	return "Could someone help? — %s" % npc.get("first", "")

static func request_thanks(npc: Dictionary, req: Dictionary, ctx: Dictionary) -> String:
	return "Thank you so much!"

static func wish_text(npc: Dictionary, item_name: String) -> String:
	return "I've always wanted a %s." % item_name

static func wish_fulfilled(npc: Dictionary, item_name: String) -> String:
	return "A %s! I can't believe it." % item_name

static func heart_gift_text(npc: Dictionary, hearts: int, gift_name: String) -> String:
	return "Here, take %s." % gift_name

static func birthday_line(npc: Dictionary, ctx: Dictionary) -> String:
	return "It's my birthday!"

static func goodbye(npc: Dictionary, ctx: Dictionary) -> String:
	return "Take care."

static func newcomer_intro(npc: Dictionary, ctx: Dictionary) -> String:
	return "Hi, I'm new here."
