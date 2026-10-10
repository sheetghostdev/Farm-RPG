extends Node
## Scene root: owns the 3D world, camera, environment, HUD, menus and windows,
## and drives the flow of starting, joining, saving and leaving a world.

var world_root: Node3D
var env: EnvController
var cam: CameraRig
var hud: HUD
var ui: UIRoot
var menu: MainMenu
var save_path := ""
var _autosave_t := 0.0
var _tester: AutoTest

func _ready() -> void:
	Game.main = self
	get_tree().root.theme = UITheme.get_theme()
	world_root = Node3D.new()
	world_root.name = "World"
	add_child(world_root)
	Zones.world_root = world_root
	env = EnvController.new()
	add_child(env)
	cam = CameraRig.new()
	add_child(cam)
	hud = HUD.new()
	add_child(hud)
	ui = UIRoot.new()
	add_child(ui)
	hud.attach_tooltip(ui.top)
	menu = MainMenu.new()
	add_child(menu)
	Game.day_started.connect(_on_day_started)
	Net.connect_failed.connect(func(r): menu.show_error(r); menu.visible = true)
	if Game.autotest != "":
		menu.visible = false
		_tester = AutoTest.new()
		add_child(_tester)
		_tester.run(Game.autotest)
	else:
		menu.open()
		Sfx.set_music("title")

# ------------------------------------------------------------------ world lifecycle

func start_new_world(world_name: String, seed_value: int, opts: Dictionary, host: bool, port: int) -> String:
	var err := ""
	if host:
		err = Net.host(port)
		if err != "":
			return err
	else:
		Net.start_offline()
	Game.world = Game.new_world_state(world_name, seed_value, opts)
	Game.tod = float(Game.world["tod"])
	Zones.overworld_gen()
	Net.server.init_new_world()
	Net.server.town_logic.init_town()
	save_path = _path_for(world_name)
	_begin_host_world()
	Net.server.quest_logic.new_day(1)
	Net.server.quest_logic._publish()
	return ""

func load_world(path: String, host: bool, port: int) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return "Couldn't open that save."
	var data = str_to_var(f.get_as_text())
	if not (data is Dictionary) or not data.has("seed"):
		return "That save file looks damaged."
	if host:
		var err := Net.host(port)
		if err != "":
			return err
	else:
		Net.start_offline()
	Game.world = data
	Game.tod = float(Game.world.get("tod", 0.0))
	save_path = path
	_begin_host_world()
	return ""

func _begin_host_world() -> void:
	Net.register_self()
	var nm: String = Game.profile["name"]
	var cd: Dictionary = Game.world["players"].get(nm, {})
	if cd.is_empty():
		cd = Game.default_character(nm, Game.profile["look"])
		Game.world["players"][nm] = cd
	cd["look"] = Game.profile["look"]
	_enter_world(cd)

func begin_world_as_client(char_data: Dictionary) -> void:
	save_path = ""
	_enter_world(char_data)

func _enter_world(char_data: Dictionary) -> void:
	menu.visible = false
	hud.fade.color.a = 1.0
	Game.load_character(char_data)
	Zones.clear_all()
	var over := Zones.ensure_zone("over") as Overworld
	var zid: String = char_data.get("zone", "over")
	var pos = char_data.get("pos", null)
	if zid != "over" and zid != "home":
		zid = "over"
		pos = null
	if pos == null or not char_data.get("spawned", false):
		pos = over.spawn_point("")
		zid = "over"
	char_data["spawned"] = true
	Game.running = true
	var info := {"name": Game.profile["name"], "look": Game.profile["look"]}
	Zones.spawn_local_player(info, zid, pos)
	for id in Net.peers:
		if id != Net.my_id():
			Zones.spawn_remote_player(id, Net.peers[id])
	cam.target = Game.local_player
	cam.snap()
	hud.visible = true
	hud.refresh_hotbar()
	hud.fade_to(0.0, 1.0)
	hud.big_text(Game.date_text(), UITheme.ACCENT, 2.0)
	Game.world_started.emit()

