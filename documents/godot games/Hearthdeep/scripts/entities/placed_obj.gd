class_name PlacedObj
extends WorldObj
## Anything a player placed: chests, workbenches, kettles, furnaces, torches,
## furniture, fruit trees, coops, animals...

const BLOCKING := {"chest": 0.45, "big_chest": 0.7, "workbench": 0.8, "furnace": 0.6, "kettle": 0.55, "stove": 0.55, "fence": 0.35,
	"lamp_post": 0.15, "beehive": 0.45, "display_stand": 0.35, "fish_tank": 0.65, "table": 0.7, "bed": 0.9, "bookshelf": 0.6,
	"bench": 0.6, "barrel": 0.4, "crate": 0.45, "scarecrow": 0.3, "coop": 2.0, "shed": 2.0, "fruit_tree": 0.3}
const CAPACITY := {"chest": 36, "big_chest": 72, "shed": 144}

var obj_type := ""
var item_id := ""
var light: OmniLight3D
var particles: CPUParticles3D
var extra_mi: MeshInstance3D
var animal: Node3D
var rot_steps := 0
var footprint := Vector2i(1, 1)
var _flicker_t := 0.0

func setup(id: String, o: Dictionary) -> void:
	oid = id
	kind = "placed"
	item_id = o["t"]
	var d := Items.def(item_id)
	obj_type = d.get("place", {}).get("obj", item_id)
	sub = obj_type
	footprint = d.get("place", {}).get("size", Vector2i(1, 1))
	rot_steps = int(o.get("r", 0))
	position = o["p"]
	rotation.y = rot_steps * PI / 2.0
	radius = max(0.5, max(footprint.x, footprint.y) * 0.5)
	_refresh_visual(o.get("d", {}))
	var b: float = BLOCKING.get(obj_type, 0.0)
	if b > 0.0:
		if obj_type in ["coop", "shed"]:
			var sz := Vector3(footprint.x - 0.3, 3.0, footprint.y - 0.6)
			add_box_blocker(sz, Vector3(0, 0, -0.2))
		elif obj_type in ["workbench", "table", "bed", "fish_tank", "bookshelf", "bench", "big_chest"]:
			var dims := {"workbench": Vector3(1.6, 1.0, 0.8), "table": Vector3(1.4, 0.8, 0.9), "bed": Vector3(1.1, 0.8, 2.1),
				"fish_tank": Vector3(1.3, 1.3, 0.6), "bookshelf": Vector3(1.2, 2.0, 0.4), "bench": Vector3(1.6, 0.8, 0.5), "big_chest": Vector3(1.4, 0.9, 0.75)}
			add_box_blocker(dims[obj_type])
		elif obj_type != "fruit_tree" or _tree_stage(o.get("d", {})) >= 3:
			add_blocker(b, 1.4)
	if obj_type == "chicken":
		animal = Animal.new()
		animal.setup(self, "chicken")
		get_parent().add_child.call_deferred(animal)

func data() -> Dictionary:
	return Game.world["objects"].get(oid, {}).get("d", {})

func on_data(d: Dictionary) -> void:
	_refresh_visual(d)

func _tree_stage(d: Dictionary) -> int:
	var planted := int(d.get("planted", Game.day()))
	return clamp(int((Game.day() - planted) / 3.5), 0, 4)

func _refresh_visual(d: Dictionary) -> void:
	var m: Mesh
	match obj_type:
		"furnace":
			m = ItemModels.placeable_mesh("furnace", 1 if d.has("bar") else 0)
		"kettle":
			var v := 0
			if d.has("res"):
				v = 1 if Game.total_minutes() < float(d.get("done", 0)) else 2
			m = ItemModels.placeable_mesh("kettle", v)
		"fruit_tree":
			var st := _tree_stage(d)
			m = ItemModels.fruit_tree_mesh(d.get("fruit", "apple"), st, int(d.get("fruit_n", 0)) > 0 and st >= 4)
		"coop":
			m = ItemModels.placeable_mesh("coop", 1 if int(d.get("feed", 0)) > 0 else 0)
		"rug", "banner", "flower_pot":
			m = ItemModels.placeable_mesh(obj_type, int(d.get("v", oid.hash() % 4)))
		"chicken":
			m = null
		_:
			m = ItemModels.placeable_mesh(obj_type)
	if m:
		set_mesh(m, 120.0)
		mesh_inst.rotation.y = 0.0
	_refresh_display(d)
	_refresh_light(d)

