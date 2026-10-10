extends Node
## Loads and unloads zones (overworld, farmhouse, cave floors), owns player
## avatars, world item pickups, enemies and short-lived effects across the network.

signal zone_entered(zone_id: String)

var world_root: Node3D
var town: TownGen = null
var zones := {}
var players := {}          # peer id -> Player
var _gen: OverworldGen = null
var _gen_seed := -1
var pickups := {}          # server: pid -> {"z", "item", "pos"}
var _next_pid := 1
var night_lights: Array = []
var occluders: Array = []   # [{mi, zone, center, half, yaw}] buildings that hide their roof when in the way
var _occ_t := 0.0
var enemies := {}          # eid -> Enemy (local nodes)
var _enemy_srv := {}       # server: eid -> zone id
var _next_eid := 1
var _snap_t := 0.0
var _unload_t := 0.0

const PLAYER_SCRIPT := preload("res://scripts/entities/player.gd")

func overworld_gen() -> OverworldGen:
	var s := int(Game.world.get("seed", 1))
	if _gen == null or _gen_seed != s:
		_gen = OverworldGen.new()
		_gen.generate(s)
		_gen_seed = s
		if Game.world.get("explored", PackedByteArray()).size() != OverworldGen.EX_W * OverworldGen.EX_W:
			var ex := PackedByteArray()
			ex.resize(OverworldGen.EX_W * OverworldGen.EX_W)
			ex.fill(0)
			Game.world["explored"] = ex
	return _gen

static func origin_for(zid: String) -> Vector3:
	if zid == "over":
		return Vector3.ZERO
	if zid == "home":
		return Vector3(-2000, 0, 0)
	if zid.begins_with("cave_"):
		var n := int(zid.substr(5))
		return Vector3(2000 + ((n - 1) % 8) * 600, 0, ((n - 1) / 8) * 600)
	return Vector3(-4000, 0, 0)

static func floor_of(zid: String) -> int:
	if zid.begins_with("cave_"):
		return int(zid.substr(5))
	return 0

func get_zone(zid: String) -> Zone:
	return zones.get(zid)

func ensure_zone(zid: String) -> Zone:
	if zones.has(zid):
		return zones[zid]
	var z: Zone
	if zid == "over":
		z = Overworld.new()
	elif zid == "home":
		z = HomeZone.new()
	elif zid.begins_with("cave_"):
		z = CaveFloor.new()
		z.floor_n = floor_of(zid)
		z.zone_id = zid
	else:
		push_error("Unknown zone " + zid)
		return null
	z.origin = origin_for(zid)
	z.name = zid
	zones[zid] = z
	world_root.add_child(z)
	z.position = Vector3.ZERO
	z.build()
	if Net.is_server():
		_on_zone_built_server(z)
	return z

func unload_zone(zid: String) -> void:
	if zid == "over" or not zones.has(zid):
		return
	var z: Zone = zones[zid]
	zones.erase(zid)
	for eid in enemies.keys():
		if enemies[eid].zone_id == zid:
			enemies.erase(eid)
	for eid in _enemy_srv.keys():
		if _enemy_srv[eid] == zid:
			_enemy_srv.erase(eid)
	for pid in pickups.keys():
		if pickups[pid]["z"] == zid:
			pickups.erase(pid)
	z.queue_free()

func clear_all() -> void:
	for zid in zones.keys():
		zones[zid].queue_free()
	zones.clear()
	for p in players.values():
		if is_instance_valid(p):
			p.queue_free()
	players.clear()
	enemies.clear()
	_enemy_srv.clear()
	pickups.clear()
	night_lights.clear()
	occluders.clear()

func register_night_light(l: Light3D) -> void:
	night_lights.append(l)

## Buildings register so their roof and upper walls can vanish when they block the view.
func register_occluder(mi: MeshInstance3D, zid: String, center: Vector3, half: Vector3, yaw: float) -> void:
	occluders.append({"mi": mi, "z": zid, "c": center, "h": half, "yaw": yaw, "hidden": false})

