class_name JournalWindow
extends UIWin
## The household journal: the chronicle the group writes by living, every thing
## they've found, fish caught, recipes learned, places, people and themselves.

const TABS := ["Chronicle", "Collection", "Fish", "Recipes", "Places", "People", "Household"]
const KIND_COLORS := {
	"founding": Color("ffd27a"), "find": Color("8ad8ff"), "fish": Color("6ab0e0"), "place": Color("9ae68a"),
	"people": Color("ff9ab0"), "project": Color("e8c06a"), "trade": Color("f2c94c"), "rescue": Color("ff9a7a"),
	"season": Color("b8e08a"), "home": Color("e0a070"), "brew": Color("c8a0ff"), "deep": Color("a090ff"),
	"battle": Color("ff8a6a"), "note": Color("f6ead2"), "event": Color("c8b89a"), "cave": Color("a090ff"),
	"farm": Color("b8d070"), "recipe": Color("e8b070"),
}
const FILTERS := [["All", []], ["Discoveries", ["find", "place", "fish", "brew", "recipe", "deep"]], ["People", ["people", "founding"]],
	["Farm & Town", ["project", "home", "farm", "trade", "season"]], ["Adventures", ["battle", "rescue", "deep", "cave"]], ["Written", ["note"]]]
const CAT_ORDER := ["crop", "fruit", "forage", "mushroom", "herb", "fish", "junk", "ore", "bar", "mineral", "gem", "monster", "curio",
	"food", "drink", "brew", "material", "seed", "sapling", "bait", "animal", "tool", "weapon", "gear", "placeable"]
const CAT_NAMES := {"crop": "Crops", "fruit": "Fruit", "forage": "Forage", "mushroom": "Mushrooms", "herb": "Herbs", "fish": "Fish",
	"junk": "Odds & Ends", "ore": "Ore", "bar": "Metal Bars", "mineral": "Minerals", "gem": "Gems", "monster": "Creature Parts",
	"curio": "Curios", "food": "Dishes", "drink": "Drinks", "brew": "Brews", "material": "Materials", "seed": "Seeds",
	"sapling": "Saplings", "bait": "Bait & Tackle", "animal": "Animal Goods", "tool": "Tools", "weapon": "Weapons",
	"gear": "Gear", "placeable": "Furniture & Fixtures"}
const WATER_NAMES := {"river": "the river", "lake": "the lake", "pond": "ponds", "hidden": "a hidden pool", "hot": "the hot spring",
	"cave_earth": "shallow cave pools", "cave_moss": "mossy cave pools", "cave_crystal": "crystal grottos", "cave_fungal": "fungal marsh pools",
	"cave_ember": "the ember depths", "cave_ancient": "the ancient deep"}

var tab := "Chronicle"
var tab_bar: HBoxContainer
var scroll: ScrollContainer
var body: VBoxContainer
var filter_i := 0
var entry_edit: LineEdit
var _open_notes := {}
var _cat_filter := ""

func _init(t: String = "") -> void:
	super._init("Household Journal", Vector2(1000, 660))
	kind = "journal"
	if t in TABS:
		tab = t
	tab_bar = HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 4)
	content.add_child(tab_bar)
	scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(970, 560)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 6)
	scroll.add_child(body)
	_rebuild()

func refresh() -> void:
	if entry_edit and is_instance_valid(entry_edit) and entry_edit.has_focus():
		return
	var sv := scroll.scroll_vertical
	_rebuild()
	_restore_scroll.call_deferred(sv)

func _restore_scroll(v: int) -> void:
	if is_instance_valid(scroll):
		scroll.scroll_vertical = v

func _set_tab(t: String) -> void:
	tab = t
	_rebuild()
	scroll.scroll_vertical = 0
	Sfx.play("click", -6.0)

