class_name KettleWindow
extends UIWin
## Brewing: drop in up to three ingredients. Their essences decide the brew.

var ings: Array = []
var top: VBoxContainer
var inv_box: VBoxContainer

func _init(o) -> void:
	super._init("Brewing Kettle", Vector2(720, 560))
	kind = "kettle"
	obj = o
	top = VBoxContainer.new()
	content.add_child(top)
	content.add_child(HSeparator.new())
	inv_box = VBoxContainer.new()
	content.add_child(inv_box)
	refresh()

func add_ingredient(slot_index: int) -> void:
	if ings.size() >= 3:
		return
	var s: Dictionary = Game.inv.get_slot(slot_index)
	if s.is_empty():
		return
	var c := Items.cat_of(s["id"])
	if c in ["tool", "weapon", "gear", "placeable", "quest", "seed"]:
		Game.say("That won't go in a kettle.", UITheme.BAD)
		return
	Game.inv.take_at(slot_index, 1)
	ings.append(s["id"])
	Sfx.play("bubble", -6.0)
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
	clear_box(top)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	top.add_child(h)
	for i in 3:
		var it: Dictionary = Items.make(ings[i]) if i < ings.size() else {}
		h.add_child(make_slot(it, "kettle", i, 60))
	h.add_child(UITheme.label("→", 30, UITheme.ACCENT))
	var pred := ""
	var known_all := true
	for id in ings:
		if not Game.is_known(id):
			known_all = false
	if not ings.is_empty():
		var res := Items.brew_result(ings)
		if Game.knows_recipe(res):
			h.add_child(make_slot(Items.make(res), "pred", 0, 60))
			pred = Items.def(res)["name"]
		else:
			h.add_child(UITheme.label("???", 30, UITheme.TEXT_DIM))
			pred = "Something new... maybe."
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	v.add_child(UITheme.label(pred, 17, UITheme.TEXT))
	var ess := {}
	for id in ings:
		if Game.is_known(id):
			for e in Items.essences_of(id):
				ess[e] = int(ess.get(e, 0)) + int(Items.essences_of(id)[e])
	var parts: Array = []
	for e in ess:
		parts.append("[color=#%s]%s %d[/color]" % [UITheme.hex(Items.ESSENCE_COLORS[e]), Items.ESSENCE_NAMES[e], ess[e]])
	if not parts.is_empty() or not known_all:
		v.add_child(UITheme.rich("Essences: " + ", ".join(PackedStringArray(parts)) + ("" if known_all else " [color=#bfe3ff](+ something unknown)[/color]"), 15))
	var b := UITheme.button("Brew (1½ hours)", _brew, 17)
	b.disabled = ings.is_empty()
	top.add_child(b)
	var guide := "[color=#%s]Strongest essence decides the brew; a strong second essence can twist it into something special. More essence makes it stronger. Fruit, grain and honey alone make drinks.[/color]" % UITheme.hex(UITheme.TEXT_DIM)
	top.add_child(UITheme.rich(guide, 14))
	var known: Array = []
	for r in Game.world["know"]["recipes"]:
		if Items.cat_of(r) in ["brew", "drink"]:
			known.append(Items.def(r)["name"])
	if not known.is_empty():
		var kl := UITheme.rich("[color=#%s]Discovered: %s[/color]" % [UITheme.hex(UITheme.GOOD), ", ".join(PackedStringArray(known))], 14)
		top.add_child(kl)
	clear_box(inv_box)
	inv_box.add_child(UITheme.label("Click an ingredient in your pack to add it", 14, UITheme.TEXT_DIM))
	inv_box.add_child(inventory_grid(10, 46))

func _brew() -> void:
	if ings.is_empty():
		return
	Net.request("kettle_brew", {"id": obj.oid, "ings": ings.duplicate()})
	for id in ings:
		Game.learn_item(id)
	Game.add_xp("cooking", 4.0 + ings.size() * 2.0)
	Game.add_stat("brews_started")
	ings.clear()
	Sfx.play("bubble")
	close_win()
