class_name Enemy
extends Node3D
## A cave creature. The host runs its AI; everyone else interpolates snapshots.
## Every attack is telegraphed (a wind-up and a marking on the ground) so that
## dodging and positioning matter more than raw stats.

enum S { IDLE, MOVE, WINDUP, ATTACK, RECOVER, STUNNED, BURROWED, EMERGE, CHARGE, HOP }

const STATS := {
	"bat": {"name": "Cave Bat", "hp": 14.0, "dmg": 6.0, "speed": 4.6, "radius": 0.45, "aggro": 11.0, "fly": true, "kb": 1.0},
	"burrower": {"name": "Burrower", "hp": 26.0, "dmg": 10.0, "speed": 4.4, "radius": 0.55, "aggro": 10.0, "kb": 0.8},
	"beetle": {"name": "Shellback", "hp": 42.0, "dmg": 12.0, "speed": 2.2, "radius": 0.85, "aggro": 9.0, "kb": 0.35},
	"slime": {"name": "Mossling", "hp": 22.0, "dmg": 8.0, "speed": 3.2, "radius": 0.6, "aggro": 9.0, "kb": 1.2},
	"spitter": {"name": "Spore Spitter", "hp": 24.0, "dmg": 9.0, "speed": 0.0, "radius": 0.6, "aggro": 12.0, "kb": 0.0},
	"golem": {"name": "Crystal Golem", "hp": 90.0, "dmg": 20.0, "speed": 1.7, "radius": 1.0, "aggro": 10.0, "kb": 0.25},
	"salamander": {"name": "Ember Salamander", "hp": 40.0, "dmg": 13.0, "speed": 4.3, "radius": 0.6, "aggro": 11.0, "kb": 0.8},
	"sentinel": {"name": "Ancient Sentinel", "hp": 110.0, "dmg": 22.0, "speed": 1.9, "radius": 0.9, "aggro": 13.0, "kb": 0.3},
}
const BIOME_TINT := [Color("8a6a4a"), Color("5a8a5a"), Color("6a7aaa"), Color("8a5a8a"), Color("aa5a3a"), Color("7a7a8a")]

var eid := 0
var etype := "bat"
var level := 1
var zone_id := ""
var zone: Zone
var elite := false
var authority := false
var hp := 10.0
var max_hp := 10.0
var dead := false
var state := S.IDLE
var state_t := 0.0
var radius := 0.6
var st := {}
# server AI
var target = null
var home := Vector3.ZERO
var path := PackedVector3Array()
var path_i := 0
var repath_t := 0.0
var attack_cd := 1.0
var kb_vel := Vector3.ZERO
var charge_dir := Vector3.ZERO
var hit_list := {}
var slow_t := 0.0
var burn_t := 0.0
var burn_tick := 0.0
var trail: Array = []
var _trail_t := 0.0
var _think_t := 0.0
var last_hitter := 0
# visuals
var model: Node3D
var body_mi: MeshInstance3D
var parts := {}
var flash_mat: StandardMaterial3D
var telegraph: MeshInstance3D
var hp_bar: Node3D
var hp_fill: MeshInstance3D
var mound: MeshInstance3D
var _anim_t := 0.0
var _net_pos := Vector3.ZERO
var _net_yaw := 0.0
var _show_hp_t := 0.0

static func base_hp(t: String, lvl: int, elite_v: bool) -> float:
	var s: Dictionary = STATS.get(t, STATS["bat"])
	return float(s["hp"]) * (1.0 + 0.15 * (lvl - 1)) * (3.0 if elite_v else 1.0)

func dmg() -> float:
	return float(st["dmg"]) * (1.0 + 0.07 * (level - 1)) * (1.4 if elite else 1.0)

func display_name() -> String:
	return ("Elder " if elite else "") + st["name"]

func setup(h: float) -> void:
	st = STATS.get(etype, STATS["bat"])
	radius = float(st["radius"]) * (1.35 if elite else 1.0)
	max_hp = base_hp(etype, level, elite)
	hp = h
	home = global_position
	_net_pos = global_position
	attack_cd = randf_range(0.5, 2.0)
	if etype == "burrower":
		state = S.BURROWED
	elif etype == "bat":
		state = S.MOVE
	_build_model()

func untargetable() -> bool:
	return state == S.BURROWED or dead

func facing_away_from(p: Vector3) -> bool:
	var fwd := Vector3(sin(rotation.y), 0, cos(rotation.y))
	var to := p - global_position
	to.y = 0
	return fwd.dot(to.normalized()) < -0.3

func state_code() -> int:
	return state

# ------------------------------------------------------------------ models