func _rebuild() -> void:
	clear_box(tab_bar)
	for t in TABS:
		var tn: String = t
		var b := UITheme.button(tn, func(): _set_tab(tn), 16)
		b.toggle_mode = true
		b.button_pressed = tn == tab
		b.custom_minimum_size = Vector2(124, 36)
		tab_bar.add_child(b)
	clear_box(body)
	entry_edit = null
	match tab:
		"Chronicle": _chronicle()
		"Collection": _collection()
		"Fish": _fish()
		"Recipes": _recipes()
		"Places": _places()
		"People": _people()
		"Household": _household()

# ------------------------------------------------------------------ helpers

static func date_for(d: int) -> String:
	var sl := Game.season_len()
	var s := int((d - 1) / sl) % 4
	var y := int((d - 1) / (sl * 4)) + 1
	return "%s %d, Year %d" % [Items.season_name(s), (d - 1) % sl + 1, y]

func _heading(text: String, sub: String = "") -> void:
	var h := HBoxContainer.new()
	h.add_child(UITheme.label(text, 21, UITheme.ACCENT))
	if sub != "":
		var s := UITheme.label("   " + sub, 15, UITheme.TEXT_DIM)
		s.size_flags_vertical = Control.SIZE_SHRINK_END
		h.add_child(s)
	body.add_child(h)

