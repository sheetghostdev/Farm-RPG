class_name InvWindow
extends UIWin
## The backpack: items, equipment, and how this character has been spending their time.

var grid_box: VBoxContainer
var equip_box: VBoxContainer
var skills_box: VBoxContainer

const EQUIP_SLOTS := ["hat", "boots", "t1", "t2"]
const EQUIP_NAMES := {"hat": "Head", "boots": "Feet", "t1": "Trinket", "t2": "Trinket"}

func _init() -> void:
	super._init("Backpack", Vector2(860, 420))
	kind = "inv"
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	content.add_child(h)
	equip_box = VBoxContainer.new()
	h.add_child(equip_box)
	grid_box = VBoxContainer.new()
	h.add_child(grid_box)
	skills_box = VBoxContainer.new()
	skills_box.custom_minimum_size = Vector2(220, 0)
	h.add_child(skills_box)
	refresh()

func refresh() -> void:
	clear_box(equip_box)
	equip_box.add_child(UITheme.label("Equipped", 16, UITheme.TEXT_DIM))
	for i in EQUIP_SLOTS.size():
		var key: String = EQUIP_SLOTS[i]
		var row := HBoxContainer.new()
		var it: Dictionary = Game.me.get("equip", {}).get(key, {})
		var s := make_slot(it, "equip", i, 54)
		row.add_child(s)
		row.add_child(UITheme.label(EQUIP_NAMES[key], 14, UITheme.TEXT_DIM))
		equip_box.add_child(row)
	clear_box(grid_box)
	grid_box.add_child(inventory_grid(10, 50))
	var btns := HBoxContainer.new()
	btns.add_child(UITheme.button("Sort pack", func():
		Game.inv.sort_pack()
		Game.inventory_changed.emit(), 15))
	btns.add_child(UITheme.label("   %d / %d slots used · %d coins (shared)" % [Game.inv.capacity - Game.inv.free_slots(), Game.inv.capacity, Game.money()], 15, UITheme.TEXT_DIM))
	grid_box.add_child(btns)
	grid_box.add_child(UITheme.label("Click to pick up · Right-click: half · Shift-click: move to open container · G: drop held item", 13, UITheme.TEXT_DIM))
	clear_box(skills_box)
	skills_box.add_child(UITheme.label(Game.profile["name"], 20, UITheme.ACCENT))
	for sk in Game.SKILLS:
		var lv := Game.skill_level(sk)
		var xp := float(Game.me.get("skills", {}).get(sk, 0))
		var nxt := 30.0 * pow(lv + 1, 2)
		var cur := 30.0 * pow(lv, 2)
		var row2 := VBoxContainer.new()
		row2.add_theme_constant_override("separation", 0)
		row2.add_child(UITheme.label("%s  %d" % [Game.SKILL_NAMES[sk], lv], 15, UITheme.TEXT))
		var pb := ProgressBar.new()
		pb.custom_minimum_size = Vector2(200, 8)
		pb.show_percentage = false
		pb.max_value = 1.0
		pb.value = 1.0 if lv >= 10 else clamp((xp - cur) / max(1.0, nxt - cur), 0.0, 1.0)
		pb.add_theme_stylebox_override("fill", UITheme.box(Color("c8a050"), Color(0, 0, 0, 0), 4, 0, 0))
		row2.add_child(pb)
		skills_box.add_child(row2)
	var traits := Game.active_traits()
	if not traits.is_empty():
		skills_box.add_child(UITheme.label("Active traits", 15, UITheme.TEXT_DIM))
		var seen := {}
		for t in traits:
			seen[t] = int(seen.get(t, 0)) + 1
		for t in seen:
			var l := UITheme.label("★ %s%s" % [Items.traits[t]["desc"], " ×%d" % seen[t] if seen[t] > 1 else ""], 13, UITheme.ACCENT)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size = Vector2(210, 0)
			skills_box.add_child(l)