func _update_occluders() -> void:
	var lp = Game.local_player
	if lp == null or Game.main == null or Game.main.cam == null:
		return
	var cam_p: Vector3 = Game.main.cam.cam.global_position
	var head: Vector3 = lp.global_position + Vector3(0, 1.2, 0)
	var keep: Array = []
	for o in occluders:
		if not is_instance_valid(o["mi"]):
			continue
		keep.append(o)
		var hide := false
		if o["z"] == lp.zone_id and Vector3(o["c"]).distance_to(head) < 40.0:
			hide = _segment_hits_box(cam_p, head, o["c"], o["h"], o["yaw"])
		if hide != o["hidden"]:
			o["hidden"] = hide
			o["mi"].material_override = Meshes.mat("vc_hidden") if hide else null
	occluders = keep

static func _segment_hits_box(a: Vector3, b: Vector3, c: Vector3, h: Vector3, yaw: float) -> bool:
	var inv := Basis(Vector3.UP, -yaw)
	var la := inv * (a - c)
	var lb := inv * (b - c)
	var d := lb - la
	var t0 := 0.0
	var t1 := 1.0
	for i in 3:
		if abs(d[i]) < 1e-6:
			if la[i] < -h[i] or la[i] > h[i]:
				return false
		else:
			var ta := (-h[i] - la[i]) / d[i]
			var tb := (h[i] - la[i]) / d[i]
			if ta > tb:
				var tmp := ta
				ta = tb
				tb = tmp
			t0 = max(t0, ta)
			t1 = min(t1, tb)
			if t0 > t1:
				return false
	return true

## Zones the server must keep simulated: every zone with a player in it.
func _needed_zones() -> Dictionary:
	var need := {"over": true}
	for id in Net.peers:
		need[Net.peers[id].get("zone", "over")] = true
	if Game.local_player:
		need[Game.local_player.zone_id] = true
	return need

func _process(delta: float) -> void:
	if not Game.running:
		return
	_unload_t += delta
	if _unload_t > 5.0:
		_unload_t = 0.0
		var need := {"over": true}
		if Net.is_server():
			need = _needed_zones()
		elif Game.local_player:
			need[Game.local_player.zone_id] = true
		for zid in zones.keys():
			if not need.has(zid):
				unload_zone(zid)
	_occ_t += delta
	if _occ_t > 0.1:
		_occ_t = 0.0
		_update_occluders()
	if Net.is_server():
		_snap_t += delta
		if _snap_t >= 0.066:
			_snap_t = 0.0
			_send_enemy_snapshots()

# ------------------------------------------------------------------ players

func spawn_local_player(info: Dictionary, zid: String, pos: Vector3) -> Node3D:
	var p = PLAYER_SCRIPT.new()
	p.peer_id = Net.my_id()
	p.is_local = true
	p.name = "P%d" % p.peer_id
	world_root.add_child(p)
	p.setup(info)
	players[p.peer_id] = p
	Game.local_player = p
	travel_local(zid, pos)
	return p

func spawn_remote_player(id: int, info: Dictionary) -> void:
	if players.has(id) or id == Net.my_id():
		return
	var p = PLAYER_SCRIPT.new()
	p.peer_id = id
	p.is_local = false
	p.name = "P%d" % id
	world_root.add_child(p)
	p.setup(info)
	p.zone_id = info.get("zone", "over")
	players[id] = p

func remove_remote_player(id: int) -> void:
	if players.has(id):
		players[id].queue_free()
		players.erase(id)

func update_remote_player(id: int, st: Array) -> void:
	var p = players.get(id)
	if p == null:
		if Net.peers.has(id):
			spawn_remote_player(id, Net.peers[id])
			p = players.get(id)
		if p == null:
			return
	p.apply_net_state(st)

func players_in_zone(zid: String) -> Array:
	var out: Array = []
	for p in players.values():
		if is_instance_valid(p) and p.zone_id == zid:
			out.append(p)
	return out

