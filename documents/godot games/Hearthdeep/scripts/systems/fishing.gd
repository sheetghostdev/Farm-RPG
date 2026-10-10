class_name Fishing
extends Node
## Casting, waiting for a bite, hooking and the reeling minigame.
## Where you fish, when, in what weather and with which bait all change what bites.

enum F { IDLE, CHARGE, CAST, WAIT, BITE, REEL }

var player
var state := F.IDLE
var power := 0.0
var t := 0.0
var bite_at := 0.0
var bobber: MeshInstance3D
var line: MeshInstance3D
var cast_from := Vector3.ZERO
var cast_to := Vector3.ZERO
var water := {}
var fish_id := ""
var bait_id := ""
var game: FishingGame
var _ripple_t := 0.0

func active() -> bool:
	return state != F.IDLE

func cancel() -> void:
	if game:
		game.queue_free()
		game = null
	_clear_visuals()
	state = F.IDLE

func _clear_visuals() -> void:
	if bobber:
		bobber.queue_free()
		bobber = null
	if line:
		line.queue_free()
		line = null

func _rod_tier() -> int:
	var it: Dictionary = player.held_item()
	return int(Items.def(it.get("id", "rod_0")).get("tool", {}).get("tier", 0))

func on_use_pressed() -> void:
	match state:
		F.IDLE:
			if Game.main.mouse_over_ui():
				return
			state = F.CHARGE
			power = 0.0
			t = 0.0
		F.WAIT, F.CAST:
			_reel_in("")
		F.BITE:
			_hook()

func on_use_released() -> void:
	if state == F.CHARGE:
		_cast()

func _process(delta: float) -> void:
	if player == null or state == F.IDLE:
		return
	t += delta
	match state:
		F.CHARGE:
			power = clamp(t / 1.1, 0.0, 1.0)
			player.doll.action = "cast"
			player.doll.action_t = 0.05
			Game.main.hud.info_l.text = "Casting power: " + "■".repeat(int(power * 10)) + "□".repeat(10 - int(power * 10))
		F.CAST:
			var k: float = clamp(t / 0.6, 0.0, 1.0)
			var p := cast_from.lerp(cast_to, k)
			p.y += sin(k * PI) * 2.5
			bobber.global_position = p
			if k >= 1.0:
				_landed()
		F.WAIT:
			_ripple_t -= delta
			bobber.global_position.y = water.get("lvl", cast_to.y) + 0.05 + sin(t * 2.0) * 0.03
			if _ripple_t <= 0.0:
				_ripple_t = 2.0
				Fx.ring(player.zone().fx_root, bobber.global_position, 0.8, Color(1, 1, 1, 0.35), 1.2)
			if t >= bite_at:
				_bite()
		F.BITE:
			bobber.global_position.y = water.get("lvl", cast_to.y) - 0.15 + sin(t * 30.0) * 0.06
			if t > 0.95:
				_reel_in("It got away before you could hook it.")
	_update_line()

