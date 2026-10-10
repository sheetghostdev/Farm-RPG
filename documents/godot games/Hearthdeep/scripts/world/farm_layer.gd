class_name FarmLayer
extends Node3D
## Tilled soil and crops on the farm. Tile state lives in Game.world.farm.tiles,
## keyed by Vector2i (1 m grid in world space).

var over: Overworld
var soil_mmi: MultiMeshInstance3D
var crops := {}         # Vector2i -> MeshInstance3D
var _dirty := true

func setup(o: Overworld) -> void:
	over = o
	soil_mmi = MultiMeshInstance3D.new()
	soil_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(soil_mmi)
	refresh_all()

func tiles() -> Dictionary:
	return Game.world["farm"]["tiles"]

static func tile_of(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x), floori(p.z))

func tile_center(k: Vector2i) -> Vector3:
	var x := k.x + 0.5
	var z := k.y + 0.5
	return Vector3(x, over.gen.h_at(x, z), z)

## Can this tile be tilled? (inside the farm, dry land, nothing in the way)
func can_till(k: Vector2i) -> bool:
	var g := over.gen
	var p := Vector2(k.x + 0.5, k.y + 0.5)
	if not g.farm_rect.grow(-0.5).has_point(p):
		return false
	if not g.water_at(p.x, p.y).is_empty():
		return false
	var hp := over.farmhouse_pos()
	var lvl := int(Game.world["farm"].get("level", 0))
	var hw := (7.0 + lvl * 2.5) / 2.0 + 1.5 + (4.0 if lvl >= 2 else 0.0)
	var hd := (5.5 + lvl * 1.5) / 2.0 + 2.8
	if abs(p.x - hp.x + (2.0 if lvl >= 2 else 0.0)) < hw and abs(p.y - hp.z) < hd:
		return false
	for o in over.query(tile_center(k), 0.6):
		if o.blocking or o.kind == "placed" or (o.kind == "res" and o.sub in ["weed", "twig", "stump", "rock", "log", "boulder"]):
			var d: Vector3 = o.global_position - tile_center(k)
			if abs(d.x) < 0.5 + o.radius * 0.6 and abs(d.z) < 0.5 + o.radius * 0.6:
				return false
	return true

func refresh_all() -> void:
	_rebuild_soil()
	for k in crops.keys():
		if not tiles().has(k) or not tiles()[k].has("crop"):
			crops[k].queue_free()
			crops.erase(k)
	for k in tiles():
		_refresh_crop(k)

func _rebuild_soil() -> void:
	var t := tiles()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _soil_mesh()
	mm.instance_count = t.size()
	var i := 0
	for k in t:
		var c := tile_center(k)
		var tv: Dictionary = t[k]
		mm.set_instance_transform(i, Transform3D(Basis(), c + Vector3(0, 0.02, 0)))
		var wet: bool = tv.get("wet", false)
		mm.set_instance_color(i, Color("3a2618") if wet else Color("6a4630"))
		i += 1
	soil_mmi.multimesh = mm

func _soil_mesh() -> Mesh:
	return Meshes.cached("soil_tile", func():
		var mb := MeshBuilder.new(3)
		mb.surface("vc_nosnow")
		mb.box(Vector3(0, 0.0, 0), Vector3(0.96, 0.08, 0.96), Color.WHITE, Vector3.ZERO, 1.0)
		for i in 3:
			mb.box(Vector3(0, 0.045, -0.3 + i * 0.3), Vector3(0.86, 0.025, 0.08), Color(0.85, 0.85, 0.85))
		mb.surface("vc")
		return mb.commit())

func crop_stage(tv: Dictionary) -> int:
	var c: Dictionary = tv.get("crop", {})
	if c.is_empty():
		return -1
	if c.get("dead", false):
		return -2
	var cd: Dictionary = Items.crops.get(c["id"], {})
	if cd.is_empty():
		return 0
	var g := int(c.get("g", 0))
	if g >= int(cd["total"]):
		return 4
	if g <= 0:
		return 0
	var acc := 0
	var st: Array = cd["stages"]
	for i in st.size():
		acc += int(st[i])
		if g < acc:
			return max(1, i)
	return 3

func _refresh_crop(k: Vector2i) -> void:
	var tv: Dictionary = tiles().get(k, {})
	var st := crop_stage(tv)
	if st == -1:
		if crops.has(k):
			crops[k].queue_free()
			crops.erase(k)
		return
	var mesh: Mesh
	if st == -2:
		mesh = Meshes.cached("dead_crop", func():
			var mb := MeshBuilder.new(1)
			mb.blade(Vector3.ZERO, 0.08, 0.25, Vector3(0.1, 0, 0), Color("8a7a4a"))
			mb.blade(Vector3(0.05, 0, 0.05), 0.08, 0.2, Vector3(-0.1, 0, 0.05), Color("7a6a3a"))
			return mb.commit())
	else:
		mesh = ItemModels.crop_mesh(tv["crop"]["id"], st)
	if not crops.has(k):
		var mi := MeshInstance3D.new()
		mi.visibility_range_end = 90.0
		add_child(mi)
		crops[k] = mi
		mi.position = tile_center(k) + Vector3(0, 0.05, 0)
		mi.rotation.y = float(abs(k.x * 73 + k.y * 151) % 628) / 100.0
	if crops[k].mesh != mesh:
		crops[k].mesh = mesh
		if st == 4:
			var tw = crops[k].create_tween()
			crops[k].scale = Vector3.ONE * 0.85
			tw.tween_property(crops[k], "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK)

func on_change(k: String, ch: Dictionary) -> void:
	match k:
		"tile":
			var key: Vector2i = ch["k"]
			_rebuild_soil()
			_refresh_crop(key)
		"tiles", "new_day", "world_sync":
			refresh_all()

func crop_prompt(k: Vector2i) -> String:
	var tv: Dictionary = tiles().get(k, {})
	var st := crop_stage(tv)
	if st == 4:
		return "Harvest %s" % Items.def(tv["crop"]["id"])["name"]
	if st == -2:
		return "Clear withered crop"
	return ""

func crop_info(k: Vector2i) -> String:
	var tv: Dictionary = tiles().get(k, {})
	var st := crop_stage(tv)
	if st < 0 or st == 4:
		return ""
	var c: Dictionary = tv["crop"]
	var cd: Dictionary = Items.crops[c["id"]]
	var left := int(cd["total"]) - int(c.get("g", 0))
	return "%s · %d day%s to go%s" % [Items.def(c["id"])["name"], left, "" if left == 1 else "s", "" if tv.get("wet", false) else " · needs water"]
