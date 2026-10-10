class_name Doll
extends Node3D
## A procedurally built, procedurally animated humanoid used for players and townsfolk.

const SKIN_TONES := [Color("f6d7c0"), Color("eac09c"), Color("d9a47c"), Color("b67e58"), Color("8d5a3c"), Color("5e3a26")]
const HAIR_COLORS := [Color("2a1d16"), Color("5a3a22"), Color("8a5a2a"), Color("c8963e"), Color("e8d090"), Color("b0452a"), Color("a8a8a8"), Color("f0f0f0"), Color("3a3a5a")]
const CLOTH_COLORS := [Color("4a7ab0"), Color("c0504a"), Color("5a9a4a"), Color("d8a03a"), Color("8a5aa8"), Color("3a8a8a"), Color("e8e0d0"), Color("6a4a3a"), Color("d86a9a"), Color("4a4a5a"), Color("8aa83a"), Color("e8803a")]

var look := {}
var hips: Node3D
var torso: Node3D
var head: Node3D
var arm_l: Node3D
var arm_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var hand_r: Node3D
var held: MeshInstance3D
var hat_node: MeshInstance3D
var parts: Array[MeshInstance3D] = []

var state := "idle"
var move_amount := 0.0      # 0..1 walk blend
var phase := 0.0
var action := ""            # "", "slash", "overhead", "thrust", "draw", "pour", "cast", "reel", "eat", "wave"
var action_t := 0.0         # 0..1
var roll_t := -1.0
var bob_time := 0.0
var talk_time := 0.0
var flash_mat: StandardMaterial3D

static func random_look(rng: RandomNumberGenerator) -> Dictionary:
	return {
		"skin": SKIN_TONES[rng.randi() % SKIN_TONES.size()],
		"hair": HAIR_COLORS[rng.randi() % HAIR_COLORS.size()],
		"hair_style": rng.randi() % 7,
		"shirt": CLOTH_COLORS[rng.randi() % CLOTH_COLORS.size()],
		"pants": [Color("4a4a5a"), Color("5a4a3a"), Color("3a4a6a"), Color("6a5a4a"), Color("4a5a3a")][rng.randi() % 5],
		"hat": -1 if rng.randf() < 0.65 else rng.randi() % 4,
		"hat_col": CLOTH_COLORS[rng.randi() % CLOTH_COLORS.size()],
		"height": rng.randf_range(0.92, 1.08),
		"build": rng.randf_range(0.9, 1.18),
		"beard": rng.randf() < 0.2,
		"apron": -1,
	}

func setup(appearance: Dictionary) -> void:
	look = appearance.duplicate()
	for c in get_children():
		c.queue_free()
	parts.clear()
	_build()