func _wrap(text: String, sz: int = 16, col: Color = UITheme.TEXT, width: float = 930.0) -> Label:
	var l := UITheme.label(text, sz, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(width, 0)
	return l

func _pip(col: Color, sz: float = 10.0) -> Control:
	var c := ColorRect.new()
	c.color = col
	c.custom_minimum_size = Vector2(sz, sz)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return c

func _info_slot(id: String, hidden_item: bool, sz: float = 44.0) -> ItemSlot:
	var s := ItemSlot.new(sz)
	s.set_item(Items.make(id))
	s.silhouette = hidden_item
	s.mouse_filter = Control.MOUSE_FILTER_PASS
	s.hovered.connect(func(sl, on):
		if not on:
			Game.main.hud.show_tooltip("")
		elif sl.silhouette:
			Game.main.hud.show_tooltip("[b]???[/b]\n[color=#c8b89a]Not found yet.[/color]")
		else:
			Game.main.hud.show_tooltip(ItemSlot.describe(sl.item)))
	return s

# ------------------------------------------------------------------ chronicle

func _chronicle() -> void:
	var chron: Array = Game.world.get("chronicle", [])
	_heading("The Chronicle", "%d entries since %s" % [chron.size(), date_for(1)])
	body.add_child(_wrap("Everything worth remembering ends up here: firsts, finds, friendships, close calls. Add your own lines too.", 15, UITheme.TEXT_DIM))
	var add := HBoxContainer.new()
	entry_edit = LineEdit.new()
	entry_edit.placeholder_text = "Write something in the chronicle..."
	entry_edit.max_length = 160
	entry_edit.custom_minimum_size = Vector2(760, 36)
	entry_edit.text_submitted.connect(func(_t): _submit_entry())
	add.add_child(entry_edit)
	add.add_child(UITheme.button("Write it down", _submit_entry, 15))
	body.add_child(add)
	var fb := HBoxContainer.new()
	fb.add_theme_constant_override("separation", 4)
	for i in FILTERS.size():
		var fi := i
		var b := UITheme.button(FILTERS[i][0], func():
			filter_i = fi
			_rebuild(), 14)
		b.toggle_mode = true
		b.button_pressed = i == filter_i
		fb.add_child(b)
	body.add_child(fb)
	body.add_child(HSeparator.new())
	var kinds: Array = FILTERS[filter_i][1]
	var last_day := -1
	var shown := 0
	for i in range(chron.size() - 1, -1, -1):
		var e: Dictionary = chron[i]
		var k: String = e.get("k", "event")
		if not kinds.is_empty() and not kinds.has(k):
			continue
		var d := int(e.get("d", 1))
		if d != last_day:
			last_day = d
			var dl := UITheme.label(date_for(d) + ("  ·  today" if d == Game.day() else ""), 15, UITheme.BORDER)
			body.add_child(dl)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.add_child(_pip(KIND_COLORS.get(k, UITheme.TEXT_DIM)))
		var txt: String = e.get("s", "")
		row.add_child(_wrap(txt, 17, UITheme.TEXT if k != "note" else Color("f0e0c0"), 900.0))
		body.add_child(row)
		shown += 1
		if shown >= 400:
			body.add_child(UITheme.label("(older entries continue in the save file...)", 14, UITheme.TEXT_DIM))
			break
	if shown == 0:
		body.add_child(UITheme.label("Nothing here yet.", 16, UITheme.TEXT_DIM))

func _submit_entry() -> void:
	if entry_edit == null:
		return
	var t := entry_edit.text.strip_edges()
	if t == "":
		return
	Net.request("chronicle", {"s": "%s wrote: \"%s\"" % [Game.profile["name"], t], "k": "note"})
	entry_edit.text = ""
	entry_edit.release_focus()
	Sfx.play("click", -4.0)
	await get_tree().create_timer(0.3).timeout
	if is_instance_valid(self):
		_rebuild()

# ------------------------------------------------------------------ collection

func _collection() -> void:
	var by_cat := {}
	var seen_n := 0
	var total := 0
	for id in Items.defs:
		var d: Dictionary = Items.defs[id]
		var c: String = d.get("cat", "")
		if c == "" or c == "quest" or id.begins_with("$") or d.get("hidden", false):
			continue
		if not by_cat.has(c):
			by_cat[c] = []
		by_cat[c].append(id)
		total += 1
		if Game.is_seen(id):
			seen_n += 1
	_heading("Collection", "%d of %d things found  ·  %d understood" % [seen_n, total, _known_count()])
	var cats: Array = []
	for c in CAT_ORDER:
		if by_cat.has(c):
			cats.append(c)
	for c in by_cat:
		if not cats.has(c):
			cats.append(c)
	var fb := HFlowContainer.new()
	fb.add_theme_constant_override("h_separation", 4)
	var allb := UITheme.button("Everything", func():
		_cat_filter = ""
		_rebuild(), 13)
	allb.toggle_mode = true
	allb.button_pressed = _cat_filter == ""
	fb.add_child(allb)
	for c in cats:
		var cc: String = c
		var b := UITheme.button(CAT_NAMES.get(c, c.capitalize()), func():
			_cat_filter = cc
			_rebuild(), 13)
		b.toggle_mode = true
		b.button_pressed = _cat_filter == c
		fb.add_child(b)
	body.add_child(fb)
	for c in cats:
		if _cat_filter != "" and c != _cat_filter:
			continue
		var ids: Array = by_cat[c]
		var got := 0
		for id in ids:
			if Game.is_seen(id):
				got += 1
		body.add_child(UITheme.label("%s   %d/%d" % [CAT_NAMES.get(c, c.capitalize()), got, ids.size()], 17, UITheme.ACCENT if got == ids.size() else UITheme.TEXT))
		var g := GridContainer.new()
		g.columns = 19
		g.add_theme_constant_override("h_separation", 4)
		g.add_theme_constant_override("v_separation", 4)
		for id in ids:
			g.add_child(_info_slot(id, not Game.is_seen(id), 46))
		body.add_child(g)

func _known_count() -> int:
	var n := 0
	for id in Game.world.get("know", {}).get("items", {}):
		if Items.has(id) and Game.is_known(id):
			n += 1
	return n

# ------------------------------------------------------------------ fish

func _fish() -> void:
	var log: Dictionary = Game.world["know"].get("fish", {})
	var ids: Array = Items.fish.keys()
	_heading("Fish Log", "%d of %d species caught" % [log.size(), ids.size()])
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 18)
	g.add_theme_constant_override("v_separation", 8)
	body.add_child(g)
	for id in ids:
		var fd: Dictionary = Items.fish[id]
		var rec: Dictionary = log.get(id, {})
		var caught := not rec.is_empty()
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(470, 0)
		row.add_theme_constant_override("separation", 10)
		row.add_child(_info_slot(id, not caught, 52))
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 0)
		var nm: String = Items.def(id)["name"] if caught else "???"
		if fd.get("legend", false):
			nm += "  ★"
		v.add_child(UITheme.label(nm, 17, Color("ffd27a") if fd.get("legend", false) and caught else UITheme.TEXT))
		var where: Array = []
		for w in fd["where"]:
			where.append(WATER_NAMES.get(w, w))
		if caught:
			v.add_child(UITheme.label("Caught %d  ·  best %d cm by %s" % [int(rec.get("n", 1)), int(rec.get("best", 0)), rec.get("best_by", rec.get("by", "?"))], 14, UITheme.GOOD))
			var when: Array = []
			if fd["seasons"].is_empty():
				when.append("any season")
			else:
				var sn: Array = []
				for s in fd["seasons"]:
					sn.append(Items.season_name(int(s)))
				when.append("/".join(PackedStringArray(sn)))
			if fd["tod"] != "any":
				when.append("at " + ("night" if fd["tod"] == "night" else "day"))
			if fd["weather"] != "any":
				when.append("in the " + fd["weather"])
			v.add_child(UITheme.label("In %s · %s" % [", ".join(PackedStringArray(where)), ", ".join(PackedStringArray(when))], 13, UITheme.TEXT_DIM))
		else:
			v.add_child(UITheme.label("Said to live in %s." % where[0] if not where.is_empty() else "Nobody knows where.", 13, UITheme.TEXT_DIM))
		row.add_child(v)
		g.add_child(row)

