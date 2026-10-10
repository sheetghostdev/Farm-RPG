class_name Player
extends CharacterBody3D
## A player avatar. The local one reads input, moves itself (client authority over
## movement) and asks the server for everything that changes the world. Remote
## ones just interpolate the state their owners broadcast.

const REACH := 2.7
const BASE_SPEED := 5.6

var peer_id := 1
var is_local := false
var zone_id := "over"
var pname := ""
var look := {}
var doll: Doll
var name_label: Label3D
var lantern: OmniLight3D
var hp := 100.0
var hot_index := 0
var held_id := ""
var downed := false
var down_t := 0.0
var sleeping := false
var facing := 0.0
var roll_t := -1.0
var roll_cd := 0.0
var roll_dir := Vector3.FORWARD
var iframes := 0.0
var action_lock := 0.0
var action_dur := 0.4
var use_cd := 0.0
var last_hurt := 100.0
var combo := 0
var charging := false
var charge := 0.0
var pending_hit := {}
var aim := Vector3.ZERO
var target_obj: WorldObj = null
var target_tile := Vector2i(-99999, -99999)
var interact_target = null
var revive_t := 0.0
var fishing: Fishing
var cam: CameraRig
var selector: MeshInstance3D
var ghost: MeshInstance3D
var ghost_item := ""
var place_rot := 0
var _action_name := ""
var _action_count := 0
var _step_t := 0.0
var _fall_guard := Vector3.ZERO
# remote interpolation
var _net_pos := Vector3.ZERO
var _net_yaw := 0.0
var _net_speed := 0.0
var _last_action := ""
var _has_net := false

func setup(info: Dictionary) -> void:
	pname = info.get("name", "Player")
	look = info.get("look", {})
	collision_layer = 2
	collision_mask = 1
	floor_max_angle = deg_to_rad(48.0)
	floor_snap_length = 0.5
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.6
	cs.shape = cap
	cs.position = Vector3(0, 0.8, 0)
	add_child(cs)
	doll = Doll.new()
	add_child(doll)
	doll.setup(look)
	lantern = OmniLight3D.new()
	lantern.light_color = Color("ffd9a0")
	lantern.position = Vector3(0.3, 1.9, 0.3)
	lantern.omni_range = 8.0
	lantern.light_energy = 0.0
	lantern.shadow_enabled = false
	add_child(lantern)
	if is_local:
		fishing = Fishing.new()
		fishing.player = self
		add_child(fishing)
		selector = MeshInstance3D.new()
		selector.mesh = _selector_mesh()
		selector.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		selector.visible = false
		selector.top_level = true
		add_child(selector)
		ghost = MeshInstance3D.new()
		ghost.top_level = true
		ghost.visible = false
		ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ghost)
		hp = float(Game.me.get("hp", 100.0))
		Game.inventory_changed.connect(_refresh_held)
		_refresh_held()
	else:
		name_label = Label3D.new()
		name_label.text = pname
		name_label.font_size = 40
		name_label.outline_size = 10
		name_label.pixel_size = 0.005
		name_label.position = Vector3(0, 2.3, 0)
		name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		name_label.modulate = look.get("shirt", Color.WHITE).lightened(0.45)
		name_label.no_depth_test = true
		add_child(name_label)
		collision_layer = 0

func _selector_mesh() -> Mesh:
	var mb := MeshBuilder.new(1)
	mb.surface("select")
	var h := 0.5
	var t := 0.06
	for e in [[Vector3(0, 0, -h), Vector3(1.0, 0.02, t)], [Vector3(0, 0, h), Vector3(1.0, 0.02, t)], [Vector3(-h, 0, 0), Vector3(t, 0.02, 1.0)], [Vector3(h, 0, 0), Vector3(t, 0.02, 1.0)]]:
		mb.box(e[0], e[1], Color.WHITE)
	return mb.commit()

func zone() -> Zone:
	return Zones.get_zone(zone_id)

func max_hp() -> float:
	if not is_local:
		return float(Net.peers.get(peer_id, {}).get("mhp", 100.0))
	return 100.0 + 25.0 * Game.trait_count("hearty") + 5.0 * Game.skill_level("combat")

func held_item() -> Dictionary:
	if not is_local:
		return {}
	return Game.inv.get_slot(hot_index)

func _refresh_held() -> void:
	var it := held_item()
	var id: String = it.get("id", "")
	if id != held_id:
		held_id = id
		doll.set_held(ItemModels.held_mesh(id) if id != "" else null)
		charging = false
		if fishing:
			fishing.cancel()
	_refresh_hat()

func _refresh_hat() -> void:
	var hat: Dictionary = Game.me.get("equip", {}).get("hat", {})
	if hat.is_empty():
		doll.set_hat(look.get("hat", -1), look.get("hat_col", Color.WHITE))
	else:
		var kinds := {"straw_hat": 0, "miners_helmet": 3, "angler_cap": 2, "leather_cap": 2, "explorer_hat": 0, "chef_hat": 4}
		doll.set_hat(kinds.get(hat["id"], 1), Items.def(hat["id"])["icon"][1])

func on_zone_changed() -> void:
	var z := zone()
	if z:
		lantern.shadow_enabled = false
	charging = false
	if fishing:
		fishing.cancel()
	_fall_guard = global_position

# ------------------------------------------------------------------ frame

func _physics_process(delta: float) -> void:
	if is_local:
		_local_physics(delta)
	else:
		_remote_physics(delta)
	_update_lantern(delta)

