class_name CraftWindow
extends UIWin
## Workbench crafting: tools of the homestead, furniture and expedition supplies.

var list: VBoxContainer
var filter := "all"

func _init(o = null) -> void:
	super._init("Workbench", Vector2(640, 560))
	kind = "craft"
	obj = o
	var tabs := HBoxContainer.new()
	if o == null:
		filter = "supplies"
		tabs.visible = false
	for f in [["all", "All"], ["supplies", "Supplies"], ["stations", "Stations"], ["farm", "Farm"], ["decor", "Decor"]]:
		var key: String = f[0]
		tabs.add_child(UITheme.button(f[1], func(): filter = key; refresh(), 15))
	content.add_child(tabs)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(620, 470)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(sc)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(list)
	refresh()

func _group(id: String) -> String:
	var d := Items.def(id)
	if d.has("place"):
		var o: String = d["place"]["obj"]
		if o in ["chest", "big_chest", "furnace", "kettle", "stove", "workbench"]:
			return "stations"
		if o in ["sprinkler", "sprinkler_2", "scarecrow", "fence", "beehive", "stone_path", "wood_path"]:
			return "farm"
		if o in ["campfire", "torch"]:
			return "supplies"
		return "decor"
	return "supplies"

func _unlocked(r: Dictionary) -> bool:
	var u: String = r.get("unlock", "")
	return u == "" or Game.is_seen(u)

func refresh() -> void:
	clear_box(list)
	var counts := Game.inv.counts()
	for r in Items.craft_recipes:
		if filter != "all" and _group(r["id"]) != filter:
			continue
		var unlocked := _unlocked(r)
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", UITheme.box(UITheme.BG_LIGHT, Color(0.4, 0.3, 0.22), 8, 1, 6))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		row.add_child(h)
		var s := make_slot(Items.make(r["id"], int(r["n"])), "recipe", 0, 46)
		h.add_child(s)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_theme_constant_override("separation", 2)
		h.add_child(v)
		if not unlocked:
			v.add_child(UITheme.label("??? — find %s to learn this" % ("something new" if not Items.has(r["unlock"]) else "a " + Items.def(r["unlock"])["name"].to_lower()), 16, UITheme.TEXT_DIM))
			s.modulate = Color(0.2, 0.2, 0.2)
			list.add_child(row)
			continue
		v.add_child(UITheme.label("%s%s" % [Items.def(r["id"])["name"], " ×%d" % int(r["n"]) if int(r["n"]) > 1 else ""], 17, UITheme.TEXT))
		v.add_child(need_row(r["needs"], counts))
		var can := Game.inv.has_all(r["needs"])
		var b := UITheme.button("Craft", func(): _craft(r, 1), 15)
		b.disabled = not can
		h.add_child(b)
		var b5 := UITheme.button("×5", func(): _craft(r, 5), 15)
		b5.disabled = not can
		h.add_child(b5)
		list.add_child(row)

func _craft(r: Dictionary, times: int) -> void:
	var made := 0
	for i in times:
		if not Game.inv.has_all(r["needs"]):
			break
		var out := Items.make(r["id"], int(r["n"]))
		if not Game.inv.can_add(out):
			Game.say("No room in your pack.", UITheme.BAD)
			break
		Game.inv.remove_all(r["needs"])
		Game.inv.add(out)
		made += 1
	if made > 0:
		Sfx.play("craft")
		Game.discover_item(r["id"])
		for id in r["needs"]:
			Game.learn_item(id)
		Game.add_stat("items_crafted", made)
		Game.inventory_changed.emit()
		Game.say("Crafted %s%s" % [Items.def(r["id"])["name"], " ×%d" % (made * int(r["n"])) if made * int(r["n"]) > 1 else ""], UITheme.GOOD)