# ------------------------------------------------------------------ recipes

func _recipes() -> void:
	var known: Dictionary = Game.world["know"].get("recipes", {})
	var cook_known := 0
	for r in Items.cook_recipes:
		if known.has(r["id"]):
			cook_known += 1
	_heading("Cooking", "%d of %d dishes" % [cook_known, Items.cook_recipes.size()])
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 18)
	body.add_child(g)
	for r in Items.cook_recipes:
		var k := known.has(r["id"])
		g.add_child(_recipe_row(r["id"], r["needs"] if k else [], k, "campfire" if r.get("campfire", false) else ""))
	body.add_child(HSeparator.new())
	var brews: Array = []
	for id in known:
		var c := Items.cat_of(id)
		if c == "brew" or c == "drink":
			brews.append(id)
	_heading("Brewing", "%d brews and drinks discovered" % brews.size())
	body.add_child(_wrap("Brews come from the essences in what you put in the kettle: the strongest essence decides the kind, the second can twist it into something special.", 14, UITheme.TEXT_DIM))
	var g2 := GridContainer.new()
	g2.columns = 2
	g2.add_theme_constant_override("h_separation", 18)
	body.add_child(g2)
	for id in brews:
		g2.add_child(_recipe_row(id, known[id].get("ings", []), true, "by " + str(known[id].get("by", "?")) if known[id].get("by", "") != "" else ""))
	if brews.is_empty():
		body.add_child(UITheme.label("No brews yet. Try a kettle and a few herbs.", 15, UITheme.TEXT_DIM))
	body.add_child(HSeparator.new())
	var craft_n := 0
	for r in Items.craft_recipes:
		if String(r.get("unlock", "")) == "" or known.has(r["id"]) or Game.is_seen(r.get("unlock", "")):
			craft_n += 1
	_heading("Crafting", "%d of %d plans" % [craft_n, Items.craft_recipes.size()])
	var g3 := GridContainer.new()
	g3.columns = 2
	g3.add_theme_constant_override("h_separation", 18)
	body.add_child(g3)
	for r in Items.craft_recipes:
		var u: String = r.get("unlock", "")
		var k3 := u == "" or known.has(r["id"]) or Game.is_seen(u)
		var needs: Array = []
		if k3:
			for id in r["needs"]:
				needs.append("%s×%d" % [id, int(r["needs"][id])])
		g3.add_child(_recipe_row(r["id"], needs, k3, ""))

