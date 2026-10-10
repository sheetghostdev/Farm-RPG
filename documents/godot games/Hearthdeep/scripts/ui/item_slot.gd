class_name ItemSlot
extends Control
## A single inventory/chest/shop slot that draws its item icon.

signal pressed(slot: ItemSlot, button: int)
signal hovered(slot: ItemSlot, on: bool)

var item := {}
var index := -1
var source := ""          # "inv", "chest", "shop", "equip"...
var selected := false
var hotkey := ""
var dim := false
var price := -1
var note := ""
var sz := 56.0

func _init(s: float = 56.0) -> void:
	sz = s
	custom_minimum_size = Vector2(s, s)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(func(): hovered.emit(self, true); queue_redraw())
	mouse_exited.connect(func(): hovered.emit(self, false); queue_redraw())

func set_item(it: Dictionary) -> void:
	item = it
	queue_redraw()

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed:
		pressed.emit(self, e.button_index)
		accept_event()

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var hov := get_global_rect().has_point(get_global_mouse_position())
	var bg := UITheme.SLOT_HI if hov else UITheme.SLOT
	draw_style_box(UITheme.box(bg, UITheme.ACCENT if selected else Color(0.55, 0.42, 0.3), 8, 3 if selected else 1, 0), r)
	if item.is_empty():
		if hotkey != "":
			draw_string(get_theme_default_font(), Vector2(5, 15), hotkey, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.35))
		return
	var traits := Items.item_traits(item)
	if traits.size() > Items.def(item["id"]).get("traits", []).size():
		draw_rect(r.grow(-3), Color(1.0, 0.85, 0.4, 0.12))
	var pad := size.x * 0.1
	IconPainter.draw_item(self, item["id"], r.grow(-pad), 0.45 if dim else 1.0)
	var font := get_theme_default_font()
	var n := int(item.get("n", 1))
	if n > 1:
		var t := str(n)
		var fs := 15 if size.x >= 48 else 12
		draw_string_outline(font, Vector2(size.x - 4 - font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x, size.y - 4), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.9))
		draw_string(font, Vector2(size.x - 4 - font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x, size.y - 4), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
	if not Game.is_known(item["id"]):
		draw_string_outline(font, Vector2(size.x - 13, 16), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, Color(0, 0, 0, 0.9))
		draw_string(font, Vector2(size.x - 13, 16), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("bfe3ff"))
	if hotkey != "":
		draw_string(font, Vector2(5, 15), hotkey, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.5))
	if item["id"].begins_with("can_") and source == "inv" and index < 10:
		var tier := int(Items.def(item["id"])["tool"]["tier"])
		var cap = [20, 35, 55, 80, 120][tier]
		var w = float(Game.me.get("water", cap)) / cap
		draw_rect(Rect2(5, size.y - 8, (size.x - 10) * w, 4), Color("6ab0ff"))
	if price >= 0:
		var pt := "%d" % price
		draw_string_outline(font, Vector2(4, size.y - 4), pt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color(0, 0, 0, 0.9))
		draw_string(font, Vector2(4, size.y - 4), pt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UITheme.ACCENT)

## Tooltip text (BBCode) for an item, honoring what the group has learned.
static func describe(it: Dictionary) -> String:
	if it.is_empty():
		return ""
	var id: String = it["id"]
	var d := Items.def(id)
	var known := Game.is_known(id)
	var s := "[b][color=#%s]%s[/color][/b]" % [UITheme.hex(UITheme.ACCENT), Items.display_name(it)]
	s += "\n[color=#%s]%s[/color]" % [UITheme.hex(UITheme.TEXT_DIM), _cat_label(d["cat"])]
	var traits := Items.item_traits(it)
	for t in traits:
		var tr: Dictionary = Items.traits.get(t, {})
		if not tr.is_empty():
			s += "\n[color=#ffd27a]★ %s[/color]" % tr["desc"]
	if d.has("weapon"):
		var w: Dictionary = d["weapon"]
		s += "\nDamage %d · Reach %.1fm · %s" % [int(w["dmg"]), w["range"], ["Very fast", "Fast", "Steady", "Slow"][clamp(int(w["time"] / 0.22), 0, 3)]]
	if d.get("desc", "") != "" and (known or d["cat"] in ["tool", "weapon", "gear", "placeable", "seed"]):
		s += "\n" + d["desc"]
	if not known:
		s += "\n[color=#bfe3ff][i]Nobody in the group knows what this is good for yet.[/i][/color]"
	else:
		var food: Dictionary = d.get("food", {})
		if int(food.get("heal", 0)) > 0:
			s += "\n[color=#9ae68a]Restores %d health[/color]" % int(food["heal"])
		if food.has("buff"):
			s += "\n[color=#9ae68a]Buff: %s[/color]" % _buff_label(food["buff"])
		var ess := Items.essences_of(id)
		if not ess.is_empty():
			var parts: Array = []
			for e in ess:
				parts.append("[color=#%s]%s %d[/color]" % [UITheme.hex(Items.ESSENCE_COLORS[e]), Items.ESSENCE_NAMES[e], int(ess[e])])
			s += "\nEssence: " + ", ".join(PackedStringArray(parts))
		if d.has("bait"):
			s += "\nBait"
	var p := Items.sell_price(it)
	if p > 0 and known:
		s += "\n[color=#%s]Sells for %d[/color]" % [UITheme.hex(UITheme.ACCENT), p]
	var seen: Dictionary = Game.world.get("know", {}).get("items", {}).get(id, {})
	if not seen.is_empty() and seen.get("by", "") != "":
		s += "\n[color=#8a7a6a][font_size=13]First found by %s on day %d[/font_size][/color]" % [seen["by"], int(seen.get("day", 1))]
	return s

static func _cat_label(c: String) -> String:
	return {"material": "Material", "ore": "Ore", "bar": "Metal Bar", "mineral": "Mineral", "gem": "Gem", "crop": "Crop", "herb": "Herb",
		"seed": "Seeds", "fruit": "Fruit", "sapling": "Sapling", "forage": "Forage", "mushroom": "Mushroom", "fish": "Fish", "monster": "Creature Part",
		"brew": "Brew", "food": "Dish", "drink": "Drink", "tool": "Tool", "weapon": "Weapon", "ammo": "Ammunition", "gear": "Equipment",
		"placeable": "Placeable", "curio": "Curiosity", "junk": "Junk", "bait": "Bait", "consumable": "Supplies", "animal": "Animal Product", "quest": "Keepsake"}.get(c, c.capitalize())

static func _buff_label(b: Dictionary) -> String:
	var n: String = {"heal": "Healing", "regen": "Regeneration", "mining": "Mining", "fishing": "Fishing", "light": "Light", "speed": "Speed",
		"defense": "Defense", "attack": "Strength", "prospect": "Prospecting", "deepfish": "Deep fishing", "dodge": "Quick dodge", "ironhide": "Ironhide"}.get(b["type"], b["type"])
	return "%s (%ds)" % [n, int(b["dur"])]