func _part(parent: Node3D, mesh: Mesh, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	parent.add_child(mi)
	parts.append(mi)
	return mi

func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n

func _build() -> void:
	var h: float = look.get("height", 1.0)
	var b: float = look.get("build", 1.0)
	var skin: Color = look.get("skin", SKIN_TONES[1])
	var shirt: Color = look.get("shirt", CLOTH_COLORS[0])
	var pants: Color = look.get("pants", Color("4a4a5a"))
	var hair: Color = look.get("hair", HAIR_COLORS[1])
	var child: bool = look.get("child", false)
	var s := 0.72 if child else 1.0
	scale = Vector3.ONE * h * s

	hips = _pivot(self, Vector3(0, 0.82, 0))
	torso = _pivot(hips, Vector3.ZERO)
	# torso
	var mb := MeshBuilder.new(7)
	mb.sphere(Vector3(0, 0.33, 0), Vector3(0.24 * b, 0.36, 0.17 * b), shirt, 4, 8)
	mb.cyl(Vector3(0, -0.02, 0), 0.21 * b, 0.23 * b, 0.12, 8, pants)
	var apron: int = look.get("apron", -1)
	if apron >= 0:
		var ac: Color = [Color("e8e0d0"), Color("6a4a3a"), Color("4a6a8a"), Color("a8865a")][apron % 4]
		mb.box(Vector3(0, 0.2, 0.165 * b), Vector3(0.34 * b, 0.55, 0.03), ac)
	_part(torso, mb.commit())
	# head
	head = _pivot(torso, Vector3(0, 0.74, 0))
	mb = MeshBuilder.new(11)
	mb.sphere(Vector3(0, 0.0, 0), Vector3(0.2, 0.22, 0.2), skin, 5, 9)
	mb.sphere(Vector3(0, -0.02, 0.19), Vector3(0.035, 0.04, 0.04), skin.darkened(0.08), 2, 5)
	for sx in [-1, 1]:
		mb.sphere(Vector3(sx * 0.075, 0.03, 0.175), Vector3(0.028, 0.034, 0.02), Color("1e1a22"), 2, 5)
		mb.sphere(Vector3(sx * 0.12, -0.05, 0.16), Vector3(0.035, 0.02, 0.015), skin.lerp(Color("e07a7a"), 0.35), 2, 5)
		mb.sphere(Vector3(sx * 0.2, 0.0, 0.0), Vector3(0.03, 0.05, 0.04), skin.darkened(0.05), 2, 5)
	mb.box(Vector3(0, -0.24, 0), Vector3(0.1, 0.1, 0.1), skin.darkened(0.05))
	_hair(mb, hair, look.get("hair_style", 0))
	if look.get("beard", false):
		mb.sphere(Vector3(0, -0.12, 0.1), Vector3(0.17, 0.12, 0.13), hair, 3, 7)
	_part(head, mb.commit())
	var hat: int = look.get("hat", -1)
	if hat >= 0:
		hat_node = _part(head, _hat_mesh(hat, look.get("hat_col", Color("d8a03a"))))
	# arms
	arm_l = _pivot(torso, Vector3(-0.27 * b, 0.58, 0))
	arm_r = _pivot(torso, Vector3(0.27 * b, 0.58, 0))
	for arm in [arm_l, arm_r]:
		mb = MeshBuilder.new(3)
		mb.cyl(Vector3(0, -0.5, 0), 0.06, 0.075, 0.5, 6, shirt)
		mb.sphere(Vector3(0, 0.0, 0), Vector3(0.08, 0.08, 0.08), shirt, 2, 6)
		mb.sphere(Vector3(0, -0.56, 0), Vector3(0.065, 0.07, 0.065), skin, 2, 6)
		_part(arm, mb.commit())
	hand_r = _pivot(arm_r, Vector3(0, -0.56, 0.02))
	# legs
	leg_l = _pivot(hips, Vector3(-0.1 * b, 0.0, 0))
	leg_r = _pivot(hips, Vector3(0.1 * b, 0.0, 0))
	for leg in [leg_l, leg_r]:
		mb = MeshBuilder.new(5)
		mb.cyl(Vector3(0, -0.74, 0), 0.075, 0.09, 0.74, 6, pants)
		mb.box(Vector3(0, -0.77, 0.05), Vector3(0.13, 0.1, 0.24), Color("4a3424"))
		_part(leg, mb.commit())
	flash_mat = Meshes.mat("flash").duplicate()
	for p in parts:
		p.material_overlay = flash_mat

func _hair(mb: MeshBuilder, col: Color, style: int) -> void:
	match style:
		0: # short cap
			mb.sphere(Vector3(0, 0.06, -0.02), Vector3(0.215, 0.2, 0.215), col, 4, 9)
		1: # bob
			mb.sphere(Vector3(0, 0.04, -0.03), Vector3(0.23, 0.22, 0.23), col, 4, 9)
			mb.box(Vector3(0, -0.08, -0.08), Vector3(0.44, 0.2, 0.3), col)
		2: # ponytail
			mb.sphere(Vector3(0, 0.06, -0.02), Vector3(0.215, 0.2, 0.215), col, 4, 9)
			mb.sphere(Vector3(0, 0.0, -0.27), Vector3(0.08, 0.16, 0.08), col, 3, 6)
		3: # bun
			mb.sphere(Vector3(0, 0.06, -0.02), Vector3(0.215, 0.2, 0.215), col, 4, 9)
			mb.sphere(Vector3(0, 0.22, -0.12), Vector3(0.1, 0.09, 0.1), col, 3, 7)
		4: # spiky
			mb.sphere(Vector3(0, 0.05, -0.02), Vector3(0.21, 0.19, 0.21), col, 4, 9)
			for i in 6:
				var a := TAU * i / 6.0
				mb.cone(Vector3(cos(a) * 0.1, 0.14, sin(a) * 0.1 - 0.03), 0.07, 0.16, 4, col, Vector3(sin(a) * 0.5, 0, -cos(a) * 0.5))
		5: # long
			mb.sphere(Vector3(0, 0.05, -0.03), Vector3(0.23, 0.22, 0.23), col, 4, 9)
			mb.box(Vector3(0, -0.2, -0.1), Vector3(0.42, 0.46, 0.22), col)
		_: # bald-ish
			mb.sphere(Vector3(0, -0.02, -0.06), Vector3(0.21, 0.14, 0.18), col, 3, 8)

func _hat_mesh(kind: int, col: Color) -> Mesh:
	var mb := MeshBuilder.new(kind)
	match kind:
		0: # wide brim straw/farm hat
			mb.cyl(Vector3(0, 0.12, 0), 0.38, 0.38, 0.03, 10, col)
			mb.cyl(Vector3(0, 0.12, 0), 0.19, 0.16, 0.18, 9, col.darkened(0.08))
		1: # beanie
			mb.sphere(Vector3(0, 0.1, 0), Vector3(0.22, 0.16, 0.22), col, 3, 8)
			mb.sphere(Vector3(0, 0.27, 0), Vector3.ONE * 0.05, col.lightened(0.3), 2, 5)
		2: # cap
			mb.sphere(Vector3(0, 0.1, 0), Vector3(0.22, 0.13, 0.22), col, 3, 8)
			mb.box(Vector3(0, 0.08, 0.22), Vector3(0.28, 0.03, 0.18), col.darkened(0.15))
		3: # miner helmet
			mb.sphere(Vector3(0, 0.1, 0), Vector3(0.24, 0.17, 0.24), col, 3, 9)
			mb.cyl(Vector3(0, 0.06, 0), 0.28, 0.28, 0.03, 10, col.darkened(0.1))
			mb.surface("glow_steady")
			mb.cyl(Vector3(0, 0.15, 0.2), 0.05, 0.05, 0.06, 6, Color("ffe8a0"), Vector3(PI / 2, 0, 0))
			mb.surface("vc")
		_:
			mb.cyl(Vector3(0, 0.12, 0), 0.3, 0.3, 0.03, 10, col)
			mb.cyl(Vector3(0, 0.12, 0), 0.18, 0.18, 0.22, 9, col)
	return mb.commit()

func set_hat(kind: int, col: Color) -> void:
	if hat_node:
		hat_node.queue_free()
		parts.erase(hat_node)
		hat_node = null
	if kind >= 0:
		hat_node = _part(head, _hat_mesh(kind, col))
		hat_node.material_overlay = flash_mat

func set_held(mesh: Mesh) -> void:
	if held:
		held.queue_free()
		held = null
	if mesh:
		held = MeshInstance3D.new()
		held.mesh = mesh
		hand_r.add_child(held)
		held.rotation = Vector3(PI / 2, 0, 0)

func flash(strength: float = 0.8) -> void:
	if flash_mat == null:
		return
	flash_mat.albedo_color = Color(1, 1, 1, strength)
	var tw := create_tween()
	tw.tween_property(flash_mat, "albedo_color", Color(1, 0.6, 0.6, 0.0), 0.18)

func play_action(kind: String) -> void:
	action = kind
	action_t = 0.0

func animate(delta: float, speed: float, action_dur: float = 0.4) -> void:
	bob_time += delta
	move_amount = lerp(move_amount, clamp(speed / 5.0, 0.0, 1.4), 1.0 - exp(-delta * 10.0))
	phase += delta * (4.0 + speed * 1.55)
	if action != "":
		action_t += delta / max(0.05, action_dur)
		if action_t >= 1.0:
			action = ""
			action_t = 0.0
	_pose(delta)

func _pose(delta: float) -> void:
	if hips == null:
		return
	var sw := sin(phase) * 0.75 * move_amount
	var bob: float = abs(sin(phase)) * 0.05 * move_amount + sin(bob_time * 2.0) * 0.008
	hips.position.y = 0.82 + bob
	rotation = Vector3.ZERO
	position = Vector3.ZERO
	torso.rotation = Vector3(0.08 * move_amount, 0, 0)
	head.rotation = Vector3(-0.06 * move_amount + sin(bob_time * 1.3) * 0.02, sin(bob_time * 0.7) * 0.05, 0)
	leg_l.rotation = Vector3(sw, 0, 0)
	leg_r.rotation = Vector3(-sw, 0, 0)
	arm_l.rotation = Vector3(-sw * 0.8, 0, -0.08)
	arm_r.rotation = Vector3(sw * 0.8, 0, 0.08)
	if talk_time > 0.0:
		talk_time -= delta
		head.rotation.x += sin(bob_time * 14.0) * 0.06
		arm_l.rotation = Vector3(-0.5 + sin(bob_time * 6.0) * 0.2, 0, -0.3)
	match state:
		"downed":
			hips.position.y = 0.22
			torso.rotation = Vector3(-1.45, 0, 0)
			leg_l.rotation = Vector3(-1.5, 0, 0.1)
			leg_r.rotation = Vector3(-1.4, 0, -0.1)
			arm_l.rotation = Vector3(-2.6 + sin(bob_time * 3.0) * 0.3, 0, 0)
			arm_r.rotation = Vector3(-2.6 - sin(bob_time * 3.0) * 0.3, 0, 0)
			return
		"sleep":
			hips.position.y = 0.3
			torso.rotation = Vector3(-1.55, 0, 0)
			leg_l.rotation = Vector3(-1.55, 0, 0)
			leg_r.rotation = Vector3(-1.55, 0, 0)
			arm_l.rotation = Vector3(0, 0, -0.1)
			arm_r.rotation = Vector3(0, 0, 0.1)
			return
		"sit":
			hips.position.y = 0.5
			leg_l.rotation = Vector3(-1.5, 0, 0)
			leg_r.rotation = Vector3(-1.5, 0, 0)
			arm_l.rotation = Vector3(-0.3, 0, 0)
			arm_r.rotation = Vector3(-0.3, 0, 0)
		"fish":
			arm_r.rotation = Vector3(-0.9, 0, 0.1)
			arm_l.rotation = Vector3(-0.7, 0, -0.2)
	if roll_t >= 0.0:
		hips.position.y = 0.55
		torso.rotation.x = roll_t * TAU
		leg_l.rotation.x = -1.2
		leg_r.rotation.x = -1.2
		arm_l.rotation.x = -1.4
		arm_r.rotation.x = -1.4
		return
	if action != "":
		var t := action_t
		match action:
			"slash":
				var e: float = ease(t, 0.4)
				arm_r.rotation = Vector3(-1.6, lerp(1.4, -1.6, e), 0.2)
				torso.rotation.y = lerp(0.5, -0.6, e)
			"overhead":
				var wind := 0.35
				if t < wind:
					arm_r.rotation = Vector3(lerp(0.0, -2.9, t / wind), 0, 0.1)
					arm_l.rotation = Vector3(lerp(0.0, -2.6, t / wind), 0, -0.1)
				else:
					var e2: float = ease((t - wind) / (1.0 - wind), 0.3)
					arm_r.rotation = Vector3(lerp(-2.9, -0.4, e2), 0, 0.1)
					arm_l.rotation = Vector3(lerp(-2.6, -0.5, e2), 0, -0.1)
					torso.rotation.x = lerp(-0.15, 0.3, e2)
			"thrust":
				var e3: float = sin(t * PI)
				arm_r.rotation = Vector3(-1.5, 0, 0.1)
				arm_l.rotation = Vector3(-1.3, 0, -0.3)
				torso.position.z = e3 * 0.25
				torso.rotation.y = -0.2 * e3
			"draw":
				arm_l.rotation = Vector3(-1.55, 0.2, 0)
				arm_r.rotation = Vector3(-1.55, lerp(0.0, 1.0, min(1.0, t * 2.0)), 0)
			"pour":
				arm_r.rotation = Vector3(-1.0, 0, 0.1)
				if held:
					held.rotation.z = sin(t * PI) * 1.2
			"cast":
				var e4: float = t
				arm_r.rotation = Vector3(lerp(-2.8, -0.9, ease(e4, 0.3)), 0, 0.1)
			"eat":
				arm_r.rotation = Vector3(-2.2 + sin(t * TAU * 2.0) * 0.2, 0, 0.4)
				head.rotation.x = 0.2
			"wave":
				arm_r.rotation = Vector3(0, 0, 2.6 + sin(t * TAU * 3.0) * 0.3)
	elif held and state != "fish":
		arm_r.rotation.x = min(arm_r.rotation.x, -0.25)
