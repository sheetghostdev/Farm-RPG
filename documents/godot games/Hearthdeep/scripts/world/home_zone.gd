class_name HomeZone
extends Zone
## The farmhouse interior. The room grows each time the farmhouse is renovated,
## the hearth keeps it warm (and cooks a proper meal), the windows follow the
## day and weather outside, and whatever the household places in here stays put.

const SIZES := [Vector2(11, 8), Vector2(15, 10), Vector2(19, 12)]
const WALL_H := 3.0
const WALL_T := 0.3
const DOOR_X := -1.6
const FLOOR_A := Color("b38250")
const FLOOR_B := Color("9c6c3f")
const PLASTER := Color("eddcbc")
const WAINSCOT := Color("8a5a36")
const BEAM := Color("6a4228")
const STONE := Color("a39b8e")
const CLOTH := [Color("b8483a"), Color("4f7aa8"), Color("6f9a4a"), Color("c8963e")]

var level := -1
var room := Vector2(11, 8)
var shell: Node3D
var _walls: Array = []        # [{"mi": MeshInstance3D, "panes": MeshInstance3D, "n": Vector3, "cut": bool}]
var _solids: Array = []       # Rect2 (local x/z) that block walking and placing
var _win_mat: StandardMaterial3D
var _fire_light: OmniLight3D
var _lamp_light: OmniLight3D
var _sun_lights: Array = []
var _fire: CPUParticles3D
var _t := 0.0

func _init() -> void:
	super._init()
	zone_id = "home"
	kind = "home"

func display_name() -> String:
	return "The Farmhouse"

func env_profile() -> String:
	return "home"

func ground_y(_x: float, _z: float) -> float:
	return origin.y

func _local(p: Vector3) -> Vector2:
	return Vector2(p.x - origin.x, p.z - origin.z)

func is_blocked(p: Vector3) -> bool:
	var l := _local(p)
	if abs(l.x) > room.x / 2.0 - 0.3 or abs(l.y) > room.y / 2.0 - 0.3:
		return true
	for r in _solids:
		if (r as Rect2).has_point(l):
			return true
	return false

func spawn_point(tag: String = "") -> Vector3:
	match tag:
		"door":
			return origin + Vector3(DOOR_X, 0.2, room.y / 2.0 - 1.3)
		"bed":
			for o in objs.values():
				if o is PlacedObj and o.obj_type == "bed":
					for side in [1.0, -1.0]:
						var p: Vector3 = o.global_position + o.global_transform.basis * Vector3(side * 1.2, 0.2, 0.2)
						if not is_blocked(p):
							return p
	return origin + Vector3(0, 0.2, 1.8)

static func farm_level() -> int:
	return clamp(int(Game.world.get("farm", {}).get("level", 0)), 0, SIZES.size() - 1)

# ------------------------------------------------------------------ build

func build() -> void:
	_build_shell()
	for oid in Game.world.get("objects", {}):
		var o: Dictionary = Game.world["objects"][oid]
		if o.get("z", "") == zone_id:
			_spawn_placed(oid, o)
	built = true

func _spawn_placed(oid: String, o: Dictionary) -> void:
	if objs.has(oid):
		return
	var po := PlacedObj.new()
	objects_root.add_child(po)
	po.setup(oid, o)
	register(po)

func _build_shell() -> void:
	level = farm_level()
	room = SIZES[level]
	if shell:
		shell.queue_free()
	for id in ["home_door", "hearth", "home_journal", "home_window_seat"]:
		if objs.has(id):
			remove_obj(id, false)
	_walls.clear()
	_solids.clear()
	_sun_lights.clear()
	shell = Node3D.new()
	shell.name = "Shell"
	add_child(shell)
	shell.position = origin
	_win_mat = StandardMaterial3D.new()
	_win_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_win_mat.albedo_color = Color(0.85, 0.93, 1.0)
	_build_collision()
	_build_floor()
	_build_walls()
	_build_hearth()
	_build_furnishings()
	_build_lights()
	_update_windows()

