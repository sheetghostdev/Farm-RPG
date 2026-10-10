class_name Projectile
extends Node3D
## Arrows, spore spit and crystal shards. Simulated identically on every peer;
## each peer only applies damage that concerns it (its own arrows, its own player).

var kind := ""
var velocity := Vector3.ZERO
var damage := 1.0
var owner_peer := 0
var zone: Zone
var extra := {}
var life := 3.0
var _hit := {}
var _done := false

func setup() -> void:
	var mb := MeshBuilder.new(1)
	match kind:
		"arrow":
			mb.cyl(Vector3(0, 0, -0.45), 0.02, 0.02, 0.8, 4, Color("c8a070"), Vector3(PI / 2, 0, 0))
			mb.cone(Vector3(0, 0, 0.35), 0.05, 0.14, 4, Color("d8d8e0"), Vector3(PI / 2, 0, 0))
			mb.box(Vector3(0, 0, -0.42), Vector3(0.12, 0.01, 0.12), Color("e8e0d0"))
		"spit":
			mb.surface("glow")
			mb.sphere(Vector3.ZERO, Vector3.ONE * 0.22, Color("c8ff6a"), 3, 6)
			mb.surface("vc")
		"shard":
			mb.surface("glow")
			mb.cyl(Vector3(0, 0, -0.4), 0.12, 0.0, 0.8, 5, Color("8fd8ff"), Vector3(PI / 2, 0, 0))
			mb.surface("vc")
	var mi := MeshInstance3D.new()
	mi.mesh = mb.commit()
	add_child(mi)
	if kind != "arrow":
		var l := OmniLight3D.new()
		l.light_color = Color("c8ff6a") if kind == "spit" else Color("8fd8ff")
		l.light_energy = 0.8
		l.omni_range = 3.0
		add_child(l)

func _physics_process(delta: float) -> void:
	if _done:
		return
	life -= delta
	if life <= 0.0:
		_impact(false)
		return
	velocity.y -= float(extra.get("g", 0.0)) * delta
	if kind == "arrow":
		velocity.y -= 4.0 * delta
	var np := global_position + velocity * delta
	if velocity.length() > 0.1:
		look_at(np if not np.is_equal_approx(global_position) else np + Vector3.FORWARD, Vector3.UP if abs(velocity.normalized().y) < 0.99 else Vector3.RIGHT)
	global_position = np
	# terrain & walls
	var gy := zone.ground_y(np.x, np.z)
	if np.y <= gy + 0.05:
		_impact(true)
		return
	if zone is CaveFloor and (zone as CaveFloor).cell_type(np) == CaveGen.T.WALL:
		_impact(false)
		return
	if kind == "arrow":
		if owner_peer == Net.my_id():
			for eid in Zones.enemies:
				var e = Zones.enemies[eid]
				if not is_instance_valid(e) or e.dead or e.zone_id != zone.zone_id or _hit.has(eid) or e.untargetable():
					continue
				var c: Vector3 = e.global_position + Vector3(0, 0.6 if e.etype != "bat" else 1.5, 0)
				if c.distance_to(np) < e.radius + 0.45:
					_hit[eid] = true
					var traits: Array = extra.get("traits", [])
					var dmg := damage
					if zone.underground() and traits.has("delver"):
						dmg *= 1.25
					var crit := randf() < 0.08 + 0.12 * Game.trait_count("keen")
					if crit:
						dmg *= 1.75
					var fx := {}
					if traits.has("ember"):
						fx["burn"] = 3.0
					if traits.has("frost"):
						fx["slow"] = 2.5
					Zones.hit_enemy(eid, dmg, velocity.normalized() * float(extra.get("kb", 3.0)), crit, fx)
					Sfx.play_at("arrow_hit", np)
					if not extra.get("pierce", false):
						_impact(false)
						return
	else:
		var lp = Game.local_player
		if lp and lp.zone_id == zone.zone_id and not lp.downed:
			if (lp.global_position + Vector3(0, 1.0, 0)).distance_to(np) < 0.75:
				lp.take_hit(damage, global_position - velocity.normalized(), kind)
				_impact(false)

func _impact(ground: bool) -> void:
	if _done:
		return
	_done = true
	match kind:
		"spit":
			Fx.burst(zone.fx_root, global_position, Color("c8ff6a"), 14, 3.0, 0.1)
			Fx.ring(zone.fx_root, global_position, float(extra.get("aoe", 1.4)), Color(0.8, 1.0, 0.4, 0.6))
			Sfx.play_at("slime", global_position)
			var lp = Game.local_player
			if lp and lp.zone_id == zone.zone_id and not lp.downed:
				var d: Vector3 = lp.global_position - global_position
				d.y = 0
				if d.length() < float(extra.get("aoe", 1.4)):
					lp.take_hit(damage, global_position, "spit")
		"shard":
			Fx.burst(zone.fx_root, global_position, Color("8fd8ff"), 10, 3.0, 0.08)
			Sfx.play_at("mine", global_position, -6.0)
		"arrow":
			if ground:
				Fx.dust(zone.fx_root, global_position)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE * 0.05, 0.1)
	tw.tween_callback(queue_free)
