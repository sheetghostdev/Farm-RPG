class_name Fx
extends RefCounted
## One-shot visual effects: debris bursts, floating text, splashes, sparkles.

static func _auto_free(n: Node, t: float) -> void:
	var tm := n.get_tree().create_timer(t)
	tm.timeout.connect(func(): if is_instance_valid(n): n.queue_free())

static func burst(parent: Node, pos: Vector3, col: Color, count: int = 8, speed: float = 3.0, size: float = 0.09, gravity: float = -14.0) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var p := CPUParticles3D.new()
	p.mesh = Meshes.cube_particle_mesh(size)
	p.amount = count
	p.one_shot = true
	p.explosiveness = 0.95
	p.lifetime = 0.7
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, gravity, 0)
	p.angular_velocity_min = -360.0
	p.angular_velocity_max = 360.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	p.color = col
	var ramp := Gradient.new()
	ramp.set_color(0, col)
	ramp.set_color(1, Color(col.r, col.g, col.b, 0.0))
	p.color_ramp = ramp
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	_auto_free(p, 1.2)

static func sparkle(parent: Node, pos: Vector3, col: Color, count: int = 12, spread_r: float = 0.6) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var p := CPUParticles3D.new()
	p.mesh = Meshes.particle_mesh(0.14, true)
	p.amount = count
	p.one_shot = true
	p.explosiveness = 0.7
	p.lifetime = 0.9
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = spread_r
	p.direction = Vector3.UP
	p.spread = 40.0
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 1.6
	p.gravity = Vector3(0, 0.5, 0)
	var ramp := Gradient.new()
	ramp.set_color(0, col)
	ramp.set_color(1, Color(col.r, col.g, col.b, 0.0))
	p.color_ramp = ramp
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	_auto_free(p, 1.4)

static func splash(parent: Node, pos: Vector3, big: bool = false) -> void:
	burst(parent, pos, Color(0.75, 0.9, 1.0, 0.9), 14 if big else 7, 4.0 if big else 2.5, 0.07, -12.0)

static func dust(parent: Node, pos: Vector3) -> void:
	burst(parent, pos, Color(0.75, 0.68, 0.55, 0.7), 6, 1.5, 0.12, -2.0)

static func float_text(parent: Node, pos: Vector3, text: String, col: Color = Color.WHITE, size: int = 48, rise: float = 1.2, dur: float = 0.9) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.outline_size = 10
	l.modulate = col
	l.outline_modulate = Color(0, 0, 0, 0.7)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.pixel_size = 0.006
	l.render_priority = 5
	l.outline_render_priority = 4
	parent.add_child(l)
	l.global_position = pos
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "global_position", pos + Vector3(randf_range(-0.3, 0.3), rise, 0), dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, dur * 0.5).set_delay(dur * 0.5)
	tw.chain().tween_callback(l.queue_free)

## Expanding flat ring on the ground (hammer slams, level ups, water rings).
static func ring(parent: Node, pos: Vector3, radius: float, col: Color, dur: float = 0.4) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.85
	tm.outer_radius = 1.0
	tm.rings = 24
	tm.ring_segments = 4
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tm.material = m
	mi.mesh = tm
	mi.scale = Vector3(0.2, 0.05, 0.2)
	parent.add_child(mi)
	mi.global_position = pos + Vector3(0, 0.08, 0)
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(radius, 0.05, radius), dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, dur)
	tw.chain().tween_callback(mi.queue_free)

## A slash arc in front of an attacker, for readable melee.
static func slash(parent: Node, pos: Vector3, yaw: float, radius: float, arc_deg: float, col: Color) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var mb := MeshBuilder.new()
	mb.surface("unshaded")
	var segs := 10
	var a0 := -deg_to_rad(arc_deg) / 2.0
	for i in segs:
		var t0 := a0 + deg_to_rad(arc_deg) * i / segs
		var t1 := a0 + deg_to_rad(arc_deg) * (i + 1) / segs
		var p0 := Vector3(sin(t0), 0, cos(t0))
		var p1 := Vector3(sin(t1), 0, cos(t1))
		var ca := Color(col.r, col.g, col.b, 0.0)
		var cb := Color(col.r, col.g, col.b, 0.55 * (float(i + 1) / segs))
		mb.tri(p0 * radius * 0.45, p0 * radius, p1 * radius, ca, cb, cb)
		mb.tri(p0 * radius * 0.45, p1 * radius, p1 * radius * 0.45, ca, cb, ca)
	var mi := MeshInstance3D.new()
	mi.mesh = mb.commit()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = pos
	mi.rotation.y = yaw
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3(1.15, 1, 1.15), 0.14)
	tw.tween_callback(mi.queue_free)
