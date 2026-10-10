class_name Pickup
extends Node3D
## An item lying in the world. Pops out, bobs, and drifts toward a nearby player.

var pid := 0
var item := {}
var zone: Zone
var velocity := Vector3.ZERO
var _t := 0.0
var _landed := false
var _requested := false
var _mi: MeshInstance3D
var _glow: OmniLight3D

func _ready() -> void:
	_mi = MeshInstance3D.new()
	_mi.mesh = ItemModels.drop_mesh(item["id"], 1.3)
	add_child(_mi)
	var traits := Items.item_traits(item)
	var rare := Items.def(item["id"]).has("weapon") or Items.def(item["id"]).has("gear") or Items.cat_of(item["id"]) in ["gem", "curio"]
	if rare or traits.size() > 0:
		_glow = OmniLight3D.new()
		_glow.light_color = Color("ffe08a") if traits.size() > 0 else Color("bfe3ff")
		_glow.light_energy = 0.9
		_glow.omni_range = 2.5
		_glow.position = Vector3(0, 0.5, 0)
		add_child(_glow)
	if int(item.get("n", 1)) > 1:
		var l := Label3D.new()
		l.text = "x%d" % int(item["n"])
		l.font_size = 32
		l.outline_size = 8
		l.pixel_size = 0.005
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.position = Vector3(0, 0.62, 0)
		l.no_depth_test = true
		add_child(l)

func _physics_process(delta: float) -> void:
	_t += delta
	if not _landed:
		velocity.y -= 22.0 * delta
		var np := global_position + velocity * delta
		var gy := zone.ground_y(np.x, np.z) if zone else np.y
		if np.y <= gy + 0.05:
			np.y = gy + 0.05
			if velocity.y < -2.0:
				velocity.y *= -0.35
				velocity.x *= 0.5
				velocity.z *= 0.5
			else:
				_landed = true
		global_position = np
	else:
		_mi.position.y = 0.15 + sin(_t * 3.0) * 0.08
		_mi.rotation.y += delta * 1.5
	if _requested or _t < 0.5:
		return
	var lp = Game.local_player
	if lp == null or lp.zone_id != zone.zone_id or lp.downed:
		return
	var d: Vector3 = lp.global_position + Vector3(0, 0.6, 0) - global_position
	var dist := d.length()
	if dist < 3.2 and Game.inv.can_add(item):
		_landed = true
		global_position += d.normalized() * min(dist, (4.0 + 10.0 / max(dist, 0.3)) * delta)
		if dist < 0.9:
			_requested = true
			Net.request("take_pickup", {"pid": pid})
			get_tree().create_timer(2.0).timeout.connect(_reset_request)

func collect_anim() -> void:
	set_physics_process(false)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE * 0.05, 0.12)
	tw.tween_callback(queue_free)

func _reset_request() -> void:
	_requested = false
