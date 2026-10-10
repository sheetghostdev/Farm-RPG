class_name UIRoot
extends CanvasLayer
## Window manager: opens/closes windows, routes slot clicks, carries the item
## held on the cursor, and hosts chat and the pause menu.

var top: Control
var win_layer: Control
var current: UIWin = null
var hand := {}
var hand_icon: ItemSlot
var paused := false
var chat_box: VBoxContainer
var chat_input: LineEdit
var chat_log: VBoxContainer
var _refresh_queued := false

func _ready() -> void:
	layer = 10
	top = Control.new()
	top.set_anchors_preset(Control.PRESET_FULL_RECT)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.theme = UITheme.get_theme()
	add_child(top)
	win_layer = Control.new()
	win_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	win_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(win_layer)
	_build_chat()
	hand_icon = ItemSlot.new(48)
	hand_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hand_icon.visible = false
	hand_icon.z_index = 50
	top.add_child(hand_icon)
	Game.inventory_changed.connect(_queue_refresh)
	Game.changed.connect(_on_world_changed)
	Net.chat_received.connect(_on_chat)

func _build_chat() -> void:
	chat_box = VBoxContainer.new()
	chat_box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	chat_box.position = Vector2(16, -330)
	chat_box.size = Vector2(440, 200)
	chat_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(chat_box)
	chat_log = VBoxContainer.new()
	chat_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chat_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chat_log.alignment = BoxContainer.ALIGNMENT_END
	chat_box.add_child(chat_log)
	chat_input = LineEdit.new()
	chat_input.placeholder_text = "Say something... (Enter to send, Esc to cancel)"
	chat_input.visible = false
	chat_input.custom_minimum_size = Vector2(440, 34)
	chat_input.text_submitted.connect(_on_chat_submit)
	chat_box.add_child(chat_input)

# ------------------------------------------------------------------ state queries

func any_open() -> bool:
	return current != null

func chat_focused() -> bool:
	return chat_input.visible

func mouse_over() -> bool:
	if current == null:
		return false
	return current.get_global_rect().has_point(current.get_global_mouse_position())

# ------------------------------------------------------------------ input

func _unhandled_input(e: InputEvent) -> void:
	if not Game.running:
		return
	if chat_input.visible:
		if e.is_action_pressed("pause"):
			chat_input.visible = false
			chat_input.release_focus()
			get_viewport().set_input_as_handled()
		return
	if e.is_action_pressed("pause"):
		if current:
			close()
		else:
			open_pause()
		get_viewport().set_input_as_handled()
	elif e.is_action_pressed("inventory"):
		if current and current.kind == "inv":
			close()
		elif current == null:
			open_inventory()
		get_viewport().set_input_as_handled()
	elif e.is_action_pressed("map") and current == null:
		open_map()
		get_viewport().set_input_as_handled()
	elif e.is_action_pressed("journal") and current == null:
		open_journal()
		get_viewport().set_input_as_handled()
	elif e.is_action_pressed("craft") and current == null:
		open_craft("field", null)
		get_viewport().set_input_as_handled()
	elif e.is_action_pressed("chat") and current == null:
		chat_input.visible = true
		chat_input.text = ""
		chat_input.grab_focus()
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if not hand.is_empty():
		hand_icon.visible = true
		hand_icon.set_item(hand)
		hand_icon.global_position = hand_icon.get_global_mouse_position() - Vector2(24, 24)
	else:
		hand_icon.visible = false
	if _refresh_queued:
		_refresh_queued = false
		if current:
			current.refresh()
	if current and current.obj != null and Game.local_player:
		if not is_instance_valid(current.obj) or current.obj.global_position.distance_to(Game.local_player.global_position) > 5.0:
			close()

func _queue_refresh() -> void:
	_refresh_queued = true

func _on_world_changed(k: String, ch: Dictionary) -> void:
	if current == null:
		return
	match k:
		"obj_data":
			if current.obj and is_instance_valid(current.obj) and current.obj.oid == ch["id"]:
				_queue_refresh()
		"shipping", "money", "know_item", "learn_item", "recipe", "quests", "town", "new_day":
			_queue_refresh()

