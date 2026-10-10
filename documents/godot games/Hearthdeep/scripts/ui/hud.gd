class_name HUD
extends CanvasLayer
## The always-on overlay: clock, money, hotbar, health, prompts, toasts, party.

var root: Control
var clock_l: Label
var date_l: Label
var money_l: Label
var weather_l: Label
var zone_l: Label
var hotbar: HBoxContainer
var hot_slots: Array = []
var hp_bar: ProgressBar
var hp_l: Label
var buffs_box: HBoxContainer
var prompt_l: Label
var info_l: Label
var toasts: VBoxContainer
var notes: VBoxContainer
var party: VBoxContainer
var center_l: Label
var fade: ColorRect
var sleep_l: Label
var tooltip: PanelContainer
var tooltip_rt: RichTextLabel
var minimap: Minimap
var _party_t := 0.0
var _note_items := {}

func _ready() -> void:
	layer = 5
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UITheme.get_theme()
	add_child(root)
	_build_top_left()
	_build_hotbar()
	_build_misc()
	Game.money_changed.connect(func(_v): _refresh_money())
	Game.inventory_changed.connect(refresh_hotbar)
	Game.toast.connect(toast)
	Game.stats_changed.connect(_refresh_buffs)
	visible = false

func _build_top_left() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 14)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	panel.add_child(v)
	date_l = UITheme.label("Spring 1", 17, UITheme.TEXT_DIM)
	clock_l = UITheme.label("6:00 am", 26, UITheme.TEXT)
	var h := HBoxContainer.new()
	weather_l = UITheme.label("Clear", 16, UITheme.TEXT_DIM)
	money_l = UITheme.label("500", 18, UITheme.ACCENT)
	h.add_child(weather_l)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(18, 0)
	h.add_child(sp)
	h.add_child(money_l)
	v.add_child(date_l)
	v.add_child(clock_l)
	v.add_child(h)
	zone_l = UITheme.label("", 16, UITheme.TEXT_DIM, true)
	v.add_child(zone_l)

func _build_hotbar() -> void:
	var anchor := Control.new()
	anchor.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(anchor)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.box(Color(0.12, 0.09, 0.08, 0.85), UITheme.BORDER, 12, 2, 8))
	anchor.add_child(panel)
	var v := VBoxContainer.new()
	panel.add_child(v)
	var hp_row := HBoxContainer.new()
	hp_row.add_theme_constant_override("separation", 10)
	v.add_child(hp_row)
	hp_bar = ProgressBar.new()
	hp_bar.custom_minimum_size = Vector2(260, 16)
	hp_bar.show_percentage = false
	hp_bar.max_value = 100
	hp_bar.value = 100
	hp_row.add_child(hp_bar)
	hp_l = UITheme.label("100 / 100", 14, UITheme.TEXT)
	hp_row.add_child(hp_l)
	buffs_box = HBoxContainer.new()
	hp_row.add_child(buffs_box)
	hotbar = HBoxContainer.new()
	hotbar.add_theme_constant_override("separation", 4)
	v.add_child(hotbar)
	for i in 10:
		var s := ItemSlot.new(58)
		s.index = i
		s.source = "inv"
		s.hotkey = str((i + 1) % 10)
		s.pressed.connect(_on_hot_pressed)
		s.hovered.connect(_on_slot_hover)
		hotbar.add_child(s)
		hot_slots.append(s)
	panel.position = Vector2(-330, -100)
	panel.resized.connect(func(): panel.position = Vector2(-panel.size.x / 2.0, -panel.size.y - 12))