func _recipe_row(id: String, needs: Array, k: bool, note: String) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(470, 0)
	row.add_theme_constant_override("separation", 8)
	row.add_child(_info_slot(id, not k, 40))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.add_child(UITheme.label(Items.def(id)["name"] if k else "???", 16))
	if k:
		var parts: Array = []
		for n in needs:
			var s := String(n)
			var count := ""
			if s.contains("×"):
				count = " ×" + s.get_slice("×", 1)
				s = s.get_slice("×", 0)
			if s.begins_with("#"):
				parts.append("any " + s.substr(1) + count)
			elif Items.has(s):
				parts.append(Items.def(s)["name"] + count)
		var line := ", ".join(PackedStringArray(parts))
		if note != "":
			line += ("  ·  " if line != "" else "") + note
		v.add_child(UITheme.label(line, 13, UITheme.TEXT_DIM))
	row.add_child(v)
	return row

# ------------------------------------------------------------------ places

func _places() -> void:
	var places: Dictionary = Game.world["know"].get("places", {})
	var g := Zones.overworld_gen()
	var named := 0
	for q in g.pois:
		if q.get("name", "") != "":
			named += 1
	_heading("Places", "%d of %d landmarks found" % [places.size(), named])
	var ids: Array = places.keys()
	ids.sort_custom(func(a, b): return int(places[a].get("day", 0)) < int(places[b].get("day", 0)))
	for id in ids:
		var p: Dictionary = places[id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.add_child(_pip(Color("9ae68a")))
		row.add_child(UITheme.label(p.get("name", id), 17))
		row.add_child(UITheme.label("found by %s, %s" % [p.get("by", "?"), date_for(int(p.get("day", 1)))], 14, UITheme.TEXT_DIM))
		body.add_child(row)
	if ids.is_empty():
		body.add_child(UITheme.label("Nowhere special yet. Go for a walk!", 15, UITheme.TEXT_DIM))
	body.add_child(HSeparator.new())
	var deepest := int(Game.world["know"].get("deepest", 0))
	_heading("The Caves", "deepest floor reached: %d" % deepest if deepest > 0 else "unexplored")
	var stones: Array = Game.world["know"].get("waystones", []).duplicate()
	stones.sort()
	if not stones.is_empty():
		var ss: Array = []
		for s in stones:
			ss.append(str(s))
		body.add_child(UITheme.label("Waystones attuned on floors " + ", ".join(PackedStringArray(ss)), 15))
	var biomes := {}
	for f in range(1, deepest + 1):
		var b: Dictionary = CaveGen.BIOMES[CaveGen.biome_index(f)]
		if not biomes.has(b["name"]):
			biomes[b["name"]] = f
	for bn in biomes:
		var row2 := HBoxContainer.new()
		row2.add_theme_constant_override("separation", 10)
		row2.add_child(_pip(Color("a090ff")))
		row2.add_child(UITheme.label(bn, 16))
		row2.add_child(UITheme.label("from floor %d" % biomes[bn], 14, UITheme.TEXT_DIM))
		body.add_child(row2)
	body.add_child(HSeparator.new())
	var notes: Array = Game.world["know"].get("notes", [])
	_heading("Notes of the Lantern Company", "%d of %d found" % [notes.size(), Lore.NOTES.size()])
	var sorted: Array = notes.duplicate()
	sorted.sort()
	for i in sorted:
		var ni := int(i)
		var t := Lore.note(ni)
		var b := UITheme.button(("▾ " if _open_notes.has(ni) else "▸ ") + t["title"], func():
			if _open_notes.has(ni):
				_open_notes.erase(ni)
			else:
				_open_notes[ni] = true
			refresh(), 15)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		body.add_child(b)
		if _open_notes.has(ni):
			var l := _wrap(t["text"], 16, Color("f0e0c0"), 900.0)
			body.add_child(l)

# ------------------------------------------------------------------ people

func _people() -> void:
	var town := Zones.town
	if town == null:
		body.add_child(UITheme.label("No town nearby.", 16))
		return
	var met: Dictionary = Game.world["know"].get("people", {})
	var me: String = Game.profile["name"]
	_heading("The People of %s" % TownGen.town_name(), "%d of %d met" % [met.size(), town.residents.size()])
	var tastes: Dictionary = Game.world["town"].get("tastes", {})
	var wishes: Dictionary = Game.world["town"].get("wishes", {})
	var list: Array = town.residents.duplicate()
	list.sort_custom(func(a, b):
		var ma := met.has(a["id"])
		var mbm := met.has(b["id"])
		if ma != mbm:
			return ma
		return TownLogic.points(a["id"], me) > TownLogic.points(b["id"], me))
	for p in list:
		var pid: String = p["id"]
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", UITheme.box(Color(0.22, 0.16, 0.13, 0.9), Color(0.45, 0.34, 0.24), 8, 1, 8))
		body.add_child(panel)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 2)
		panel.add_child(v)
		if not met.has(pid):
			v.add_child(UITheme.label("Someone you haven't met  ·  %s" % ("a child" if p["age"] == "child" else TownGen.job_title(p) if p["role"] not in ["", "house"] else "a resident"), 15, UITheme.TEXT_DIM))
			continue
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 14)
		top.add_child(UITheme.label(p["name"], 18, UITheme.ACCENT))
		var job := TownGen.job_title(p) if p["role"] not in ["", "house"] else ("Child" if p["age"] == "child" else "Resident")
		top.add_child(UITheme.label(job, 15, UITheme.TEXT_DIM))
		var h := TownLogic.hearts(pid, me)
		var hs := ""
		for i in 10:
			hs += "♥" if i < h else "♡"
		top.add_child(UITheme.label(hs, 16, Color("ff8aa0")))
		var bd: Array = p.get("birthday", [0, 1])
		top.add_child(UITheme.label("Birthday: %s %d" % [Items.season_name(int(bd[0])), int(bd[1])], 14, UITheme.TEXT_DIM))
		v.add_child(top)
		var fam: Array = []
		for rel in p.get("family", {}):
			var ids = p["family"][rel]
			if ids is String:
				ids = [ids]
			for oid in ids:
				var o := town.resident(oid)
				if not o.is_empty():
					fam.append("%s (%s)" % [o["first"], TownGen.relation_word(rel)])
		var line := ""
		if not fam.is_empty():
			line += "Family: " + ", ".join(PackedStringArray(fam))
		var ints: Array = p.get("interests", [])
		if not ints.is_empty():
			line += ("   ·   " if line != "" else "") + "Into " + ", ".join(PackedStringArray(ints))
		if line != "":
			v.add_child(_wrap(line, 14, UITheme.TEXT, 900.0))
		var tl: Dictionary = tastes.get(pid, {})
		var loves: Array = []
		var likes: Array = []
		var dislikes: Array = []
		for item in tl:
			var nm: String = Items.def(item).get("name", item)
			match tl[item]:
				"love": loves.append(nm)
				"like": likes.append(nm)
				"dislike": dislikes.append(nm)
		var tline := ""
		if not loves.is_empty():
			tline += "Loves: " + ", ".join(PackedStringArray(loves)) + "   "
		if not likes.is_empty():
			tline += "Likes: " + ", ".join(PackedStringArray(likes)) + "   "
		if not dislikes.is_empty():
			tline += "Not keen on: " + ", ".join(PackedStringArray(dislikes))
		if tline != "":
			v.add_child(_wrap(tline, 13, Color("ffb8c8"), 900.0))
		if wishes.has(pid):
			v.add_child(UITheme.label("Got their wish from %s." % wishes[pid], 13, UITheme.GOOD))