func _build_collision() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	shell.add_child(body)
	var w := room.x
	var d := room.y
	var boxes := [
		[Vector3(0, -0.25, 0), Vector3(w + 2, 0.5, d + 2)],
		[Vector3(0, WALL_H / 2.0, -d / 2.0 - WALL_T / 2.0), Vector3(w + 1, WALL_H, WALL_T)],
		[Vector3(0, WALL_H / 2.0, d / 2.0 + WALL_T / 2.0), Vector3(w + 1, WALL_H, WALL_T)],
		[Vector3(-w / 2.0 - WALL_T / 2.0, WALL_H / 2.0, 0), Vector3(WALL_T, WALL_H, d + 1)],
		[Vector3(w / 2.0 + WALL_T / 2.0, WALL_H / 2.0, 0), Vector3(WALL_T, WALL_H, d + 1)],
	]
	for b in boxes:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = b[1]
		cs.shape = bs
		cs.position = b[0]
		body.add_child(cs)

## Adds a solid rectangle (local coordinates) with a matching collider.
func _solid(center: Vector2, size: Vector2, h: float = 1.0) -> void:
	_solids.append(Rect2(center - size / 2.0, size))
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	shell.add_child(body)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(size.x, h, size.y)
	cs.shape = bs
	cs.position = Vector3(center.x, h / 2.0, center.y)
	body.add_child(cs)

func _build_floor() -> void:
	var mb := MeshBuilder.new(Game.hash_ints(int(Game.world.get("seed", 1)), 77, level))
	var w := room.x
	var d := room.y
	var strip := 0.5
	var rows := int(ceil(d / strip))
	for r in rows:
		var z0 := -d / 2.0 + r * strip
		var x := -w / 2.0
		var off := mb.rng.randf_range(0.4, 2.2)
		while x < w / 2.0:
			var len: float = min(off, w / 2.0 - x)
			off = mb.rng.randf_range(1.6, 3.2)
			var c: Color = FLOOR_A.lerp(FLOOR_B, mb.rng.randf()) * mb.rng.randf_range(0.95, 1.05)
			c.a = 1.0
			mb.box(Vector3(x + len / 2.0, -0.05, z0 + strip / 2.0), Vector3(len - 0.02, 0.1, strip - 0.03), c)
			x += len
	# dark gaps under the boards
	mb.box(Vector3(0, -0.13, 0), Vector3(w, 0.06, d), Color("3a2818"))
	# door mat
	mb.box(Vector3(DOOR_X, 0.015, d / 2.0 - 0.75), Vector3(1.5, 0.03, 0.9), Color("8a6a3a"))
	mb.box(Vector3(DOOR_X, 0.03, d / 2.0 - 0.75), Vector3(1.3, 0.02, 0.7), Color("a8844a"))
	Meshes.inst(mb.commit(), shell)

# ------------------------------------------------------------------ walls

## Each wall is built in its own frame: local +z points into the room and the
## inner face sits at z = 0. Walls nearest the camera get cut away at runtime.
func _build_walls() -> void:
	var w := room.x
	var d := room.y
	var nwin := 1 + level
	var sides := [
		{"c": Vector3(0, 0, -d / 2.0), "yaw": 0.0, "len": w, "n": Vector3(0, 0, -1), "side": "n"},
		{"c": Vector3(0, 0, d / 2.0), "yaw": PI, "len": w, "n": Vector3(0, 0, 1), "side": "s"},
		{"c": Vector3(-w / 2.0, 0, 0), "yaw": PI / 2.0, "len": d, "n": Vector3(-1, 0, 0), "side": "w"},
		{"c": Vector3(w / 2.0, 0, 0), "yaw": -PI / 2.0, "len": d, "n": Vector3(1, 0, 0), "side": "e"},
	]
	for sd in sides:
		var len: float = sd["len"]
		var windows: Array = []
		match sd["side"]:
			"n":
				# either side of the hearth
				for i in nwin:
					var x := 2.6 + i * 3.2
					if x < len / 2.0 - 1.0:
						windows.append(-x)
						windows.append(x)
			"s":
				# local x is mirrored on the south wall; keep clear of the door
				for x in [-2.8, 1.4, 4.4, -6.0, 7.0]:
					if abs(x - (-DOOR_X)) > 1.6 and abs(x) < len / 2.0 - 0.9 and windows.size() < 1 + nwin:
						windows.append(x)
			_:
				for i in nwin:
					var x2 := (i - (nwin - 1) / 2.0) * 3.0
					windows.append(x2)
		_build_wall(sd, windows)