func leave_world() -> void:
	if Net.is_server():
		save_world()
	else:
		Net.push_my_data()
	Game.running = false
	Game.local_player = null
	ui.close_all()
	Zones.clear_all()
	Net.leave()
	hud.visible = false
	menu.open()
	Sfx.set_music("title")
	Sfx.set_ambience("none")

func on_disconnected() -> void:
	Game.running = false
	Game.local_player = null
	ui.close_all()
	Zones.clear_all()
	hud.visible = false
	menu.open()
	menu.show_error("Lost connection to the host.")

func _path_for(world_name: String) -> String:
	var safe := ""
	for ch in world_name.to_lower():
		safe += ch if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") else "_"
	DirAccess.make_dir_recursive_absolute("user://worlds")
	return "user://worlds/%s.hearth" % safe

func save_world() -> void:
	if not Net.is_server() or save_path == "" or Game.world.is_empty():
		return
	Net.push_my_data()
	Game.world["tod"] = Game.tod
	Game.world["saved_at"] = Time.get_datetime_string_from_system()
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f:
		f.store_string(var_to_str(Game.world))

func autosave() -> void:
	save_world()

func _process(delta: float) -> void:
	if Game.running and Net.is_server():
		_autosave_t += delta
		if _autosave_t > 180.0:
			_autosave_t = 0.0
			save_world()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and Game.running:
		if Net.is_server():
			save_world()

# ------------------------------------------------------------------ queries used by gameplay code

func windows_open() -> bool:
	return ui.any_open()

func ui_blocking() -> bool:
	return ui.any_open() or ui.chat_focused() or menu.visible

func mouse_over_ui() -> bool:
	return ui.mouse_over()

func is_time_paused() -> bool:
	return ui.paused

func slot_clicked(slot: ItemSlot, button: int) -> void:
	ui.slot_clicked(slot, button)

# ------------------------------------------------------------------ events

func on_zone_changed(z: Zone) -> void:
	env.set_zone(z)
	cam.set_zone_style(z.underground(), z.kind == "home")
	cam.snap()
	hud.zone_l.text = z.display_name()

func _on_day_started(d: int) -> void:
	for z in Zones.zones.values():
		z.on_new_day()
	var lp = Game.local_player
	if lp:
		if lp.sleeping:
			lp.wake_up()
			lp.hp = lp.max_hp()
			hud.fade.color.a = 1.0
			hud.fade_to(0.0, 1.5)
		Game.me["water"] = Game.me.get("water", 20)
	hud.big_text("%s\n%s" % [Game.date_text(), {"clear": "A clear day", "cloudy": "Clouds rolling in", "rain": "Rain today", "storm": "A storm is brewing", "fog": "Thick fog this morning", "snow": "Snow is falling"}.get(Game.weather(), "")], UITheme.ACCENT, 2.5)
	hud.refresh_hotbar()

func on_tell(kind: String, data: Dictionary) -> void:
	match kind:
		"toast":
			Game.toast.emit(data["text"], data.get("color", Color.WHITE))
		"sfx":
			Sfx.play(data["s"])
		"stat":
			Game.add_stat(data["k"], int(data.get("n", 1)))
		"revived":
			if Game.local_player:
				Game.local_player.revive(data.get("by", "A friend"))
		"buff":
			Game.add_buff(data["type"], float(data["mag"]), float(data["dur"]))
			if Game.local_player and float(data.get("heal", 0)) > 0:
				Game.local_player.hp = min(Game.local_player.max_hp(), Game.local_player.hp + float(data["heal"]))
			Game.say("%s shared a cordial with you." % data.get("from", "Someone"), Color("9ae68a"))
		"note":
			ui.show_note(int(data["i"]))
		_:
			ui.on_tell(kind, data)

