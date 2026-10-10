class_name MeshBuilder
extends RefCounted
## Accumulates flat-shaded, vertex-coloured triangles into named surfaces, then
## commits them to an ArrayMesh. Every model in the game is built with this.
## Primitive helpers orient their triangles outward automatically.

var surfaces := {}
var cur := "vc"
var xf := Transform3D.IDENTITY
var rng := RandomNumberGenerator.new()

func _init(seed_value: int = 0) -> void:
	rng.seed = seed_value

func surface(nm: String) -> MeshBuilder:
	cur = nm
	return self

func _buf() -> Dictionary:
	if not surfaces.has(cur):
		surfaces[cur] = {"v": PackedVector3Array(), "n": PackedVector3Array(), "c": PackedColorArray()}
	return surfaces[cur]

## Adds a triangle given counter-clockwise (seen from the front) vertices in local space.
func tri(a: Vector3, b: Vector3, c: Vector3, col: Color, cb = null, cc = null) -> void:
	var wa := xf * a
	var wb := xf * b
	var wc := xf * c
	var n := (wb - wa).cross(wc - wa)
	if n.length_squared() < 1e-12:
		return
	n = n.normalized()
	var buf := _buf()
	# Godot treats clockwise winding as front-facing.
	buf["v"].append(wa)
	buf["v"].append(wc)
	buf["v"].append(wb)
	buf["n"].append(n)
	buf["n"].append(n)
	buf["n"].append(n)
	buf["c"].append(col)
	buf["c"].append(cc if cc != null else col)
	buf["c"].append(cb if cb != null else col)

## Triangle oriented to face away from `inside` (local space).
func tri_out(a: Vector3, b: Vector3, c: Vector3, col: Color, inside: Vector3) -> void:
	var n := (b - a).cross(c - a)
	if n.dot((a + b + c) / 3.0 - inside) < 0.0:
		tri(a, c, b, col)
	else:
		tri(a, b, c, col)

func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
	tri(a, b, c, col)
	tri(a, c, d, col)

func quad_out(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, inside: Vector3) -> void:
	tri_out(a, b, c, col, inside)
	tri_out(a, c, d, col, inside)