func _build_wall(sd: Dictionary, windows: Array) -> void:
	var len: float = sd["len"]
	var mb := MeshBuilder.new(String(sd["side"]).hash() + level)
	var pm := MeshBuilder.new(1)
	var old := mb.push(MeshBuilder.T(sd["c"], Vector3(0, sd["yaw"], 0)))
	var pold := pm.push(MeshBuilder.T(sd["c"], Vector3(0, sd["yaw"], 0)))
	# the wall itself, extended over the corners
	mb.box(Vector3(0, WALL_H / 2.0, -WALL_T / 2.0), Vector3(len + WALL_T * 2.0, WALL_H, WALL_T), PLASTER)
	# wainscot, rail, top beam, posts
	mb.box(Vector3(0, 0.47, 0.03), Vector3(len, 0.94, 0.06), WAINSCOT)
	mb.box(Vector3(0, 0.97, 0.06), Vector3(len, 0.08, 0.12), BEAM)
	mb.box(Vector3(0, 0.06, 0.07), Vector3(len, 0.12, 0.08), BEAM.darkened(0.2))
	mb.box(Vector3(0, WALL_H - 0.12, 0.08), Vector3(len, 0.24, 0.16), BEAM)
	var posts := int(len / 3.6) + 1
	for i in posts + 1:
		var px := -len / 2.0 + len * i / float(posts)
		mb.box(Vector3(px, WALL_H / 2.0, 0.06), Vector3(0.22, WALL_H, 0.12), BEAM)
	for wx in windows:
		_window(mb, pm, float(wx))
	if sd["side"] == "s":
		_door(mb, -DOOR_X)
	_wall_decor(mb, sd["side"], len, windows)
	mb.pop(old)
	pm.pop(pold)
	var mi := Meshes.inst(mb.commit(), shell)
	var panes: MeshInstance3D = null
	if not pm.is_empty():
		panes = Meshes.inst(pm.commit(), shell)
		panes.material_override = _win_mat
	_walls.append({"mi": mi, "panes": panes, "n": sd["n"], "cut": false})

func _window(mb: MeshBuilder, pm: MeshBuilder, x: float) -> void:
	var y := 1.75
	mb.box(Vector3(x, y, 0.04), Vector3(1.3, 1.35, 0.08), BEAM)
	pm.box(Vector3(x, y, 0.09), Vector3(1.06, 1.1, 0.02), Color.WHITE)
	mb.box(Vector3(x, y, 0.11), Vector3(0.07, 1.1, 0.03), BEAM)
	mb.box(Vector3(x, y, 0.11), Vector3(1.06, 0.07, 0.03), BEAM)
	mb.box(Vector3(x, y - 0.66, 0.14), Vector3(1.45, 0.08, 0.26), BEAM.lightened(0.1))
	# curtains
	var cc: Color = CLOTH[int(abs(x * 7.0 + level)) % CLOTH.size()]
	for s in [-1.0, 1.0]:
		mb.box(Vector3(x + s * 0.72, y + 0.05, 0.16), Vector3(0.24, 1.45, 0.05), cc)
		mb.box(Vector3(x + s * 0.72, y - 0.2, 0.19), Vector3(0.28, 0.06, 0.04), cc.darkened(0.25))
	mb.box(Vector3(x, y + 0.78, 0.17), Vector3(1.8, 0.05, 0.05), Color("4a3a2a"))
	# a little pot on some sills
	if int(abs(x * 3.0)) % 2 == 0:
		mb.cyl(Vector3(x + 0.3, y - 0.62, 0.17), 0.09, 0.11, 0.16, 6, Color("c07a52"))
		mb.surface("plant")
		mb.blob(Vector3(x + 0.3, y - 0.38, 0.17), Vector3(0.14, 0.14, 0.12), Color("5f9a3f"), 0.2, 1)
		mb.surface("vc")

