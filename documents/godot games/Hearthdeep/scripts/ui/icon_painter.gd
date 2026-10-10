class_name IconPainter
extends RefCounted
## Draws item icons as small vector illustrations on any CanvasItem.

static var _ci: CanvasItem
static var _r: Rect2

static func P(x: float, y: float) -> Vector2:
	return _r.position + Vector2(x, y) * _r.size

static func S(v: float) -> float:
	return v * _r.size.x

static func poly(pts: Array, col: Color, outline: bool = true) -> void:
	var pv := PackedVector2Array()
	for p in pts:
		pv.append(P(p.x, p.y))
	_ci.draw_colored_polygon(pv, col)
	if outline:
		pv.append(pv[0])
		_ci.draw_polyline(pv, col.darkened(0.55), max(1.0, S(0.035)), true)

static func circ(x: float, y: float, r: float, col: Color, outline: bool = true) -> void:
	_ci.draw_circle(P(x, y), S(r), col)
	if outline:
		_ci.draw_arc(P(x, y), S(r), 0, TAU, 20, col.darkened(0.55), max(1.0, S(0.035)), true)

static func ell(x: float, y: float, rx: float, ry: float, col: Color, rot: float = 0.0, outline: bool = true) -> void:
	var pts: Array = []
	for i in 18:
		var a := TAU * i / 18.0
		var v := Vector2(cos(a) * rx, sin(a) * ry).rotated(rot)
		pts.append(Vector2(x, y) + v)
	poly(pts, col, outline)

static func line(x0: float, y0: float, x1: float, y1: float, col: Color, w: float = 0.08) -> void:
	_ci.draw_line(P(x0, y0), P(x1, y1), col.darkened(0.55), S(w) + max(1.0, S(0.05)), true)
	_ci.draw_line(P(x0, y0), P(x1, y1), col, S(w), true)

static func rect(x: float, y: float, w: float, h: float, col: Color, outline: bool = true) -> void:
	poly([Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)], col, outline)

static func shine(x: float, y: float, r: float = 0.05) -> void:
	_ci.draw_circle(P(x, y), S(r), Color(1, 1, 1, 0.55))

static func draw_item(ci: CanvasItem, id: String, r: Rect2, alpha: float = 1.0) -> void:
	if id == "" or not Items.has(id):
		return
	var icon: Array = Items.def(id)["icon"]
	var c: Color = icon[1]
	var c2: Color = icon[2] if icon.size() > 2 else c.lightened(0.35)
	c.a *= alpha
	c2.a *= alpha
	draw_shape(ci, icon[0], r, c, c2)