func _update_lantern(delta: float) -> void:
	var z := zone()
	var want := 0.0
	var rng := 8.0
	if z and z.underground():
		want = 1.5
		rng = 8.5
	elif z and z.kind == "over" and Game.daylight() < 0.35:
		want = 0.7 * (1.0 - Game.daylight() / 0.35)
		rng = 7.0
	if is_local:
		rng *= 1.0 + 0.4 * Game.trait_count("glowing") + 0.5 * Game.buff("light")
	lantern.light_energy = lerp(lantern.light_energy, want, 1.0 - exp(-delta * 3.0))
	lantern.omni_range = rng
	lantern.visible = lantern.light_energy > 0.02

func _remote_physics(delta: float) -> void:
	if not _has_net:
		return
	var lp = Game.local_player
	visible = lp != null and lp.zone_id == zone_id
	if global_position.distance_to(_net_pos) > 8.0:
		global_position = _net_pos
	else:
		global_position = global_position.lerp(_net_pos, 1.0 - exp(-delta * 14.0))
	rotation.y = lerp_angle(rotation.y, _net_yaw, 1.0 - exp(-delta * 14.0))
	doll.state = "downed" if downed else ("sleep" if sleeping else ("fish" if _last_action.begins_with("fishing") else "idle"))
	doll.roll_t = roll_t
	if roll_t >= 0.0:
		roll_t += delta / 0.38
		if roll_t >= 1.0:
			roll_t = -1.0
	doll.animate(delta, _net_speed, action_dur)

func refresh_visibility() -> void:
	var lp = Game.local_player
	visible = lp != null and lp.zone_id == zone_id

func net_state() -> Array:
	var flags := 0
	if roll_t >= 0.0:
		flags |= 1
	var hv := Vector2(velocity.x, velocity.z).length()
	var act := "%s#%d" % [_action_name, _action_count]
	if fishing and fishing.active():
		act = "fishing#0"
	return [zone_id, global_position, rotation.y, flags, held_id, sleeping, downed, hp, max_hp(), act, hv]

func apply_net_state(st: Array) -> void:
	var new_zone: String = st[0]
	if new_zone != zone_id:
		zone_id = new_zone
		global_position = st[1]
	_net_pos = st[1]
	_net_yaw = st[2]
	if int(st[3]) & 1 and roll_t < 0.0:
		roll_t = 0.0
	var h: String = st[4]
	if h != held_id:
		held_id = h
		doll.set_held(ItemModels.held_mesh(h) if h != "" else null)
	sleeping = st[5]
	downed = st[6]
	hp = st[7]
	var act: String = st[9]
	if act != _last_action:
		_last_action = act
		var nm := act.get_slice("#", 0)
		if nm != "" and nm != "fishing":
			doll.play_action(nm)
			action_dur = 0.4
	_net_speed = st[10]
	_has_net = true

# ------------------------------------------------------------------ local control

func _local_physics(delta: float) -> void:
	var z := zone()
	if z == null:
		return
	cam = Game.main.cam if Game.main else null
	use_cd = max(0.0, use_cd - delta)
	roll_cd = max(0.0, roll_cd - delta)
	iframes = max(0.0, iframes - delta)
	action_lock = max(0.0, action_lock - delta)
	last_hurt += delta
	var ui_block: bool = Game.main.ui_blocking() if Game.main else false
	var input := Vector2.ZERO
	if not ui_block:
		input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if sleeping:
		if input.length() > 0.2:
			wake_up()
		doll.state = "sleep"
		doll.animate(delta, 0.0)
		velocity = Vector3.ZERO
		return
	if downed:
		_downed_tick(delta, input)
		return
	var move := Vector3.ZERO
	if cam:
		move = cam.right_flat() * input.x - cam.forward_flat() * input.y
	if move.length() > 1.0:
		move = move.normalized()
	var spd := BASE_SPEED * (1.0 + 0.12 * Game.trait_count("swift") + 0.25 * Game.buff("speed"))
	if Input.is_action_pressed("walk"):
		spd *= 0.5
	if action_lock > 0.0:
		spd *= 0.3
	if fishing.active():
		spd = 0.0
	# aim
	if cam and not ui_block:
		aim = cam.mouse_ground(global_position.y + 0.3)
	var hv := Vector3.ZERO
	if roll_t >= 0.0:
		roll_t += delta / _roll_time()
		hv = roll_dir * (_roll_speed() * (1.0 - roll_t * 0.5))
		if roll_t >= 1.0:
			roll_t = -1.0
	else:
		hv = move * spd
		if move.length() > 0.1 and action_lock <= 0.0 and not charging:
			facing = atan2(move.x, move.z)
	# blocked by deep water / chasms
	if hv.length() > 0.01:
		if abs(hv.x) > 0.01 and z.is_blocked(Vector3(global_position.x + sign(hv.x) * 0.5, global_position.y, global_position.z)):
			hv.x = 0.0
		if abs(hv.z) > 0.01 and z.is_blocked(Vector3(global_position.x, global_position.y, global_position.z + sign(hv.z) * 0.5)):
			hv.z = 0.0
	velocity.x = hv.x
	velocity.z = hv.z
	if is_on_floor():
		velocity.y = -0.5
	else:
		velocity.y -= 24.0 * delta
	move_and_slide()
	if global_position.y < z.ground_y(global_position.x, global_position.z) - 3.0 or global_position.y < -60.0:
		global_position = _fall_guard + Vector3(0, 0.5, 0)
		velocity = Vector3.ZERO
	elif is_on_floor() and not z.is_blocked(global_position):
		_fall_guard = global_position
	rotation.y = lerp_angle(rotation.y, facing, 1.0 - exp(-delta * 16.0))
	# footsteps
	var hspeed := Vector2(velocity.x, velocity.z).length()
	if hspeed > 1.0 and is_on_floor() and roll_t < 0.0:
		_step_t += delta * hspeed
		if _step_t > 2.2:
			_step_t = 0.0
			Sfx.play_at("step_stone" if z.underground() else "step", global_position, -14.0)
	# doll
	doll.roll_t = roll_t
	doll.state = "fish" if fishing.active() else "idle"
	doll.animate(delta, hspeed if roll_t < 0.0 else 0.0, action_dur)
	# input actions
	if not ui_block:
		_handle_hotbar()
		if Input.is_action_just_pressed("dodge") and roll_cd <= 0.0 and roll_t < 0.0 and not fishing.active():
			_start_roll(move)
		_handle_use(delta)
		if Input.is_action_just_pressed("drop"):
			_drop_held(Input.is_key_pressed(KEY_SHIFT))
		if Input.is_action_just_pressed("rotate_place"):
			place_rot = (place_rot + 1) % 4
	_update_targets(z)
	if not ui_block and Input.is_action_pressed("interact"):
		_handle_interact(delta, Input.is_action_just_pressed("interact"))
	else:
		revive_t = 0.0
	if pending_hit.size() > 0:
		pending_hit["t"] = float(pending_hit["t"]) - delta
		if float(pending_hit["t"]) <= 0.0:
			var ph := pending_hit
			pending_hit = {}
			_resolve_use(ph)
	_regen(delta, z)