func _door(mb: MeshBuilder, x: float) -> void:
	mb.box(Vector3(x, 1.12, 0.05), Vector3(1.35, 2.3, 0.1), BEAM)
	mb.box(Vector3(x, 1.05, 0.1), Vector3(1.05, 2.1, 0.06), Color("7a3a24"))
	for i in 4:
		mb.box(Vector3(x - 0.39 + i * 0.26, 1.05, 0.14), Vector3(0.03, 2.0, 0.02), Color("5a2a18"))
	mb.box(Vector3(x, 0.55, 0.14), Vector3(1.0, 0.08, 0.03), Color("4a3a2a"))
	mb.box(Vector3(x, 1.65, 0.14), Vector3(1.0, 0.08, 0.03), Color("4a3a2a"))
	mb.sphere(Vector3(x - 0.36, 1.05, 0.17), Vector3.ONE * 0.05, Color("d8b04a"), 2, 4)
	# coat pegs beside the door
	mb.box(Vector3(x + 1.3, 1.75, 0.04), Vector3(0.9, 0.12, 0.06), BEAM)
	for i in 3:
		mb.box(Vector3(x + 1.0 + i * 0.3, 1.72, 0.12), Vector3(0.04, 0.04, 0.14), Color("3a2a1a"))
	mb.box(Vector3(x + 1.0, 1.35, 0.13), Vector3(0.3, 0.7, 0.08), Color("6a7a4a"))
	mb.sphere(Vector3(x + 1.6, 1.62, 0.12), Vector3(0.18, 0.08, 0.18), Color("c8a060"), 2, 6)

func _wall_decor(mb: MeshBuilder, side: String, len: float, windows: Array) -> void:
	var free_x: Array = []
	var x := -len / 2.0 + 1.0
	while x < len / 2.0 - 1.0:
		var ok := true
		for wx in windows:
			if abs(x - float(wx)) < 1.4:
				ok = false
		if side == "s" and abs(x - (-DOOR_X)) < 2.4:
			ok = false
		if side == "n" and abs(x) < 2.0:
			ok = false
		if ok:
			free_x.append(x)
		x += 1.0
	var n := 0
	for fx in free_x:
		if n >= 2 + level:
			break
		if mb.rng.randf() < 0.55:
			continue
		n += 1
		match mb.rng.randi() % 4:
			0:
				# framed picture
				var fc: Color = [Color("6ab0d8"), Color("8ac06a"), Color("e0a060"), Color("b080c0")][mb.rng.randi() % 4]
				mb.box(Vector3(fx, 1.9, 0.03), Vector3(0.8, 0.6, 0.05), Color("5a3a22"))
				mb.box(Vector3(fx, 1.9, 0.06), Vector3(0.66, 0.46, 0.02), fc)
				mb.box(Vector3(fx, 1.82, 0.075), Vector3(0.66, 0.16, 0.01), fc.darkened(0.35))
				mb.sphere(Vector3(fx + 0.15, 2.0, 0.075), Vector3(0.06, 0.06, 0.01), Color("fff2c0"), 2, 5)
			1:
				# shelf with jars
				mb.box(Vector3(fx, 1.6, 0.14), Vector3(1.0, 0.06, 0.26), BEAM.lightened(0.1))
				for j in 3:
					var jc: Color = [Color("d8a050"), Color("a8c8d0"), Color("c05a4a"), Color("8a9a5a")][mb.rng.randi() % 4]
					mb.cyl(Vector3(fx - 0.3 + j * 0.3, 1.63, 0.14), 0.07, 0.07, 0.16 + mb.rng.randf() * 0.1, 6, jc)
			2:
				# hanging herbs
				mb.box(Vector3(fx, 2.3, 0.08), Vector3(0.7, 0.05, 0.05), BEAM)
				mb.surface("plant")
				for j in 3:
					mb.blob(Vector3(fx - 0.22 + j * 0.22, 2.1, 0.1), Vector3(0.08, 0.18, 0.08), [Color("6a8a3a"), Color("8a9a4a"), Color("a08a4a")][j], 0.2, 1)
				mb.surface("vc")
			3:
				# wall sconce with a candle
				mb.box(Vector3(fx, 1.95, 0.05), Vector3(0.14, 0.3, 0.06), Color("4a3a2a"))
				mb.box(Vector3(fx, 1.82, 0.14), Vector3(0.2, 0.04, 0.2), Color("4a3a2a"))
				mb.cyl(Vector3(fx, 1.84, 0.14), 0.04, 0.04, 0.18, 6, Color("f4ead0"))
				mb.surface("glow")
				mb.sphere(Vector3(fx, 2.07, 0.14), Vector3(0.035, 0.06, 0.035), Color("ffb050"), 2, 4)
				mb.surface("vc")