static func draw_shape(ci: CanvasItem, shape: String, r: Rect2, c: Color, c2: Color) -> void:
	_ci = ci
	_r = r
	var wood := Color("9a6b3f")
	var metal := Color("b9b4ae")
	match shape:
		"log":
			poly([Vector2(0.15, 0.4), Vector2(0.75, 0.25), Vector2(0.85, 0.55), Vector2(0.25, 0.72)], c)
			ell(0.8, 0.4, 0.09, 0.15, c2, -0.25)
			ell(0.8, 0.4, 0.04, 0.07, c.darkened(0.2), -0.25, false)
		"stone":
			poly([Vector2(0.2, 0.62), Vector2(0.28, 0.35), Vector2(0.5, 0.25), Vector2(0.75, 0.33), Vector2(0.82, 0.6), Vector2(0.6, 0.75), Vector2(0.35, 0.75)], c)
			poly([Vector2(0.35, 0.4), Vector2(0.5, 0.33), Vector2(0.6, 0.42)], c.lightened(0.25), false)
			if c2 != c.lightened(0.35):
				circ(0.55, 0.55, 0.08, c2)
		"fiber":
			for i in 5:
				var x := 0.3 + i * 0.1
				line(x, 0.8, x + 0.12 - i * 0.05, 0.2, c, 0.05)
			line(0.25, 0.55, 0.75, 0.5, c.darkened(0.3), 0.06)
		"clay":
			ell(0.5, 0.58, 0.3, 0.2, c)
			ell(0.45, 0.5, 0.15, 0.08, c.lightened(0.2), 0.0, false)
		"ore", "core":
			poly([Vector2(0.18, 0.6), Vector2(0.3, 0.3), Vector2(0.55, 0.22), Vector2(0.8, 0.38), Vector2(0.8, 0.65), Vector2(0.5, 0.8)], c)
			circ(0.42, 0.45, 0.07, c2, false)
			circ(0.6, 0.55, 0.06, c2, false)
			circ(0.55, 0.36, 0.05, c2, false)
		"drop":
			poly([Vector2(0.5, 0.18), Vector2(0.72, 0.55), Vector2(0.62, 0.78), Vector2(0.38, 0.78), Vector2(0.28, 0.55)], c)
			shine(0.43, 0.55)
		"bone":
			line(0.28, 0.72, 0.72, 0.28, c, 0.12)
			for p in [Vector2(0.24, 0.7), Vector2(0.3, 0.77), Vector2(0.7, 0.23), Vector2(0.77, 0.3)]:
				circ(p.x, p.y, 0.08, c)
		"bag":
			poly([Vector2(0.3, 0.35), Vector2(0.7, 0.35), Vector2(0.8, 0.78), Vector2(0.2, 0.78)], c)
			rect(0.38, 0.25, 0.24, 0.12, c2)
			circ(0.5, 0.58, 0.07, c2, false)
		"worm":
			var pts := [Vector2(0.2, 0.6), Vector2(0.35, 0.45), Vector2(0.5, 0.6), Vector2(0.65, 0.45), Vector2(0.8, 0.55)]
			for i in pts.size() - 1:
				line(pts[i].x, pts[i].y, pts[i + 1].x, pts[i + 1].y, c, 0.1)
		"bar":
			poly([Vector2(0.15, 0.62), Vector2(0.32, 0.4), Vector2(0.85, 0.4), Vector2(0.7, 0.62)], c.lightened(0.15))
			poly([Vector2(0.15, 0.62), Vector2(0.7, 0.62), Vector2(0.7, 0.75), Vector2(0.15, 0.75)], c)
			poly([Vector2(0.7, 0.62), Vector2(0.85, 0.4), Vector2(0.85, 0.53), Vector2(0.7, 0.75)], c.darkened(0.2))
			shine(0.4, 0.5)
		"crystal":
			poly([Vector2(0.5, 0.12), Vector2(0.65, 0.35), Vector2(0.6, 0.85), Vector2(0.4, 0.85), Vector2(0.35, 0.35)], c)
			poly([Vector2(0.3, 0.45), Vector2(0.38, 0.6), Vector2(0.35, 0.85), Vector2(0.22, 0.82), Vector2(0.2, 0.6)], c.darkened(0.1))
			poly([Vector2(0.7, 0.45), Vector2(0.8, 0.6), Vector2(0.78, 0.85), Vector2(0.65, 0.85), Vector2(0.62, 0.6)], c.lightened(0.1))
			shine(0.46, 0.35)
		"gem":
			poly([Vector2(0.3, 0.35), Vector2(0.7, 0.35), Vector2(0.82, 0.48), Vector2(0.5, 0.82), Vector2(0.18, 0.48)], c)
			poly([Vector2(0.3, 0.35), Vector2(0.7, 0.35), Vector2(0.6, 0.48), Vector2(0.4, 0.48)], c.lightened(0.3), false)
			shine(0.4, 0.42)
		"round", "egg", "nut":
			if shape == "egg":
				ell(0.5, 0.55, 0.22, 0.28, c)
			else:
				circ(0.5, 0.56, 0.27, c)
				if shape == "round":
					line(0.5, 0.3, 0.55, 0.18, Color("6a4a2a"), 0.05)
					ell(0.62, 0.22, 0.1, 0.05, c2 if c2 != c.lightened(0.35) else Color("5aa83a"), -0.4)
			shine(0.42, 0.46, 0.06)
		"long":
			poly([Vector2(0.3, 0.3), Vector2(0.48, 0.25), Vector2(0.72, 0.85)], c)
			for i in 3:
				line(0.38, 0.28, 0.25 + i * 0.12, 0.08, c2, 0.06)
		"berry", "grain":
			if shape == "grain":
				line(0.5, 0.88, 0.5, 0.3, Color("8a7a3a"), 0.04)
				for i in 5:
					ell(0.42, 0.3 + i * 0.1, 0.07, 0.04, c, -0.5)
					ell(0.58, 0.3 + i * 0.1, 0.07, 0.04, c, 0.5)
			else:
				for p in [Vector2(0.4, 0.45), Vector2(0.6, 0.45), Vector2(0.5, 0.62), Vector2(0.33, 0.65), Vector2(0.67, 0.65), Vector2(0.5, 0.3)]:
					circ(p.x, p.y, 0.12, c)
				shine(0.37, 0.42, 0.04)
				if c2 != c.lightened(0.35):
					ell(0.5, 0.2, 0.14, 0.06, c2)
		"gourd":
			ell(0.5, 0.58, 0.32, 0.25, c)
			line(0.4, 0.4, 0.4, 0.78, c.darkened(0.2), 0.03)
			line(0.6, 0.4, 0.6, 0.78, c.darkened(0.2), 0.03)
			rect(0.46, 0.25, 0.08, 0.12, c2)
		"herb", "leaf":
			line(0.5, 0.85, 0.5, 0.35, Color("4a7a2a"), 0.05)
			ell(0.36, 0.5, 0.16, 0.08, c, 0.6)
			ell(0.64, 0.45, 0.16, 0.08, c, -0.6)
			ell(0.5, 0.28, 0.08, 0.16, c.lightened(0.1))
			if c2 != c.lightened(0.35):
				circ(0.5, 0.25, 0.05, c2, false)
		"flower":
			line(0.5, 0.88, 0.5, 0.45, Color("4a8a3a"), 0.05)
			for i in 6:
				var a := TAU * i / 6.0
				circ(0.5 + cos(a) * 0.14, 0.38 + sin(a) * 0.14, 0.1, c)
			circ(0.5, 0.38, 0.08, c2 if c2 != c.lightened(0.35) else Color("f2c94c"))
		"mushroom":
			rect(0.42, 0.45, 0.16, 0.35, c2 if c2 != c.lightened(0.35) else Color("efe6d8"))
			poly([Vector2(0.15, 0.5), Vector2(0.25, 0.3), Vector2(0.5, 0.2), Vector2(0.75, 0.3), Vector2(0.85, 0.5)], c)
			circ(0.35, 0.36, 0.04, c.lightened(0.4), false)
			circ(0.6, 0.32, 0.03, c.lightened(0.4), false)
		"honey":
			for p in [Vector2(0.38, 0.4), Vector2(0.62, 0.4), Vector2(0.5, 0.6), Vector2(0.26, 0.6), Vector2(0.74, 0.6)]:
				var pts2: Array = []
				for i in 6:
					var a := TAU * i / 6.0
					pts2.append(p + Vector2(cos(a), sin(a)) * 0.13)
				poly(pts2, c)
		"feather":
			poly([Vector2(0.25, 0.8), Vector2(0.45, 0.4), Vector2(0.72, 0.15), Vector2(0.62, 0.45)], c)
			line(0.25, 0.82, 0.68, 0.22, c.darkened(0.3), 0.03)
		"sapling":
			line(0.5, 0.85, 0.5, 0.4, Color("6b4a32"), 0.06)
			circ(0.5, 0.35, 0.2, c)
			circ(0.42, 0.32, 0.06, c2, false)
			ell(0.5, 0.86, 0.22, 0.06, Color("6a4a32"))
		"seed":
			rect(0.25, 0.18, 0.5, 0.65, c2)
			circ(0.5, 0.48, 0.15, c)
			rect(0.25, 0.18, 0.5, 0.1, c.darkened(0.2))
		"fish":
			ell(0.48, 0.5, 0.3, 0.16, c)
			poly([Vector2(0.75, 0.5), Vector2(0.9, 0.35), Vector2(0.9, 0.65)], c.darkened(0.15))
			ell(0.5, 0.56, 0.2, 0.06, c2, 0.0, false)
			circ(0.3, 0.46, 0.035, Color(0.1, 0.1, 0.1), false)
		"wing":
			poly([Vector2(0.15, 0.4), Vector2(0.5, 0.25), Vector2(0.85, 0.4), Vector2(0.7, 0.55), Vector2(0.55, 0.5), Vector2(0.5, 0.65), Vector2(0.45, 0.5), Vector2(0.3, 0.55)], c)
		"gel":
			ell(0.5, 0.6, 0.3, 0.2, c)
			ell(0.5, 0.48, 0.18, 0.14, c.lightened(0.15), 0.0, false)
			shine(0.42, 0.45)
		"claw":
			for i in 3:
				poly([Vector2(0.3 + i * 0.15, 0.8), Vector2(0.38 + i * 0.15, 0.8), Vector2(0.45 + i * 0.12, 0.25)], c)
		"shell":
			ell(0.5, 0.55, 0.3, 0.26, c)
			line(0.5, 0.3, 0.5, 0.8, c.darkened(0.3), 0.03)
			shine(0.38, 0.45)
		"cog":
			for i in 8:
				var a := TAU * i / 8.0
				rect(0.5 + cos(a) * 0.28 - 0.06, 0.5 + sin(a) * 0.28 - 0.06, 0.12, 0.12, c)
			circ(0.5, 0.5, 0.25, c)
			circ(0.5, 0.5, 0.09, c.darkened(0.4), false)
		"bottle":
			rect(0.43, 0.15, 0.14, 0.18, Color("d8c8a8"))
			poly([Vector2(0.4, 0.3), Vector2(0.6, 0.3), Vector2(0.78, 0.55), Vector2(0.72, 0.85), Vector2(0.28, 0.85), Vector2(0.22, 0.55)], Color(0.9, 0.95, 1.0, 0.5 * c.a))
			poly([Vector2(0.25, 0.58), Vector2(0.75, 0.58), Vector2(0.72, 0.85), Vector2(0.28, 0.85)], c, false)
			shine(0.36, 0.48)
		"mug":
			rect(0.25, 0.3, 0.42, 0.52, Color("a8774a"))
			rect(0.28, 0.33, 0.36, 0.15, c, false)
			_ci.draw_arc(P(0.7, 0.55), S(0.12), -PI / 2, PI / 2, 10, Color("a8774a").darkened(0.3), S(0.06), true)
			ell(0.46, 0.3, 0.22, 0.06, Color(1, 1, 1, 0.85))
		"plate", "skewer":
			if shape == "skewer":
				line(0.15, 0.85, 0.85, 0.15, Color("c8a070"), 0.04)
				for i in 3:
					circ(0.35 + i * 0.15, 0.65 - i * 0.15, 0.1, c)
			else:
				ell(0.5, 0.6, 0.38, 0.2, Color("f0ece0"))
				ell(0.5, 0.55, 0.22, 0.12, c)
				ell(0.6, 0.52, 0.1, 0.06, c2, 0.0, false)
		"bowl":
			poly([Vector2(0.15, 0.45), Vector2(0.85, 0.45), Vector2(0.7, 0.8), Vector2(0.3, 0.8)], Color("c89a6a"))
			ell(0.5, 0.45, 0.35, 0.1, c)
			circ(0.42, 0.44, 0.04, c2, false)
			circ(0.58, 0.46, 0.05, c2, false)
		"bread":
			ell(0.5, 0.58, 0.34, 0.2, c)
			for i in 3:
				line(0.35 + i * 0.13, 0.48, 0.42 + i * 0.13, 0.62, c.darkened(0.3), 0.025)
		"pie":
			ell(0.5, 0.6, 0.36, 0.18, c2)
			ell(0.5, 0.55, 0.3, 0.13, c)
			for i in 3:
				line(0.3 + i * 0.2, 0.47, 0.35 + i * 0.2, 0.63, c2, 0.04)
		"bandage":
			rect(0.2, 0.38, 0.6, 0.26, c)
			rect(0.4, 0.38, 0.2, 0.26, c.darkened(0.12), false)
		"hoe":
			line(0.25, 0.85, 0.65, 0.2, wood, 0.07)
			poly([Vector2(0.58, 0.18), Vector2(0.85, 0.22), Vector2(0.82, 0.34), Vector2(0.6, 0.28)], c)
		"can":
			poly([Vector2(0.25, 0.4), Vector2(0.65, 0.4), Vector2(0.62, 0.82), Vector2(0.28, 0.82)], c)
			line(0.62, 0.55, 0.85, 0.35, c, 0.06)
			_ci.draw_arc(P(0.45, 0.4), S(0.15), PI, TAU, 10, c.darkened(0.3), S(0.05), true)
		"axe":
			line(0.3, 0.88, 0.62, 0.18, wood, 0.07)
			poly([Vector2(0.55, 0.15), Vector2(0.8, 0.22), Vector2(0.78, 0.45), Vector2(0.55, 0.35)], c)
		"pick":
			line(0.3, 0.88, 0.58, 0.25, wood, 0.07)
			poly([Vector2(0.2, 0.3), Vector2(0.55, 0.15), Vector2(0.88, 0.32), Vector2(0.55, 0.24)], c)
		"rod":
			line(0.2, 0.88, 0.8, 0.12, c, 0.045)
			_ci.draw_line(P(0.8, 0.12), P(0.85, 0.6), Color(1, 1, 1, 0.7), 1.0)
			circ(0.85, 0.62, 0.04, Color("e04a3a"), false)
			circ(0.3, 0.75, 0.06, Color("4a4a4a"))
		"sword":
			poly([Vector2(0.45, 0.62), Vector2(0.78, 0.18), Vector2(0.84, 0.22), Vector2(0.52, 0.68)], c.lightened(0.2))
			line(0.36, 0.56, 0.6, 0.76, c.darkened(0.3), 0.06)
			line(0.28, 0.85, 0.48, 0.66, wood, 0.07)
		"spear":
			line(0.18, 0.88, 0.7, 0.3, wood, 0.05)
			poly([Vector2(0.64, 0.3), Vector2(0.88, 0.1), Vector2(0.72, 0.38)], c.lightened(0.15))
		"hammer":
			line(0.28, 0.88, 0.58, 0.35, wood, 0.07)
			poly([Vector2(0.38, 0.28), Vector2(0.62, 0.12), Vector2(0.82, 0.4), Vector2(0.58, 0.55)], c)
		"dagger":
			poly([Vector2(0.5, 0.55), Vector2(0.75, 0.2), Vector2(0.58, 0.6)], c.lightened(0.2))
			line(0.42, 0.52, 0.62, 0.66, c.darkened(0.3), 0.05)
			line(0.35, 0.8, 0.5, 0.62, wood, 0.07)
		"bow":
			_ci.draw_arc(P(0.3, 0.5), S(0.42), -1.15, 1.15, 16, c.darkened(0.4), S(0.1), true)
			_ci.draw_arc(P(0.3, 0.5), S(0.42), -1.15, 1.15, 16, c, S(0.07), true)
			_ci.draw_line(P(0.48, 0.12), P(0.48, 0.88), Color(1, 1, 1, 0.8), 1.5)
		"arrow":
			line(0.2, 0.8, 0.75, 0.25, Color("c8a070"), 0.04)
			poly([Vector2(0.7, 0.2), Vector2(0.86, 0.14), Vector2(0.8, 0.3)], c)
			poly([Vector2(0.2, 0.8), Vector2(0.18, 0.66), Vector2(0.28, 0.72)], Color("e8e0d0"))
		"hat":
			ell(0.5, 0.62, 0.38, 0.1, c)
			poly([Vector2(0.32, 0.6), Vector2(0.36, 0.3), Vector2(0.64, 0.3), Vector2(0.68, 0.6)], c.lightened(0.08))
			rect(0.34, 0.5, 0.32, 0.06, c.darkened(0.3), false)
		"boots":
			poly([Vector2(0.3, 0.2), Vector2(0.5, 0.2), Vector2(0.5, 0.62), Vector2(0.78, 0.68), Vector2(0.78, 0.8), Vector2(0.28, 0.8)], c)
			rect(0.28, 0.74, 0.5, 0.06, c.darkened(0.35), false)
		"ring":
			_ci.draw_arc(P(0.5, 0.56), S(0.22), 0, TAU, 20, c.darkened(0.4), S(0.1), true)
			_ci.draw_arc(P(0.5, 0.56), S(0.22), 0, TAU, 20, c, S(0.07), true)
			poly([Vector2(0.42, 0.34), Vector2(0.5, 0.22), Vector2(0.58, 0.34), Vector2(0.5, 0.4)], Color("bfe3ff"))
		"amulet":
			_ci.draw_arc(P(0.5, 0.3), S(0.25), 0.3, PI - 0.3, 14, Color("c8a85a"), S(0.03), true)
			poly([Vector2(0.5, 0.45), Vector2(0.68, 0.62), Vector2(0.5, 0.85), Vector2(0.32, 0.62)], c)
			shine(0.45, 0.6)
		"chest":
			rect(0.15, 0.42, 0.7, 0.38, c)
			poly([Vector2(0.15, 0.42), Vector2(0.2, 0.25), Vector2(0.8, 0.25), Vector2(0.85, 0.42)], c.lightened(0.1))
			rect(0.45, 0.42, 0.1, 0.14, Color("f2c94c"))
		"table":
			rect(0.12, 0.38, 0.76, 0.1, c)
			rect(0.18, 0.48, 0.07, 0.35, c.darkened(0.2))
			rect(0.75, 0.48, 0.07, 0.35, c.darkened(0.2))
		"chair":
			rect(0.3, 0.15, 0.08, 0.7, c.darkened(0.15))
			rect(0.3, 0.5, 0.42, 0.08, c)
			rect(0.64, 0.58, 0.07, 0.27, c.darkened(0.2))
		"furnace", "stove", "kettle":
			if shape == "kettle":
				ell(0.5, 0.55, 0.32, 0.26, c)
				rect(0.3, 0.3, 0.4, 0.06, c.darkened(0.2))
				ell(0.5, 0.31, 0.18, 0.04, Color("6ad86a"), 0.0, false)
			else:
				rect(0.2, 0.25, 0.6, 0.58, c)
				rect(0.35, 0.5, 0.3, 0.2, Color("ff8a3a"))
				if shape == "furnace":
					rect(0.42, 0.1, 0.16, 0.16, c.darkened(0.2))
		"campfire", "torch":
			if shape == "torch":
				line(0.5, 0.88, 0.5, 0.4, Color("6b4a32"), 0.08)
			else:
				line(0.2, 0.8, 0.8, 0.66, Color("6b4a32"), 0.08)
				line(0.2, 0.66, 0.8, 0.8, Color("5b3a22"), 0.08)
			poly([Vector2(0.5, 0.12), Vector2(0.66, 0.38), Vector2(0.6, 0.58), Vector2(0.4, 0.58), Vector2(0.34, 0.38)], Color("ff9a2a"))
			poly([Vector2(0.5, 0.28), Vector2(0.58, 0.45), Vector2(0.5, 0.56), Vector2(0.42, 0.45)], Color("ffe08a"), false)
		"sprinkler":
			ell(0.5, 0.75, 0.2, 0.08, Color("6a6a6a"))
			rect(0.46, 0.4, 0.08, 0.35, c)
			for i in 4:
				var a := TAU * i / 4.0 + 0.4
				line(0.5, 0.4, 0.5 + cos(a) * 0.25, 0.4 + sin(a) * 0.12, c, 0.04)
			circ(0.3, 0.25, 0.04, Color("8ac0ff"), false)
			circ(0.72, 0.22, 0.04, Color("8ac0ff"), false)
		"fence":
			for x in [0.25, 0.5, 0.75]:
				rect(x - 0.05, 0.25, 0.1, 0.6, c)
			rect(0.15, 0.38, 0.7, 0.07, c.darkened(0.15))
			rect(0.15, 0.6, 0.7, 0.07, c.darkened(0.15))
		"lamp":
			rect(0.47, 0.35, 0.06, 0.55, c)
			rect(0.38, 0.15, 0.24, 0.22, Color("ffd27a"))
			rect(0.36, 0.12, 0.28, 0.05, c)
		"pot":
			poly([Vector2(0.3, 0.5), Vector2(0.7, 0.5), Vector2(0.64, 0.85), Vector2(0.36, 0.85)], Color("c07a52"))
			circ(0.5, 0.38, 0.18, c)
		"tank":
			rect(0.15, 0.3, 0.7, 0.5, Color(0.6, 0.85, 1.0, 0.7))
			ell(0.48, 0.55, 0.12, 0.06, Color("f28a2a"))
			rect(0.12, 0.78, 0.76, 0.08, Color("a8774a"))
		"rug":
			rect(0.12, 0.3, 0.76, 0.42, c)
			rect(0.22, 0.38, 0.56, 0.26, c.lightened(0.25), false)
		"bed":
			rect(0.12, 0.45, 0.76, 0.3, Color("a8774a"))
			rect(0.15, 0.4, 0.5, 0.15, c)
			rect(0.66, 0.4, 0.2, 0.12, Color("f4f2ea"))
			rect(0.12, 0.25, 0.08, 0.55, Color("8a6a4a"))
		"gnome":
			poly([Vector2(0.5, 0.1), Vector2(0.68, 0.45), Vector2(0.32, 0.45)], c)
			circ(0.5, 0.52, 0.12, Color("f2d0b0"))
			ell(0.5, 0.62, 0.12, 0.1, Color("f4f2ea"))
			rect(0.36, 0.68, 0.28, 0.2, Color("4a6ab0"))
		"coin":
			circ(0.5, 0.52, 0.28, c)
			circ(0.5, 0.52, 0.18, c.lightened(0.2), false)
			shine(0.42, 0.44)
		"fossil":
			circ(0.5, 0.52, 0.3, c)
			for i in 3:
				_ci.draw_arc(P(0.5, 0.52), S(0.08 + i * 0.07), 0.0, PI * 1.5, 10, c.darkened(0.35), max(1.0, S(0.03)), true)
		"idol":
			rect(0.35, 0.45, 0.3, 0.4, c)
			circ(0.5, 0.35, 0.15, c)
			circ(0.45, 0.33, 0.03, Color(0.1, 0.1, 0.1), false)
			circ(0.55, 0.33, 0.03, Color(0.1, 0.1, 0.1), false)
		"key":
			circ(0.32, 0.4, 0.13, c)
			circ(0.32, 0.4, 0.05, Color(0, 0, 0, 0.5), false)
			line(0.42, 0.48, 0.8, 0.78, c, 0.06)
			line(0.68, 0.68, 0.62, 0.78, c, 0.05)
		"scroll":
			rect(0.25, 0.25, 0.5, 0.52, c)
			ell(0.5, 0.25, 0.27, 0.05, c.darkened(0.15))
			ell(0.5, 0.77, 0.27, 0.05, c.darkened(0.15))
			for i in 3:
				line(0.33, 0.38 + i * 0.12, 0.67, 0.38 + i * 0.12, c.darkened(0.4), 0.015)
		"rope":
			_ci.draw_arc(P(0.5, 0.5), S(0.25), 0, TAU, 20, c.darkened(0.3), S(0.1), true)
			_ci.draw_arc(P(0.5, 0.5), S(0.25), 0, TAU, 20, c, S(0.07), true)
			_ci.draw_arc(P(0.5, 0.5), S(0.13), 0, TAU, 14, c, S(0.06), true)
		"box":
			rect(0.2, 0.3, 0.6, 0.5, c)
			line(0.2, 0.3, 0.8, 0.8, c.darkened(0.25), 0.03)
			line(0.8, 0.3, 0.2, 0.8, c.darkened(0.25), 0.03)
		_:
			rect(0.25, 0.25, 0.5, 0.5, c)