func _roll_time() -> float:
	return 0.45 if Game.has_trait("featherstep") else 0.36

func _roll_speed() -> float:
	return 12.5 if Game.has_trait("featherstep") else 11.0

func _start_roll(move: Vector3) -> void:
	roll_dir = move.normalized() if move.length() > 0.1 else Vector3(sin(facing), 0, cos(facing))
	facing = atan2(roll_dir.x, roll_dir.z)
	roll_t = 0.0
	iframes = _roll_time() * 0.8
	var cd := 0.55
	if Game.has_trait("featherstep"):
		cd = 0.35
	if Game.buff("dodge") > 0.0:
		cd = 0.1
	roll_cd = _roll_time() + cd
	charging = false
	pending_hit = {}
	action_lock = 0.0
	Sfx.play_at("roll", global_position, -6.0)
	Fx.dust(zone().fx_root, global_position)

func _regen(delta: float, z: Zone) -> void:
	var mh := max_hp()
	if hp >= mh:
		hp = mh
		return
	var rate := 0.0
	if last_hurt > 6.0:
		if z.kind == "home":
			rate = 4.0
		elif not z.underground():
			rate = 1.2
			var g = (z as Overworld).gen if z is Overworld else null
			if g and (g.farm_rect.has_point(Vector2(global_position.x, global_position.z)) or g.town_rect.has_point(Vector2(global_position.x, global_position.z))):
				rate = 3.0
	if Game.buff("regen") > 0.0:
		rate += 6.0 * Game.buff("regen")
	for o in z.query(global_position, 3.5):
		if o is PlacedObj and o.obj_type == "campfire":
			rate += 2.0
			break
	hp = min(mh, hp + rate * delta)

func _handle_hotbar() -> void:
	for i in 10:
		if Input.is_action_just_pressed("hot_%d" % i):
			select_hot(i)
	if Input.is_action_just_pressed("hot_next") and not Input.is_key_pressed(KEY_CTRL):
		select_hot((hot_index + 1) % 10)
	if Input.is_action_just_pressed("hot_prev") and not Input.is_key_pressed(KEY_CTRL):
		select_hot((hot_index + 9) % 10)

func select_hot(i: int) -> void:
	if i == hot_index:
		return
	hot_index = i
	_refresh_held()
	Sfx.play("tick", -12.0)
	if Game.main:
		Game.main.hud.refresh_hotbar()

# ------------------------------------------------------------------ targeting

func _aim_dir() -> Vector3:
	var d := aim - global_position
	d.y = 0
	if d.length() < 0.2 or (cam == null):
		return Vector3(sin(facing), 0, cos(facing))
	return d.normalized()

func _aim_point(max_r: float) -> Vector3:
	var d := aim - global_position
	d.y = 0
	if d.length() > max_r:
		d = d.normalized() * max_r
	if d.length() < 0.6:
		d = _aim_dir() * 1.0
	return global_position + d

func _tool_kind(it: Dictionary) -> String:
	if it.is_empty():
		return ""
	var d := Items.def(it["id"])
	if d.has("tool"):
		return d["tool"]["kind"]
	if d.has("weapon"):
		return "weapon"
	if d.has("seed"):
		return "seed"
	if d.has("place"):
		return "place"
	if d.has("food"):
		return "eat"
	return ""

func _update_targets(z: Zone) -> void:
	var it := held_item()
	var tk := _tool_kind(it)
	target_obj = null
	target_tile = Vector2i(-99999, -99999)
	selector.visible = false
	var farm: FarmLayer = (z as Overworld).farm if z is Overworld else null
	if tk in ["hoe", "can", "seed"] and farm:
		var ap := _aim_point(1.8)
		var k := FarmLayer.tile_of(ap)
		target_tile = k
		var ok := true
		if tk == "hoe":
			ok = farm.can_till(k) and not farm.tiles().has(k)
		elif tk == "seed":
			ok = farm.tiles().has(k) and not farm.tiles()[k].has("crop")
		selector.visible = true
		selector.global_position = farm.tile_center(k) + Vector3(0, 0.08, 0)
		selector.material_override = null if ok else Meshes.mat("ghost_bad")
	if tk in ["axe", "pick", "weapon", "hoe", "can"]:
		var tool_name: String = tk if tk != "weapon" else "any"
		var ap2 := _aim_point(REACH)
		var best := z.nearest(ap2, 1.3, func(o): return o.accepts_tool(tool_name) and (o.global_position - global_position).length() < REACH + o.radius)
		if best == null:
			var front := global_position + _aim_dir() * 1.3
			best = z.nearest(front, 1.2, func(o): return o.accepts_tool(tool_name))
		if best and (tk != "weapon" or best is ResourceNode):
			target_obj = best
			if tk in ["axe", "pick"] or (tk == "weapon" and best.sub in ["weed", "barrel", "crate"]):
				selector.visible = true
				selector.material_override = null
				selector.global_position = best.global_position + Vector3(0, 0.06, 0)
	_update_ghost(it, tk, z)