func _refresh_display(d: Dictionary) -> void:
	if extra_mi:
		extra_mi.queue_free()
		extra_mi = null
	if obj_type in ["display_stand", "fish_tank"] and d.has("item"):
		extra_mi = MeshInstance3D.new()
		extra_mi.mesh = ItemModels.drop_mesh(d["item"]["id"], 1.6)
		extra_mi.position = Vector3(0, 0.98, 0) if obj_type == "display_stand" else Vector3(0, 0.85, 0)
		add_child(extra_mi)
	if obj_type == "beehive" and _hive_ready(d):
		extra_mi = MeshInstance3D.new()
		extra_mi.mesh = ItemModels.drop_mesh("honeycomb", 1.0)
		extra_mi.position = Vector3(0, 1.55, 0)
		add_child(extra_mi)
	if obj_type == "coop" and int(d.get("eggs", 0)) > 0:
		extra_mi = MeshInstance3D.new()
		extra_mi.mesh = ItemModels.drop_mesh("egg", 1.0)
		extra_mi.position = Vector3(-0.8, 0.0, 1.2)
		add_child(extra_mi)

func _hive_ready(d: Dictionary) -> bool:
	return Game.day() - int(d.get("last", Game.day())) >= 3

func _refresh_light(d: Dictionary) -> void:
	var want := false
	var col := Color("ffb050")
	var rng := 6.0
	var energy := 1.2
	match obj_type:
		"torch":
			want = true
			rng = 8.0
			energy = 1.6
		"campfire":
			want = true
			rng = 9.0
			energy = 1.8
		"lamp_post":
			want = true
			col = Color("ffd38a")
			rng = 9.0
		"furnace":
			want = d.has("bar")
			energy = 0.9
		"kettle":
			want = d.has("res")
			col = Color("8aff9a")
			energy = 0.6
			rng = 3.0
	if want and light == null:
		light = OmniLight3D.new()
		light.position = Vector3(0, 1.3 if obj_type != "lamp_post" else 2.3, 0)
		add_child(light)
		if obj_type == "lamp_post":
			Zones.register_night_light(light)
	if light:
		light.visible = want
		light.light_color = col
		light.omni_range = rng
		light.light_energy = energy
	if obj_type in ["torch", "campfire"] and particles == null:
		particles = _fire(Vector3(0, 1.3, 0) if obj_type == "torch" else Vector3(0, 0.25, 0), 0.6 if obj_type == "torch" else 1.0)

func _fire(pos: Vector3, s: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.mesh = Meshes.particle_mesh(0.28 * s, true)
	p.amount = 14
	p.lifetime = 0.6
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.12 * s
	p.direction = Vector3.UP
	p.spread = 10.0
	p.initial_velocity_min = 0.8
	p.initial_velocity_max = 1.5
	p.gravity = Vector3(0, 1.0, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.85, 0.4, 0.9))
	g.add_point(0.5, Color(1.0, 0.45, 0.1, 0.7))
	g.set_color(g.get_point_count() - 1, Color(0.4, 0.1, 0.05, 0.0))
	p.color_ramp = g
	p.position = pos
	p.visibility_range_end = 70.0
	add_child(p)
	return p

func _process(delta: float) -> void:
	if light and light.visible and obj_type in ["torch", "campfire"]:
		_flicker_t += delta
		light.light_energy = (1.6 if obj_type == "torch" else 1.8) * (0.85 + 0.15 * sin(_flicker_t * 13.0) * sin(_flicker_t * 7.3))
	if obj_type == "kettle" and data().has("res") and int(_flicker_t) % 2 == 0:
		_flicker_t += delta