# ------------------------------------------------------------------ hearth

func _build_hearth() -> void:
	var d := room.y
	var mb := MeshBuilder.new(9)
	var old := mb.push(MeshBuilder.T(Vector3(0, 0, -d / 2.0)))
	mb.box(Vector3(0, 0.07, 0.62), Vector3(3.0, 0.14, 1.3), STONE.darkened(0.15))
	# stacked stone pillars
	for s in [-1.0, 1.0]:
		for i in 5:
			var c: Color = STONE * mb.rng.randf_range(0.88, 1.08)
			c.a = 1.0
			mb.box(Vector3(s * 1.0 + mb.rng.randf_range(-0.03, 0.03), 0.17 + i * 0.29, 0.42), Vector3(0.6, 0.28, 0.84), c)
	for i in 4:
		var c2: Color = STONE * mb.rng.randf_range(0.88, 1.08)
		c2.a = 1.0
		mb.box(Vector3(-0.9 + i * 0.6, 1.62, 0.43), Vector3(0.58, 0.36, 0.86), c2)
	mb.box(Vector3(0, 1.86, 0.48), Vector3(3.1, 0.12, 1.0), BEAM)
	mb.box(Vector3(0, 2.45, 0.28), Vector3(2.1, 1.1, 0.56), STONE.darkened(0.06))
	# firebox
	mb.box(Vector3(0, 0.75, 0.06), Vector3(1.45, 1.3, 0.1), Color(0.1, 0.07, 0.05))
	mb.box(Vector3(0, 0.16, 0.45), Vector3(1.4, 0.04, 0.8), Color(0.16, 0.11, 0.08))
	mb.box(Vector3(-0.15, 0.27, 0.45), Vector3(0.9, 0.16, 0.18), BEAM.darkened(0.3), Vector3(0, 0.4, 0))
	mb.box(Vector3(0.18, 0.27, 0.5), Vector3(0.85, 0.15, 0.16), BEAM.darkened(0.2), Vector3(0, -0.5, 0))
	mb.surface("glow")
	for i in 6:
		mb.sphere(Vector3(mb.rng.randf_range(-0.4, 0.4), 0.2, mb.rng.randf_range(0.3, 0.65)), Vector3.ONE * 0.07, Color("ff7a2a"), 2, 4)
	mb.surface("vc")
	# things on the mantel
	mb.cyl(Vector3(-1.2, 1.92, 0.5), 0.05, 0.05, 0.22, 6, Color("f4ead0"))
	mb.cyl(Vector3(-1.0, 1.92, 0.5), 0.05, 0.05, 0.15, 6, Color("f4ead0"))
	mb.box(Vector3(0.9, 2.1, 0.42), Vector3(0.36, 0.36, 0.14), Color("5a3a22"))
	mb.box(Vector3(0.9, 2.1, 0.5), Vector3(0.26, 0.26, 0.02), Color("f4ead0"))
	mb.box(Vector3(0.9, 2.14, 0.515), Vector3(0.02, 0.1, 0.01), Color("2a2a2a"))
	mb.box(Vector3(0.93, 2.1, 0.515), Vector3(0.07, 0.02, 0.01), Color("2a2a2a"))
	mb.cyl(Vector3(0.3, 1.92, 0.5), 0.09, 0.07, 0.24, 6, Color("4f7aa8"))
	mb.surface("glow")
	mb.sphere(Vector3(-1.2, 2.18, 0.5), Vector3(0.03, 0.05, 0.03), Color("ffb050"), 2, 4)
	mb.sphere(Vector3(-1.0, 2.11, 0.5), Vector3(0.03, 0.05, 0.03), Color("ffb050"), 2, 4)
	mb.surface("vc")
	# a pot hanging on a crane
	mb.box(Vector3(-0.55, 1.0, 0.25), Vector3(0.05, 1.0, 0.05), Color("2a2a2a"))
	mb.box(Vector3(-0.3, 1.45, 0.35), Vector3(0.55, 0.04, 0.04), Color("2a2a2a"))
	mb.sphere(Vector3(-0.1, 0.95, 0.45), Vector3(0.22, 0.2, 0.22), Color("3a3a3e"), 3, 8)
	mb.pop(old)
	var mi := Meshes.inst(mb.commit(), shell)
	# the hearth belongs with the north wall so it hides with it
	if not _walls.is_empty():
		_walls[0]["extra"] = mi
	_solid(Vector2(0, -d / 2.0 + 0.55), Vector2(3.0, 1.1), 1.8)
	var f := Feature.new().setup("hearth", "hearth", "Cook at the hearth", origin + Vector3(0, 0, -d / 2.0 + 1.0), 1.3)
	add_child(f)
	register(f)
	_fire = CPUParticles3D.new()
	_fire.mesh = Meshes.particle_mesh(0.2, true)
	_fire.amount = 22
	_fire.lifetime = 0.8
	_fire.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_fire.emission_box_extents = Vector3(0.4, 0.04, 0.14)
	_fire.direction = Vector3.UP
	_fire.spread = 10.0
	_fire.initial_velocity_min = 0.5
	_fire.initial_velocity_max = 1.0
	_fire.gravity = Vector3(0, 0.5, 0)
	_fire.scale_amount_min = 0.6
	_fire.scale_amount_max = 1.4
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.85, 0.4, 1.0))
	ramp.set_color(1, Color(0.9, 0.25, 0.05, 0.0))
	_fire.color_ramp = ramp
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1.0))
	curve.add_point(Vector2(1, 0.2))
	_fire.scale_amount_curve = curve
	shell.add_child(_fire)
	_fire.position = Vector3(0, 0.32, -d / 2.0 + 0.48)
	_fire.emitting = true
	_fire_light = OmniLight3D.new()
	_fire_light.light_color = Color("ff9a48")
	_fire_light.light_energy = 2.0
	_fire_light.omni_range = 7.5 + level * 1.5
	_fire_light.omni_attenuation = 1.2
	_fire_light.position = Vector3(0, 0.9, -d / 2.0 + 1.2)
	shell.add_child(_fire_light)