# ------------------------------------------------------------------ windows

func show_win(w: UIWin) -> void:
	close()
	current = w
	win_layer.add_child(w)
	w.closed.connect(close)
	w.reset_size()
	await get_tree().process_frame
	if is_instance_valid(w):
		var vs := top.get_viewport_rect().size
		w.position = ((vs - w.size) / 2.0).floor()
		w.position.y = max(10.0, w.position.y - 30.0)
	Sfx.play("ui_open", -8.0)

func close() -> void:
	if current == null:
		return
	if current.has_method("on_close"):
		current.on_close()
	if not hand.is_empty():
		var left := Game.inv.add(hand)
		if left > 0 and Game.local_player:
			var rest: Dictionary = hand.duplicate(true)
			rest["n"] = left
			Net.request("drop_item", {"item": rest, "zone": Game.local_player.zone_id, "pos": Game.local_player.global_position + Vector3(0, 0.8, 0)})
		hand = {}
		Game.inventory_changed.emit()
	var w := current
	current = null
	w.queue_free()
	Game.main.hud.show_tooltip("")
	Sfx.play("ui_close", -10.0)

func close_all() -> void:
	close()
	paused = false
	chat_input.visible = false

func open_inventory() -> void:
	show_win(InvWindow.new())

func open_chest(o) -> void:
	show_win(ChestWindow.new(o, false))

func open_shipping() -> void:
	show_win(ChestWindow.new(null, true))

func open_craft(k: String, o = null) -> void:
	var w := CraftWindow.new(o)
	if k == "field":
		w.title_l.text = "Field Crafting (supplies only — use a workbench for more)"
		w.filter = "supplies"
		w.refresh()
	show_win(w)

func open_furnace(o) -> void:
	show_win(FurnaceWindow.new(o))

func open_kettle(o) -> void:
	show_win(KettleWindow.new(o))

func open_cook(o, campfire: bool) -> void:
	show_win(CookWindow.new(o, campfire))

func open_map() -> void:
	show_win(MapWindow.new())

func open_journal(tab: String = "") -> void:
	show_win(JournalWindow.new(tab))

func open_pause() -> void:
	var w := UIWin.new("Paused", Vector2(360, 300))
	w.kind = "pause"
	if not Net.is_online():
		paused = true
	w.closed.connect(func(): paused = false)
	w.content.add_child(UITheme.button("Resume", close, 18))
	w.content.add_child(UITheme.button("Settings", open_settings, 18))
	if Net.is_server():
		w.content.add_child(UITheme.button("Save now", func():
			Game.main.save_world()
			Game.say("World saved.", UITheme.GOOD), 18))
	if Net.is_online() and Net.is_server():
		w.content.add_child(UITheme.label("Hosting on port %d · %d/6 players" % [Net.DEFAULT_PORT, Net.peers.size()], 14, UITheme.TEXT_DIM))
	w.content.add_child(UITheme.button("Save & quit to title" if Net.is_server() else "Leave world", func():
		close()
		Game.main.leave_world(), 18))
	w.content.add_child(UITheme.label("Controls: WASD move · Space dodge · LMB use · E interact\nTab pack · M map · J journal · C field craft · G drop · T rotate · Q/R camera", 13, UITheme.TEXT_DIM))
	show_win(w)

func open_settings() -> void:
	var w := UIWin.new("Settings", Vector2(420, 280))
	for bus in ["Master", "Music", "SFX", "Ambience"]:
		var row := HBoxContainer.new()
		var l := UITheme.label(bus, 16)
		l.custom_minimum_size = Vector2(110, 0)
		row.add_child(l)
		var sl := HSlider.new()
		sl.min_value = 0.0
		sl.max_value = 1.0
		sl.step = 0.05
		sl.custom_minimum_size = Vector2(240, 24)
		var idx := AudioServer.get_bus_index(bus)
		sl.value = db_to_linear(AudioServer.get_bus_volume_db(idx)) if idx >= 0 else 1.0
		var b: String = bus
		sl.value_changed.connect(func(v): Sfx.set_bus_volume(b, v))
		row.add_child(sl)
		w.content.add_child(row)
	var fs := CheckButton.new()
	fs.text = "Fullscreen"
	fs.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fs.toggled.connect(func(on): DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED))
	w.content.add_child(fs)
	show_win(w)

