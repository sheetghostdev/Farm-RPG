class_name Minimap
extends Control
## Corner minimap. Shows the explored world around the player, friends and landmarks.

static var _over_tex: ImageTexture
static var _over_seed := -1
static var _fog_tex: ImageTexture
static var _fog_dirty := true

var zoom := 2.2
var _t := 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(200, 200)
	size = Vector2(200, 200)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Game.changed.connect(func(k, _c): if k == "explored" or k == "world_sync": _fog_dirty = true)

static func overworld_texture() -> ImageTexture:
	var g := Zones.overworld_gen()
	if _over_tex and _over_seed == g.seed_value:
		return _over_tex
	var S := OverworldGen.S
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	for z in S:
		for x in S:
			var i := z * S + x
			var c := g.color_at(x, z)
			var h := g.heights[z * OverworldGen.N + x]
			if g.water_idx[i] != 0 and h < g.water_lvl[i]:
				c = Color("4f8ab0").lerp(Color("2f5a80"), clamp((g.water_lvl[i] - h) / 2.0, 0.0, 1.0))
			else:
				var shade := clamp((h - 2.0) / 30.0, 0.0, 1.0)
				c = c.lightened(shade * 0.25)
				var b := g.biome[i]
				if b == OverworldGen.B.FOREST or b == OverworldGen.B.PINE or b == OverworldGen.B.BIRCH:
					c = c.darkened(0.12)
			c.a = 1.0
			img.set_pixel(x, z, c)
	# buildings & roads accent
	for b in g.bridges:
		var p: Vector2 = b["p"]
		for k in range(-3, 4):
			var q = p + b["dir"] * k
			if q.x >= 0 and q.y >= 0 and q.x < S and q.y < S:
				img.set_pixel(int(q.x), int(q.y), Color("8a6a4a") if not b["broken"] else Color("5a4a3a"))
	var fr := g.farm_rect
	for x in range(int(fr.position.x), int(fr.end.x)):
		img.set_pixel(x, int(fr.position.y), Color("a88a5a"))
		img.set_pixel(x, int(fr.end.y), Color("a88a5a"))
	_over_tex = ImageTexture.create_from_image(img)
	_over_seed = g.seed_value
	_fog_dirty = true
	return _over_tex

static func fog_texture() -> ImageTexture:
	if _fog_tex and not _fog_dirty:
		return _fog_tex
	var W := OverworldGen.EX_W
	var ex: PackedByteArray = Game.world.get("explored", PackedByteArray())
	var img := Image.create(W, W, false, Image.FORMAT_RGBA8)
	for i in W * W:
		var e := 0 if i >= ex.size() else ex[i]
		img.set_pixel(i % W, i / W, Color(0.08, 0.06, 0.06, 0.0 if e else 0.92))
	if _fog_tex:
		_fog_tex.update(img)
	else:
		_fog_tex = ImageTexture.create_from_image(img)
	_fog_dirty = false
	return _fog_tex

func _process(delta: float) -> void:
	_t += delta
	if _t > 0.1:
		_t = 0.0
		queue_redraw()