func _build_model() -> void:
	model = Node3D.new()
	add_child(model)
	var bi := CaveGen.biome_index(level)
	var tint: Color = BIOME_TINT[bi]
	var mb := MeshBuilder.new(eid)
	var eye := Color("ffe08a") if elite else Color("ff5a3a")
	match etype:
		"bat":
			mb.sphere(Vector3(0, 0, 0), Vector3(0.28, 0.25, 0.3), Color("4a3a4a").lerp(tint, 0.2), 3, 7)
			mb.cone(Vector3(-0.12, 0.2, 0.0), 0.07, 0.18, 4, Color("3a2a3a"))
			mb.cone(Vector3(0.12, 0.2, 0.0), 0.07, 0.18, 4, Color("3a2a3a"))
			mb.surface("glow_steady")
			for s in [-1, 1]:
				mb.sphere(Vector3(s * 0.09, 0.05, 0.25), Vector3.ONE * 0.04, eye, 2, 4)
			mb.surface("vc")
			for s in [-1, 1]:
				var w := MeshBuilder.new(eid + s)
				w.surface("foliage_still")
				w.tri(Vector3(0, 0, 0.12), Vector3(s * 0.75, 0.1, 0.0), Vector3(0, 0, -0.18), Color("3a2a3a"))
				w.tri(Vector3(s * 0.75, 0.1, 0.0), Vector3(s * 0.45, -0.05, -0.25), Vector3(0, 0, -0.18), Color("2a1a2a"))
				var wp := Node3D.new()
				wp.position = Vector3(s * 0.2, 0.05, 0)
				model.add_child(wp)
				var wmi := MeshInstance3D.new()
				wmi.mesh = w.commit()
				wp.add_child(wmi)
				parts["wing%d" % s] = wp
		"burrower":
			mb.sphere(Vector3(0, 0.35, 0), Vector3(0.45, 0.35, 0.6), Color("7a5a4a").lerp(tint, 0.2), 4, 8)
			mb.cone(Vector3(0, 0.38, 0.5), 0.16, 0.35, 6, Color("e8a0a0"), Vector3(PI / 2, 0, 0))
			for s in [-1, 1]:
				mb.box(Vector3(s * 0.35, 0.15, 0.4), Vector3(0.18, 0.08, 0.25), Color("e8d8c0"), Vector3(0, s * 0.3, 0))
			mb.surface("glow_steady")
			for s in [-1, 1]:
				mb.sphere(Vector3(s * 0.14, 0.52, 0.42), Vector3.ONE * 0.035, eye, 2, 4)
			mb.surface("vc")
		"beetle":
			var shell := Color("3a5a8a").lerp(tint, 0.35)
			mb.sphere(Vector3(0, 0.45, -0.1), Vector3(0.75, 0.45, 0.9), shell, 4, 9, 0.0, Vector3.ZERO, shell.darkened(0.4))
			mb.box(Vector3(0, 0.75, -0.1), Vector3(0.05, 0.1, 1.5), shell.darkened(0.3))
			mb.sphere(Vector3(0, 0.35, 0.8), Vector3(0.35, 0.28, 0.3), Color("2a2a30"), 3, 7)
			mb.cone(Vector3(0, 0.45, 1.0), 0.12, 0.5, 5, Color("d8d0b0"), Vector3(PI / 2.4, 0, 0))
			for i in 3:
				for s in [-1, 1]:
					mb.cyl(Vector3(s * 0.55, 0.25, -0.4 + i * 0.4), 0.05, 0.03, 0.55, 4, Color("2a2a30"), Vector3(0, 0, s * 1.9))
			mb.surface("glow_steady")
			for s in [-1, 1]:
				mb.sphere(Vector3(s * 0.15, 0.45, 1.05), Vector3.ONE * 0.05, eye, 2, 4)
			mb.surface("vc")
		"slime":
			mb.surface("vc_shiny")
			mb.sphere(Vector3(0, 0.38, 0), Vector3(0.6, 0.42, 0.6), Color("6ac05a").lerp(tint, 0.4), 4, 9, 0.0, Vector3.ZERO, Color("3a7a3a").lerp(tint, 0.4))
			mb.surface("vc")
			for s in [-1, 1]:
				mb.sphere(Vector3(s * 0.18, 0.55, 0.48), Vector3(0.09, 0.11, 0.05), Color("1a1a1a"), 2, 5)
			mb.surface("plant")
			mb.blob(Vector3(0.1, 0.78, 0), Vector3(0.22, 0.08, 0.2), Color("5a9a4a"), 0.3, 0)
			mb.surface("vc")
		"spitter":
			mb.cyl(Vector3.ZERO, 0.32, 0.25, 0.6, 7, Color("e8dcc8"))
			mb.sphere(Vector3(0, 0.75, 0), Vector3(0.65, 0.4, 0.65), Color("b85a8a").lerp(tint, 0.3), 3, 9, 0.0, Vector3.ZERO, Color("6a2a4a"))
			mb.surface("glow")
			for i in 6:
				var a := TAU * i / 6.0
				mb.sphere(Vector3(cos(a) * 0.4, 0.95, sin(a) * 0.4), Vector3.ONE * 0.08, Color("e8ff8a"), 2, 4)
			mb.surface("vc")
			mb.cyl(Vector3(0, 0.6, 0.45), 0.15, 0.2, 0.2, 7, Color("4a1a2a"), Vector3(PI / 2, 0, 0))
		"golem":
			var rock := Color("6a6a78").lerp(tint, 0.3)
			mb.blob(Vector3(0, 1.3, 0), Vector3(0.85, 0.75, 0.6), rock, 0.15, 1)
			mb.blob(Vector3(0, 2.0, 0.15), Vector3(0.4, 0.35, 0.35), rock.lightened(0.05), 0.15, 0)
			for s in [-1, 1]:
				mb.blob(Vector3(s * 1.0, 1.0, 0.1), Vector3(0.35, 0.65, 0.35), rock.darkened(0.05), 0.2, 0)
				mb.blob(Vector3(s * 0.4, 0.35, 0), Vector3(0.3, 0.4, 0.3), rock.darkened(0.1), 0.2, 0)
			mb.surface("glow")
			for i in 4:
				var a2 := TAU * i / 4.0
				mb.cyl(Vector3(cos(a2) * 0.35, 1.8, sin(a2) * 0.25 - 0.2), 0.1, 0.0, 0.5, 5, Color("8fd8ff"), Vector3(cos(a2) * 0.4, 0, sin(a2) * 0.4))
			mb.sphere(Vector3(0, 2.05, 0.45), Vector3(0.18, 0.06, 0.05), eye if elite else Color("8fd8ff"), 2, 5)
			mb.surface("vc")
		"salamander":
			var red := Color("c84a2a").lerp(tint, 0.2)
			mb.sphere(Vector3(0, 0.3, 0), Vector3(0.3, 0.22, 0.75), red, 3, 8)
			mb.sphere(Vector3(0, 0.35, 0.75), Vector3(0.25, 0.18, 0.3), red.lightened(0.1), 3, 7)
			mb.cone(Vector3(0, 0.28, -0.6), 0.18, 0.8, 5, red.darkened(0.15), Vector3(-PI / 2, 0, 0))
			for i in 2:
				for s in [-1, 1]:
					mb.cyl(Vector3(s * 0.25, 0.2, -0.25 + i * 0.5), 0.06, 0.05, 0.3, 4, red.darkened(0.2), Vector3(0, 0, s * 1.4))
			mb.surface("glow")
			for i in 5:
				mb.cone(Vector3(0, 0.48, 0.4 - i * 0.25), 0.07, 0.2, 4, Color("ffa040"))
			mb.surface("vc")
		"sentinel":
			var stone := Color("8a8a96")
			mb.box(Vector3(0, 1.1, 0), Vector3(0.9, 1.2, 0.6), stone)
			mb.box(Vector3(0, 2.0, 0), Vector3(0.6, 0.55, 0.55), stone.lightened(0.05))
			for s in [-1, 1]:
				mb.box(Vector3(s * 0.65, 1.2, 0), Vector3(0.3, 1.0, 0.35), stone.darkened(0.05))
				mb.box(Vector3(s * 0.25, 0.25, 0), Vector3(0.3, 0.5, 0.35), stone.darkened(0.1))
			mb.cone(Vector3(0, 2.3, 0), 0.4, 0.4, 4, Color("c8a85a"), Vector3(0, PI / 4, 0))
			mb.surface("glow")
			mb.box(Vector3(0, 2.0, 0.28), Vector3(0.4, 0.08, 0.02), Color("7fe3ff") if not elite else eye)
			mb.box(Vector3(0, 1.2, 0.31), Vector3(0.15, 0.4, 0.02), Color("7fe3ff"))
			mb.surface("vc")
	body_mi = MeshInstance3D.new()
	body_mi.mesh = mb.commit()
	model.add_child(body_mi)
	if etype == "bat":
		model.position.y = 1.5
	if elite:
		model.scale = Vector3.ONE * 1.35
		var l := OmniLight3D.new()
		l.light_color = Color("ffd36b")
		l.light_energy = 0.8
		l.omni_range = 4.0
		l.position = Vector3(0, 1.5, 0)
		add_child(l)
	flash_mat = Meshes.mat("flash").duplicate()
	body_mi.material_overlay = flash_mat
	telegraph = MeshInstance3D.new()
	telegraph.visible = false
	telegraph.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	telegraph.top_level = true
	add_child(telegraph)
	if etype == "burrower":
		mound = MeshInstance3D.new()
		mound.mesh = Props.get_mesh("clay_mound", 0)
		mound.scale = Vector3(0.8, 1.5, 0.8)
		add_child(mound)
	_build_hp_bar()