var _ghost_ok := false

func _update_ghost(it: Dictionary, tk: String, z: Zone) -> void:
	if tk != "place":
		ghost.visible = false
		return
	var id: String = it["id"]
	var d := Items.def(id)
	if id != ghost_item:
		ghost_item = id
		var obj: String = d["place"]["obj"]
		if obj == "fruit_tree":
			ghost.mesh = ItemModels.fruit_tree_mesh(d["place"]["fruit"], 0, false)
		elif obj == "chicken":
			ghost.mesh = ItemModels.drop_mesh("egg", 2.0)
		else:
			ghost.mesh = ItemModels.placeable_mesh(obj)
	var pos := place_position(id)
	_ghost_ok = can_place(id, pos)
	ghost.visible = true
	ghost.global_position = pos
	ghost.rotation.y = place_rot * PI / 2.0
	ghost.material_override = Meshes.mat("ghost_ok" if _ghost_ok else "ghost_bad")

func place_position(id: String) -> Vector3:
	var d := Items.def(id)
	var size: Vector2i = d["place"].get("size", Vector2i(1, 1))
	if place_rot % 2 == 1:
		size = Vector2i(size.y, size.x)
	var ap := _aim_point(2.2 + max(size.x, size.y) * 0.5)
	var x := floorf(ap.x) + (0.5 if size.x % 2 == 1 else 0.0)
	var zz := floorf(ap.z) + (0.5 if size.y % 2 == 1 else 0.0)
	var z := zone()
	return Vector3(x, z.ground_y(x, zz), zz)

func can_place(id: String, pos: Vector3) -> bool:
	var z := zone()
	var p: Dictionary = Items.def(id)["place"]
	if z.kind == "cave" and not p.get("cave", false):
		return false
	if z.kind == "home" and not p.get("indoor", false):
		return false
	if z.kind == "over" and not p.get("outdoor", true):
		return false
	if z.is_blocked(pos) or not z.water_at(pos).is_empty():
		return false
	var size: Vector2i = p.get("size", Vector2i(1, 1))
	if place_rot % 2 == 1:
		size = Vector2i(size.y, size.x)
	if p["obj"] in ["coop", "shed", "fruit_tree", "beehive", "chicken"] and z is Overworld:
		if not (z as Overworld).gen.farm_rect.grow(-1.0).has_point(Vector2(pos.x, pos.z)):
			return false
	if z is Overworld:
		var farm: FarmLayer = (z as Overworld).farm
		for dx in size.x:
			for dz in size.y:
				var k := FarmLayer.tile_of(pos + Vector3(dx - size.x / 2.0 + 0.5, 0, dz - size.y / 2.0 + 0.5))
				if farm.tiles().has(k) and p["obj"] not in ["sprinkler", "sprinkler_2", "scarecrow", "torch"]:
					return false
		if (z as Overworld).gen.town_rect.has_point(Vector2(pos.x, pos.z)):
			return false
	if p["obj"] in ["stone_path", "wood_path", "rug"]:
		for o in z.query(pos, 0.5):
			if o is PlacedObj and o.obj_type in ["stone_path", "wood_path", "rug"] and o.global_position.distance_to(pos) < 0.5:
				return false
		return true
	return z.area_free(pos, Vector2(size.x * 0.48, size.y * 0.48)) and global_position.distance_to(pos) > 0.6

# ------------------------------------------------------------------ using items

func _handle_use(delta: float) -> void:
	var it := held_item()
	var tk := _tool_kind(it)
	if tk == "weapon" and Items.def(it["id"])["weapon"]["kind"] == "bow":
		_handle_bow(delta, it)
		return
	if tk == "rod":
		if Input.is_action_just_pressed("use"):
			fishing.on_use_pressed()
		elif Input.is_action_just_released("use"):
			fishing.on_use_released()
		return
	if not Input.is_action_pressed("use") or use_cd > 0.0 or roll_t >= 0.0 or action_lock > 0.0:
		return
	if Game.main and Game.main.mouse_over_ui():
		return
	if tk == "":
		return
	facing = atan2(_aim_dir().x, _aim_dir().z)
	match tk:
		"hoe", "axe", "pick":
			_begin_use("overhead", 0.42, 0.24, {"tool": tk, "it": it})
		"can":
			_begin_use("pour", 0.45, 0.22, {"tool": tk, "it": it})
		"weapon":
			_attack(it)
		"seed":
			if Input.is_action_just_pressed("use"):
				_plant(it)
		"place":
			if Input.is_action_just_pressed("use"):
				_place(it)
		"eat":
			if Input.is_action_just_pressed("use"):
				_eat(it)

func _begin_use(anim: String, dur: float, impact: float, data: Dictionary) -> void:
	action_dur = dur
	action_lock = dur
	use_cd = dur
	doll.play_action(anim)
	_action_name = anim
	_action_count += 1
	data["t"] = impact
	pending_hit = data
	Sfx.play_at("swing", global_position, -10.0)

