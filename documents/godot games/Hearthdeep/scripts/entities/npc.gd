class_name NPC
extends Node3D
## A townsperson. Where they are is a pure function of the game clock and their
## schedule, so every player sees them in the same place with no syncing.

const SPEED := 1.15     # meters per game minute (about 1.6 m/s in real time)

var data := {}
var town: TownGen
var zone_id := "over"
var doll: Doll
var tag: Label3D
var blocks: Array = []
var _blocks_day := -1
var _last_pos := Vector3.ZERO
var _speed := 0.0
var freeze_t := 0.0
var face_target := Vector3.ZERO
var activity := ""
var inside := false
var radius := 0.5
var oid := ""

func setup(p: Dictionary, t: TownGen) -> void:
	data = p
	town = t
	oid = p["id"]
	name = p["id"]
	add_to_group("npcs")
	doll = Doll.new()
	add_child(doll)
	doll.setup(p["look"])
	var role: String = p["role"]
	if role in ["smith", "carpenter", "innkeeper", "baker", "herbalist"]:
		doll.look["apron"] = {"smith": 1, "carpenter": 3, "innkeeper": 0, "baker": 0, "herbalist": 2}[role]
		doll.setup(doll.look)
	tag = Label3D.new()
	tag.text = p["first"]
	tag.font_size = 34
	tag.outline_size = 8
	tag.pixel_size = 0.005
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.position = Vector3(0, 2.25 if p["age"] != "child" else 1.7, 0)
	tag.modulate = Color(1, 0.95, 0.85, 0.0)
	tag.no_depth_test = true
	add_child(tag)

func display_name() -> String:
	return data["name"]

func prompt(_player) -> String:
	if inside or not visible:
		return ""
	return "Talk to %s" % data["first"]

func interact(player) -> void:
	freeze_t = 10.0
	face_target = player.global_position
	doll.talk_time = 1.5
	Game.main.ui.open_dialogue(self)

## Is this person standing at their shop counter right now?
func at_work() -> bool:
	return activity == "work" and not inside

# ------------------------------------------------------------------ schedule

func _build_blocks(day: int) -> void:
	_blocks_day = day
	blocks.clear()
	var p := data
	var home := town.building(p["home"])
	var rng := RandomNumberGenerator.new()
	rng.seed = Game.hash_ints(int(p["voice_seed"]), day)
	var rain := Game.weather_for_day(day) in ["rain", "storm", "snow"]
	var yard: Vector3 = home.get("front", town.center) if not home.is_empty() else town.center
	var plaza := _plaza_spot(rng)
	var tavern := town.building_for_role("innkeeper")
	var tavern_spot: Vector3 = tavern.get("front", town.center) + Vector3(rng.randf_range(-2, 2), 0, rng.randf_range(-2, 2))
	var age: String = p["age"]
	var role: String = p["role"]
	var wake := 60.0 if age == "adult" else (30.0 if age == "elder" else 90.0)
	var bed := 960.0 if age == "adult" else (900.0 if age == "elder" else 840.0)
	_add(0, wake, yard, true, 0.0, "home")
	var shop_role = TownGen.ROLE_INFO.get(role, {}).has("building") and role != "curio_hall"
	if shop_role:
		var wb := town.building_for_role(role)
		var counter: Vector3 = wb.get("counter", town.center)
		var start := 180.0 if role != "innkeeper" else 300.0
		var end := 660.0 if role != "innkeeper" else 1020.0
		if role == "mayor":
			counter = wb.get("front", town.center) + wb.get("fwd", Vector3.ZERO) * 1.5
			end = 600.0
		_add(wake, start, yard if not rain else wb.get("front", yard), false, 2.0, "morning")
		_add(start, end, counter, false, 0.3, "work")
		if role != "innkeeper":
			_add(end, 840.0, tavern_spot if rng.randf() < 0.6 else plaza, false, 3.0, "social")
			_add(840.0, bed, yard, false, 1.5, "evening")
		else:
			_add(end, bed + 30.0, tavern.get("front", yard), false, 2.0, "closing")
	elif age == "child":
		var friend_home := yard
		if not p["friends"].is_empty():
			var f: Dictionary = town.resident(p["friends"][rng.randi() % p["friends"].size()])
			if not f.is_empty():
				friend_home = town.building(f["home"]).get("front", yard)
		if rain:
			_add(wake, 420.0, yard, true, 0.0, "home")
			_add(420.0, 720.0, tavern_spot, false, 2.5, "play")
		else:
			_add(wake, 360.0, plaza, false, 6.0, "play")
			_add(360.0, 420.0, yard, false, 2.0, "lunch")
			_add(420.0, 660.0, friend_home, false, 4.0, "play")
			_add(660.0, 780.0, plaza, false, 6.0, "play")
		_add(780.0, bed, yard, false, 2.0, "evening")
	elif age == "elder":
		var bench := _bench_spot(rng)
		_add(wake, 300.0, bench if not rain else yard, rain, 0.2, "sit")
		_add(300.0, 480.0, yard, false, 1.5, "garden")
		_add(480.0, 720.0, tavern_spot if rain or rng.randf() < 0.5 else bench, false, 1.0, "social")
		_add(720.0, bed, yard, false, 1.0, "evening")
	else:
		var job := _job_spot(role, rng, yard)
		_add(wake, 300.0, yard, false, 2.5, "morning")
		_add(300.0, 420.0, plaza, false, 5.0, "social")
		_add(420.0, 660.0, job if not rain else tavern_spot, false, 3.0, "job")
		_add(660.0, 840.0, tavern_spot, false, 2.5, "social")
		_add(840.0, bed, yard, false, 1.5, "evening")
	_add(bed, 1440.0, yard, true, 0.0, "home")