# ------------------------------------------------------------------ built-in furniture

func _build_furnishings() -> void:
	var w := room.x
	var d := room.y
	var mb := MeshBuilder.new(31 + level)
	# lectern with the household journal
	var lp := Vector3(-w / 2.0 + 0.75, 0, 1.4)
	mb.box(lp + Vector3(0, 0.05, 0), Vector3(0.6, 0.1, 0.5), BEAM)
	mb.box(lp + Vector3(0, 0.55, 0), Vector3(0.16, 1.0, 0.16), BEAM)
	mb.box(lp + Vector3(0.0, 1.08, 0), Vector3(0.5, 0.06, 0.62), BEAM.lightened(0.1), Vector3(0, 0, -0.35))
	mb.box(lp + Vector3(0.03, 1.13, -0.13), Vector3(0.4, 0.04, 0.26), Color("f4ead0"), Vector3(0, 0, -0.35))
	mb.box(lp + Vector3(0.03, 1.13, 0.13), Vector3(0.4, 0.04, 0.26), Color("efe2c4"), Vector3(0, 0, -0.35))
	mb.box(lp + Vector3(0.03, 1.12, 0), Vector3(0.42, 0.03, 0.56), Color("7a2a2a"), Vector3(0, 0, -0.35))
	_solid(Vector2(lp.x, lp.z), Vector2(0.6, 0.6), 1.2)
	var jf := Feature.new().setup("home_journal", "chronicle", "Read the household journal", origin + lp + Vector3(0.6, 0, 0), 1.0)
	add_child(jf)
	register(jf)
	if level >= 1:
		# kitchen counter along the north wall, east of the hearth
		var x0 := w / 2.0 - 3.4
		var x1 := w / 2.0 - 0.2
		var cz := -d / 2.0 + 0.35
		mb.box(Vector3((x0 + x1) / 2.0, 0.45, cz), Vector3(x1 - x0, 0.9, 0.7), Color("8a5a36"))
		mb.box(Vector3((x0 + x1) / 2.0, 0.93, cz + 0.02), Vector3(x1 - x0 + 0.06, 0.06, 0.76), Color("c8b8a0"))
		for i in int((x1 - x0) / 0.8):
			mb.box(Vector3(x0 + 0.4 + i * 0.8, 0.45, cz + 0.36), Vector3(0.7, 0.75, 0.03), Color("9a6a42"))
			mb.sphere(Vector3(x0 + 0.62 + i * 0.8, 0.7, cz + 0.39), Vector3.ONE * 0.03, Color("d8b04a"), 2, 4)
		mb.cyl(Vector3(x0 + 0.5, 0.96, cz), 0.16, 0.14, 0.12, 8, Color("d8d0c0"))
		mb.box(Vector3(x1 - 0.8, 0.99, cz), Vector3(0.5, 0.04, 0.32), Color("b88a5a"))
		mb.sphere(Vector3(x1 - 1.5, 1.04, cz), Vector3(0.12, 0.09, 0.12), Color("e0503a"), 2, 6)
		mb.sphere(Vector3(x1 - 1.3, 1.03, cz + 0.08), Vector3(0.09, 0.08, 0.09), Color("f2c94c"), 2, 6)
		_solid(Vector2((x0 + x1) / 2.0, cz), Vector2(x1 - x0, 0.75), 1.0)
		# window seat on the west wall
		mb.box(Vector3(-w / 2.0 + 0.35, 0.25, -1.5), Vector3(0.7, 0.5, 1.8), BEAM.lightened(0.05))
		mb.box(Vector3(-w / 2.0 + 0.38, 0.55, -1.5), Vector3(0.62, 0.12, 1.7), CLOTH[1])
		mb.box(Vector3(-w / 2.0 + 0.2, 0.75, -2.05), Vector3(0.18, 0.35, 0.4), CLOTH[3])
		_solid(Vector2(-w / 2.0 + 0.35, -1.5), Vector2(0.7, 1.8), 0.6)
	if level >= 2:
		# stairs up to the loft along the east wall
		var sx := w / 2.0 - 0.65
		for i in 10:
			var sz := d / 2.0 - 1.4 - i * 0.42
			mb.box(Vector3(sx, 0.15 + i * 0.29, sz), Vector3(1.2, 0.08, 0.42), BEAM.lightened(0.15))
			mb.box(Vector3(sx, (0.15 + i * 0.29) / 2.0, sz), Vector3(1.1, 0.15 + i * 0.29, 0.38), BEAM.darkened(0.1))
		mb.box(Vector3(sx - 0.62, 1.6, d / 2.0 - 3.3), Vector3(0.06, 0.06, 4.2), BEAM, Vector3(-0.6, 0, 0))
		_solid(Vector2(sx, d / 2.0 - 3.3), Vector2(1.2, 4.3), 2.0)
		# a reading nook: armchair and bookcase
		var ap := Vector3(w / 2.0 - 2.6, 0, -d / 2.0 + 2.4)
		mb.box(ap + Vector3(0, 0.25, 0), Vector3(0.9, 0.5, 0.85), CLOTH[0])
		mb.box(ap + Vector3(0, 0.75, -0.36), Vector3(0.9, 0.7, 0.18), CLOTH[0].darkened(0.1))
		for s in [-1.0, 1.0]:
			mb.box(ap + Vector3(s * 0.45, 0.6, 0), Vector3(0.16, 0.35, 0.85), CLOTH[0].darkened(0.15))
		_solid(Vector2(ap.x, ap.z), Vector2(1.0, 0.95), 1.0)
	var mi := Meshes.inst(mb.commit(), shell)
	mi.position = Vector3.ZERO