## Move the local player to a zone (loading it if needed).
func travel_local(zid: String, pos = null, tag: String = "") -> void:
	var p = Game.local_player
	if p == null:
		return
	var z := ensure_zone(zid)
	if z == null:
		return
	var target: Vector3 = pos if pos != null else z.spawn_point(tag)
	var old: String = p.zone_id
	p.zone_id = zid
	p.global_position = target
	p.velocity = Vector3.ZERO
	p.on_zone_changed()
	if Game.main:
		Game.main.on_zone_changed(z)
	if not Net.is_server():
		Net.request("enter_zone", {"z": zid})
	else:
		_server_player_entered(Net.my_id(), zid)
	for rp in players.values():
		if is_instance_valid(rp) and not rp.is_local:
			rp.refresh_visibility()
	zone_entered.emit(zid)

# ------------------------------------------------------------------ server-side zone simulation

func server_enter_zone(peer: int, zid: String) -> void:
	if not Net.peers.has(peer):
		return
	Net.peers[peer]["zone"] = zid
	ensure_zone(zid)
	_server_player_entered(peer, zid)

func _server_player_entered(peer: int, zid: String) -> void:
	var z := get_zone(zid)
	if z and z.has_method("on_player_entered_server"):
		z.on_player_entered_server(peer)
	# send current pickups and enemies in that zone
	if peer != Net.my_id():
		var pk: Array = []
		for pid in pickups:
			if pickups[pid]["z"] == zid:
				pk.append([pid, pickups[pid]["item"], pickups[pid]["pos"]])
		var en: Array = []
		for eid in _enemy_srv:
			if _enemy_srv[eid] == zid and enemies.has(eid):
				var e = enemies[eid]
				en.append([eid, e.etype, e.global_position, e.level, e.hp, e.elite])
		_rpc_zone_snapshot.rpc_id(peer, zid, pk, en)

func _on_zone_built_server(z: Zone) -> void:
	if z.has_method("server_populate"):
		z.server_populate()

@rpc("authority", "reliable")
func _rpc_zone_snapshot(zid: String, pk: Array, en: Array) -> void:
	var z := get_zone(zid)
	if z == null:
		return
	for p in pk:
		_add_pickup_local(zid, p[0], p[1], p[2], Vector3.ZERO)
	for e in en:
		_add_enemy_local(zid, e[0], e[1], e[2], e[3], e[4], e[5])

# ------------------------------------------------------------------ pickups

## Server: drop items into the world as pickups everyone can grab.
func spawn_pickups(zid: String, pos: Vector3, items: Array, spread: float = 1.5) -> void:
	if not Net.is_server():
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for it in items:
		if it["id"] == "$money":
			Net.server.add_money(int(it["n"]), "")
			Net.broadcast({"t": "toast", "text": "+%d coins" % int(it["n"]), "color": Color("ffd36b")})
			continue
		var pid := _next_pid
		_next_pid += 1
		var vel := Vector3(rng.randf_range(-spread, spread), rng.randf_range(4.0, 6.0), rng.randf_range(-spread, spread))
		pickups[pid] = {"z": zid, "item": it, "pos": pos}
		_rpc_pickup_add.rpc(zid, pid, it, pos, vel)

@rpc("authority", "call_local", "reliable")
func _rpc_pickup_add(zid: String, pid: int, item: Dictionary, pos: Vector3, vel: Vector3) -> void:
	_add_pickup_local(zid, pid, item, pos, vel)

func _add_pickup_local(zid: String, pid: int, item: Dictionary, pos: Vector3, vel: Vector3) -> void:
	var z := get_zone(zid)
	if z == null:
		return
	if z.pickups_root.has_node("pk%d" % pid):
		return
	var pk := Pickup.new()
	pk.name = "pk%d" % pid
	pk.pid = pid
	pk.item = item
	pk.zone = z
	z.pickups_root.add_child(pk)
	pk.global_position = pos
	pk.velocity = vel

func take_pickup_server(peer: int, pid: int) -> void:
	if not pickups.has(pid):
		return
	var it: Dictionary = pickups[pid]["item"]
	var zid: String = pickups[pid]["z"]
	pickups.erase(pid)
	_rpc_pickup_del.rpc(zid, pid)
	Net.grant(peer, [it])