func _add(a: float, b: float, spot: Vector3, is_inside: bool, wander: float, act: String) -> void:
	if b <= a:
		return
	spot.y = town.center.y if not Zones.get_zone("over") else Zones.get_zone("over").ground_y(spot.x, spot.z)
	blocks.append({"a": a, "b": b, "spot": spot, "inside": is_inside, "wander": wander, "act": act})

func _plaza_spot(rng: RandomNumberGenerator) -> Vector3:
	var a := rng.randf() * TAU
	return town.center + Vector3(cos(a), 0, sin(a)) * rng.randf_range(4.0, 8.0)

func _bench_spot(rng: RandomNumberGenerator) -> Vector3:
	for d in town.decor:
		if d["k"] == "bench" and rng.randf() < 0.5:
			return d["p"]
	return _plaza_spot(rng)

func _job_spot(role: String, rng: RandomNumberGenerator, yard: Vector3) -> Vector3:
	match role:
		"farmer", "herder":
			var a := rng.randf() * TAU
			return town.center + Vector3(cos(a), 0, sin(a)) * (TownGen.R_OUTER + 8.0)
		"teacher", "scholar", "historian":
			return town.building_for_role("mayor").get("front", town.center) + Vector3(rng.randf_range(-3, 3), 0, rng.randf_range(-3, 3))
		"musician":
			return _bench_spot(rng)
		"guard", "explorer":
			var ang: float = town.road_angles[1]
			return town.center + Vector3(cos(ang), 0, sin(ang)) * (TownGen.R_OUTER + 4.0)
		"courier":
			var b: Dictionary = town.buildings[rng.randi() % town.buildings.size()]
			return b["front"]
	return yard + Vector3(rng.randf_range(-2, 2), 0, rng.randf_range(-2, 2))

