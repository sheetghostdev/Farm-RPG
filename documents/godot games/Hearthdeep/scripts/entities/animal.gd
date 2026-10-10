class_name Animal
extends Node3D
## A farm animal that potters around its home spot. Its path is a pure function
## of the game clock, so every player sees it in the same place without syncing.

var home: PlacedObj
var species := "chicken"
var seed_f := 0.0
var _body: Node3D
var _head: Node3D
var _t := 0.0
var _last := Vector3.ZERO

func setup(h: PlacedObj, sp: String) -> void:
	home = h
	species = sp
	seed_f = float(abs(h.oid.hash()) % 1000) * 0.137

func _ready() -> void:
	_body = Node3D.new()
	add_child(_body)
	var mb := MeshBuilder.new(int(seed_f * 100))
	var white := Color("f4f0e6") if int(seed_f * 10) % 3 != 0 else Color("b8743a")
	mb.sphere(Vector3(0, 0.28, 0), Vector3(0.2, 0.18, 0.26), white, 3, 7)
	mb.cone(Vector3(0, 0.3, -0.22), 0.1, 0.18, 4, white.darkened(0.1), Vector3(-2.2, 0, 0))
	for s in [-1, 1]:
		mb.cyl(Vector3(s * 0.07, 0.0, 0), 0.015, 0.015, 0.14, 4, Color("e8a03a"))
	var bmi := MeshInstance3D.new()
	bmi.mesh = mb.commit()
	_body.add_child(bmi)
	_head = Node3D.new()
	_head.position = Vector3(0, 0.45, 0.18)
	_body.add_child(_head)
	var hb := MeshBuilder.new(3)
	hb.sphere(Vector3.ZERO, Vector3(0.1, 0.11, 0.1), white, 3, 6)
	hb.cone(Vector3(0, 0, 0.09), 0.035, 0.08, 4, Color("e8a03a"), Vector3(PI / 2, 0, 0))
	hb.box(Vector3(0, 0.1, 0), Vector3(0.03, 0.08, 0.1), Color("d8302a"))
	for s in [-1, 1]:
		hb.sphere(Vector3(s * 0.07, 0.03, 0.05), Vector3.ONE * 0.015, Color("1a1a1a"), 2, 4)
	var hmi := MeshInstance3D.new()
	hmi.mesh = hb.commit()
	_head.add_child(hmi)

func _process(delta: float) -> void:
	if home == null or not is_instance_valid(home):
		queue_free()
		return
	_t += delta
	var tm := Game.total_minutes() * 0.6 + seed_f * 37.0
	var night := Game.is_night()
	var r := 1.2 if night else 3.5
	var off := Vector3(sin(tm * 0.031 + seed_f) * r + sin(tm * 0.077) * 0.8, 0, cos(tm * 0.023 + seed_f * 2.0) * r + cos(tm * 0.061) * 0.8)
	var target := home.global_position + off
	var z := home.zone
	if z:
		target.y = z.ground_y(target.x, target.z)
	var moved := target - _last
	global_position = target
	if moved.length() > 0.001:
		rotation.y = lerp_angle(rotation.y, atan2(moved.x, moved.z), 0.15)
	var walking = moved.length() / max(delta, 0.001) > 0.05
	_body.position.y = abs(sin(_t * 12.0)) * 0.04 if walking else 0.0
	_head.rotation.x = (sin(_t * 3.0 + seed_f) * 0.5 + 0.3) if not walking and int(_t + seed_f) % 4 == 0 else 0.0
	_last = target