@rpc("authority", "call_local", "reliable")
func _rpc_pickup_del(zid: String, pid: int) -> void:
	var z := get_zone(zid)
	if z and z.pickups_root.has_node("pk%d" % pid):
		z.pickups_root.get_node("pk%d" % pid).collect_anim()

# ------------------------------------------------------------------ enemies

func server_spawn_enemy(zid: String, etype: String, pos: Vector3, level: int, elite: bool = false) -> int:
	var eid := _next_eid
	_next_eid += 1
	_enemy_srv[eid] = zid
	var hp := Enemy.base_hp(etype, level, elite)
	_rpc_enemy_add.rpc(zid, eid, etype, pos, level, hp, elite)
	return eid

@rpc("authority", "call_local", "reliable")
func _rpc_enemy_add(zid: String, eid: int, etype: String, pos: Vector3, level: int, hp: float, elite: bool) -> void:
	_add_enemy_local(zid, eid, etype, pos, level, hp, elite)

func _add_enemy_local(zid: String, eid: int, etype: String, pos: Vector3, level: int, hp: float, elite: bool) -> void:
	var z := get_zone(zid)
	if z == null or enemies.has(eid):
		return
	var e := Enemy.new()
	e.eid = eid
	e.etype = etype
	e.level = level
	e.zone_id = zid
	e.zone = z
	e.elite = elite
	e.authority = Net.is_server()
	z.enemies_root.add_child(e)
	e.global_position = pos
	e.setup(hp)
	enemies[eid] = e

func _send_enemy_snapshots() -> void:
	if not Net.is_online():
		return
	var by_zone := {}
	for eid in _enemy_srv:
		var e = enemies.get(eid)
		if e == null or not is_instance_valid(e):
			continue
		var zid: String = _enemy_srv[eid]
		if not by_zone.has(zid):
			by_zone[zid] = []
		by_zone[zid].append_array([eid, e.global_position.x, e.global_position.y, e.global_position.z, e.rotation.y, e.state_code(), e.hp, e.state_t])
	for zid in by_zone:
		for peer in Net.peers:
			if peer != Net.my_id() and Net.peers[peer].get("zone", "") == zid:
				_rpc_enemy_snap.rpc_id(peer, by_zone[zid])

@rpc("authority", "unreliable_ordered")
func _rpc_enemy_snap(data: Array) -> void:
	var i := 0
	while i + 7 < data.size():
		var e = enemies.get(int(data[i]))
		if e:
			e.apply_snapshot(Vector3(data[i + 1], data[i + 2], data[i + 3]), data[i + 4], int(data[i + 5]), float(data[i + 6]), float(data[i + 7]))
		i += 8

## A client hit an enemy: forward to the server which owns its health.
func hit_enemy(eid: int, dmg: float, kb: Vector3, crit: bool, effects: Dictionary = {}) -> void:
	if Net.is_server():
		_server_hit(Net.my_id(), eid, dmg, kb, crit, effects)
	else:
		_rpc_hit_enemy.rpc_id(1, eid, dmg, kb, crit, effects)

@rpc("any_peer", "reliable")
func _rpc_hit_enemy(eid: int, dmg: float, kb: Vector3, crit: bool, effects: Dictionary) -> void:
	if Net.is_server():
		_server_hit(multiplayer.get_remote_sender_id(), eid, dmg, kb, crit, effects)

func _server_hit(peer: int, eid: int, dmg: float, kb: Vector3, crit: bool, effects: Dictionary) -> void:
	var e = enemies.get(eid)
	if e == null or e.dead:
		return
	var real: float = e.server_take_hit(dmg, kb, effects, peer)
	_rpc_enemy_hit_fx.rpc(eid, real, kb, crit)
	if e.hp <= 0.0:
		e.dead = true
		var zid: String = _enemy_srv.get(eid, e.zone_id)
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		var scav := bool(effects.get("scav", false))
		var drops := Loot.enemy_drops(e.etype, floor_of(zid), rng, scav)
		if e.elite:
			drops.append_array(Loot.enemy_drops(e.etype, floor_of(zid) + 4, rng, true))
			drops.append(Loot.equipment(Loot.tier_for_depth(floor_of(zid)) + 1, rng))
		spawn_pickups(zid, e.global_position + Vector3(0, 0.5, 0), drops)
		_enemy_srv.erase(eid)
		_rpc_enemy_die.rpc(eid, peer)
		var z := get_zone(zid)
		if z and z.has_method("on_enemy_killed"):
			z.on_enemy_killed(e.etype, peer, e.elite)
		Net.server.on_enemy_killed(peer, e.etype, zid)

