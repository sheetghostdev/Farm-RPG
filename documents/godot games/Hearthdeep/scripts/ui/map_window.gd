class_name MapWindow
extends UIWin
## The full map: what the household has explored, named landmarks, friends,
## and pins anyone can drop for everyone. Underground it shows the current floor.

var view: MapView

func _init() -> void:
	super._init("Map", Vector2(940, 720))
	kind = "map"
	view = MapView.new()
	view.custom_minimum_size = Vector2(910, 620)
	content.add_child(view)
	content.add_child(UITheme.label("Scroll to zoom · drag to look around · right-click to drop a pin (or remove one) for everyone", 14, UITheme.TEXT_DIM))
	var lp = Game.local_player
	if lp and lp.zone():
		title_l.text = lp.zone().display_name() if not (lp.zone() is HomeZone) else "Map"

func refresh() -> void:
	view.queue_redraw()


class MapView extends Control:
	var zoom := 2.0
	var center := Vector2.ZERO
	var bounds := Rect2(0, 0, 320, 320)
	var zone_id := "over"
	var cave: CaveFloor = null
	var _drag := false
	var _fitted := false
	var _t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		clip_contents = true
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		var lp = Game.local_player
		var z = lp.zone() if lp else null
		if z is CaveFloor:
			cave = z
			zone_id = z.zone_id
			bounds = cave.map_rect()
			center = Vector2(lp.global_position.x, lp.global_position.z)
		else:
			zone_id = "over"
			bounds = Rect2(0, 0, OverworldGen.S, OverworldGen.S)
			var g := Zones.overworld_gen()
			if lp and z is Overworld:
				center = Vector2(lp.global_position.x, lp.global_position.z)
			else:
				center = g.farm_rect.get_center()

	func _process(delta: float) -> void:
		_t += delta
		if not _fitted and size.x > 10:
			_fitted = true
			zoom = min(size.x / bounds.size.x, size.y / bounds.size.y) * (1.6 if cave == null else 1.0)
			_clamp_center()
		if fmod(_t, 0.2) < delta:
			queue_redraw()

	func to_screen(p: Vector2) -> Vector2:
		return size / 2.0 + (p - center) * zoom

	func to_world(s: Vector2) -> Vector2:
		return center + (s - size / 2.0) / zoom

	func _clamp_center() -> void:
		center.x = clamp(center.x, bounds.position.x, bounds.end.x)
		center.y = clamp(center.y, bounds.position.y, bounds.end.y)

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton:
			var mb: InputEventMouseButton = e
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				if mb.pressed:
					var before := to_world(mb.position)
					var fit: float = min(size.x / bounds.size.x, size.y / bounds.size.y)
					zoom = clamp(zoom * (1.15 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.15), fit * 0.8, 14.0)
					center += before - to_world(mb.position)
					_clamp_center()
					queue_redraw()
				accept_event()
			elif mb.button_index == MOUSE_BUTTON_LEFT:
				_drag = mb.pressed
				accept_event()
			elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
				_pin_at(to_world(mb.position))
				accept_event()
		elif e is InputEventMouseMotion and _drag:
			center -= (e as InputEventMouseMotion).relative / zoom
			_clamp_center()
			queue_redraw()
			accept_event()

	func _pin_at(p: Vector2) -> void:
		var pins: Array = Game.world["know"].get("pins", [])
		for i in pins.size():
			var pn: Dictionary = pins[i]
			if pn.get("z", "") == zone_id and (Vector2(pn["p"]) - p).length() * zoom < 12.0:
				Net.request("map_pin", {"op": "del", "i": i})
				Sfx.play("click")
				return
		if not bounds.has_point(p):
			return
		var look: Dictionary = Game.profile.get("look", {})
		Net.request("map_pin", {"op": "add", "z": zone_id, "p": p, "c": look.get("shirt", Color("ffd27a"))})
		Sfx.play("place", -6.0)

	func _draw() -> void:
		var font := get_theme_default_font()
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.09, 0.07, 0.06) if cave else Color(0.12, 0.1, 0.08))
		var r := Rect2(to_screen(bounds.position), bounds.size * zoom)
		if cave:
			var tex := cave.map_texture()
			if tex:
				draw_texture_rect(tex, r, false)
		else:
			draw_texture_rect(Minimap.overworld_texture(), r, false)
			_draw_over_features(font)
			draw_texture_rect(Minimap.fog_texture(), r, false)
			_draw_over_labels(font)
		draw_rect(r, UITheme.BORDER, false, 2.0)
		if cave:
			for m in cave.map_markers():
				var sp := to_screen(Vector2(m["p"].x, m["p"].z))
				draw_circle(sp, 6.0, Color(0, 0, 0, 0.7))
				draw_circle(sp, 4.5, m["c"])
				if m.has("label"):
					var lw := font.get_string_size(m["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
					_text(font, sp + Vector2(-lw / 2.0, 20), m["label"], 13, m["c"].lightened(0.3))
		# pins
		for pn in Game.world["know"].get("pins", []):
			if pn.get("z", "") != zone_id:
				continue
			var sp2 := to_screen(pn["p"])
			var c: Color = pn.get("c", Color("ffd27a"))
			draw_line(sp2, sp2 + Vector2(0, -16), Color(0.1, 0.08, 0.06), 2.0)
			draw_circle(sp2 + Vector2(0, -18), 6.0, Color(0.1, 0.08, 0.06))
			draw_circle(sp2 + Vector2(0, -18), 4.5, c)
			_text(font, sp2 + Vector2(8, -12), pn.get("by", ""), 12, UITheme.TEXT_DIM)
		# players
		for p in Zones.players.values():
			if not is_instance_valid(p) or p.zone_id != (zone_id if cave else "over"):
				continue
			var sp3 := to_screen(Vector2(p.global_position.x, p.global_position.z))
			var col: Color = p.look.get("shirt", Color.WHITE)
			if p == Game.local_player:
				var a: float = p.rotation.y
				var fwd := Vector2(sin(a), cos(a))
				var side := Vector2(fwd.y, -fwd.x)
				var pts := PackedVector2Array([sp3 + fwd * 11.0, sp3 - fwd * 7.0 + side * 7.0, sp3 - fwd * 7.0 - side * 7.0])
				draw_colored_polygon(pts, Color("ffd27a"))
				draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[0]]), Color(0, 0, 0, 0.9), 2.0)
			else:
				draw_circle(sp3, 7.0, Color(0, 0, 0, 0.7))
				draw_circle(sp3, 5.5, col.lightened(0.25))
			_text(font, sp3 + Vector2(10, -6), p.pname, 14, Color.WHITE)
		# compass and info
		var cpos := Vector2(size.x - 34, 36)
		draw_circle(cpos, 20, Color(0.1, 0.08, 0.06, 0.8))
		draw_colored_polygon(PackedVector2Array([cpos + Vector2(0, -16), cpos + Vector2(5, 0), cpos + Vector2(-5, 0)]), Color("e05a4a"))
		draw_colored_polygon(PackedVector2Array([cpos + Vector2(0, 16), cpos + Vector2(5, 0), cpos + Vector2(-5, 0)]), Color("f6ead2"))
		_text(font, cpos + Vector2(-5, -22), "N", 14, UITheme.TEXT)
		var info := Game.date_text() + "  ·  " + Game.clock_text()
		if not cave:
			info += "  ·  %d%% explored" % _explored_pct()
		else:
			info += "  ·  floor %d of the caves  ·  deepest %d" % [cave.floor_n, int(Game.world["know"].get("deepest", 0))]
		_text(font, Vector2(12, size.y - 12), info, 15, UITheme.TEXT)

	func _text(font: Font, p: Vector2, t: String, sz: int, col: Color) -> void:
		draw_string_outline(font, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, 5, Color(0, 0, 0, 0.85))
		draw_string(font, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)

	func _explored_pct() -> int:
		var ex: PackedByteArray = Game.world.get("explored", PackedByteArray())
		if ex.is_empty():
			return 0
		var n := 0
		for b in ex:
			n += b
		return int(round(100.0 * n / ex.size()))

	func _is_explored(p: Vector2) -> bool:
		var ex: PackedByteArray = Game.world.get("explored", PackedByteArray())
		var W := OverworldGen.EX_W
		var x := int(p.x / OverworldGen.EXPLORE_CELL)
		var z := int(p.y / OverworldGen.EXPLORE_CELL)
		if x < 0 or z < 0 or x >= W or z >= W or ex.size() != W * W:
			return false
		return ex[z * W + x] != 0

	## Houses and roads drawn under the fog.
	func _draw_over_features(_font: Font) -> void:
		var g := Zones.overworld_gen()
		var town := Zones.town
		if town:
			for b in town.buildings:
				var p3: Vector3 = b.get("pos", Vector3.ZERO)
				var hw := float(b.get("w", 6.0)) / 2.0
				var hd := float(b.get("d", 5.0)) / 2.0
				var bs := Basis(Vector3.UP, float(b.get("yaw", 0.0)))
				var pts := PackedVector2Array()
				for c in [Vector3(-hw, 0, -hd), Vector3(hw, 0, -hd), Vector3(hw, 0, hd), Vector3(-hw, 0, hd)]:
					var w3: Vector3 = p3 + bs * c
					pts.append(to_screen(Vector2(w3.x, w3.z)))
				var rc: Color = b.get("roof", Color("8a5a46"))
				draw_colored_polygon(pts, rc.darkened(0.15))
				pts.append(pts[0])
				draw_polyline(pts, Color(0, 0, 0, 0.45), 1.0)
		var hp := Vector2(g.farm_rect.get_center().x, g.farm_rect.position.y + 6.5)
		var hs := Vector2(7.0 + 2.5 * HomeZone.farm_level(), 5.5 + 1.5 * HomeZone.farm_level()) * zoom
		draw_rect(Rect2(to_screen(hp) - hs / 2.0, hs), Color("b5523b"))
		for k in Game.world["farm"]["tiles"]:
			var kk: Vector2i = k
			var t: Dictionary = Game.world["farm"]["tiles"][k]
			var c := Color("6a4a2a") if t.get("wet", false) else Color("8a6a40")
			if t.has("crop"):
				c = Color("6a9a3a")
			draw_rect(Rect2(to_screen(Vector2(kk.x, kk.y)), Vector2(zoom, zoom)), c)

	func _draw_over_labels(font: Font) -> void:
		var g := Zones.overworld_gen()
		var known: Dictionary = Game.world["know"].get("places", {})
		# the border walls and the gates through them
		for w in g.walls:
			draw_line(to_screen(w["a"]), to_screen(w["b"]), Color("d8d0b8"), max(2.0, zoom * 0.8))
		for gt in g.gates:
			var gp := to_screen(gt["p"])
			draw_circle(gp, 4.0, Color(0, 0, 0, 0.7))
			draw_circle(gp, 3.0, Color("e8c06a"))
		# the wild regions beyond the valley
		var regions := {"north": Vector2(160, 36), "west": Vector2(30, 170), "south": Vector2(170, 284), "east": Vector2(290, 190)}
		for r in regions:
			var rp: Vector2 = regions[r]
			var nm: String = ValleyLayout.REGION_NAMES[r]
			var sz := 20
			var w2 := font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
			_text(font, to_screen(rp) - Vector2(w2 / 2.0, 0), nm, sz, Color(0.95, 0.9, 0.8, 0.8))
		var marks: Array = []
		marks.append([Vector2(g.farm_rect.get_center().x, g.farm_rect.position.y + 6.5), "Home", Color("ffd27a"), 17])
		marks.append([g.town_center, TownGen.town_name(), Color("ffb0a0"), 18])
		marks.append([g.cave_pos + Vector2(0, 10), "Delver's Yard", Color("b0a0ff"), 16])
		for q in g.pois:
			var nm: String = q.get("name", "")
			if nm == "" or not known.has(q["id"]):
				continue
			marks.append([q["pos"], nm, Color("f6ead2"), 14])
		for m in marks:
			var sp := to_screen(m[0])
			if not Rect2(Vector2(-50, -20), size + Vector2(100, 40)).has_point(sp):
				continue
			draw_circle(sp, 5.0, Color(0, 0, 0, 0.75))
			draw_circle(sp, 3.5, m[2])
			var w := font.get_string_size(m[1], HORIZONTAL_ALIGNMENT_LEFT, -1, m[3]).x
			_text(font, sp + Vector2(-w / 2.0, -9), m[1], m[3], m[2])