func show_message(text: String, title: String = "") -> void:
	var w := UIWin.new(title, Vector2(480, 160))
	w.kind = "msg"
	var r := UITheme.rich(text, 17)
	r.custom_minimum_size = Vector2(460, 0)
	w.content.add_child(r)
	w.content.add_child(UITheme.button("OK", close, 16))
	show_win(w)

func show_note(i: int) -> void:
	var t := Lore.note(i)
	show_message("[i]%s[/i]" % t["text"], t["title"])
	Net.request("found_note", {"i": i})

func open_cave_menu(from_waystone: bool = false) -> void:
	var w := UIWin.new("The Caves", Vector2(420, 200))
	w.kind = "cave"
	var deepest := int(Game.world["know"].get("deepest", 0))
	w.content.add_child(UITheme.label("Deepest floor reached: %d" % deepest if deepest > 0 else "Nobody has gone down yet.", 16, UITheme.TEXT_DIM))
	var g := GridContainer.new()
	g.columns = 4
	w.content.add_child(g)
	g.add_child(UITheme.button("Floor 1", func():
		close()
		Game.main.travel_to_floor(1), 16))
	var stones: Array = Game.world["know"].get("waystones", [])
	stones = stones.duplicate()
	stones.sort()
	for f in stones:
		var fl: int = f
		g.add_child(UITheme.button("Floor %d" % fl, func():
			close()
			Game.main.travel_to_floor(fl), 16))
	if from_waystone:
		w.content.add_child(UITheme.button("Return to the surface", func():
			close()
			Game.main.escape_to_surface(), 16))
	w.content.add_child(UITheme.label("Activate waystones (every 5 floors) to travel back to them.", 13, UITheme.TEXT_DIM))
	show_win(w)

func on_feature(f) -> void:
	TownUI.on_feature(self, f)

func on_tell(kind: String, data: Dictionary) -> void:
	TownUI.on_tell(self, kind, data)

# ------------------------------------------------------------------ slot clicks

func slot_clicked(slot: ItemSlot, button: int) -> void:
	var shift := Input.is_key_pressed(KEY_SHIFT)
	match slot.source:
		"inv":
			_click_inv(slot.index, button, shift)
		"equip":
			_click_equip(slot.index)
		"chest":
			if current is ChestWindow:
				var its: Array = current.items()
				if not hand.is_empty():
					Net.request("chest_put", {"id": current.obj.oid, "item": hand})
					hand = {}
				elif slot.index < its.size():
					var it: Dictionary = its[slot.index]
					var n := int(it["n"]) if button == MOUSE_BUTTON_LEFT else max(1, int(it["n"]) / 2)
					if Game.inv.can_add(Items.make(it["id"], n) if not it.has("d") else it):
						Net.request("chest_take", {"id": current.obj.oid, "idx": slot.index, "n": n, "expect": it["id"]})
					else:
						Game.say("No room in your pack.", UITheme.BAD)
		"ship":
			if not hand.is_empty():
				Net.request("ship_put", {"item": hand})
				hand = {}
			else:
				Net.request("ship_take", {"idx": slot.index})
		"kettle", "cookpot":
			if current and current.has_method("remove_ingredient"):
				current.remove_ingredient(slot.index)
		"shop":
			TownUI.shop_click(self, slot, button, shift)
		"gift":
			TownUI.gift_click(self, slot)
	_queue_refresh()
	Game.main.hud.refresh_hotbar()