func _resolve_use(ph: Dictionary) -> void:
	var z := zone()
	if z == null:
		return
	if ph.get("weapon", false):
		_melee_hit(ph["it"])
		return
	var tool: String = ph.get("tool", "")
	var it: Dictionary = ph.get("it", {})
	var tier := int(Items.def(it.get("id", "hoe_0")).get("tool", {}).get("tier", 0))
	match tool:
		"hoe":
			if target_tile.x > -99999 and z is Overworld and (z as Overworld).farm.can_till(target_tile) and not (z as Overworld).farm.tiles().has(target_tile):
				Net.request("till", {"tiles": _area_tiles(target_tile, tier, (z as Overworld).farm, "till")})
				Fx.dust(z.fx_root, (z as Overworld).farm.tile_center(target_tile))
				Sfx.play_at("dig", global_position)
				Game.add_xp("farming", 0.5)
				return
			var o := z.nearest(_aim_point(REACH), 1.4, func(x): return x.accepts_tool("hoe") and not (x is Feature))
			if o:
				o.tool_hit(self, "hoe", tier, 1.0)
			elif target_tile.x > -99999 and z is Overworld and (z as Overworld).farm.tiles().has(target_tile):
				var tv: Dictionary = (z as Overworld).farm.tiles()[target_tile]
				if tv.has("crop") and tv["crop"].get("dead", false):
					Net.request("clear_crop", {"k": target_tile})
		"can":
			_water(z, it, tier)
		"axe", "pick":
			var pw := 1.0 + tier * 0.75
			if tool == "pick":
				pw *= 1.0 + 0.5 * Game.buff("mining") + 0.1 * Game.skill_level("mining")
			else:
				pw *= 1.0 + 0.4 * Game.trait_count("woodsman") + 0.08 * Game.skill_level("foraging")
			if target_obj and is_instance_valid(target_obj) and target_obj.accepts_tool(tool):
				target_obj.tool_hit(self, tool, tier, pw)
				Zones.fx(zone_id, "shake", target_obj.global_position, {"id": target_obj.oid})
				Zones.fx(zone_id, "burst", target_obj.global_position + Vector3(0, 0.7, 0), {"c": Color("c8a070") if tool == "axe" else Color("8f8d88"), "s": "chop" if tool == "axe" else "mine"})
			elif tool == "pick" and target_tile.x > -99999 and z is Overworld:
				pass
			else:
				var ap := _aim_point(1.6)
				if tool == "pick" and z is Overworld:
					var k := FarmLayer.tile_of(ap)
					var tv2: Dictionary = (z as Overworld).farm.tiles().get(k, {})
					if not tv2.is_empty() and not tv2.has("crop"):
						Net.request("untill", {"k": k})
						return
				Sfx.play_at("whoosh", global_position, -8.0)

func _area_tiles(k: Vector2i, tier: int, farm: FarmLayer, mode: String) -> Array:
	var out: Array = [k]
	if tier <= 0:
		return out
	var d := _aim_dir()
	var step := Vector2i(int(round(d.x)), int(round(d.z)))
	if step == Vector2i.ZERO:
		step = Vector2i(0, 1)
	if abs(d.x) > abs(d.z):
		step = Vector2i(sign(d.x), 0)
	else:
		step = Vector2i(0, sign(d.z))
	var side := Vector2i(step.y, step.x)
	var length = [1, 3, 5, 3, 5][tier]
	var width = [1, 1, 1, 3, 3][tier]
	out.clear()
	for i in length:
		for j in width:
			var t = k + step * i + side * (j - width / 2)
			if mode == "till":
				if farm.can_till(t) and not farm.tiles().has(t):
					out.append(t)
			else:
				if farm.tiles().has(t):
					out.append(t)
	if out.is_empty():
		out.append(k)
	return out

func _water(z: Zone, it: Dictionary, tier: int) -> void:
	var cap = [20, 35, 55, 80, 120][tier]
	var cur := int(Game.me.get("water", cap))
	# refill from any water nearby
	var ap := _aim_point(2.6)
	if not z.water_at(ap).is_empty() or _near_well(z):
		Game.me["water"] = cap
		Fx.splash(z.fx_root, ap if z.water_at(ap).size() > 0 else global_position + _aim_dir())
		Sfx.play_at("splash", ap)
		Game.say("Watering can filled.", Color("bfe3ff"))
		return
	if cur <= 0:
		Game.say("The watering can is empty. Fill it at water or a well.", Color("ffb08a"))
		return
	if target_tile.x > -99999 and z is Overworld:
		var farm: FarmLayer = (z as Overworld).farm
		if farm.tiles().has(target_tile):
			var ts := _area_tiles(target_tile, tier, farm, "water")
			Net.request("water", {"tiles": ts, "gt": Game.has_trait("greenthumb")})
			Game.me["water"] = max(0, cur - ts.size())
			for t in ts:
				Fx.burst(z.fx_root, farm.tile_center(t) + Vector3(0, 0.3, 0), Color(0.6, 0.8, 1.0, 0.8), 5, 1.5, 0.06)
			Sfx.play_at("water", global_position)
			Game.add_xp("farming", 0.4 * ts.size())
			Game.main.hud.refresh_hotbar()
			return
	# watering an object that accepts the can (a well)
	Sfx.play_at("water", global_position, -6.0)

func _near_well(z: Zone) -> bool:
	for o in z.query(global_position, 2.8):
		if o is Feature and o.action == "well":
			return true
	return false

