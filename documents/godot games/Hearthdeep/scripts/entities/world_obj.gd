class_name WorldObj
extends Node3D
## Base for anything in a zone that players can target: trees, rocks, ore,
## forage, chests, placed objects and so on.

var oid := ""
var kind := ""
var sub := ""
var radius := 0.6
var blocking := false
var zone: Zone
var grid_cell := Vector2i.ZERO
var mesh_inst: MeshInstance3D
var body: StaticBody3D
var _shake_t := 0.0
var _base_rot := 0.0

func prompt(_player) -> String:
	return ""

func interact(_player) -> void:
	pass

func accepts_tool(_tool: String) -> bool:
	return false

func tool_hit(_player, _tool: String, _tier: int, _power: float) -> void:
	pass

func set_mesh(m: Mesh, vis_range: float = 0.0, rot_y: float = 0.0, scl: float = 1.0) -> MeshInstance3D:
	if mesh_inst:
		mesh_inst.queue_free()
	mesh_inst = Meshes.inst(m, self, Vector3.ZERO, rot_y, scl, vis_range)
	_base_rot = rot_y
	return mesh_inst

func add_blocker(r: float, h: float = 2.0, offset: Vector3 = Vector3.ZERO) -> void:
	body = StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = r
	shape.height = h
	cs.shape = shape
	cs.position = offset + Vector3(0, h / 2.0, 0)
	body.add_child(cs)
	add_child(body)
	blocking = true

func add_box_blocker(size: Vector3, offset: Vector3 = Vector3.ZERO, rot_y: float = 0.0) -> void:
	if body == null:
		body = StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		add_child(body)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position = offset + Vector3(0, size.y / 2.0, 0)
	cs.rotation.y = rot_y
	body.add_child(cs)
	blocking = true

func shake(amount: float = 0.08) -> void:
	_shake_t = 0.25
	if mesh_inst:
		var tw := create_tween()
		tw.tween_property(mesh_inst, "rotation:z", amount, 0.05)
		tw.tween_property(mesh_inst, "rotation:z", -amount * 0.7, 0.07)
		tw.tween_property(mesh_inst, "rotation:z", 0.0, 0.08)

## Animated removal. Trees topple, everything else shrinks away.
func vanish(fall: bool = false) -> void:
	if body:
		body.queue_free()
		body = null
	var tw := create_tween()
	if fall and mesh_inst:
		var dir := 1.0 if randf() < 0.5 else -1.0
		tw.tween_property(mesh_inst, "rotation:z", dir * 1.5, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(mesh_inst, "scale", Vector3.ONE * 0.01, 0.3)
	else:
		tw.tween_property(self, "scale", Vector3.ONE * 0.05, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)

func pop_in() -> void:
	scale = Vector3.ONE * 0.1
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func highlight_height() -> float:
	return 1.2