func _build_hp_bar() -> void:
	hp_bar = Node3D.new()
	hp_bar.position = Vector3(0, 2.6 if etype in ["golem", "sentinel"] else 1.6, 0)
	if etype == "bat":
		hp_bar.position.y = 2.4
	add_child(hp_bar)
	var bg := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.0, 0.1)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0, 0, 0, 0.6)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.no_depth_test = true
	q.material = m
	bg.mesh = q
	hp_bar.add_child(bg)
	hp_fill = MeshInstance3D.new()
	var q2 := QuadMesh.new()
	q2.size = Vector2(0.96, 0.07)
	var m2 := m.duplicate()
	m2.albedo_color = Color("e05a4a") if not elite else Color("ffd36b")
	m2.render_priority = 1
	q2.material = m2
	hp_fill.mesh = q2
	hp_bar.add_child(hp_fill)
	hp_bar.visible = false

# ------------------------------------------------------------------ network

func apply_snapshot(p: Vector3, yaw: float, s: int, h: float, t: float) -> void:
	_net_pos = p
	_net_yaw = yaw
	if s != state:
		state = s
		_on_state_visual()
	state_t = t
	if h < hp:
		_show_hp_t = 4.0
	hp = h

# ------------------------------------------------------------------ main loop

func _physics_process(delta: float) -> void:
	if dead:
		return
	if authority:
		_think(delta)
	else:
		global_position = global_position.lerp(_net_pos, 1.0 - exp(-delta * 12.0))
		rotation.y = lerp_angle(rotation.y, _net_yaw, 1.0 - exp(-delta * 12.0))
		state_t += delta
	_animate(delta)