func _build_lights() -> void:
	var w := room.x
	var d := room.y
	_lamp_light = OmniLight3D.new()
	_lamp_light.light_color = Color("ffd8a0")
	_lamp_light.omni_range = max(w, d) * 0.9
	_lamp_light.omni_attenuation = 0.8
	_lamp_light.position = Vector3(0, 2.7, 0.5)
	shell.add_child(_lamp_light)
	# daylight spilling in through the windows
	for p in [Vector3(-w * 0.3, 1.8, -d / 2.0 + 1.0), Vector3(w * 0.3, 1.8, -d / 2.0 + 1.0), Vector3(-w / 2.0 + 1.0, 1.8, 0), Vector3(w / 2.0 - 1.0, 1.8, 0)]:
		var l := OmniLight3D.new()
		l.light_color = Color("fff0d8")
		l.omni_range = 5.0 + level
		l.position = p
		shell.add_child(l)
		_sun_lights.append(l)
	var door := Feature.new().setup("home_door", "leave_home", "Go outside", origin + Vector3(DOOR_X, 0, d / 2.0 - 0.45), 1.2)
	add_child(door)
	register(door)

# ------------------------------------------------------------------ runtime

func _process(delta: float) -> void:
	_t += delta
	if _fire_light:
		var f := 1.9 + 0.25 * sin(_t * 11.0) + 0.18 * sin(_t * 23.7 + 1.3) + 0.1 * sin(_t * 5.1)
		_fire_light.light_energy = f
	var lp = Game.local_player
	if lp == null or lp.zone_id != zone_id:
		return
	if fmod(_t, 0.5) < delta:
		_update_windows()
	_update_cut()