func _update_line() -> void:
	if bobber == null:
		return
	if line == null:
		line = MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.008
		cm.bottom_radius = 0.008
		cm.height = 1.0
		cm.radial_segments = 4
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(1, 1, 1, 0.7)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		cm.material = m
		line.mesh = cm
		line.top_level = true
		add_child(line)
	var tip: Vector3 = player.global_position + Vector3(0, 2.3, 0) + Vector3(sin(player.rotation.y), 0, cos(player.rotation.y)) * 1.3
	var b := bobber.global_position
	var mid := (tip + b) / 2.0
	var len := tip.distance_to(b)
	line.global_position = mid
	if len > 0.01:
		var up := (tip - b).normalized()
		var basis := Basis()
		var x := up.cross(Vector3.FORWARD if abs(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
		var z := x.cross(up).normalized()
		basis = Basis(x, up, z)
		line.global_transform = Transform3D(basis.scaled(Vector3(1, len, 1)), mid)

func _cast() -> void:
	var dir: Vector3 = player._aim_dir()
	player.facing = atan2(dir.x, dir.z)
	var dist := 2.0 + power * (8.0 + _rod_tier() * 1.0)
	cast_from = player.global_position + Vector3(0, 2.0, 0) + dir * 1.0
	cast_to = player.global_position + dir * dist
	var z = player.zone()
	cast_to.y = z.ground_y(cast_to.x, cast_to.z)
	water = z.water_at(cast_to)
	if not water.is_empty():
		cast_to.y = float(water["lvl"])
	bobber = MeshInstance3D.new()
	var mb := MeshBuilder.new(3)
	mb.sphere(Vector3(0, 0.05, 0), Vector3.ONE * 0.09, Color("e04a3a"), 3, 6)
	mb.sphere(Vector3(0, -0.04, 0), Vector3(0.09, 0.05, 0.09), Color("f4f2ea"), 2, 6)
	bobber.mesh = mb.commit()
	bobber.top_level = true
	add_child(bobber)
	bobber.global_position = cast_from
	player.doll.play_action("cast")
	player.action_dur = 0.5
	Sfx.play_at("whoosh", player.global_position)
	state = F.CAST
	t = 0.0
	Game.main.hud.info_l.text = ""

func _landed() -> void:
	if water.is_empty():
		_reel_in("No water there.")
		return
	Fx.splash(player.zone().fx_root, cast_to)
	Sfx.play_at("splash", cast_to, -6.0)
	bait_id = _best_bait()
	var base := randf_range(3.0, 11.0)
	var mult := 1.0
	if bait_id != "":
		mult *= float(Items.def(bait_id)["bait"].get("bite", 1.0))
	mult *= 1.0 - 0.12 * Game.trait_count("angler")
	mult *= 1.0 - 0.035 * Game.skill_level("fishing")
	mult *= 1.0 - 0.3 * min(Game.buff("fishing"), 2.0) * 0.5
	if Game.buff("deepfish") > 0.0 and player.zone().underground():
		mult *= 0.55
	if Game.is_raining():
		mult *= 0.8
	bite_at = base * max(0.2, mult)
	state = F.WAIT
	t = 0.0
	_ripple_t = 0.5

func _best_bait() -> String:
	for b in ["deluxe_bait", "glowgrub", "magnet_lure", "worm"]:
		if Game.inv.count(b) > 0:
			return b
	return ""

func _bite() -> void:
	state = F.BITE
	t = 0.0
	fish_id = _choose_fish()
	Sfx.play_at("bite", bobber.global_position)
	Fx.splash(player.zone().fx_root, bobber.global_position)
	Fx.float_text(player.zone().fx_root, player.global_position + Vector3(0, 2.6, 0), "!", Color("ffd36b"), 90, 0.4, 0.8)
	Game.main.hud.info_l.text = "Something's biting! Click!"

func _choose_fish() -> String:
	var z = player.zone()
	var kind: String = water.get("kind", "river")
	var pool := Items.fish_for(kind, Game.season(), Game.is_night(), Game.is_raining())
	var junk_chance := 0.1 if not z.underground() else 0.04
	if pool.is_empty() or randf() < junk_chance:
		return ["old_boot", "driftwood", "river_weed", "soggy_letter"][randi() % 4] if not z.underground() else "cave_mushroom"
	var rare_boost := 0.0
	if bait_id != "":
		rare_boost += float(Items.def(bait_id)["bait"].get("rare", 0.0))
	if Game.buff("deepfish") > 0.0:
		rare_boost += 0.3
	rare_boost += 0.04 * Game.skill_level("fishing")
	var tot := 0.0
	var weights: Array = []
	for f in pool:
		var fd: Dictionary = Items.fish[f]
		var w := float(fd["weight"])
		if w < 8.0:
			w *= 1.0 + rare_boost * 3.0
		if fd.get("legend", false):
			w = 0.6 + rare_boost * 2.0
		weights.append(w)
		tot += w
	var r := randf() * tot
	for i in pool.size():
		r -= float(weights[i])
		if r <= 0.0:
			return pool[i]
	return pool[0]

func _hook() -> void:
	if bait_id != "" and Game.inv.count(bait_id) > 0:
		Game.inv.remove(bait_id, 1)
		Game.inventory_changed.emit()
	if Items.cat_of(fish_id) != "fish":
		_finish(true, false, true)
		return
	state = F.REEL
	t = 0.0
	game = FishingGame.new()
	var tier := _rod_tier()
	var zone_px = 70.0 + 7.0 * Game.skill_level("fishing") + 22.0 * tier + 22.0 * Game.trait_count("angler") + 30.0 * min(Game.buff("fishing"), 2.0)
	var treasure_ch := 0.05 + 0.04 * tier + 0.08 * Game.trait_count("lucky")
	if bait_id == "magnet_lure":
		treasure_ch += 0.25
	var fd: Dictionary = Items.fish[fish_id]
	game.setup(fish_id, int(fd["diff"]), fd["behavior"], zone_px, randf() < treasure_ch, Game.has_trait("steady"))
	game.finished.connect(_on_game_done)
	Game.main.hud.root.add_child(game)
	Game.main.hud.info_l.text = ""

func _on_game_done(success: bool, treasure: bool, perfect: bool) -> void:
	game = null
	_finish(success, treasure, false, perfect)

func _finish(success: bool, treasure: bool, junk: bool, perfect: bool = false) -> void:
	var z = player.zone()
	if success:
		var size := 0
		if Items.fish.has(fish_id):
			var sr: Array = Items.fish[fish_id]["size"]
			size = int(lerp(float(sr[0]), float(sr[1]), pow(randf(), 1.5 - 0.05 * Game.skill_level("fishing"))))
		Net.request("catch_fish", {"id": fish_id, "size": size, "z": player.zone_id, "treasure": treasure, "perfect": perfect, "by": Game.profile["name"]})
		Sfx.play("catch" if not junk else "pluck")
		if not junk:
			Game.add_xp("fishing", 4.0 + Items.fish[fish_id]["diff"] * 0.25 + (5.0 if perfect else 0.0))
			Game.add_stat("fish_caught")
			Fx.splash(z.fx_root, bobber.global_position if bobber else player.global_position, true)
	else:
		Sfx.play("fish_escape")
		Game.say("The fish slipped away...", UITheme.TEXT_DIM)
	_clear_visuals()
	state = F.IDLE

func _reel_in(msg: String) -> void:
	if msg != "":
		Game.say(msg, UITheme.TEXT_DIM)
	Sfx.play_at("reel", player.global_position, -6.0)
	_clear_visuals()
	state = F.IDLE
	Game.main.hud.info_l.text = ""