func _set_state(s: int) -> void:
	state = s
	state_t = 0.0
	_on_state_visual()

func _on_state_visual() -> void:
	if state == S.WINDUP or state == S.EMERGE:
		Sfx.play_at("telegraph", global_position, -8.0)
		if etype in ["beetle", "golem", "salamander"]:
			Sfx.play_at("growl" if etype != "beetle" else "charge", global_position, -4.0)
		if etype == "bat":
			Sfx.play_at("bat", global_position, -6.0)
	if state == S.ATTACK and etype in ["golem"]:
		Sfx.play_at("slam", global_position)
		Fx.ring(zone.fx_root, global_position, 3.2, Color(1, 0.6, 0.4, 0.7))
		if Game.main and Game.local_player and Game.local_player.global_position.distance_to(global_position) < 9.0:
			Game.main.cam.shake(0.25)
	if state == S.BURROWED:
		Sfx.play_at("burrow", global_position, -6.0)
	if state == S.EMERGE:
		Fx.dust(zone.fx_root, global_position)

# ------------------------------------------------------------------ AI (host only)

func _players() -> Array:
	var out: Array = []
	for p in Zones.players_in_zone(zone_id):
		if not p.downed and not p.sleeping:
			out.append(p)
	return out

func _pick_target() -> void:
	var best = null
	var bd: float = float(st["aggro"]) * (1.3 if target != null else 1.0)
	for p in _players():
		var d: float = p.global_position.distance_to(global_position)
		if d < bd and (d < 4.0 or _los(p.global_position)):
			bd = d
			best = p
	target = best

func _los(p: Vector3) -> bool:
	var a := global_position
	var n := int(a.distance_to(p) / 0.6)
	for i in range(1, n):
		var q := a.lerp(p, float(i) / n)
		if (zone as CaveFloor).cell_type(q) == CaveGen.T.WALL:
			return false
	return true

func _move(dir: Vector3, speed: float, delta: float, flying: bool = false) -> bool:
	dir.y = 0
	if dir.length() < 0.001:
		return true
	dir = dir.normalized()
	if slow_t > 0.0:
		speed *= 0.5
	var step := dir * speed * delta
	var cf := zone as CaveFloor
	var np := global_position + step
	if cf.can_stand(np + dir * radius * 0.6, flying):
		global_position = np
		return true
	var sx := Vector3(step.x, 0, 0)
	var sz := Vector3(0, 0, step.z)
	if abs(step.x) > 0.0001 and cf.can_stand(global_position + sx + sx.normalized() * radius * 0.6, flying):
		global_position += sx
		return false
	if abs(step.z) > 0.0001 and cf.can_stand(global_position + sz + sz.normalized() * radius * 0.6, flying):
		global_position += sz
		return false
	return false

func _chase(delta: float, speed: float) -> void:
	if target == null:
		return
	var tp: Vector3 = target.global_position
	if _los(tp):
		path = PackedVector3Array()
		_face(tp, delta)
		_move(tp - global_position, speed, delta)
		return
	repath_t -= delta
	if repath_t <= 0.0 or path_i >= path.size():
		repath_t = 0.7
		path = (zone as CaveFloor).path_to(global_position, tp)
		path_i = 1
	if path_i < path.size():
		var wp := path[path_i]
		if Vector2(wp.x - global_position.x, wp.z - global_position.z).length() < 0.4:
			path_i += 1
		else:
			_face(wp, delta)
			_move(wp - global_position, speed, delta)

func _face(p: Vector3, delta: float, rate: float = 8.0) -> void:
	var d := p - global_position
	if Vector2(d.x, d.z).length() > 0.05:
		rotation.y = lerp_angle(rotation.y, atan2(d.x, d.z), 1.0 - exp(-delta * rate))

func _separate(delta: float) -> void:
	for e in Zones.enemies.values():
		if e == self or not is_instance_valid(e) or e.zone_id != zone_id:
			continue
		var d: Vector3 = global_position - e.global_position
		d.y = 0
		var minr: float = radius + e.radius
		if d.length() < minr and d.length() > 0.01:
			_move(d, (minr - d.length()) * 4.0, delta, etype == "bat")

func _hurt_players_in(center: Vector3, r: float, amount: float, src: String, once: bool = false) -> void:
	for p in _players():
		var d: Vector3 = p.global_position - center
		d.y = 0
		if d.length() <= r + 0.35:
			if once:
				if hit_list.has(p.peer_id):
					continue
				hit_list[p.peer_id] = true
			Zones.hurt_player(p.peer_id, amount, center, src)