# ------------------------------------------------------------------ household

func _household() -> void:
	var w := Game.world
	var lvl := int(w["farm"].get("level", 0))
	_heading(w.get("name", "Our World"), "%s  ·  day %d" % [Game.date_text(), Game.day()])
	var house = ["A small farmhouse", "A renovated farmhouse", "A two-storey farmhouse"][clamp(lvl, 0, 2)]
	var fields := 0
	var growing := 0
	for k in w["farm"]["tiles"]:
		fields += 1
		if w["farm"]["tiles"][k].has("crop"):
			growing += 1
	var placed := 0
	for oid in w["objects"]:
		if w["objects"][oid].get("z", "") in ["over", "home"]:
			placed += 1
	body.add_child(_wrap("%s, %d tilled plots (%d growing), %d things built or placed. The household purse holds %d coins. %s has %d projects built." % [
		house, fields, growing, placed, Game.money(), TownGen.town_name(), _built_projects()], 16))
	body.add_child(HSeparator.new())
	var stat_names := [["crops_harvested", "crops harvested"], ["fish_caught", "fish caught"], ["ore_mined", "ore mined"],
		["trees_felled", "trees felled"], ["creatures_defeated", "creatures defeated"], ["meals_cooked", "meals cooked"],
		["brews_started", "brews started"], ["places_found", "places found"], ["requests_done", "favors done"],
		["things_placed", "things placed"], ["conversations", "conversations"], ["times_carried_home", "times carried home"]]
	var players: Dictionary = w.get("players", {})
	for nm in players:
		var pd: Dictionary = players[nm] if nm != Game.profile["name"] else Game.me
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", UITheme.box(Color(0.22, 0.16, 0.13, 0.9), Color(0.45, 0.34, 0.24), 8, 1, 10))
		body.add_child(panel)
		var v := VBoxContainer.new()
		panel.add_child(v)
		var online := false
		for id in Net.peers:
			if Net.peers[id].get("name", "") == nm:
				online = true
		v.add_child(UITheme.label(nm + ("  (here now)" if online else ""), 19, UITheme.ACCENT))
		var sk := GridContainer.new()
		sk.columns = 3
		sk.add_theme_constant_override("h_separation", 26)
		v.add_child(sk)
		for s in Game.SKILLS:
			var xp := float(pd.get("skills", {}).get(s, 0))
			var lv := Game.skill_level(s, pd)
			var h := HBoxContainer.new()
			h.custom_minimum_size = Vector2(290, 0)
			var l := UITheme.label("%s %d" % [Game.SKILL_NAMES[s], lv], 15)
			l.custom_minimum_size = Vector2(170, 0)
			h.add_child(l)
			var bar := ProgressBar.new()
			bar.show_percentage = false
			bar.custom_minimum_size = Vector2(110, 12)
			bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var lo := 30.0 * lv * lv
			var hi := 30.0 * (lv + 1) * (lv + 1)
			bar.value = 100.0 if lv >= 10 else (xp - lo) / (hi - lo) * 100.0
			h.add_child(bar)
			sk.add_child(h)
		var parts: Array = []
		for st in stat_names:
			var n := int(pd.get("stats", {}).get(st[0], 0))
			if n > 0:
				parts.append("%d %s" % [n, st[1]])
		v.add_child(_wrap(", ".join(PackedStringArray(parts)) if not parts.is_empty() else "Just getting started.", 14, UITheme.TEXT_DIM, 900.0))

func _built_projects() -> int:
	var n := 0
	for pid in Game.world["town"].get("projects", {}):
		if Game.world["town"]["projects"][pid].get("state", "") == "built":
			n += 1
	return n
