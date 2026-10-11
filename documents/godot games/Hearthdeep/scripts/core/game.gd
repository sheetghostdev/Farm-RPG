extends Node
## World state, clock, seasons, weather, shared knowledge and the chronicle.
## The server owns the authoritative copy of `world`; every peer applies the same
## stream of change dictionaries through apply_change().

signal world_started
signal day_started(day: int)
signal changed(kind: String, data: Dictionary)
signal toast(text: String, color: Color)
signal money_changed(value: int)
signal inventory_changed
signal stats_changed
signal chronicle_added(entry: Dictionary)

const MIN_PER_SEC := 1.0 / 0.7          # game minutes per real second
const DAY_MINUTES := 1440.0
const NIGHT_START := 840.0              # 20:00 (tod counts from 06:00)
const SKILLS := ["farming", "foraging", "fishing", "mining", "combat", "cooking"]
const SKILL_NAMES := {"farming": "Farming", "foraging": "Foraging", "fishing": "Fishing", "mining": "Mining", "combat": "Combat", "cooking": "Brewing & Cooking"}
const BAG_START := 30

var world := {}
var running := false
var tod := 0.0
var time_mult := 1.0
var main: Node = null
var local_player: Node3D = null
var me := {}                # local character data
var profile := {"name": "Wanderer", "look": {}}
var inv: Inventory
var buffs := {}             # local buffs: type -> {"mag": float, "t": float}
var _sync_t := 0.0
var _push_t := 0.0
var autotest := ""
var day_processing := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	inv = Inventory.new()
	_setup_input()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--autotest="):
			autotest = a.substr(11)
	_load_profile()

# ------------------------------------------------------------------ input

func _key(action: String, keys: Array, mouse: Array = [], joy: Array = []) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(action, e)
	for m in mouse:
		var e := InputEventMouseButton.new()
		e.button_index = m
		InputMap.action_add_event(action, e)
	for j in joy:
		var e := InputEventJoypadButton.new()
		e.button_index = j
		InputMap.action_add_event(action, e)