func _think(delta: float) -> void:
	state_t += delta
	attack_cd -= delta
	slow_t = max(0.0, slow_t - delta)
	if burn_t > 0.0:
		burn_t -= delta
		burn_tick -= delta
		if burn_tick <= 0.0:
			burn_tick = 0.5
			Zones._server_hit(last_hitter, eid, 2.0 + level * 0.4, Vector3.ZERO, false, {})
			if dead:
				return
	if kb_vel.length() > 0.05:
		_move(kb_vel, kb_vel.length(), delta, etype == "bat")
		kb_vel = kb_vel.lerp(Vector3.ZERO, 1.0 - exp(-delta * 9.0))
	_think_t -= delta
	if _think_t <= 0.0:
		_think_t = 0.3
		if state in [S.IDLE, S.MOVE, S.BURROWED, S.HOP]:
			_pick_target()
	match etype:
		"bat":
			_ai_bat(delta)
		"burrower":
			_ai_burrower(delta)
		"beetle":
			_ai_beetle(delta)
		"slime":
			_ai_slime(delta)
		"spitter":
			_ai_spitter(delta)
		"golem":
			_ai_golem(delta)
		"salamander":
			_ai_salamander(delta)
		"sentinel":
			_ai_sentinel(delta)
	if state != S.CHARGE:
		_separate(delta)