@rpc("authority", "call_local", "reliable")
func _rpc_enemy_hit_fx(eid: int, dmg: float, kb: Vector3, crit: bool) -> void:
	var e = enemies.get(eid)
	if e:
		e.hit_fx(dmg, kb, crit)

@rpc("authority", "call_local", "reliable")
func _rpc_enemy_die(eid: int, killer: int) -> void:
	var e = enemies.get(eid)
	if e:
		enemies.erase(eid)
		e.die_fx()
		if killer == Net.my_id():
			Game.add_xp("combat", 4.0 + e.level * 0.6)
			Game.add_stat("creatures_defeated")

## Server -> one player: you were hit by something.
func hurt_player(peer: int, dmg: float, from: Vector3, src: String) -> void:
	if peer == Net.my_id():
		if Game.local_player:
			Game.local_player.take_hit(dmg, from, src)
	else:
		_rpc_hurt.rpc_id(peer, dmg, from, src)

@rpc("authority", "reliable")
func _rpc_hurt(dmg: float, from: Vector3, src: String) -> void:
	if Game.local_player:
		Game.local_player.take_hit(dmg, from, src)

# ------------------------------------------------------------------ projectiles & fx

func fire_projectile(zid: String, kind: String, pos: Vector3, vel: Vector3, dmg: float, owner_peer: int, extra: Dictionary = {}) -> void:
	_spawn_projectile_local(zid, kind, pos, vel, dmg, owner_peer, extra)
	if Net.is_online():
		_rpc_projectile.rpc(zid, kind, pos, vel, dmg, owner_peer, extra)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_projectile(zid: String, kind: String, pos: Vector3, vel: Vector3, dmg: float, owner_peer: int, extra: Dictionary) -> void:
	_spawn_projectile_local(zid, kind, pos, vel, dmg, owner_peer, extra)

func _spawn_projectile_local(zid: String, kind: String, pos: Vector3, vel: Vector3, dmg: float, owner_peer: int, extra: Dictionary) -> void:
	var z := get_zone(zid)
	if z == null:
		return
	var pr := Projectile.new()
	pr.kind = kind
	pr.velocity = vel
	pr.damage = dmg
	pr.owner_peer = owner_peer
	pr.zone = z
	pr.extra = extra
	z.fx_root.add_child(pr)
	pr.global_position = pos
	pr.setup()

## Cosmetic effect broadcast (tree shake, splash, slash arcs) for other players.
func fx(zid: String, kind: String, pos: Vector3, args: Dictionary = {}) -> void:
	if Net.is_online():
		_rpc_fx.rpc(zid, kind, pos, args)

@rpc("any_peer", "call_remote", "unreliable")
func _rpc_fx(zid: String, kind: String, pos: Vector3, args: Dictionary) -> void:
	var z := get_zone(zid)
	if z == null:
		return
	match kind:
		"burst":
			Fx.burst(z.fx_root, pos, args.get("c", Color.WHITE), 8, 3.0)
			Sfx.play_at(args.get("s", "mine"), pos)
		"splash":
			Fx.splash(z.fx_root, pos, args.get("big", false))
			Sfx.play_at("splash", pos)
		"slash":
			Fx.slash(z.fx_root, pos, args.get("yaw", 0.0), args.get("r", 2.0), args.get("arc", 100.0), Color(1, 1, 1))
			Sfx.play_at("swing", pos)
		"shake":
			var o = z.objs.get(args.get("id", ""))
			if o:
				o.shake()
		"sparkle":
			Fx.sparkle(z.fx_root, pos, args.get("c", Color("ffe08a")))
		"ring":
			Fx.ring(z.fx_root, pos, args.get("r", 3.0), args.get("c", Color(1, 1, 1, 0.6)))