func _update_windows() -> void:
	var day := Game.daylight()
	var wth := Game.weather()
	var day_col := Color(0.86, 0.94, 1.0)
	if wth in ["rain", "storm", "fog", "cloudy"]:
		day_col = Color(0.7, 0.76, 0.82)
	elif wth == "snow":
		day_col = Color(0.92, 0.95, 1.0)
	var dusk: float = clamp(1.0 - abs(day - 0.5) * 2.0, 0.0, 1.0) * 0.35
	var night_col := Color(0.08, 0.1, 0.2)
	var c := night_col.lerp(day_col, day).lerp(Color(1.0, 0.7, 0.45), dusk)
	if _win_mat:
		_win_mat.albedo_color = c
	var sun_e := 0.9 * day * (0.6 if wth in ["rain", "storm", "fog"] else 1.0)
	for l in _sun_lights:
		l.light_energy = sun_e
		l.visible = sun_e > 0.02
	if _lamp_light:
		_lamp_light.light_energy = 0.35 + 0.65 * (1.0 - day)

## Walls between the camera and the room are cut down to waist height.
func _update_cut() -> void:
	if Game.main == null or Game.main.cam == null:
		return
	var cp: Vector3 = Game.main.cam.cam.global_position - origin
	var dir := Vector3(cp.x, 0, cp.z)
	if dir.length() < 0.01:
		return
	dir = dir.normalized()
	for wd in _walls:
		var cut: bool = (wd["n"] as Vector3).dot(dir) > 0.2
		if cut == wd["cut"]:
			continue
		wd["cut"] = cut
		wd["mi"].material_override = Meshes.mat("vc_hidden") if cut else null
		if wd.get("extra"):
			wd["extra"].material_override = Meshes.mat("vc_hidden") if cut else null
		if wd["panes"]:
			wd["panes"].visible = not cut

func on_new_day() -> void:
	if farm_level() != level:
		_rebuild()

func _rebuild() -> void:
	var lp = Game.local_player
	_build_shell()
	if lp and lp.zone_id == zone_id and is_blocked(lp.global_position):
		lp.global_position = spawn_point("door")

func _on_change(k: String, ch: Dictionary) -> void:
	match k:
		"obj_add":
			if ch["v"].get("z", "") == zone_id:
				_spawn_placed(ch["id"], ch["v"])
		"obj_del":
			if objs.has(ch["id"]):
				remove_obj(ch["id"])
		"obj_data":
			if objs.has(ch["id"]) and objs[ch["id"]] is PlacedObj:
				objs[ch["id"]].on_data(ch["v"])
		"farm_level":
			if farm_level() != level:
				_rebuild()