func _build_misc() -> void:
	prompt_l = UITheme.label("", 20, UITheme.TEXT, true)
	prompt_l.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_l.position = Vector2(-300, -160)
	prompt_l.size = Vector2(600, 30)
	root.add_child(prompt_l)
	info_l = UITheme.label("", 15, UITheme.TEXT_DIM, true)
	info_l.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	info_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_l.position = Vector2(-300, -186)
	info_l.size = Vector2(600, 24)
	root.add_child(info_l)
	toasts = VBoxContainer.new()
	toasts.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toasts.position = Vector2(-350, 18)
	toasts.size = Vector2(700, 200)
	toasts.alignment = BoxContainer.ALIGNMENT_BEGIN
	toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toasts)
	notes = VBoxContainer.new()
	notes.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	notes.position = Vector2(-260, 0)
	notes.size = Vector2(240, 300)
	notes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(notes)
	party = VBoxContainer.new()
	party.position = Vector2(16, 190)
	party.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(party)
	center_l = UITheme.label("", 34, UITheme.ACCENT, true)
	center_l.set_anchors_preset(Control.PRESET_CENTER)
	center_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_l.position = Vector2(-400, -140)
	center_l.size = Vector2(800, 50)
	center_l.modulate.a = 0.0
	root.add_child(center_l)
	sleep_l = UITheme.label("", 22, Color("c8d0ff"), true)
	sleep_l.set_anchors_preset(Control.PRESET_CENTER)
	sleep_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sleep_l.position = Vector2(-400, 60)
	sleep_l.size = Vector2(800, 40)
	root.add_child(sleep_l)
	minimap = Minimap.new()
	minimap.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	minimap.position = Vector2(-216, 14)
	root.add_child(minimap)
	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fade)
	tooltip = PanelContainer.new()
	tooltip.add_theme_stylebox_override("panel", UITheme.box(Color(0.1, 0.07, 0.06, 0.97), UITheme.BORDER, 8, 2, 10))
	tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip.visible = false
	tooltip.z_index = 100
	tooltip_rt = UITheme.rich("", 16)
	tooltip_rt.custom_minimum_size = Vector2(300, 0)
	tooltip_rt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip.add_child(tooltip_rt)

## The tooltip must sit above every window, so it lives on the top UI layer.
func attach_tooltip(parent: Node) -> void:
	if tooltip.get_parent():
		tooltip.get_parent().remove_child(tooltip)
	parent.add_child(tooltip)

func show_tooltip(text: String) -> void:
	if text == "":
		tooltip.visible = false
		return
	tooltip_rt.text = text
	tooltip.visible = true
	tooltip.size = Vector2.ZERO

func _on_slot_hover(slot: ItemSlot, on: bool) -> void:
	show_tooltip(ItemSlot.describe(slot.item) if on else "")

func _on_hot_pressed(slot: ItemSlot, button: int) -> void:
	if Game.main.windows_open():
		Game.main.slot_clicked(slot, button)
		return
	if Game.local_player:
		Game.local_player.select_hot(slot.index)

func _process(delta: float) -> void:
	if not visible:
		return
	if tooltip.visible:
		var mp := tooltip.get_global_mouse_position() + Vector2(18, 18)
		var vs := tooltip.get_viewport_rect().size
		if mp.x + tooltip.size.x > vs.x:
			mp.x -= tooltip.size.x + 30
		if mp.y + tooltip.size.y > vs.y:
			mp.y = vs.y - tooltip.size.y - 4
		tooltip.global_position = mp
	clock_l.text = Game.clock_text()
	date_l.text = Game.date_text()
	weather_l.text = {"clear": "☀ Clear", "cloudy": "☁ Cloudy", "rain": "☂ Rain", "storm": "⚡ Storm", "fog": "≋ Fog", "snow": "❄ Snow"}.get(Game.weather(), Game.weather())
	var lp = Game.local_player
	if lp:
		var mh: float = lp.max_hp()
		hp_bar.max_value = mh
		hp_bar.value = lp.hp
		hp_l.text = "%d / %d" % [int(ceil(lp.hp)), int(mh)]
		var t = lp.best_interactable() if not Game.main.ui_blocking() else null
		var p: String = lp.prompt_for(t)
		prompt_l.text = ("[E]  " + p) if p != "" else ""
		info_l.text = _info_line(lp)
		if lp.sleeping:
			var n := 0
			for id in Net.peers:
				if Net.peers[id].get("sleep", false):
					n += 1
			sleep_l.text = "Sleeping... %s" % ("" if Net.peers.size() <= 1 else "(%d/%d asleep)" % [n, Net.peers.size()])
		elif lp.downed:
			sleep_l.text = "Down! %d..." % int(ceil(lp.down_t))
		else:
			sleep_l.text = ""
	_party_t += delta
	if _party_t > 0.5:
		_party_t = 0.0
		_refresh_party()
		_refresh_buffs()