func _plant(it: Dictionary) -> void:
	var z := zone()
	if not (z is Overworld) or target_tile.x <= -99999:
		Game.say("Seeds need tilled soil on the farm.", Color("ffb08a"))
		return
	var farm: FarmLayer = (z as Overworld).farm
	var tv: Dictionary = farm.tiles().get(target_tile, {})
	if tv.is_empty():
		Game.say("Till the soil with a hoe first.", Color("ffb08a"))
		return
	if tv.has("crop"):
		return
	var crop: String = Items.def(it["id"])["seed"]
	var cd: Dictionary = Items.crops[crop]
	if not cd["perennial"] and not cd["seasons"].has(Game.season()):
		Game.say("%s won't grow in %s." % [Items.def(crop)["name"], Items.season_name(Game.season())], Color("ffb08a"))
		return
	Game.inv.take_at(hot_index, 1)
	Game.inventory_changed.emit()
	Net.request("plant", {"k": target_tile, "crop": crop, "by": Game.profile["name"]})
	doll.play_action("eat")
	Sfx.play_at("plant", global_position)
	Game.add_xp("farming", 1.0)
	Game.add_stat("seeds_planted")

func _place(it: Dictionary) -> void:
	var id: String = it["id"]
	var pos := place_position(id)
	if not can_place(id, pos):
		Sfx.play("error", -6.0)
		return
	Game.inv.take_at(hot_index, 1)
	Game.inventory_changed.emit()
	var extra := {}
	if id.ends_with("_sapling"):
		extra = {"fruit": Items.def(id)["place"]["fruit"], "planted": Game.day(), "fruit_n": 0}
	Net.request("place_obj", {"item": id, "z": zone_id, "p": pos, "r": place_rot, "d": extra})
	Sfx.play_at("place", pos)
	Game.add_stat("things_placed")

func _eat(it: Dictionary) -> void:
	var id: String = it["id"]
	var d := Items.def(id)
	var food: Dictionary = d["food"]
	var use: String = food.get("use", "")
	var z := zone()
	if use == "escape":
		if not z.underground():
			Game.say("You're already above ground.", Color("ffb08a"))
			return
		Game.inv.take_at(hot_index, 1)
		Game.inventory_changed.emit()
		Game.main.escape_to_surface()
		return
	if use == "grow" or use == "rain":
		if not (z is Overworld):
			Game.say("Pour it out on the farm.", Color("ffb08a"))
			return
		Game.inv.take_at(hot_index, 1)
		Game.inventory_changed.emit()
		if use == "rain":
			Net.request("water_all", {})
		else:
			Net.request("grow_area", {"pos": global_position, "r": float(food.get("radius", 4.0))})
		Fx.sparkle(z.fx_root, global_position + Vector3(0, 1, 0), Items.def(id)["icon"][1], 30, 3.0)
		Sfx.play_at("magic", global_position)
		doll.play_action("pour")
		Game.learn_item(id)
		return
	if food.get("raw", false) and hp >= max_hp() - 1.0:
		Game.say("You're not hungry enough to eat that raw.", Color("ffb08a"))
		return
	Game.inv.take_at(hot_index, 1)
	Game.inventory_changed.emit()
	action_dur = 0.6
	action_lock = 0.5
	doll.play_action("eat")
	_action_name = "eat"
	_action_count += 1
	var mult := 1.0 + 0.3 * Game.trait_count("gourmand") + 0.05 * Game.skill_level("cooking")
	var heal := float(food.get("heal", 0)) * mult
	if heal > 0:
		hp = min(max_hp(), hp + heal)
		Fx.float_text(z.fx_root, global_position + Vector3(0, 2.2, 0), "+%d" % int(heal), Color("8aff9a"), 44)
	var b: Dictionary = food.get("buff", {})
	if not b.is_empty():
		Game.add_buff(b["type"], float(b["mag"]) * mult, float(b["dur"]))
		if food.get("party", false):
			Net.request("party_buff", {"type": b["type"], "mag": float(b["mag"]), "dur": float(b["dur"]), "heal": heal, "z": zone_id})
	Sfx.play_at("drink" if d.get("drink", false) else "eat", global_position)
	Game.learn_item(id)
	Game.add_stat("meals_eaten" if not d.get("drink", false) else "drinks")

func _drop_held(all: bool) -> void:
	var it := held_item()
	if it.is_empty():
		return
	var n := int(it["n"]) if all else 1
	var out := Game.inv.take_at(hot_index, n)
	Game.inventory_changed.emit()
	Net.request("drop_item", {"item": out, "zone": zone_id, "pos": global_position + Vector3(sin(facing), 0.8, cos(facing)) * 1.0})

# ------------------------------------------------------------------ combat

func _attack(it: Dictionary) -> void:
	var w: Dictionary = Items.def(it["id"])["weapon"]
	var t: float = w["time"] * (0.85 if Items.item_traits(it).has("quickdraw") or Game.has_trait("quickdraw") else 1.0)
	var kind: String = w["kind"]
	var anim := "slash"
	match kind:
		"spear":
			anim = "thrust"
		"hammer":
			anim = "overhead"
		"dagger":
			anim = "slash"
	combo = (combo + 1) % 2
	action_dur = t
	action_lock = t * 0.8
	use_cd = t
	doll.play_action(anim)
	_action_name = anim
	_action_count += 1
	var impact: float = w.get("windup", 0.0) if w.get("windup", 0.0) > 0.0 else t * 0.3
	pending_hit = {"t": impact, "weapon": true, "it": it}
	Sfx.play_at("swing", global_position, -6.0)
	if kind == "spear":
		velocity += Vector3(sin(facing), 0, cos(facing)) * 3.0