func _wander(delta: float, speed: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0 + eid * 3.1
	var goal := home + Vector3(sin(t * 0.3) * 3.0, 0, cos(t * 0.23) * 3.0)
	if global_position.distance_to(goal) > 0.5:
		_face(goal, delta, 3.0)
		_move(goal - global_position, speed * 0.35, delta, etype == "bat")

func _ai_bat(delta: float) -> void:
	match state:
		S.MOVE, S.IDLE:
			if target == null:
				_wander(delta, float(st["speed"]))
				return
			var tp: Vector3 = target.global_position
			var t := state_t * 2.2 + eid
			var orbit := tp + Vector3(sin(t) * 3.2, 0, cos(t) * 3.2)
			_face(tp, delta)
			_move(orbit - global_position, float(st["speed"]), delta, true)
			if attack_cd <= 0.0 and global_position.distance_to(tp) < 5.5:
				_set_state(S.WINDUP)
		S.WINDUP:
			if target:
				_face(target.global_position, delta, 12.0)
			if state_t > 0.4:
				charge_dir = Vector3(sin(rotation.y), 0, cos(rotation.y))
				hit_list.clear()
				_set_state(S.CHARGE)
		S.CHARGE:
			_move(charge_dir, 8.0, delta, true)
			_hurt_players_in(global_position, radius + 0.3, dmg(), "bat", true)
			if state_t > 0.45:
				attack_cd = randf_range(1.6, 2.8)
				_set_state(S.RECOVER)
		S.RECOVER:
			_move(-charge_dir, 2.5, delta, true)
			if state_t > 0.6:
				_set_state(S.MOVE)

func _ai_burrower(delta: float) -> void:
	match state:
		S.BURROWED:
			if target == null:
				_wander(delta, 3.0)
				return
			_chase(delta, float(st["speed"]))
			var d: float = global_position.distance_to(target.global_position)
			if d < 1.4 and state_t > 0.8:
				_set_state(S.EMERGE)
		S.EMERGE:
			if state_t > 0.7:
				hit_list.clear()
				_hurt_players_in(global_position, 1.8, dmg(), "burrower", true)
				_set_state(S.RECOVER)
		S.RECOVER:
			if target:
				_face(target.global_position, delta, 3.0)
			if state_t > 1.9:
				_set_state(S.BURROWED)
		_:
			_set_state(S.BURROWED)

func _ai_beetle(delta: float) -> void:
	match state:
		S.IDLE, S.MOVE:
			if target == null:
				_wander(delta, float(st["speed"]))
				return
			var d: float = global_position.distance_to(target.global_position)
			if d < 8.0 and attack_cd <= 0.0 and _los(target.global_position):
				_set_state(S.WINDUP)
			else:
				_chase(delta, float(st["speed"]))
		S.WINDUP:
			if target:
				_face(target.global_position, delta, 6.0 if state_t < 0.6 else 0.5)
			if state_t > 0.95:
				charge_dir = Vector3(sin(rotation.y), 0, cos(rotation.y))
				hit_list.clear()
				_set_state(S.CHARGE)
		S.CHARGE:
			var ok := _move(charge_dir, 9.5, delta)
			_hurt_players_in(global_position + charge_dir * radius * 0.6, radius + 0.2, dmg(), "beetle", true)
			if not ok:
				Fx.burst(zone.fx_root, global_position + charge_dir * radius + Vector3(0, 0.6, 0), Color("8a7a6a"), 12, 4.0)
				Zones.fx(zone_id, "burst", global_position + charge_dir * radius + Vector3(0, 0.6, 0), {"c": Color("8a7a6a"), "s": "slam"})
				Sfx.play_at("slam", global_position)
				_set_state(S.STUNNED)
			elif state_t > 1.3:
				attack_cd = randf_range(2.0, 3.0)
				_set_state(S.RECOVER)
		S.STUNNED:
			if state_t > 2.3:
				attack_cd = 1.0
				_set_state(S.MOVE)
		S.RECOVER:
			if state_t > 0.8:
				_set_state(S.MOVE)

func _ai_slime(delta: float) -> void:
	match state:
		S.IDLE, S.MOVE, S.HOP:
			if target == null:
				_wander(delta, 2.0)
				return
			if state != S.HOP and state_t > 0.75:
				_set_state(S.HOP)
				charge_dir = (target.global_position - global_position)
				charge_dir.y = 0
				charge_dir = charge_dir.normalized()
				hit_list.clear()
			if state == S.HOP:
				_face(global_position + charge_dir, delta)
				_move(charge_dir, float(st["speed"]) * 1.4, delta)
				if state_t > 0.45:
					_hurt_players_in(global_position, radius + 0.25, dmg(), "slime", true)
					_set_state(S.MOVE)

func _ai_spitter(delta: float) -> void:
	match state:
		S.IDLE, S.MOVE:
			if target and attack_cd <= 0.0:
				_set_state(S.WINDUP)
		S.WINDUP:
			if target:
				_face(target.global_position, delta)
			if state_t > 0.9:
				if target:
					var tp: Vector3 = target.global_position
					var from := global_position + Vector3(0, 1.0, 0)
					var tt := 0.9
					var v := (tp - from) / tt
					v.y = (tp.y - from.y) / tt + 0.5 * 22.0 * tt
					Zones.fire_projectile(zone_id, "spit", from, v, dmg(), 0, {"g": 22.0, "aoe": 1.4})
					Sfx.play_at("spit", global_position)
				attack_cd = randf_range(1.8, 2.6)
				_set_state(S.RECOVER)
		S.RECOVER:
			if state_t > 1.0:
				_set_state(S.IDLE)

func _ai_golem(delta: float) -> void:
	match state:
		S.IDLE, S.MOVE:
			if target == null:
				_wander(delta, float(st["speed"]))
				return
			var d: float = global_position.distance_to(target.global_position)
			if d < 3.0 and attack_cd <= 0.0:
				_set_state(S.WINDUP)
			elif d > 6.0 and d < 11.0 and attack_cd <= -2.0 and _los(target.global_position):
				_set_state(S.EMERGE)
			else:
				_chase(delta, float(st["speed"]))
		S.WINDUP:
			if state_t > 1.1:
				_hurt_players_in(global_position, 3.2, dmg(), "golem")
				attack_cd = randf_range(2.0, 3.0)
				_set_state(S.ATTACK)
		S.EMERGE:
			if target:
				_face(target.global_position, delta, 5.0)
			if state_t > 0.85:
				var dir := Vector3(sin(rotation.y), 0, cos(rotation.y))
				Zones.fire_projectile(zone_id, "shard", global_position + Vector3(0, 1.6, 0) + dir, dir * 15.0, dmg() * 0.6, 0, {})
				attack_cd = 1.5
				_set_state(S.RECOVER)
		S.ATTACK:
			if state_t > 0.3:
				_set_state(S.RECOVER)
		S.RECOVER:
			if state_t > 1.0:
				_set_state(S.MOVE)

func _ai_salamander(delta: float) -> void:
	_trail_t -= delta
	if _trail_t <= 0.0 and state in [S.MOVE, S.CHARGE]:
		_trail_t = 0.3
		trail.append({"p": global_position, "t": 3.0})
		Zones.fx(zone_id, "sparkle", global_position, {"c": Color("ff8a3a")})
		Fx.sparkle(zone.fx_root, global_position, Color("ff8a3a"), 4, 0.3)
	for tp in trail:
		tp["t"] = float(tp["t"]) - delta
	trail = trail.filter(func(x): return float(x["t"]) > 0.0)
	if int(state_t * 2.0) != int((state_t - delta) * 2.0):
		for tp in trail:
			_hurt_players_in(tp["p"], 0.6, 3.0 + level * 0.2, "fire")
	match state:
		S.IDLE, S.MOVE:
			if target == null:
				_wander(delta, float(st["speed"]))
				return
			var d: float = global_position.distance_to(target.global_position)
			if d < 4.0 and attack_cd <= 0.0:
				_set_state(S.WINDUP)
			else:
				_chase(delta, float(st["speed"]))
		S.WINDUP:
			if target:
				_face(target.global_position, delta, 10.0)
			if state_t > 0.45:
				charge_dir = Vector3(sin(rotation.y), 0, cos(rotation.y))
				hit_list.clear()
				_set_state(S.CHARGE)
		S.CHARGE:
			_move(charge_dir, 8.5, delta)
			_hurt_players_in(global_position + charge_dir * 0.5, radius + 0.2, dmg(), "salamander", true)
			if state_t > 0.38:
				attack_cd = randf_range(1.2, 2.0)
				_set_state(S.RECOVER)
		S.RECOVER:
			if state_t > 0.6:
				_set_state(S.MOVE)

func _ai_sentinel(delta: float) -> void:
	match state:
		S.IDLE, S.MOVE:
			if target == null:
				_wander(delta, float(st["speed"]))
				return
			var d: float = global_position.distance_to(target.global_position)
			if d < 2.6 and attack_cd <= 0.0:
				_set_state(S.HOP)
			elif d < 12.0 and attack_cd <= 0.0 and _los(target.global_position):
				_set_state(S.WINDUP)
			else:
				_chase(delta, float(st["speed"]))
		S.WINDUP:
			if target:
				_face(target.global_position, delta, 4.0 if state_t < 0.6 else 0.3)
			if state_t > 1.05:
				var dir := Vector3(sin(rotation.y), 0, cos(rotation.y))
				for p in _players():
					var rel: Vector3 = p.global_position - global_position
					rel.y = 0
					var along := rel.dot(dir)
					if along > 0.0 and along < 12.0 and (rel - dir * along).length() < 0.9:
						Zones.hurt_player(p.peer_id, dmg(), global_position, "beam")
				attack_cd = randf_range(2.2, 3.2)
				_set_state(S.ATTACK)
		S.HOP:
			if target:
				_face(target.global_position, delta, 6.0)
			if state_t > 0.6:
				var fwd := Vector3(sin(rotation.y), 0, cos(rotation.y))
				_hurt_players_in(global_position + fwd * 1.3, 1.6, dmg() * 0.8, "sentinel")
				attack_cd = 1.2
				_set_state(S.RECOVER)
		S.ATTACK:
			if state_t > 0.35:
				_set_state(S.RECOVER)
		S.RECOVER:
			if state_t > 1.2:
				_set_state(S.MOVE)

## Host applies a hit. Returns the damage actually dealt.
func server_take_hit(amount: float, kb: Vector3, effects: Dictionary, peer: int) -> float:
	if dead or untargetable():
		return 0.0
	var mult := 1.0
	if etype == "beetle" and state != S.STUNNED and kb.length() > 0.01:
		var fwd := Vector3(sin(rotation.y), 0, cos(rotation.y))
		if fwd.dot(-kb.normalized()) > 0.45:
			mult = 0.3
	if state == S.STUNNED:
		mult = 2.0
	var real := amount * mult
	hp -= real
	kb_vel += kb * float(st["kb"]) * (0.5 if elite else 1.0)
	if effects.get("burn", 0.0) > 0.0:
		burn_t = float(effects["burn"])
	if effects.get("slow", 0.0) > 0.0:
		slow_t = float(effects["slow"])
	if peer != 0:
		last_hitter = peer
	if peer != 0 and Net.peers.has(peer):
		var p = Zones.players.get(peer)
		if p and p.zone_id == zone_id:
			target = p
	if etype == "burrower" and state == S.RECOVER and hp > 0:
		state_t = max(state_t, 1.4)
	return real

# ------------------------------------------------------------------ visuals (everyone)

func hit_fx(amount: float, kb: Vector3, crit: bool) -> void:
	if flash_mat:
		flash_mat.albedo_color = Color(1, 1, 1, 0.85)
		var tw := create_tween()
		tw.tween_property(flash_mat, "albedo_color", Color(1, 1, 1, 0.0), 0.15)
	if model:
		var tw2 := create_tween()
		tw2.tween_property(model, "scale", model.scale * Vector3(1.15, 0.85, 1.15), 0.05)
		tw2.tween_property(model, "scale", Vector3.ONE * (1.35 if elite else 1.0), 0.1)
	var armored := amount < 0.5 * float(st["dmg"]) and etype == "beetle"
	var col := Color("ffd36b") if crit else (Color("a0a0a0") if armored else Color.WHITE)
	Fx.float_text(zone.fx_root, global_position + Vector3(0, 1.6 + randf() * 0.4, 0), ("%d!" if crit else "%d") % max(1, int(round(amount))), col, 58 if crit else 44)
	Fx.burst(zone.fx_root, global_position + Vector3(0, 0.7, 0), BIOME_TINT[CaveGen.biome_index(level)].lightened(0.3), 6, 3.0, 0.07)
	Sfx.play_at("hit" if not armored else "clank", global_position)
	_show_hp_t = 4.0
	if crit and Game.main:
		Game.main.cam.shake(0.08)

func die_fx() -> void:
	dead = true
	telegraph.visible = false
	Fx.burst(zone.fx_root, global_position + Vector3(0, 0.6, 0), BIOME_TINT[CaveGen.biome_index(level)].lightened(0.2), 18, 5.0, 0.12)
	Fx.sparkle(zone.fx_root, global_position + Vector3(0, 0.8, 0), Color(1, 1, 0.8), 10, 0.6)
	Sfx.play_at("enemy_die", global_position)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3(1.3, 0.1, 1.3), 0.18)
	tw.tween_callback(queue_free)