func _axis(action: String, axis: int, value: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = value
	InputMap.action_add_event(action, e)

func _setup_input() -> void:
	_key("move_up", [KEY_W, KEY_UP])
	_key("move_down", [KEY_S, KEY_DOWN])
	_key("move_left", [KEY_A, KEY_LEFT])
	_key("move_right", [KEY_D, KEY_RIGHT])
	_axis("move_up", JOY_AXIS_LEFT_Y, -1.0)
	_axis("move_down", JOY_AXIS_LEFT_Y, 1.0)
	_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_key("use", [], [MOUSE_BUTTON_LEFT], [JOY_BUTTON_X])
	_key("interact", [KEY_E, KEY_F], [MOUSE_BUTTON_RIGHT], [JOY_BUTTON_A])
	_key("dodge", [KEY_SPACE], [], [JOY_BUTTON_B])
	_key("walk", [KEY_SHIFT])
	_key("inventory", [KEY_TAB, KEY_I], [], [JOY_BUTTON_Y])
	_key("map", [KEY_M], [], [JOY_BUTTON_BACK])
	_key("journal", [KEY_J])
	_key("craft", [KEY_C])
	_key("cam_left", [KEY_Q], [], [JOY_BUTTON_LEFT_SHOULDER])
	_key("cam_right", [KEY_R], [], [JOY_BUTTON_RIGHT_SHOULDER])
	_key("rotate_place", [KEY_T])
	_key("pause", [KEY_ESCAPE], [], [JOY_BUTTON_START])
	_key("chat", [KEY_ENTER, KEY_KP_ENTER])
	_key("drop", [KEY_G])
	_key("hot_next", [], [MOUSE_BUTTON_WHEEL_DOWN])
	_key("hot_prev", [], [MOUSE_BUTTON_WHEEL_UP])
	_key("zoom_in", [KEY_EQUAL, KEY_KP_ADD])
	_key("zoom_out", [KEY_MINUS, KEY_KP_SUBTRACT])
	for i in 10:
		_key("hot_%d" % i, [KEY_1 + i if i < 9 else KEY_0])

# ------------------------------------------------------------------ profile

func _load_profile() -> void:
	var f := FileAccess.open("user://profile.cfg", FileAccess.READ)
	if f:
		var v = str_to_var(f.get_as_text())
		if v is Dictionary:
			profile = v
	if profile.get("look", {}).is_empty():
		var r := RandomNumberGenerator.new()
		r.randomize()
		profile["look"] = Doll.random_look(r)
		profile["look"]["hat"] = -1
		profile["name"] = ["Wren", "Juniper", "Rowan", "Sage", "Ash", "Robin", "Fern", "Hollis", "Quinn", "Ellis"][r.randi() % 10]

func save_profile() -> void:
	var f := FileAccess.open("user://profile.cfg", FileAccess.WRITE)
	if f:
		f.store_string(var_to_str(profile))

# ------------------------------------------------------------------ world creation

static func seed_from_text(t: String) -> int:
	t = t.strip_edges()
	if t.is_valid_int():
		return abs(int(t)) % 2147483647
	if t == "":
		return randi() % 2147483647
	return abs(t.hash()) % 2147483647

func new_world_state(world_name: String, seed_value: int, opts: Dictionary) -> Dictionary:
	return {
		"version": 1,
		"name": world_name,
		"seed": seed_value,
		"settings": {"season_len": int(opts.get("season_len", 14)), "loss": int(opts.get("loss", 1)), "time_scale": float(opts.get("time_scale", 1.0))},
		"day": 1,
		"tod": 60.0,
		"money": 500,
		"farm": {"tiles": {}, "level": 0},
		"objects": {},
		"next_oid": 1,
		"removed": {},
		"town": {},
		"quests": {"active": [], "done": [], "next_id": 1, "board_day": 0},
		"know": {"items": {}, "fish": {}, "places": {}, "recipes": {}, "deepest": 0, "waystones": [], "notes": [], "people": {}},
		"chronicle": [],
		"explored": PackedByteArray(),
		"players": {},
		"shipping": [],
		"flags": {},
		"created": Time.get_datetime_string_from_system(),
	}

func rng_for(salt: String, a: int = 0, b: int = 0) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash_ints(int(world.get("seed", 1)), salt.hash(), a, b)
	return r

static func hash_ints(a: int, b: int, c: int = 0, d: int = 0) -> int:
	var h := 2166136261
	for v in [a, b, c, d]:
		h = (h ^ (v & 0xffffffff)) * 16777619
		h = h & 0xffffffffffff
		h = h ^ (h >> 13)
	return h & 0x7fffffffffff

# ------------------------------------------------------------------ clock

func day() -> int:
	return int(world.get("day", 1))

func season_len() -> int:
	return int(world.get("settings", {}).get("season_len", 14))

func season() -> int:
	return int((day() - 1) / season_len()) % 4

func year() -> int:
	return int((day() - 1) / (season_len() * 4)) + 1

func day_of_season() -> int:
	return (day() - 1) % season_len() + 1

func clock_minutes() -> int:
	return int(360.0 + tod) % 1440

func clock_text() -> String:
	var m := clock_minutes()
	var hh := int(m / 60)
	var mm := int(m % 60) / 10 * 10
	var ampm := "am" if hh < 12 else "pm"
	var h12 := hh % 12
	if h12 == 0:
		h12 = 12
	return "%d:%02d %s" % [h12, mm, ampm]

func date_text() -> String:
	return "%s %d, Year %d" % [Items.season_name(season()), day_of_season(), year()]

func is_night() -> bool:
	return tod >= NIGHT_START - 30.0

## 0 at deep night, 1 at full day.
func daylight() -> float:
	var m := float(clock_minutes())
	if m < 300.0:
		return 0.0
	if m < 420.0:
		return smoothstep(300.0, 420.0, m)
	if m < 1080.0:
		return 1.0
	if m < 1230.0:
		return 1.0 - smoothstep(1080.0, 1230.0, m)
	return 0.0

func weather() -> String:
	return weather_for_day(day())

func weather_for_day(d: int) -> String:
	if d <= 1:
		return "clear"
	var s := int((d - 1) / season_len()) % 4
	var r := rng_for("weather", d)
	var x := r.randf()
	match s:
		0:
			if x < 0.28: return "rain"
			if x < 0.36: return "fog"
			if x < 0.5: return "cloudy"
		1:
			if x < 0.08: return "storm"
			if x < 0.2: return "rain"
			if x < 0.3: return "cloudy"
		2:
			if x < 0.24: return "rain"
			if x < 0.4: return "fog"
			if x < 0.55: return "cloudy"
		3:
			if x < 0.42: return "snow"
			if x < 0.55: return "cloudy"
			if x < 0.62: return "fog"
	return "clear"

func is_raining() -> bool:
	var w := weather()
	return w == "rain" or w == "storm"

func total_minutes() -> float:
	return (day() - 1) * DAY_MINUTES + tod

# ------------------------------------------------------------------ main loop

func _process(delta: float) -> void:
	if not running:
		return
	var scale_v := float(world.get("settings", {}).get("time_scale", 1.0))
	var paused_ui := false
	if multiplayer.multiplayer_peer is OfflineMultiplayerPeer and main and main.has_method("is_time_paused"):
		paused_ui = main.is_time_paused()
	if not paused_ui:
		tod += delta * MIN_PER_SEC * scale_v * time_mult
	if Net.is_server():
		time_mult = 45.0 if Net.everyone_sleeping() else 1.0
		if tod >= DAY_MINUTES and not day_processing:
			day_processing = true
			Net.server.start_new_day()
			day_processing = false
		_sync_t += delta
		if _sync_t > 2.0:
			_sync_t = 0.0
			Net.broadcast_time()
	else:
		tod = min(tod, DAY_MINUTES - 0.01)
	_tick_buffs(delta)
	_push_t += delta
	if _push_t > 15.0:
		_push_t = 0.0
		Net.push_my_data()

# ------------------------------------------------------------------ local character

func default_character(nm: String, look: Dictionary) -> Dictionary:
	var slots: Array = []
	slots.resize(42)
	for i in slots.size():
		slots[i] = {}
	var start := [Items.make("hoe_0"), Items.make("can_0"), Items.make("axe_0"), Items.make("pick_0"), Items.make("sword_0"),
		Items.make("rod_0"), Items.make("turnip_seeds", 12), Items.make("potato_seeds", 6), Items.make("campfire_bread", 5), Items.make("worm", 10)]
	for i in start.size():
		slots[i] = start[i]
	slots[10] = Items.make("escape_rope", 3)
	return {"name": nm, "look": look, "inv": slots, "bag": BAG_START,
		"equip": {"hat": {}, "boots": {}, "t1": {}, "t2": {}}, "hp": 100.0,
		"skills": {}, "stats": {}, "zone": "over", "pos": null, "spawned": false}

func load_character(data: Dictionary) -> void:
	me = data
	inv.load_from(me["inv"], int(me.get("bag", BAG_START)))
	inventory_changed.emit()
	stats_changed.emit()

func character_snapshot() -> Dictionary:
	me["inv"] = inv.slots.duplicate(true)
	me["bag"] = inv.capacity
	if local_player:
		me["hp"] = local_player.hp
		me["zone"] = local_player.zone_id
		me["pos"] = local_player.global_position
	return me.duplicate(true)

func skill_level(skill: String, data: Dictionary = {}) -> int:
	var d := data if not data.is_empty() else me
	var xp := float(d.get("skills", {}).get(skill, 0))
	return min(10, int(sqrt(xp / 30.0)))

func add_xp(skill: String, amount: float) -> void:
	if me.is_empty():
		return
	var before := skill_level(skill)
	if not me.has("skills"):
		me["skills"] = {}
	me["skills"][skill] = float(me["skills"].get(skill, 0)) + amount
	var after := skill_level(skill)
	if after > before:
		toast.emit("%s improved to %d" % [SKILL_NAMES[skill], after], Color("ffe08a"))
		Sfx.play("levelup")
	stats_changed.emit()

func add_stat(stat: String, amount: int = 1) -> void:
	if me.is_empty():
		return
	if not me.has("stats"):
		me["stats"] = {}
	me["stats"][stat] = int(me["stats"].get(stat, 0)) + amount

func stat(stat_name: String, data: Dictionary = {}) -> int:
	var d := data if not data.is_empty() else me
	return int(d.get("stats", {}).get(stat_name, 0))

## Equipment traits from gear + the held item.
func active_traits() -> Array:
	var out: Array = []
	if me.is_empty():
		return out
	for slot in me.get("equip", {}):
		var it: Dictionary = me["equip"][slot]
		if not it.is_empty():
			out.append_array(Items.item_traits(it))
	if local_player:
		var held: Dictionary = local_player.held_item()
		if not held.is_empty() and (Items.def(held["id"]).has("weapon") or Items.def(held["id"]).has("tool")):
			out.append_array(Items.item_traits(held))
	return out

func has_trait(t: String) -> bool:
	return active_traits().has(t)

func trait_count(t: String) -> int:
	return active_traits().count(t)

## Grant items to the local inventory (called after the server approves an action).
func local_grant(items: Array, quiet: bool = false) -> void:
	for it in items:
		var left := inv.add(it)
		var got := int(it["n"]) - left
		if got > 0:
			if not quiet and main:
				main.hud.pickup_note(it, got)
			discover_item(it["id"])
			add_stat("items_gathered", got)
		if left > 0:
			var rest: Dictionary = it.duplicate(true)
			rest["n"] = left
			if local_player:
				Net.request("drop_item", {"item": rest, "zone": local_player.zone_id, "pos": local_player.global_position + Vector3(0, 0.5, 0)})
			toast.emit("Your pack is full!", Color("ff9a7a"))
	inventory_changed.emit()

# ------------------------------------------------------------------ buffs

func add_buff(type: String, mag: float, dur: float) -> void:
	var cur: Dictionary = buffs.get(type, {})
	if cur.is_empty() or float(cur["mag"]) <= mag:
		buffs[type] = {"mag": mag, "t": dur, "max": dur}
	else:
		cur["t"] = max(float(cur["t"]), dur)
	stats_changed.emit()

func buff(type: String) -> float:
	if buffs.has(type):
		return float(buffs[type]["mag"])
	return 0.0

func _tick_buffs(delta: float) -> void:
	var gone := []
	for k in buffs:
		buffs[k]["t"] = float(buffs[k]["t"]) - delta
		if float(buffs[k]["t"]) <= 0.0:
			gone.append(k)
	for k in gone:
		buffs.erase(k)
	if not gone.is_empty():
		stats_changed.emit()

# ------------------------------------------------------------------ knowledge

func is_known(id: String) -> bool:
	if Items.def(id).get("known", false):
		return true
	return bool(world.get("know", {}).get("items", {}).get(id, {}).get("known", false))

func is_seen(id: String) -> bool:
	return world.get("know", {}).get("items", {}).has(id)

func discover_item(id: String) -> void:
	if not is_seen(id):
		Net.request("know_item", {"id": id, "by": profile["name"]})

func learn_item(id: String, how: String = "") -> void:
	if not is_known(id):
		Net.request("learn_item", {"id": id, "by": profile["name"], "how": how})

func knows_recipe(id: String) -> bool:
	return world.get("know", {}).get("recipes", {}).has(id)

# ------------------------------------------------------------------ change application

func apply_change(ch: Dictionary) -> void:
	var t: String = ch.get("t", "")
	match t:
		"money":
			world["money"] = int(ch["v"])
			money_changed.emit(world["money"])
		"time":
			if not Net.is_server():
				var nd := int(ch["day"])
				if nd != day():
					pass
				tod = float(ch["tod"])
		"tile":
			var k: Vector2i = ch["k"]
			if ch["v"] == null or (ch["v"] is Dictionary and ch["v"].is_empty()):
				world["farm"]["tiles"].erase(k)
			else:
				world["farm"]["tiles"][k] = ch["v"]
		"tiles":
			for k in ch["v"]:
				var tv = ch["v"][k]
				if tv == null or (tv is Dictionary and tv.is_empty()):
					world["farm"]["tiles"].erase(k)
				else:
					world["farm"]["tiles"][k] = tv
		"obj_add":
			world["objects"][ch["id"]] = ch["v"]
		"obj_del":
			world["objects"].erase(ch["id"])
		"obj_data":
			if world["objects"].has(ch["id"]):
				world["objects"][ch["id"]]["d"] = ch["v"]
		"removed":
			var z: String = ch["z"]
			if not world["removed"].has(z):
				world["removed"][z] = {}
			world["removed"][z][ch["id"]] = int(ch["day"])
		"know_item":
			var ki: Dictionary = world["know"]["items"]
			if not ki.has(ch["id"]):
				ki[ch["id"]] = {"day": day(), "by": ch["by"], "known": false}
		"learn_item":
			var ki2: Dictionary = world["know"]["items"]
			if not ki2.has(ch["id"]):
				ki2[ch["id"]] = {"day": day(), "by": ch["by"], "known": true}
			else:
				ki2[ch["id"]]["known"] = true
			toast.emit("Learned what %s is good for." % Items.def(ch["id"])["name"], Color("bfe3ff"))
		"recipe":
			world["know"]["recipes"][ch["id"]] = {"day": day(), "by": ch.get("by", ""), "ings": ch.get("ings", [])}
		"fish":
			world["know"]["fish"][ch["id"]] = ch["v"]
		"place":
			world["know"]["places"][ch["id"]] = ch["v"]
		"deepest":
			world["know"]["deepest"] = int(ch["v"])
		"waystone":
			if not world["know"]["waystones"].has(int(ch["v"])):
				world["know"]["waystones"].append(int(ch["v"]))
		"note":
			if not world["know"]["notes"].has(int(ch["v"])):
				world["know"]["notes"].append(int(ch["v"]))
		"explored":
			_apply_explored(ch["v"])
		"cave_seen":
			_apply_cave_seen(int(ch["f"]), ch["v"])
		"chronicle":
			world["chronicle"].append(ch["v"])
			chronicle_added.emit(ch["v"])
		"town":
			world["town"][ch["k"]] = ch["v"]
		"quests":
			world["quests"] = ch["v"]
		"shipping":
			world["shipping"] = ch["v"]
		"flag":
			world["flags"][ch["k"]] = ch["v"]
		"people":
			world["know"]["people"][ch["id"]] = ch["v"]
		"pins":
			world["know"]["pins"] = ch["v"]
		"farm_level":
			world["farm"]["level"] = int(ch["v"])
		"new_day":
			_apply_new_day(ch)
		"toast":
			toast.emit(ch["text"], ch.get("color", Color.WHITE))
		"world_sync":
			world = ch["v"]
	changed.emit(t, ch)

func _apply_new_day(ch: Dictionary) -> void:
	var p: Dictionary = ch["v"]
	for k in p:
		world[k] = p[k]
	tod = float(ch.get("tod", 0.0))
	buffs.clear()
	day_started.emit(day())

func _apply_explored(cells: PackedInt32Array) -> void:
	var ex: PackedByteArray = world["explored"]
	for c in cells:
		if c >= 0 and c < ex.size():
			ex[c] = 1
	world["explored"] = ex

func _apply_cave_seen(f: int, cells: PackedInt32Array) -> void:
	var know: Dictionary = world["know"]
	if not know.has("cave_seen"):
		know["cave_seen"] = {}
	var b = know["cave_seen"].get(f, null)
	if b == null:
		var dm := CaveGen.dims(f)
		b = PackedByteArray()
		b.resize(dm.x * dm.y)
		b.fill(0)
	var bytes: PackedByteArray = b
	for c in cells:
		if c >= 0 and c < bytes.size():
			bytes[c] = 1
	know["cave_seen"][f] = bytes

func chronicle(text: String, kind: String = "event") -> void:
	Net.request("chronicle", {"s": text, "k": kind})

func say(text: String, color: Color = Color.WHITE) -> void:
	toast.emit(text, color)

func money() -> int:
	return int(world.get("money", 0))
