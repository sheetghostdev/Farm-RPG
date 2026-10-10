class_name CookWindow
extends UIWin
## Cooking at a stove or campfire: known dishes, plus an experiment pot.

var campfire := false
var ings: Array = []
var list: VBoxContainer
var exp_box: HBoxContainer
var inv_box: VBoxContainer

func _init(o, at_campfire: bool) -> void:
	campfire = at_campfire
	super._init("Campfire Cooking" if at_campfire else "Cookstove", Vector2(760, 600))
	kind = "cook"
	obj = o
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	content.add_child(h)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(420, 300)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	h.add_child(sc)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(list)
	var right := VBoxContainer.new()
	h.add_child(right)
	right.add_child(UITheme.label("Experiment", 18, UITheme.ACCENT))
	var l := UITheme.label("Toss in 1-3 ingredients from your pack and see what happens.", 14, UITheme.TEXT_DIM)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(260, 0)
	right.add_child(l)
	exp_box = HBoxContainer.new()
	right.add_child(exp_box)
	right.add_child(UITheme.button("Cook it", _experiment, 16))
	content.add_child(HSeparator.new())
	inv_box = VBoxContainer.new()
	content.add_child(inv_box)
	refresh()

func add_ingredient(slot_index: int) -> void:
	if ings.size() >= 3:
		return
	var s: Dictionary = Game.inv.get_slot(slot_index)
	if s.is_empty() or not (Items.def(s["id"]).has("food") or Items.cat_of(s["id"]) in ["crop", "fish", "mushroom", "forage", "herb", "fruit", "animal"]):
		Game.say("That doesn't belong in a pot.", UITheme.BAD)
		return
	Game.inv.take_at(slot_index, 1)
	ings.append(s["id"])
	Game.inventory_changed.emit()

func remove_ingredient(i: int) -> void:
	if i < ings.size():
		Game.inv.add(Items.make(ings[i]))
		ings.remove_at(i)
		Game.inventory_changed.emit()

func on_close() -> void:
	for id in ings:
		Game.inv.add(Items.make(id))
	ings.clear()
	Game.inventory_changed.emit()

func refresh() -> void:
	clear_box(list)
	var counts := Game.inv.counts()
	var any := false
	for r in Items.cook_recipes:
		if campfire and not r["campfire"]:
			continue
		if not Game.knows_recipe(r["id"]):
			continue
		any = true
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", UITheme.box(UITheme.BG_LIGHT, Color(0.4, 0.3, 0.22), 8, 1, 6))
		var h := HBoxContainer.new()
		row.add_child(h)
		h.add_child(make_slot(Items.make(r["id"]), "recipe", 0, 44))
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(v)
		v.add_child(UITheme.label(Items.def(r["id"])["name"], 16, UITheme.TEXT))
		var labels: Array = []
		for n in r["needs"]:
			labels.append(Items.need_label(n))
		v.add_child(UITheme.label(", ".join(PackedStringArray(labels)), 13, UITheme.TEXT_DIM))
		var pick := Items.pick_ingredients(r["needs"], counts)
		var b := UITheme.button("Cook", func(): _cook(r), 15)
		b.disabled = pick.is_empty()
		h.add_child(b)
		list.add_child(row)
	if not any:
		var l := UITheme.label("No recipes yet. Experiment, or make friends in town — cooks love to share.", 15, UITheme.TEXT_DIM)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(400, 0)
		list.add_child(l)
	clear_box(exp_box)
	for i in 3:
		exp_box.add_child(make_slot(Items.make(ings[i]) if i < ings.size() else {}, "cookpot", i, 56))
	clear_box(inv_box)
	inv_box.add_child(inventory_grid(10, 44))

func _cook(r: Dictionary) -> void:
	var pick := Items.pick_ingredients(r["needs"], Game.inv.counts())
	if pick.is_empty():
		return
	var out := Items.make(r["id"])
	for id in pick:
		Game.inv.remove(id, 1)
	Game.inv.add(out)
	_after_cook(r["id"], pick)

func _experiment() -> void:
	if ings.is_empty():
		return
	var res := Items.cook_result(ings, campfire)
	if res == "":
		Game.say("That didn't come together into anything. You pick your ingredients back out.", UITheme.TEXT_DIM)
		Sfx.play("error", -6.0)
		return
	var used := ings.duplicate()
	ings.clear()
	Game.inv.add(Items.make(res))
	if not Game.knows_recipe(res):
		Net.request("learn_recipe", {"id": res, "by": Game.profile["name"]})
		Game.say("New recipe: %s!" % Items.def(res)["name"], UITheme.GOOD)
		Sfx.play("discovery")
	_after_cook(res, used)

func _after_cook(res: String, used: Array) -> void:
	Sfx.play("craft")
	for id in used:
		Game.learn_item(id)
	Game.discover_item(res)
	Game.add_xp("cooking", 3.0 + used.size() * 1.5)
	Game.add_stat("meals_cooked")
	Game.inventory_changed.emit()
	refresh()