func _animate(delta: float) -> void:
	_anim_t += delta
	if model == null:
		return
	if _show_hp_t > 0.0:
		_show_hp_t -= delta
		hp_bar.visible = true
		hp_fill.scale.x = clamp(hp / max(max_hp, 1.0), 0.0, 1.0)
		hp_fill.position.x = -(1.0 - hp_fill.scale.x) * 0.48
	else:
		hp_bar.visible = false
	var base_scale := 1.35 if elite else 1.0
	model.rotation = Vector3.ZERO
	match etype:
		"bat":
			var flap := sin(_anim_t * 18.0) * 0.9
			parts["wing-1"].rotation.z = flap
			parts["wing1"].rotation.z = -flap
			model.position.y = 1.5 + sin(_anim_t * 3.0) * 0.15
			if state == S.CHARGE:
				model.position.y = 1.0
		"burrower":
			var under := state == S.BURROWED
			model.visible = not under
			mound.visible = under or state == S.EMERGE
			if under:
				mound.position.y = 0.0
				if int(_anim_t * 6.0) % 2 == 0 and randf() < 0.3:
					Fx.dust(zone.fx_root, global_position)
			if state == S.EMERGE:
				model.visible = true
				model.position.y = lerp(-0.8, 0.0, clamp(state_t / 0.7, 0.0, 1.0))
			elif not under:
				model.position.y = 0.0
		"beetle":
			if state == S.WINDUP:
				model.rotation.x = -0.15 + sin(_anim_t * 30.0) * 0.03
			elif state == S.CHARGE:
				model.rotation.x = 0.15
			elif state == S.STUNNED:
				model.rotation.z = sin(_anim_t * 6.0) * 0.25
				model.rotation.x = 0.3
			else:
				model.position.y = abs(sin(_anim_t * 8.0)) * 0.03
		"slime":
			var sq := 1.0
			if state == S.HOP:
				model.position.y = sin(clamp(state_t / 0.45, 0.0, 1.0) * PI) * 0.8
				sq = 1.1
			else:
				model.position.y = 0.0
				sq = 1.0 + sin(_anim_t * 5.0) * 0.06
			model.scale = Vector3(base_scale / sqrt(sq), base_scale * sq, base_scale / sqrt(sq))
		"spitter":
			var inflate = 1.0 + (clamp(state_t / 0.9, 0.0, 1.0) * 0.35 if state == S.WINDUP else 0.0) + sin(_anim_t * 2.0) * 0.03
			model.scale = Vector3(inflate, 1.0 / inflate * 1.1, inflate) * base_scale
		"golem":
			if state == S.WINDUP:
				model.position.y = clamp(state_t / 1.1, 0.0, 1.0) * 0.5
				model.rotation.x = -0.25 * clamp(state_t / 1.1, 0.0, 1.0)
			elif state == S.ATTACK:
				model.position.y = 0.0
				model.rotation.x = 0.2
			else:
				model.position.y = abs(sin(_anim_t * 3.0)) * 0.05
		"salamander":
			model.rotation.y = sin(_anim_t * 14.0) * 0.12
		"sentinel":
			model.position.y = sin(_anim_t * 1.5) * 0.06 + 0.1
	_update_telegraph()