## Double sided quad (leaves, cloth, banners).
func quad2(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
	quad(a, b, c, d, col)
	quad(a, d, c, b, col)

func push(t: Transform3D) -> Transform3D:
	var old := xf
	xf = xf * t
	return old

func pop(old: Transform3D) -> void:
	xf = old

static func T(pos: Vector3, rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> Transform3D:
	var b := Basis.from_euler(rot).scaled(scl)
	return Transform3D(b, pos)

# ------------------------------------------------------------------ primitives

func box(center: Vector3, size: Vector3, col: Color, rot: Vector3 = Vector3.ZERO, shade_top: float = 1.0) -> void:
	var old := push(T(center, rot))
	var h := size * 0.5
	var c := [
		Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(-h.x, h.y, -h.z),
		Vector3(-h.x, -h.y, h.z), Vector3(h.x, -h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z),
	]
	var top := col if shade_top == 1.0 else col.lightened(shade_top - 1.0) if shade_top > 1.0 else col.darkened(1.0 - shade_top)
	var side := col.darkened(0.06)
	var o := Vector3.ZERO
	quad_out(c[0], c[1], c[2], c[3], side, o)
	quad_out(c[5], c[4], c[7], c[6], side, o)
	quad_out(c[4], c[0], c[3], c[7], side, o)
	quad_out(c[1], c[5], c[6], c[2], side, o)
	quad_out(c[3], c[2], c[6], c[7], top, o)
	quad_out(c[4], c[5], c[1], c[0], col.darkened(0.25), o)
	pop(old)

## Tapered cylinder / frustum along +Y from `base`.
func cyl(base: Vector3, r_bot: float, r_top: float, h: float, segs: int, col: Color, rot: Vector3 = Vector3.ZERO, cap_top: bool = true, cap_bot: bool = false, top_col = null) -> void:
	var old := push(T(base, rot))
	var inside := Vector3(0, h * 0.5, 0)
	var tc: Color = top_col if top_col != null else col.lightened(0.05)
	for i in segs:
		var a0 := TAU * float(i) / segs
		var a1 := TAU * float(i + 1) / segs
		var b0 := Vector3(cos(a0) * r_bot, 0, sin(a0) * r_bot)
		var b1 := Vector3(cos(a1) * r_bot, 0, sin(a1) * r_bot)
		var t0 := Vector3(cos(a0) * r_top, h, sin(a0) * r_top)
		var t1 := Vector3(cos(a1) * r_top, h, sin(a1) * r_top)
		var shade := col.darkened(0.08 * (0.5 + 0.5 * sin(a0 + 0.8)))
		if r_top <= 0.001:
			tri_out(b0, b1, t0, shade, inside)
		elif r_bot <= 0.001:
			tri_out(b0, t1, t0, shade, inside)
		else:
			quad_out(b0, b1, t1, t0, shade, inside)
		if cap_top and r_top > 0.001:
			tri_out(Vector3(0, h, 0), t0, t1, tc, inside)
		if cap_bot and r_bot > 0.001:
			tri_out(Vector3(0, 0, 0), b0, b1, col.darkened(0.25), inside)
	pop(old)

func cone(base: Vector3, r: float, h: float, segs: int, col: Color, rot: Vector3 = Vector3.ZERO) -> void:
	cyl(base, r, 0.0, h, segs, col, rot, false, true)

## Low-poly UV sphere (squashable). jitter > 0 roughens it into a rock/blob.
func sphere(center: Vector3, r: Vector3, col: Color, rings: int = 4, segs: int = 7, jitter: float = 0.0, rot: Vector3 = Vector3.ZERO, col_bottom = null) -> void:
	var old := push(T(center, rot))
	var pts := []
	for i in rings + 1:
		var lat := -PI / 2.0 + PI * float(i) / rings
		var row := []
		for j in segs:
			var lon := TAU * float(j) / segs + (0.3 * i)
			var p := Vector3(cos(lat) * cos(lon), sin(lat), cos(lat) * sin(lon))
			if jitter > 0.0 and i > 0 and i < rings:
				p *= 1.0 + rng.randf_range(-jitter, jitter)
			row.append(p * r)
		pts.append(row)
	var cb: Color = col_bottom if col_bottom != null else col.darkened(0.18)
	for i in rings:
		for j in segs:
			var j1 := (j + 1) % segs
			var a: Vector3 = pts[i][j]
			var b: Vector3 = pts[i][j1]
			var c: Vector3 = pts[i + 1][j1]
			var d: Vector3 = pts[i + 1][j]
			var t = float(i) / max(1, rings - 1)
			var cc := cb.lerp(col, clamp(t, 0.0, 1.0))
			quad_out(a, b, c, d, cc, Vector3.ZERO)
	pop(old)

## Icosphere-based organic blob (foliage clumps, bushes, boulders).
func blob(center: Vector3, r: Vector3, col: Color, jitter: float = 0.15, subdiv: int = 1, rot: Vector3 = Vector3.ZERO, col_bottom = null) -> void:
	var old := push(T(center, rot))
	var t := (1.0 + sqrt(5.0)) / 2.0
	var verts := [
		Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
		Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
		Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1),
	]
	for i in verts.size():
		verts[i] = verts[i].normalized()
	var faces := [
		[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
		[3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9], [4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1],
	]
	for s in subdiv:
		var cache := {}
		var nf := []
		for f in faces:
			var m := []
			for k in 3:
				var a: int = f[k]
				var b: int = f[(k + 1) % 3]
				var key := Vector2i(min(a, b), max(a, b))
				if not cache.has(key):
					verts.append(((verts[a] + verts[b]) * 0.5).normalized())
					cache[key] = verts.size() - 1
				m.append(cache[key])
			nf.append([f[0], m[0], m[2]])
			nf.append([f[1], m[1], m[0]])
			nf.append([f[2], m[2], m[1]])
			nf.append([m[0], m[1], m[2]])
		faces = nf
	var jit := []
	for v in verts:
		jit.append(v * (1.0 + rng.randf_range(-jitter, jitter)) * r)
	var cb: Color = col_bottom if col_bottom != null else col.darkened(0.22)
	for f in faces:
		var a: Vector3 = jit[f[0]]
		var b: Vector3 = jit[f[1]]
		var c: Vector3 = jit[f[2]]
		var hy = ((a + b + c) / 3.0).y / max(0.001, r.y)
		var cc := cb.lerp(col, clamp(hy * 0.5 + 0.6, 0.0, 1.0))
		cc = cc.lightened(rng.randf_range(-0.03, 0.05))
		tri_out(a, b, c, cc, Vector3.ZERO)
	pop(old)

## A flat polygon (convex or star-shaped around its centroid) facing +Y.
func disc(center: Vector3, r: float, segs: int, col: Color, y_up: bool = true) -> void:
	for i in segs:
		var a0 := TAU * float(i) / segs
		var a1 := TAU * float(i + 1) / segs
		var p0 := center + Vector3(cos(a0) * r, 0, sin(a0) * r)
		var p1 := center + Vector3(cos(a1) * r, 0, sin(a1) * r)
		if y_up:
			tri_out(center, p0, p1, col, center - Vector3(0, 1, 0))
		else:
			tri_out(center, p0, p1, col, center + Vector3(0, 1, 0))

## Upright double-sided blade / leaf card.
func blade(base: Vector3, w: float, h: float, lean: Vector3, col: Color, tip_col = null) -> void:
	var tc: Color = tip_col if tip_col != null else col.lightened(0.2)
	var right := Vector3(w * 0.5, 0, 0)
	var top := base + Vector3(0, h, 0) + lean
	tri(base - right, base + right, top, col, col, tc)
	tri(base + right, base - right, top, col, col, tc)

func commit(mesh: ArrayMesh = null) -> ArrayMesh:
	var m := mesh if mesh != null else ArrayMesh.new()
	for nm in surfaces:
		var buf: Dictionary = surfaces[nm]
		if buf["v"].is_empty():
			continue
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = buf["v"]
		arrays[Mesh.ARRAY_NORMAL] = buf["n"]
		arrays[Mesh.ARRAY_COLOR] = buf["c"]
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		m.surface_set_material(m.get_surface_count() - 1, Meshes.mat(nm))
		m.surface_set_name(m.get_surface_count() - 1, nm)
	return m

func is_empty() -> bool:
	for nm in surfaces:
		if not surfaces[nm]["v"].is_empty():
			return false
	return true