func _click_inv(i: int, button: int, shift: bool) -> void:
	if i >= Game.inv.capacity:
		return
	var s: Dictionary = Game.inv.get_slot(i)
	# containers that take items with a plain click
	if current is KettleWindow or current is CookWindow:
		current.add_ingredient(i)
		return
	if current is ShopWindow and (shift or hand.is_empty()) and not s.is_empty():
		TownUI.sell_from_slot(self, i, button, shift)
		return
	if current is GiftWindow and not s.is_empty():
		current.pick(i)
		return
	if shift and not s.is_empty():
		if current is ChestWindow:
			var out := Game.inv.take_at(i, int(s["n"]))
			if current.shipping:
				Net.request("ship_put", {"item": out})
			else:
				Net.request("chest_put", {"id": current.obj.oid, "item": out})
			Sfx.play("place", -10.0)
		else:
			# swap between hotbar and pack
			var target_range := range(Inventory.HOTBAR, Game.inv.capacity) if i < Inventory.HOTBAR else range(0, Inventory.HOTBAR)
			for j in target_range:
				if Game.inv.get_slot(j).is_empty():
					Game.inv.set_slot(j, s)
					Game.inv.set_slot(i, {})
					break
		Game.inventory_changed.emit()
		return
	if button == MOUSE_BUTTON_RIGHT:
		if hand.is_empty() and not s.is_empty():
			var half: int = max(1, int(s["n"]) / 2)
			hand = Game.inv.take_at(i, half)
		elif not hand.is_empty():
			if s.is_empty():
				var one: Dictionary = hand.duplicate(true)
				one["n"] = 1
				Game.inv.set_slot(i, one)
				hand["n"] = int(hand["n"]) - 1
			elif Items.can_stack(s, hand) and int(s["n"]) < Items.stack_max(s["id"]):
				s["n"] = int(s["n"]) + 1
				hand["n"] = int(hand["n"]) - 1
			if int(hand.get("n", 0)) <= 0:
				hand = {}
		Game.inventory_changed.emit()
		return
	if hand.is_empty():
		if not s.is_empty():
			hand = s
			Game.inv.set_slot(i, {})
	elif s.is_empty():
		Game.inv.set_slot(i, hand)
		hand = {}
	elif Items.can_stack(s, hand):
		var room: int = Items.stack_max(s["id"]) - int(s["n"])
		var put: int = min(room, int(hand["n"]))
		s["n"] = int(s["n"]) + put
		hand["n"] = int(hand["n"]) - put
		if int(hand["n"]) <= 0:
			hand = {}
	else:
		Game.inv.set_slot(i, hand)
		hand = s
	Sfx.play("tick", -12.0)
	Game.inventory_changed.emit()

func _click_equip(idx: int) -> void:
	var key: String = InvWindow.EQUIP_SLOTS[idx]
	var want := "trinket" if key.begins_with("t") else key
	var eq: Dictionary = Game.me["equip"]
	var cur: Dictionary = eq.get(key, {})
	if not hand.is_empty():
		var g: Dictionary = Items.def(hand["id"]).get("gear", {})
		if g.get("slot", "") != want:
			Game.say("That doesn't go there.", UITheme.BAD)
			return
		eq[key] = hand
		hand = cur
		Sfx.play("place", -6.0)
	elif not cur.is_empty():
		hand = cur
		eq[key] = {}
	Game.stats_changed.emit()
	if Game.local_player:
		Game.local_player._refresh_hat()
	Game.inventory_changed.emit()

# ------------------------------------------------------------------ chat

func _on_chat_submit(t: String) -> void:
	chat_input.visible = false
	chat_input.release_focus()
	if t.strip_edges() != "":
		Net.send_chat(t)

func _on_chat(from_name: String, text: String, col: Color) -> void:
	var r := UITheme.rich("[color=#%s]%s:[/color] %s" % [UITheme.hex(col), from_name, text.replace("[", "(")], 16)
	r.custom_minimum_size = Vector2(440, 0)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chat_log.add_child(r)
	while chat_log.get_child_count() > 8:
		chat_log.get_child(0).queue_free()
		chat_log.remove_child(chat_log.get_child(0))
	var tw := r.create_tween()
	tw.tween_interval(12.0)
	tw.tween_property(r, "modulate:a", 0.0, 2.0)
	tw.tween_callback(r.queue_free)
	Sfx.play("chat", -8.0)
