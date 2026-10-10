class_name CameraRig
extends Node3D
## Slightly elevated third-person camera: follows the local player, orbits with
## Q/R or middle mouse, zooms with Ctrl+wheel or +/-, and shakes on impacts.

var cam: Camera3D
var target: Node3D
var yaw := 0.0
var pitch := deg_to_rad(-42.0)
var target_pitch := deg_to_rad(-42.0)
var dist := 14.0
var target_dist := 14.0
var shake_amt := 0.0
var _drag := false
var _focus := Vector3.ZERO

func _ready() -> void:
	cam = Camera3D.new()
	cam.fov = 50.0
	cam.near = 0.2
	cam.far = 420.0
	add_child(cam)
	cam.current = true

func set_zone_style(underground: bool, indoor: bool) -> void:
	if indoor:
		target_pitch = deg_to_rad(-58.0)
		target_dist = clamp(target_dist, 8.0, 12.0)
	elif underground:
		target_pitch = deg_to_rad(-60.0)
		target_dist = clamp(target_dist, 9.0, 16.0)
	else:
		target_pitch = deg_to_rad(-42.0)

func snap() -> void:
	if target:
		_focus = target.global_position
		pitch = target_pitch
		dist = target_dist
		_place()

func shake(a: float) -> void:
	shake_amt = max(shake_amt, a)

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		if e.button_index == MOUSE_BUTTON_MIDDLE:
			_drag = e.pressed
		if e.pressed and e.ctrl_pressed:
			if e.button_index == MOUSE_BUTTON_WHEEL_UP:
				target_dist = clamp(target_dist - 1.2, 6.0, 26.0)
				get_viewport().set_input_as_handled()
			elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				target_dist = clamp(target_dist + 1.2, 6.0, 26.0)
				get_viewport().set_input_as_handled()
	elif e is InputEventMouseMotion and _drag:
		yaw -= e.relative.x * 0.006

func _process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	if Game.main and not Game.main.ui_blocking():
		if Input.is_action_pressed("cam_left"):
			yaw += delta * 1.8
		if Input.is_action_pressed("cam_right"):
			yaw -= delta * 1.8
		if Input.is_action_pressed("zoom_in"):
			target_dist = clamp(target_dist - delta * 10.0, 6.0, 26.0)
		if Input.is_action_pressed("zoom_out"):
			target_dist = clamp(target_dist + delta * 10.0, 6.0, 26.0)
		var rs := Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
		if abs(rs) > 0.25:
			yaw -= rs * delta * 2.0
	var tp := target.global_position + Vector3(0, 1.0, 0)
	if _focus.distance_to(tp) > 30.0:
		_focus = tp
	_focus = _focus.lerp(tp, 1.0 - exp(-delta * 9.0))
	pitch = lerp(pitch, target_pitch, 1.0 - exp(-delta * 4.0))
	dist = lerp(dist, target_dist, 1.0 - exp(-delta * 6.0))
	_place()
	if shake_amt > 0.0:
		cam.h_offset = randf_range(-1, 1) * shake_amt
		cam.v_offset = randf_range(-1, 1) * shake_amt
		shake_amt = max(0.0, shake_amt - delta * 1.8)
	else:
		cam.h_offset = 0.0
		cam.v_offset = 0.0

func _place() -> void:
	var back := Vector3(sin(yaw) * cos(pitch), -sin(pitch), cos(yaw) * cos(pitch))
	global_position = _focus
	cam.global_position = _focus + back * dist
	cam.look_at(_focus, Vector3.UP)

## Basis vectors for camera-relative movement on the ground plane.
func forward_flat() -> Vector3:
	return Vector3(-sin(yaw), 0, -cos(yaw))

func right_flat() -> Vector3:
	return Vector3(cos(yaw), 0, -sin(yaw))

## Where the mouse points on a horizontal plane at the given height.
func mouse_ground(height: float) -> Vector3:
	var vp := get_viewport()
	var mp := vp.get_mouse_position()
	var from := cam.project_ray_origin(mp)
	var dir := cam.project_ray_normal(mp)
	if abs(dir.y) < 0.0001:
		return from
	var t := (height - from.y) / dir.y
	return from + dir * t