func _update_telegraph() -> void:
	var show := false
	var fwd := Vector3(sin(rotation.y), 0, cos(rotation.y))
	var prog := 0.0
	match etype:
		"beetle":
			if state == S.WINDUP:
				show = true
				prog = state_t / 0.95
				_tele_rect(fwd, 9.0, radius * 2.0)
		"golem":
			if state == S.WINDUP:
				show = true
				prog = state_t / 1.1
				_tele_circle(3.2)
			elif state == S.EMERGE:
				show = true
				prog = state_t / 0.85
				_tele_rect(fwd, 12.0, 0.6)
		"burrower":
			if state == S.EMERGE:
				show = true
				prog = state_t / 0.7
				_tele_circle(1.8)
		"sentinel":
			if state == S.WINDUP:
				show = true
				prog = state_t / 1.05
				_tele_rect(fwd, 12.0, 1.8)
			elif state == S.HOP:
				show = true
				prog = state_t / 0.6
				_tele_circle(1.6, global_position + fwd * 1.3)
		"salamander":
			if state == S.WINDUP:
				show = true
				prog = state_t / 0.45
				_tele_rect(fwd, 3.2, 0.9)
		"bat":
			if state == S.WINDUP:
				show = true
				prog = state_t / 0.4
				_tele_rect(fwd, 3.6, 0.7)
		"spitter":
			if state == S.WINDUP and target != null:
				pass
	telegraph.visible = show and not dead
	if show:
		var m: ShaderMaterial = telegraph.material_override
		if m:
			m.set_shader_parameter("prog", clamp(prog, 0.0, 1.0))
			m.set_shader_parameter("col", Color(1.0, 0.25 + 0.35 * (1.0 - prog), 0.15, 0.75))

func _tele_mat() -> ShaderMaterial:
	if telegraph.material_override == null:
		telegraph.material_override = Meshes.mat("telegraph").duplicate()
	return telegraph.material_override

func _tele_circle(r: float, at = null) -> void:
	_tele_mat()
	if not (telegraph.mesh is CylinderMesh):
		var cm := CylinderMesh.new()
		cm.top_radius = 1.0
		cm.bottom_radius = 1.0
		cm.height = 0.02
		cm.radial_segments = 32
		telegraph.mesh = cm
	telegraph.global_position = (at if at != null else global_position) + Vector3(0, 0.06, 0)
	telegraph.scale = Vector3(r, 1.0, r)
	telegraph.material_override.set_shader_parameter("shape", 0.0)
	telegraph.rotation = Vector3.ZERO

func _tele_rect(fwd: Vector3, length: float, width: float) -> void:
	_tele_mat()
	if not (telegraph.mesh is BoxMesh):
		var bm := BoxMesh.new()
		bm.size = Vector3(1, 0.02, 1)
		telegraph.mesh = bm
	telegraph.global_position = global_position + fwd * (length / 2.0) + Vector3(0, 0.06, 0)
	telegraph.rotation = Vector3(0, rotation.y, 0)
	telegraph.scale = Vector3(width, 1.0, length)
	telegraph.material_override.set_shader_parameter("shape", 1.0)