func _melee_hit(it: Dictionary) -> void:
	var z := zone()
	var w: Dictionary = Items.def(it["id"])["weapon"]
	var traits := Items.item_traits(it)
	var rng: float = w["range"] * (1.2 if traits.has("reach") else 1.0)
	var arc: float = w["arc"]
	var fwd := Vector3(sin(facing), 0, cos(facing))
	Fx.slash(z.fx_root, global_position + Vector3(0, 1.0, 0), facing, rng, max(arc, 40.0), Color(1, 1, 0.95))
	Zones.fx(zone_id, "slash", global_position + Vector3(0, 1.0, 0), {"yaw": facing, "r": rng, "arc": max(arc, 40.0)})
	if w["kind"] == "hammer":
		Fx.ring(z.fx_root, global_position + fwd * 1.2, rng, Color(1, 0.95, 0.8, 0.7))
		if cam:
			cam.shake(0.12)
	var hit_any := false
	for eid in Zones.enemies:
		var e = Zones.enemies[eid]
		if not is_instance_valid(e) or e.zone_id != zone_id or e.dead or e.untargetable():
			continue
		var d: Vector3 = e.global_position - global_position
		d.y = 0
		if d.length() > rng + e.radius:
			continue
		if d.length() > 0.5 and rad_to_deg(fwd.angle_to(d.normalized())) > arc / 2.0 + 10.0:
			continue
		_deal_damage(e, it, w, traits, d)
		hit_any = true
	# break barrels/crates and cut weeds
	for o in z.query(global_position + fwd * rng * 0.5, rng * 0.6):
		if o is ResourceNode and o.accepts_tool("any") and o.sub in ["weed", "barrel", "crate", "twig"]:
			var d2: Vector3 = o.global_position - global_position
			d2.y = 0
			if d2.length() < 0.5 or rad_to_deg(fwd.angle_to(d2.normalized())) < max(arc, 60.0) / 2.0 + 15.0:
				o.tool_hit(self, "any", 5, 2.0)
	if hit_any:
		Sfx.play_at("hit", global_position)

func _deal_damage(e, it: Dictionary, w: Dictionary, traits: Array, d: Vector3) -> void:
	var dmg: float = w["dmg"]
	var z := zone()
	if z.underground() and traits.has("delver"):
		dmg *= 1.25
	if not z.underground() and traits.has("homebody"):
		dmg *= 1.2
	if traits.has("brutal"):
		dmg *= 1.1
	dmg *= 1.0 + 0.25 * Game.buff("attack") + 0.03 * Game.skill_level("combat")
	var crit_ch: float = w["crit"] + 0.12 * Game.trait_count("keen")
	if w["kind"] == "dagger" and e.facing_away_from(global_position):
		crit_ch += 0.4
	var crit := randf() < crit_ch
	if crit:
		dmg *= 1.75
	var kb: Vector3 = d.normalized() * float(w["kb"]) * (1.5 if traits.has("brutal") else 1.0)
	var fx := {}
	if traits.has("ember"):
		fx["burn"] = 3.0
	if traits.has("frost"):
		fx["slow"] = 2.5
	if Game.has_trait("scavenger"):
		fx["scav"] = true
	Zones.hit_enemy(e.eid, dmg, kb, crit, fx)
	if traits.has("leeching") or Game.has_trait("leeching"):
		hp = min(max_hp(), hp + 2.0)

func _handle_bow(delta: float, it: Dictionary) -> void:
	if Input.is_action_pressed("use") and roll_t < 0.0 and use_cd <= 0.0 and not (Game.main and Game.main.mouse_over_ui()):
		if not charging:
			if _arrow_id() == "":
				if Input.is_action_just_pressed("use"):
					Game.say("No arrows! Craft some at a workbench.", Color("ffb08a"))
				return
			charging = true
			charge = 0.0
			doll.play_action("draw")
			_action_name = "draw"
			_action_count += 1
			action_dur = 10.0
		charge = min(1.0, charge + delta / 0.6)
		facing = atan2(_aim_dir().x, _aim_dir().z)
		doll.action_t = min(0.5, charge * 0.5)
	elif charging:
		charging = false
		doll.action = ""
		var arrow := _arrow_id()
		if arrow == "":
			return
		Game.inv.remove(arrow, 1)
		Game.inventory_changed.emit()
		var w: Dictionary = Items.def(it["id"])["weapon"]
		var mult: float = Items.def(arrow)["ammo"]["dmg"]
		var dmg: float = w["dmg"] * mult * (0.35 + 0.65 * charge)
		var dir := _aim_dir()
		var spd := 16.0 + 16.0 * charge
		Zones.fire_projectile(zone_id, "arrow", global_position + Vector3(0, 1.3, 0) + dir * 0.6, dir * spd, dmg, Net.my_id(),
			{"pierce": Items.def(arrow)["ammo"].get("pierce", false), "traits": Items.item_traits(it), "kb": w["kb"]})
		use_cd = 0.25
		Sfx.play_at("bow", global_position)

func _arrow_id() -> String:
	for a in ["crystal_arrow", "iron_arrow", "arrow"]:
		if Game.inv.count(a) > 0:
			return a
	return ""

func take_hit(dmg: float, from: Vector3, src: String) -> void:
	if not is_local or downed or sleeping:
		return
	if iframes > 0.0:
		Fx.float_text(zone().fx_root, global_position + Vector3(0, 2, 0), "dodged", Color("bfe3ff"), 34)
		return
	var def := 0.15 * Game.trait_count("stalwart") + 0.25 * Game.buff("defense") + (0.25 if Game.buff("ironhide") > 0 else 0.0)
	dmg *= 1.0 - min(0.75, def)
	hp -= dmg
	last_hurt = 0.0
	iframes = 0.35
	doll.flash(0.9)
	if cam:
		cam.shake(0.18)
	Sfx.play_at("hurt", global_position)
	Fx.float_text(zone().fx_root, global_position + Vector3(0, 2.1, 0), "-%d" % int(ceil(dmg)), Color("ff7a6a"), 46)
	if Game.buff("ironhide") <= 0.0:
		var kb := global_position - from
		kb.y = 0
		if kb.length() > 0.01:
			velocity += kb.normalized() * 6.0
			global_position += kb.normalized() * 0.4
	if fishing.active():
		fishing.cancel()
	if hp <= 0.0:
		hp = 0.0
		_go_down(src)