func _info_line(lp) -> String:
	var z = lp.zone()
	if z is Overworld and lp.target_tile.x > -99999:
		return (z as Overworld).farm.crop_info(lp.target_tile)
	if lp.target_obj and is_instance_valid(lp.target_obj) and lp.target_obj is ResourceNode:
		var r := ResourceNode.info(lp.target_obj.sub)
		var tier := int(r.get("tier", 0))
		var held: Dictionary = lp.held_item()
		var ht := int(Items.def(held.get("id", "")).get("tool", {}).get("tier", 0))
		if tier > ht and r.get("tool", "") in ["pick", "axe"]:
			return "%s · needs a %s %s" % [lp.target_obj.display(), Items.TOOL_TIERS[tier], "pickaxe" if r["tool"] == "pick" else "axe"]
		return lp.target_obj.display()
	return ""

func _refresh_money() -> void:
	money_l.text = "%d coins" % Game.money()

func refresh_hotbar() -> void:
	var lp = Game.local_player
	for i in 10:
		var s: ItemSlot = hot_slots[i]
		s.set_item(Game.inv.get_slot(i))
		s.selected = lp != null and lp.hot_index == i
		s.queue_redraw()
	_refresh_money()

func _refresh_buffs() -> void:
	for c in buffs_box.get_children():
		c.queue_free()
	for b in Game.buffs:
		var l := UITheme.label("%s %ds" % [ItemSlot._buff_label({"type": b, "dur": 0}).get_slice(" (", 0), int(Game.buffs[b]["t"])], 13, UITheme.GOOD)
		buffs_box.add_child(l)

func _refresh_party() -> void:
	for c in party.get_children():
		c.queue_free()
	if Net.peers.size() <= 1:
		return
	for id in Net.peers:
		if id == Net.my_id():
			continue
		var p: Dictionary = Net.peers[id]
		var zid: String = p.get("zone", "over")
		var where := "Surface" if zid == "over" else ("Farmhouse" if zid == "home" else "Floor %d" % Zones.floor_of(zid))
		var status := " ♥%d" % int(p.get("hp", 100))
		if p.get("down", false):
			status = " DOWN!"
		elif p.get("sleep", false):
			status = " zzz"
		var l := UITheme.label("%s — %s%s" % [p["name"], where, status], 15, p.get("look", {}).get("shirt", Color.WHITE).lightened(0.45), true)
		party.add_child(l)

func toast(text: String, col: Color = Color.WHITE) -> void:
	var l := UITheme.label(text, 19, col, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(700, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toasts.add_child(l)
	while toasts.get_child_count() > 5:
		toasts.get_child(0).queue_free()
		toasts.remove_child(toasts.get_child(0))
	var tw := l.create_tween()
	tw.tween_interval(4.0)
	tw.tween_property(l, "modulate:a", 0.0, 1.0)
	tw.tween_callback(l.queue_free)

func pickup_note(it: Dictionary, n: int) -> void:
	var id: String = it["id"]
	var nm := Items.display_name(it)
	if _note_items.has(id) and is_instance_valid(_note_items[id]["l"]):
		var e: Dictionary = _note_items[id]
		e["n"] = int(e["n"]) + n
		e["l"].get_child(1).text = "+%d %s" % [e["n"], nm]
		e["t"].kill()
		e["l"].modulate.a = 1.0
		e["t"] = _fade_note(e["l"])
		return
	var h := HBoxContainer.new()
	var icon := ItemSlot.new(30)
	icon.set_item(Items.make(id))
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(icon)
	var l := UITheme.label("+%d %s" % [n, nm], 17, UITheme.TEXT, true)
	h.add_child(l)
	notes.add_child(h)
	_note_items[id] = {"l": h, "n": n, "t": _fade_note(h)}
	Sfx.play("pickup", -10.0)

func _fade_note(h: Control) -> Tween:
	var tw := h.create_tween()
	tw.tween_interval(2.5)
	tw.tween_property(h, "modulate:a", 0.0, 0.8)
	tw.tween_callback(h.queue_free)
	return tw

func big_text(text: String, col: Color = UITheme.ACCENT, dur: float = 2.5) -> void:
	center_l.text = text
	center_l.add_theme_color_override("font_color", col)
	var tw := center_l.create_tween()
	center_l.modulate.a = 0.0
	tw.tween_property(center_l, "modulate:a", 1.0, 0.4)
	tw.tween_interval(dur)
	tw.tween_property(center_l, "modulate:a", 0.0, 0.8)

func fade_to(a: float, dur: float = 0.35) -> Tween:
	var tw := fade.create_tween()
	tw.tween_property(fade, "color:a", a, dur)
	return tw