func _draw() -> void:
	var lp = Game.local_player
	if lp == null:
		return
	var z = lp.zone()
	var r := Rect2(Vector2.ZERO, size)
	draw_style_box(UITheme.box(Color(0.1, 0.08, 0.07, 0.9), UITheme.BORDER, 100, 3, 0), r)
	if z == null:
		return
	var center := size / 2.0
	var pp: Vector3 = lp.global_position
	if z is Overworld:
		var tex := overworld_texture()
		var fog := fog_texture()
		var span := size.x / zoom
		var src := Rect2(pp.x - span / 2.0, pp.z - span / 2.0, span, span)
		_draw_clipped(tex, src, Vector2(1, 1))
		var fs := float(OverworldGen.EXPLORE_CELL)
		_draw_clipped(fog, Rect2(src.position / fs, src.size / fs), Vector2(1, 1))
		_draw_pois(z, pp)
	elif z.has_method("map_texture"):
		var tex2: Texture2D = z.map_texture()
		var mr: Rect2 = z.map_rect()
		if tex2:
			var span2 := size.x / zoom
			var scale_px := Vector2(tex2.get_width() / mr.size.x, tex2.get_height() / mr.size.y)
			var src2 := Rect2((pp.x - span2 / 2.0 - mr.position.x) * scale_px.x, (pp.z - span2 / 2.0 - mr.position.y) * scale_px.y, span2 * scale_px.x, span2 * scale_px.y)
			_draw_clipped(tex2, src2, Vector2(1, 1))
			if z.has_method("map_markers"):
				for m in z.map_markers():
					var yaw1: float = Game.main.cam.yaw if Game.main and Game.main.cam else 0.0
					var d2: Vector2 = ((Vector2(m["p"].x, m["p"].z) - Vector2(pp.x, pp.z)) * zoom).rotated(yaw1)
					if d2.length() < size.x / 2.0 - 8.0:
						draw_circle(center + d2, 4.0, m["c"])
	# other players
	for p in Zones.players_in_zone(lp.zone_id):
		if p == lp:
			continue
		var yaw0: float = Game.main.cam.yaw if Game.main and Game.main.cam else 0.0
		var d: Vector2 = ((Vector2(p.global_position.x, p.global_position.z) - Vector2(pp.x, pp.z)) * zoom).rotated(yaw0)
		if d.length() > size.x / 2.0 - 6.0:
			d = d.normalized() * (size.x / 2.0 - 6.0)
		draw_circle(center + d, 5.0, Color(0, 0, 0, 0.6))
		draw_circle(center + d, 4.0, p.look.get("shirt", Color.WHITE).lightened(0.3))
	# self arrow (rotated so up is camera-forward)
	var yaw: float = Game.main.cam.yaw if Game.main and Game.main.cam else 0.0
	var a: float = -(lp.rotation.y - yaw) + PI
	var pts := PackedVector2Array([center + Vector2(0, -8).rotated(a), center + Vector2(5, 6).rotated(a), center + Vector2(-5, 6).rotated(a)])
	draw_colored_polygon(pts, Color("ffd27a"))
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[0]]), Color(0, 0, 0, 0.8), 1.5)
	draw_arc(center, size.x / 2.0 - 2, 0, TAU, 48, UITheme.BORDER, 3.0, true)

## Draws a source region of a texture into the circular map, rotated with the camera.
func _draw_clipped(tex: Texture2D, src: Rect2, _s: Vector2) -> void:
	var yaw: float = Game.main.cam.yaw if Game.main and Game.main.cam else 0.0
	var center := size / 2.0
	var rad := size.x / 2.0 - 3.0
	var segs := 40
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	var tsz := Vector2(tex.get_width(), tex.get_height())
	for i in segs:
		var ang := TAU * i / segs
		var off := Vector2(cos(ang), sin(ang)) * rad
		pts.append(center + off)
		var w := off.rotated(-yaw)
		var uv := (src.position + src.size / 2.0 + w / size.x * src.size) / tsz
		uvs.append(uv)
	var cols := PackedColorArray()
	cols.resize(segs)
	cols.fill(Color.WHITE)
	draw_polygon(pts, cols, uvs, tex)

func _draw_pois(z: Overworld, pp: Vector3) -> void:
	var yaw: float = Game.main.cam.yaw if Game.main and Game.main.cam else 0.0
	var center := size / 2.0
	var g := z.gen
	var marks: Array = []
	marks.append([Vector2(g.farm_rect.get_center().x, g.farm_rect.position.y + 6), Color("ffd27a")])
	marks.append([g.town_center, Color("e8a0a0")])
	marks.append([g.cave_pos, Color("b0a0ff")])
	for q in g.pois:
		if Game.world["know"]["places"].has(q["id"]):
			marks.append([q["pos"], Color("f6ead2")])
	for m in marks:
		var d: Vector2 = (m[0] - Vector2(pp.x, pp.z)) * zoom
		d = d.rotated(yaw)
		if d.length() < size.x / 2.0 - 8.0:
			draw_circle(center + d, 3.5, Color(0, 0, 0, 0.7))
			draw_circle(center + d, 2.5, m[1])