func prompt(player) -> String:
	var d := data()
	match obj_type:
		"chest", "big_chest":
			return "Open chest"
		"shed":
			return "Open shed storage"
		"workbench":
			return "Use workbench"
		"furnace":
			if d.has("bar"):
				return "Collect %s" % Items.def(d["bar"])["name"] if Game.total_minutes() >= float(d.get("done", 0)) else "Smelting... (%s)" % _eta(d)
			return "Load the furnace"
		"kettle":
			if d.has("res"):
				return ("Collect %s" % Items.def(d["res"])["name"]) if Game.total_minutes() >= float(d.get("done", 0)) else "Brewing... (%s)" % _eta(d)
			return "Brew something"
		"stove":
			return "Cook"
		"campfire":
			return "Cook over the fire"
		"bed":
			return "Sleep"
		"display_stand", "fish_tank":
			if d.has("item"):
				return "Take %s" % Items.display_name(d["item"])
			var held: Dictionary = player.held_item()
			if held.is_empty():
				return ""
			if obj_type == "fish_tank" and Items.cat_of(held["id"]) != "fish":
				return ""
			return "Display %s" % Items.display_name(held)
		"beehive":
			return "Collect honeycomb" if _hive_ready(d) else ""
		"fruit_tree":
			return "Pick %s" % Items.def(d.get("fruit", "apple"))["name"] if int(d.get("fruit_n", 0)) > 0 else ""
		"coop":
			if int(d.get("eggs", 0)) > 0:
				return "Collect eggs (%d)" % int(d["eggs"])
			if player.held_item().get("id", "") == "feed":
				return "Fill the trough"
			return "Coop (trough: %d feed)" % int(d.get("feed", 0))
	return ""

func _eta(d: Dictionary) -> String:
	var mins := int(float(d.get("done", 0)) - Game.total_minutes())
	if mins >= 60:
		return "%dh %02dm" % [mins / 60, mins % 60]
	return "%dm" % max(1, mins)

func interact(player) -> void:
	var d := data()
	var z := zone.zone_id
	match obj_type:
		"chest", "big_chest", "shed":
			Game.main.open_chest(self)
		"workbench":
			Game.main.open_craft("workbench", self)
		"furnace":
			if d.has("bar"):
				if Game.total_minutes() >= float(d.get("done", 0)):
					Net.request("station_collect", {"id": oid})
			else:
				Game.main.open_furnace(self)
		"kettle":
			if d.has("res"):
				if Game.total_minutes() >= float(d.get("done", 0)):
					Net.request("station_collect", {"id": oid})
			else:
				Game.main.open_kettle(self)
		"stove":
			Game.main.open_cook(self, false)
		"campfire":
			Game.main.open_cook(self, true)
		"bed":
			player.go_to_sleep(global_position)
		"display_stand", "fish_tank":
			if d.has("item"):
				Net.request("display_take", {"id": oid})
			else:
				var held: Dictionary = player.held_item()
				if not held.is_empty():
					var one: Dictionary = held.duplicate(true)
					one["n"] = 1
					Game.inv.take_at(player.hot_index, 1)
					Game.inventory_changed.emit()
					Net.request("display_set", {"id": oid, "item": one})
		"beehive":
			if _hive_ready(d):
				Net.request("station_collect", {"id": oid})
		"fruit_tree":
			if int(d.get("fruit_n", 0)) > 0:
				Net.request("station_collect", {"id": oid})
		"coop":
			if int(d.get("eggs", 0)) > 0:
				Net.request("station_collect", {"id": oid})
			elif player.held_item().get("id", "") == "feed":
				var n: int = min(10, Game.inv.count("feed"))
				Game.inv.remove("feed", n)
				Game.inventory_changed.emit()
				Net.request("coop_feed", {"id": oid, "n": n})

func accepts_tool(t: String) -> bool:
	return t in ["pick", "axe"]

func tool_hit(player, t: String, _tier: int, _power: float) -> void:
	if not accepts_tool(t):
		return
	if obj_type in ["chest", "big_chest", "shed"] and not data().get("items", []).is_empty():
		Game.say("Empty it first.", Color("ffb08a"))
		shake(0.03)
		return
	if obj_type in ["furnace", "kettle"] and (data().has("bar") or data().has("res")):
		Game.say("It's still working.", Color("ffb08a"))
		return
	shake(0.06)
	Net.request("pickup_obj", {"id": oid})

func is_bed() -> bool:
	return obj_type == "bed"

func vanish(fall: bool = false) -> void:
	if animal and is_instance_valid(animal):
		animal.queue_free()
	super.vanish(fall)