func on_feature(f: Feature, player) -> void:
	match f.action:
		"enter_home":
			_transition(func(): Zones.travel_local("home", null, "door"))
			Sfx.play("door")
		"leave_home":
			_transition(func(): Zones.travel_local("over", null, "door"))
			Sfx.play("door")
		"enter_cave":
			ui.open_cave_menu()
		"ladder_up":
			var n := Zones.floor_of(player.zone_id)
			Sfx.play("stairs")
			if n <= 1:
				_transition(func(): Zones.travel_local("over", null, "cave"))
			else:
				_transition(func(): Zones.travel_local("cave_%d" % (n - 1), null, "down"))
		"stairs_down":
			var n2 := Zones.floor_of(player.zone_id)
			Sfx.play("stairs")
			_transition(func(): Zones.travel_local("cave_%d" % (n2 + 1), null, "up"))
		"waystone":
			Net.request("waystone", {"f": Zones.floor_of(player.zone_id)})
			ui.open_cave_menu(true)
		"ship_bin":
			ui.open_shipping()
		"well":
			Game.say("Fill your watering can here (use it on the well).", UITheme.TEXT)
		"chronicle":
			ui.open_journal("Chronicle")
		"sign":
			ui.show_message(f.args.get("text", ""))
		"soak":
			if player.hp < player.max_hp():
				player.hp = player.max_hp()
			Game.add_buff("regen", 0.3, 120.0)
			Game.say("The warm water soaks the aches away.", Color("ffd0b0"))
			Sfx.play("splash")
		"npc", "board", "shop", "project":
			ui.on_feature(f)
		_:
			ui.on_feature(f)

func _transition(cb: Callable) -> void:
	var tw := hud.fade_to(1.0, 0.25)
	tw.tween_callback(cb)
	tw.tween_property(hud.fade, "color:a", 0.0, 0.45)

func travel_to_floor(n: int) -> void:
	_transition(func(): Zones.travel_local("cave_%d" % n, null, "up"))

## Out of health with nobody to help: wake up at home with lighter pockets.
func pass_out() -> void:
	var lp = Game.local_player
	if lp == null:
		return
	var zid: String = lp.zone_id
	var lost := _lose_items()
	Net.request("passed_out", {"z": zid})
	Game.add_stat("times_carried_home")
	var tw := hud.fade_to(1.0, 0.8)
	tw.tween_callback(func():
		Zones.travel_local("home", null, "bed")
		lp.hp = lp.max_hp() * 0.5
		lp.downed = false
		Game.tod = min(Game.DAY_MINUTES - 1.0, Game.tod + 120.0) if Net.is_server() else Game.tod
		var msg := "You wake up at home. Someone found you and carried you back."
		if lost != "":
			msg += "\nLost along the way: " + lost
		ui.show_message(msg))
	tw.tween_property(hud.fade, "color:a", 0.0, 1.2)

func _lose_items() -> String:
	var mode := int(Game.world["settings"].get("loss", 1))
	if mode == 0:
		return ""
	var frac := 0.25 if mode == 1 else 0.6
	var lost: Array = []
	for i in Game.inv.capacity:
		var s: Dictionary = Game.inv.get_slot(i)
		if s.is_empty():
			continue
		var c := Items.cat_of(s["id"])
		if c in ["tool", "weapon", "gear", "quest"]:
			continue
		if c in ["ore", "material", "mineral", "gem", "monster", "fish", "forage", "mushroom", "bar"] and randf() < 0.7:
			var n := int(ceil(int(s["n"]) * frac * randf_range(0.5, 1.0)))
			if n > 0:
				Game.inv.take_at(i, n)
				lost.append("%d %s" % [n, Items.def(s["id"])["name"]])
	Game.inventory_changed.emit()
	return ", ".join(PackedStringArray(lost.slice(0, 6))) + ("..." if lost.size() > 6 else "")

func escape_to_surface() -> void:
	Sfx.play("magic")
	_transition(func(): Zones.travel_local("over", null, "cave"))

# ------------------------------------------------------------------ window shortcuts used by world objects

func open_chest(o) -> void:
	ui.open_chest(o)

func open_craft(kind: String, o = null) -> void:
	ui.open_craft(kind, o)

func open_furnace(o) -> void:
	ui.open_furnace(o)

func open_kettle(o) -> void:
	ui.open_kettle(o)

func open_cook(o, campfire: bool) -> void:
	ui.open_cook(o, campfire)