# ------------------------------------------------------------------ downed / revive

func _go_down(src: String) -> void:
	downed = true
	var solo := Zones.players_in_zone(zone_id).size() <= 1
	down_t = 6.0 if solo else 30.0
	charging = false
	pending_hit = {}
	Sfx.play("downed")
	Game.say("You're down! %s" % ("" if solo else "Hold on — a friend can revive you."), Color("ff9a7a"))
	Net.request("downed", {"src": src, "z": zone_id})

func _downed_tick(delta: float, input: Vector2) -> void:
	down_t -= delta
	doll.state = "downed"
	doll.animate(delta, 0.0)
	var move := Vector3.ZERO
	if cam:
		move = (cam.right_flat() * input.x - cam.forward_flat() * input.y) * 0.8
	velocity.x = move.x
	velocity.z = move.z
	velocity.y = -1.0 if is_on_floor() else velocity.y - 24.0 * delta
	move_and_slide()
	var all_down := true
	for p in Zones.players_in_zone(zone_id):
		if not p.downed:
			all_down = false
	if down_t <= 0.0 or all_down and down_t < 25.0:
		if all_down and down_t > 3.0:
			down_t = 3.0
		if down_t <= 0.0:
			downed = false
			Game.main.pass_out()

func revive(by_name: String) -> void:
	if not downed:
		return
	downed = false
	hp = max_hp() * 0.35
	iframes = 1.5
	Game.say("%s got you back on your feet!" % by_name, Color("8aff9a"))
	Sfx.play("revive")

func go_to_sleep(bed_pos: Vector3) -> void:
	sleeping = true
	global_position = bed_pos + Vector3(0, 0.55, 0)
	Game.say("You settle in for the night. Time passes quickly once everyone's asleep.", Color("c8d0ff"))

func wake_up() -> void:
	if not sleeping:
		return
	sleeping = false
	global_position += Vector3(1.2, -0.5, 0)

func play_gather() -> void:
	doll.play_action("eat")
	_action_name = "eat"
	_action_count += 1
	action_dur = 0.35

# ------------------------------------------------------------------ interaction

func _interactables(z: Zone) -> Array:
	var out: Array = []
	for o in z.query(global_position, 3.0):
		if o.prompt(self) != "":
			out.append(o)
	return out

func best_interactable():
	var z := zone()
	if z == null:
		return null
	var best = null
	var best_score := 1e9
	var fwd := Vector3(sin(facing), 0, cos(facing))
	var ap := _aim_point(2.4)
	for o in z.query(global_position, 3.2):
		if o.prompt(self) == "":
			continue
		var d: Vector3 = o.global_position - global_position
		d.y = 0
		var dist = d.length() - o.radius
		if dist > 1.9:
			continue
		var ang := fwd.angle_to(d.normalized()) if d.length() > 0.1 else 0.0
		var score = dist + ang * 0.6 + (o.global_position - ap).length() * 0.25
		if score < best_score:
			best_score = score
			best = o
	# harvestable crops
	if z is Overworld:
		var farm: FarmLayer = (z as Overworld).farm
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				var k := FarmLayer.tile_of(ap) + Vector2i(dx, dz)
				if farm.crop_prompt(k) != "":
					var cpos := farm.tile_center(k)
					var dd := cpos.distance_to(global_position)
					if dd < 2.2:
						var sc := dd - 0.3 + (cpos - ap).length() * 0.3
						if sc < best_score:
							best_score = sc
							best = k
	# NPCs and other players
	for n in get_tree().get_nodes_in_group("npcs"):
		if n.zone_id != zone_id:
			continue
		var d3: Vector3 = n.global_position - global_position
		d3.y = 0
		if d3.length() < 2.4:
			var sc2 := d3.length() - 0.5
			if sc2 < best_score:
				best_score = sc2
				best = n
	for p in Zones.players_in_zone(zone_id):
		if p == self or not p.downed:
			continue
		var d4: Vector3 = p.global_position - global_position
		if d4.length() < 2.2:
			best = p
			break
	return best

func prompt_for(t) -> String:
	if t == null:
		return ""
	if t is Vector2i:
		return (zone() as Overworld).farm.crop_prompt(t)
	if t is Player:
		return "Hold to revive %s" % t.pname
	return t.prompt(self)

func _handle_interact(delta: float, just: bool) -> void:
	var t = best_interactable()
	if t is Player:
		revive_t += delta
		if revive_t > 2.0:
			revive_t = 0.0
			Net.request("revive", {"peer": t.peer_id, "by": Game.profile["name"]})
			Game.add_stat("revives")
		return
	revive_t = 0.0
	if not just:
		return
	if t == null:
		return
	facing = atan2((_target_pos(t) - global_position).x, (_target_pos(t) - global_position).z)
	if t is Vector2i:
		var farm: FarmLayer = (zone() as Overworld).farm
		var tv: Dictionary = farm.tiles().get(t, {})
		if farm.crop_stage(tv) == -2:
			Net.request("clear_crop", {"k": t})
		else:
			Net.request("harvest", {"k": t})
			Game.add_xp("farming", 3.0)
		play_gather()
		Sfx.play_at("pluck", global_position)
		return
	t.interact(self)

func _target_pos(t) -> Vector3:
	if t is Vector2i:
		return (zone() as Overworld).farm.tile_center(t)
	return t.global_position