## Walking route between two spots: radially onto the ring street, around, and out.
func _route(a: Vector3, b: Vector3) -> PackedVector3Array:
	var pts := PackedVector3Array()
	pts.append(a)
	var c := town.center
	var ra := Vector2(a.x - c.x, a.z - c.z)
	var rb := Vector2(b.x - c.x, b.z - c.z)
	var ring := TownGen.PLAZA_R + 3.0
	if ra.length() > ring + 1.0 or rb.length() > ring + 1.0:
		var aa := ra.angle()
		var ab := rb.angle()
		var da := wrapf(ab - aa, -PI, PI)
		var steps := int(abs(da) / 0.35) + 1
		for i in steps + 1:
			var ang := aa + da * float(i) / steps
			pts.append(c + Vector3(cos(ang), 0, sin(ang)) * ring)
	pts.append(b)
	return pts

func _pos_at(t: float) -> Dictionary:
	var day := Game.day()
	if _blocks_day != day:
		_build_blocks(day)
	var idx := 0
	for i in blocks.size():
		if t >= blocks[i]["a"] and t < blocks[i]["b"]:
			idx = i
			break
	var blk: Dictionary = blocks[idx]
	var prev: Dictionary = blocks[max(0, idx - 1)]
	var since: float = t - blk["a"]
	var route := _route(prev["spot"], blk["spot"])
	var length := 0.0
	for i in range(1, route.size()):
		length += route[i - 1].distance_to(route[i])
	var walked := since * SPEED
	if idx > 0 and walked < length and prev["spot"].distance_to(blk["spot"]) > 1.0:
		var left := walked
		for i in range(1, route.size()):
			var seg := route[i - 1].distance_to(route[i])
			if left <= seg:
				var p := route[i - 1].lerp(route[i], left / max(seg, 0.001))
				return {"p": p, "inside": false, "act": "walk", "dir": (route[i] - route[i - 1]).normalized()}
			left -= seg
	var w: float = blk["wander"]
	var seed_f := float(int(data["voice_seed"]) % 997)
	var off := Vector3.ZERO
	if w > 0.0:
		var tt := t * 0.05 + seed_f
		off = Vector3(sin(tt * 0.9) + sin(tt * 2.3) * 0.4, 0, cos(tt * 0.7) + cos(tt * 1.9) * 0.4) * w * 0.6
	return {"p": blk["spot"] + off, "inside": blk["inside"], "act": blk["act"], "dir": Vector3.ZERO}

func _process(delta: float) -> void:
	if not Game.running:
		return
	var lp = Game.local_player
	var near = lp != null and lp.zone_id == zone_id and lp.global_position.distance_to(global_position) < 90.0
	if freeze_t > 0.0:
		freeze_t -= delta
		var d := face_target - global_position
		if d.length() > 0.1:
			rotation.y = lerp_angle(rotation.y, atan2(d.x, d.z), 1.0 - exp(-delta * 8.0))
		doll.animate(delta, 0.0)
		_update_tag(lp)
		return
	var st := _pos_at(Game.tod)
	inside = st["inside"]
	activity = st["act"]
	visible = not inside
	var p: Vector3 = st["p"]
	var z = Zones.get_zone("over")
	if z:
		p.y = z.ground_y(p.x, p.z)
	var mv := p - _last_pos
	mv.y = 0
	_speed = lerp(_speed, mv.length() / max(delta, 0.001), 0.2)
	global_position = p
	if mv.length() > 0.002:
		rotation.y = lerp_angle(rotation.y, atan2(mv.x, mv.z), 1.0 - exp(-delta * 8.0))
	elif activity == "work":
		var b := town.building_for_role(data["role"])
		if not b.is_empty():
			var f: Vector3 = b.get("fwd", Vector3.FORWARD)
			rotation.y = lerp_angle(rotation.y, atan2(f.x, f.z), 0.1)
	_last_pos = p
	if near and visible:
		doll.state = "sit" if activity == "sit" else "idle"
		doll.animate(delta, min(_speed, 3.0))
	_update_tag(lp)

func _update_tag(lp) -> void:
	if lp == null:
		return
	var d: float = lp.global_position.distance_to(global_position)
	tag.modulate.a = clamp((7.0 - d) / 2.0, 0.0, 1.0)
