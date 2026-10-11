class_name AutoTest
extends Node
## Command-line driven tests: --autotest=<name>. Used for headless checks and screenshots.

var out_dir := "res://tests_out"

func run(name: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var gi := FileAccess.open(out_dir + "/.gdignore", FileAccess.WRITE)
	if gi:
		gi.store_string("")
	var parts := name.split(":")
	call_deferred("_run_" + parts[0], parts.slice(1))

func _log(s: String) -> void:
	print("[autotest] ", s)

func _start_world(seed_v: int = 12345) -> void:
	Game.profile["name"] = "Tester"
	var t0 := Time.get_ticks_msec()
	var err: String = Game.main.start_new_world("Test World", seed_v, {"season_len": 14}, false, 0)
	_log("world started in %d ms err='%s'" % [Time.get_ticks_msec() - t0, err])

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _shot(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		await get_tree().process_frame
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var p := ProjectSettings.globalize_path(out_dir + "/" + name + ".png")
	img.save_png(p)
	_log("saved " + p)

func _run_gen(_a: Array) -> void:
	_start_world()
	await _frames(10)
	var z = Zones.get_zone("over")
	_log("objs=%d spawns=%d pois=%d" % [z.objs.size(), z.gen.spawns.size(), z.gen.pois.size()])
	get_tree().quit()

func _run_shot(a: Array) -> void:
	_start_world(int(a[0]) if a.size() > 0 else 12345)
	await _frames(30)
	var lp = Game.local_player
	var views := a.slice(1) if a.size() > 1 else ["farm"]
	for v in views:
		_place_view(v)
		await _frames(40)
		await _shot("shot_" + v)
	get_tree().quit()

func _place_view(v: String) -> void:
	var z = Zones.get_zone("over")
	var lp = Game.local_player
	var g = z.gen
	var cam = Game.main.cam
	match v:
		"farm":
			Game.tod = 240.0
		"town":
			lp.global_position = z.spawn_point("town")
		"cave":
			lp.global_position = z.spawn_point("cave")
		"lake":
			var c: Vector2 = g.ponds[0]["c"]
			lp.global_position = Vector3(c.x + g.ponds[0]["r"] + 4, g.h_at(c.x + g.ponds[0]["r"] + 4, c.y) + 1, c.y)
		"dusk":
			Game.tod = 760.0
		"night":
			Game.tod = 900.0
		"far":
			cam.target_dist = 26.0
	cam.snap()

## Renders a grid of models in a neutral scene: --autotest=gallery:<set>
func _run_gallery(a: Array) -> void:
	Game.world = Game.new_world_state("G", 1, {})
	Game.running = false
	var set_name: String = a[0] if a.size() > 0 else "props"
	var keys: Array = []
	match set_name:
		"props":
			keys = ["oak", "pine", "birch", "willow", "dead_tree", "stump", "log", "bush", "berry_bush", "rock", "rock_med", "boulder",
				"weed", "twig", "fern", "reeds", "standing_stone", "ruin_wall", "tent", "fire_ring", "signpost", "well", "shipping_bin", "lamp",
				"notice_board", "fountain", "market_stall", "cave_entrance", "farmhouse", "giant_oak", "lookout", "scaffold"]
		"cave":
			keys = ["cave:cave_rock", "cave:ore_rock", "cave:crystal_cluster", "cave:crystal_big", "cave:cracked_wall", "cave:chest", "cave:ladder",
				"cave:hole", "cave:waystone", "cave:bones", "cave:stalagmite", "cave:support", "cave:glow_shrooms", "cave:giant_mushroom", "cave:pillar", "cave:statue"]
		"place":
			for k in ["chest", "big_chest", "workbench", "furnace", "kettle", "stove", "campfire", "torch", "sprinkler", "scarecrow", "fence",
				"lamp_post", "flower_pot", "beehive", "display_stand", "fish_tank", "table", "chair", "rug", "bed", "bookshelf", "banner", "garden_gnome", "coop", "shed"]:
				keys.append("place:" + k)
		"crops":
			for c in ["turnip", "potato", "tomato", "corn", "pumpkin", "wheat", "blueberry", "sunpetal", "glowcap", "crystalbloom", "mint", "hops"]:
				for st in 5:
					keys.append("crop:%s:%d" % [c, st])
		"items":
			for id in ["copper_ore", "iron_bar", "quartz", "crystal_shard", "turnip", "carrot", "river_trout", "glowcap", "brew_vigor_1", "wood", "campfire_bread", "sword_2", "pick_1", "bow_1", "hammer_3", "spear_2"]:
				keys.append("item:" + id)
	var root := Node3D.new()
	add_child(root)
	var envn := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.55, 0.65, 0.75)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.7, 0.72, 0.75)
	e.ambient_light_energy = 0.6
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	envn.environment = e
	root.add_child(envn)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.shadow_enabled = true
	root.add_child(sun)
	var cols := int(ceil(sqrt(keys.size() * 1.6)))
	var spacing := 9.0 if set_name in ["props"] else 4.0
	if set_name in ["crops", "items"]:
		spacing = 1.6
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(cols * spacing + 10, cols * spacing + 10)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.45, 0.6, 0.35)
	pm.material = gm
	ground.mesh = pm
	ground.position = Vector3(cols * spacing / 2.0 - spacing / 2.0, 0, (keys.size() / cols) * spacing / 2.0)
	root.add_child(ground)
	for i in keys.size():
		var k: String = keys[i]
		var m: Mesh
		if k.begins_with("cave:"):
			m = CaveProps.get_mesh(k.substr(5), 0)
		elif k.begins_with("place:"):
			m = ItemModels.placeable_mesh(k.substr(6))
		elif k.begins_with("crop:"):
			var parts := k.split(":")
			m = ItemModels.crop_mesh(parts[1], int(parts[2]))
		elif k.begins_with("item:"):
			m = ItemModels.held_mesh(k.substr(5))
		else:
			m = Props.get_mesh(k, 1 if k == "bridge" else 0)
		var mi := MeshInstance3D.new()
		mi.mesh = m
		mi.position = Vector3((i % cols) * spacing, 0, (i / cols) * spacing)
		root.add_child(mi)
		var l := Label3D.new()
		l.text = k
		l.font_size = 64 if spacing > 3 else 28
		l.pixel_size = 0.01 if spacing > 3 else 0.006
		l.position = mi.position + Vector3(0, 0.05, spacing * 0.42)
		l.rotation_degrees = Vector3(-90, 0, 0)
		root.add_child(l)
	var cam := Camera3D.new()
	root.add_child(cam)
	var center := Vector3((cols - 1) * spacing / 2.0, 0, (keys.size() / cols) * spacing / 2.0)
	cam.position = center + Vector3(0, cols * spacing * 0.75, cols * spacing * 0.75)
	cam.look_at(center)
	cam.current = true
	cam.fov = 50
	await _frames(20)
	await _shot("gallery_" + set_name)
	get_tree().quit()

var _fails := 0

func _check(cond: bool, what: String) -> void:
	if cond:
		_log("PASS " + what)
	else:
		_fails += 1
		_log("FAIL " + what)

func _nearest_res(sub: String):
	var z = Zones.get_zone("over")
	var lp = Game.local_player
	var best = null
	var bd := 1e9
	for o in z.objs.values():
		if o is ResourceNode and o.sub == sub:
			var d: float = o.global_position.distance_to(lp.global_position)
			if d < bd:
				bd = d
				best = o
	return best

## Exercises core loops without input: --autotest=play
func _run_play(_a: Array) -> void:
	_start_world()
	await _frames(10)
	var lp = Game.local_player
	var z = Zones.get_zone("over")
	# gathering
	var wood0 := Game.inv.count("wood")
	var tree = _nearest_res("oak")
	if tree == null:
		tree = _nearest_res("pine")
	_check(tree != null, "found a tree")
	tree.tool_hit(lp, "axe", 0, 100.0)
	await _frames(5)
	_check(Game.inv.count("wood") > wood0, "chopping gives wood (%d -> %d)" % [wood0, Game.inv.count("wood")])
	_check(not z.objs.has(tree.oid), "tree removed after felling")
	var stone0 := Game.inv.count("stone")
	var rock = _nearest_res("rock")
	rock.tool_hit(lp, "pick", 0, 100.0)
	await _frames(5)
	_check(Game.inv.count("stone") > stone0, "mining gives stone")
	var weed = _nearest_res("weed")
	weed.interact(lp)
	await _frames(5)
	_check(not z.objs.has(weed.oid), "weed pulled")
	# farming
	var g = z.gen
	var k := Vector2i(int(g.farm_rect.get_center().x) + 6, int(g.farm_rect.get_center().y) + 12)
	var free_k := k
	for dx in 10:
		var kk := k + Vector2i(dx, 0)
		if z.farm.can_till(kk):
			free_k = kk
			break
	Net.request("till", {"tiles": [free_k]})
	await _frames(2)
	_check(Game.world["farm"]["tiles"].has(free_k), "tilled a tile")
	Net.request("plant", {"k": free_k, "crop": "turnip", "by": "Tester"})
	Net.request("water", {"tiles": [free_k]})
	await _frames(2)
	_check(Game.world["farm"]["tiles"][free_k].get("crop", {}).get("id", "") == "turnip", "planted turnip")
	_check(Game.world["farm"]["tiles"][free_k].get("wet", false), "watered")
	for d in 4:
		Net.request("water", {"tiles": [free_k]})
		Net.server.start_new_day()
		await _frames(2)
	_check(z.farm.crop_stage(Game.world["farm"]["tiles"][free_k]) == 4, "turnip matured after 4 watered days (stage %d)" % z.farm.crop_stage(Game.world["farm"]["tiles"][free_k]))
	var t0 := Game.inv.count("turnip")
	Net.request("harvest", {"k": free_k})
	await _frames(2)
	_check(Game.inv.count("turnip") > t0, "harvested turnips")
	_check(Game.day() == 5, "day advanced to 5")
	# placing & chests
	var n0: int = Game.world["objects"].size()
	var cp: Vector3 = lp.global_position + Vector3(3, 0, 3)
	cp.y = z.ground_y(cp.x, cp.z)
	Net.request("place_obj", {"item": "chest", "z": "over", "p": cp, "r": 0, "d": {}})
	await _frames(3)
	_check(Game.world["objects"].size() == n0 + 1, "placed a chest")
	var oid := ""
	for o in Game.world["objects"]:
		if Vector3(Game.world["objects"][o]["p"]).distance_to(cp) < 0.1:
			oid = o
	_check(z.objs.has(oid), "chest node exists")
	Game.inv.remove("stone", 2)
	Net.request("chest_put", {"id": oid, "item": Items.make("stone", 2)})
	await _frames(2)
	_check(Game.world["objects"][oid]["d"]["items"].size() == 1, "chest holds stone")
	Net.request("chest_take", {"id": oid, "idx": 0, "n": 2, "expect": "stone"})
	await _frames(2)
	_check(Game.world["objects"][oid]["d"]["items"].size() == 0, "took stone back")
	# windows
	var ui = Game.main.ui
	var po = z.objs[oid]
	for step in ["inv", "chest", "craft", "field", "pause", "cave", "ship"]:
		match step:
			"inv": ui.open_inventory()
			"chest": ui.open_chest(po)
			"craft": ui.open_craft("workbench", null)
			"field": ui.open_craft("field", null)
			"pause": ui.open_pause()
			"cave": ui.open_cave_menu()
			"ship": ui.open_shipping()
		await _frames(4)
		_check(ui.current != null, "window %s opened" % step)
		ui.close()
	Net.request("place_obj", {"item": "kettle", "z": "over", "p": cp + Vector3(2, 0, 0), "r": 0, "d": {}})
	Net.request("place_obj", {"item": "furnace", "z": "over", "p": cp + Vector3(4, 0, 0), "r": 0, "d": {}})
	await _frames(3)
	for o in z.objs.values():
		if o is PlacedObj and o.obj_type == "kettle":
			lp.global_position = o.global_position + Vector3(1.2, 0, 0)
			ui.open_kettle(o)
			await _frames(3)
			Game.inv.add(Items.make("mint", 3))
			ui.current.add_ingredient(Game.inv.first_index("mint"))
			ui.current.add_ingredient(Game.inv.first_index("mint"))
			ui.current._brew()
			await _frames(3)
			_check(o.data().get("res", "") == "brew_zephyr_0", "brewed swiftfoot from mint (%s)" % o.data().get("res", ""))
		if o is PlacedObj and o.obj_type == "furnace":
			lp.global_position = o.global_position + Vector3(1.2, 0, 0)
			ui.open_furnace(o)
			await _frames(3)
			ui.close()
	ui.open_cook(null, false)
	await _frames(3)
	ui.close()
	# travel
	Zones.travel_local("home", null, "door")
	await _frames(5)
	_check(lp.zone_id == "home", "entered home zone")
	Zones.travel_local("over", null, "door")
	await _frames(5)
	_log("DONE fails=%d" % _fails)
	get_tree().quit()

func _run_uishot(_a: Array) -> void:
	_start_world()
	await _frames(20)
	var ui = Game.main.ui
	var lp = Game.local_player
	var z = Zones.get_zone("over")
	for id in ["copper_ore", "iron_bar", "glowcap", "river_trout", "brew_lumen_1", "quartz", "honeycomb"]:
		Game.inv.add(Items.make(id, 3))
	Game.inv.add(Loot.equipment(3, RandomNumberGenerator.new()))
	Game.inventory_changed.emit()
	ui.open_inventory()
	await _frames(10)
	await _shot("ui_inventory")
	ui.close()
	var chest = null
	for o in z.objs.values():
		if o is PlacedObj and o.obj_type == "chest":
			chest = o
	lp.global_position = chest.global_position + Vector3(1.5, 0, 0)
	ui.open_chest(chest)
	await _frames(10)
	await _shot("ui_chest")
	ui.close()
	ui.open_craft("workbench", null)
	await _frames(10)
	await _shot("ui_craft")
	get_tree().quit()

func _run_town(a: Array) -> void:
	_start_world(int(a[0]) if a.size() > 0 else 12345)
	await _frames(10)
	var t: TownGen = Zones.town
	_log("Town: %s, %d buildings, %d residents" % [t.name, t.buildings.size(), t.residents.size()])
	for p in t.residents:
		var fam := []
		for k in p["family"]:
			fam.append(k)
		_log("  %s (%s, %s) %s | %s | loves %s | family %s" % [p["name"], p["age"], TownGen.job_title(p), "/".join(PackedStringArray(p["traits"])), "/".join(PackedStringArray(p["interests"])), p["loves"], fam])
	var qs: Array = QuestLogic.quests()["active"]
	_log("Requests: %d" % qs.size())
	for r in qs:
		_log("  - %s :: %s" % [QuestLogic.title(r), r.get("text", "")])
	for p in t.residents.slice(0, 6):
		var ctx := TownUI.context_for(p, "Tester")
		_log("  [%s] %s" % [p["first"], " / ".join(PackedStringArray(Dialogue.talk(p, ctx)))])
	var lp = Game.local_player
	var over = Zones.get_zone("over")
	Game.tod = 300.0  # 11am
	await _frames(5)
	var tb = over.town
	var keeper: Dictionary = t.keeper_of("general")
	var n = tb.npc(keeper["id"])
	_check(n != null, "general store keeper exists")
	_check(n.at_work(), "keeper at the counter at 11am (act=%s)" % n.activity)
	lp.global_position = n.global_position + Vector3(0, 0, 1.5)
	n.interact(lp)
	await _frames(5)
	_check(Game.main.ui.current != null and Game.main.ui.current.kind == "dialogue", "dialogue opened")
	await _shot("town_dialogue")
	Game.main.ui.close()
	var m0 := Game.money()
	Net.request("shop_buy", {"shop": "general", "id": "turnip_seeds", "n": 2})
	await _frames(3)
	_check(Game.money() < m0, "bought seeds (%d -> %d)" % [m0, Game.money()])
	Game.inv.add(Items.make("stone", 40))
	Net.request("shop_sell", {"item": Items.make("stone", 40), "shop": "general"})
	await _frames(3)
	Net.request("gift", {"npc": keeper["id"], "item": keeper["loves"][0]})
	await _frames(3)
	_check(TownLogic.points(keeper["id"], Game.profile["name"]) >= 80, "loved gift raised friendship (%d)" % TownLogic.points(keeper["id"], Game.profile["name"]))
	# fund the bridge project
	Game.world["money"] = 5000
	Net.request("project_give", {"pid": "bridge", "item": "wood", "n": 60})
	Net.request("project_give", {"pid": "bridge", "item": "stone", "n": 40})
	Net.request("project_give", {"pid": "bridge", "coins": 500})
	await _frames(3)
	_check(Game.world["town"]["projects"]["bridge"]["state"] == "funded", "bridge funded")
	Net.server.start_new_day()
	await _frames(5)
	_check(Game.world["flags"].get("bridge_fixed", false), "bridge fixed next day")
	_check(int(Game.world["town"]["level"]) == 1, "town level 1")
	Game.main.ui.show_win(BoardWindow.new("requests"))
	await _frames(5)
	await _shot("town_board")
	Game.main.ui.close()
	Game.main.ui.show_win(BoardWindow.new("projects"))
	await _frames(5)
	await _shot("town_projects")
	Game.main.ui.close()
	# overview shot
	Game.tod = 360.0
	lp.global_position = t.center + Vector3(0, 0, 12)
	Game.main.cam.target_dist = 26.0
	Game.main.cam.snap()
	await _frames(30)
	await _shot("town_overview")
	Game.tod = 900.0
	await _frames(30)
	await _shot("town_night")
	_log("DONE fails=%d" % _fails)
	get_tree().quit()

func _run_cave(a: Array) -> void:
	_start_world(12345)
	await _frames(5)
	var floors: Array = []
	for x in a:
		floors.append(int(x))
	if floors.is_empty():
		floors = [1]
	var lp = Game.local_player
	for f in floors:
		var t0 := Time.get_ticks_msec()
		Zones.travel_local("cave_%d" % f, null, "up")
		await _frames(3)
		var z: CaveFloor = Zones.get_zone("cave_%d" % f)
		var ne := 0
		for e in Zones.enemies.values():
			if e.zone_id == z.zone_id:
				ne += 1
		_log("floor %d (%s): built in %d ms, %dx%d, rooms=%d, nodes=%d, enemies=%d, bridges=%d, hidden=%s" % [f, z.gen.biome["name"], Time.get_ticks_msec() - t0, z.gen.W, z.gen.H, z.gen.rooms.size(), z.objs.size(), ne, z.gen.bridges.size(), str(z.gen.hidden_wall)])
		_check(z.gen.walkable(z.gen.exit_cell), "exit reachable cell on floor %d" % f)
		await _frames(20)
		await _shot("cave_%d" % f)
		# zoomed-out overview of the floor
		Game.main.cam.target_dist = 26.0
		await _frames(20)
		await _shot("cave_%d_far" % f)
		Game.main.cam.target_dist = 14.0
	# combat on the last floor
	var z2: CaveFloor = Zones.get_zone(lp.zone_id)
	var target = null
	for e in Zones.enemies.values():
		if e.zone_id == z2.zone_id and not e.dead:
			target = e
			break
	if target:
		var eid: int = target.eid
		var et: String = target.etype
		lp.global_position = target.global_position + Vector3(1.5, 0, 0)
		for i in 40:
			if not Zones.enemies.has(eid):
				break
			Zones.hit_enemy(eid, 30.0, Vector3(1, 0, 0), false, {})
			await _frames(2)
		_check(not Zones.enemies.has(eid), "killed a %s" % et)
		await _frames(30)
		var pk: int = z2.pickups_root.get_child_count()
		_log("pickups on floor after kill: %d" % pk)
	# let creatures attack a standing player
	var hp0: float = lp.hp
	for e in Zones.enemies.values():
		if e.zone_id == z2.zone_id and not e.dead:
			lp.global_position = e.global_position + Vector3(1.2, 0, 0.5)
			break
	for i in 240:
		await get_tree().physics_frame
	_log("player hp %d -> %d (downed=%s)" % [int(hp0), int(lp.hp), str(lp.downed)])
	_check(lp.hp < hp0 or lp.downed, "creatures attacked the player")
	await _shot("cave_combat")
	# mine some ore
	var ore = null
	for o in z2.objs.values():
		if is_instance_valid(o) and o is ResourceNode and o.sub.begins_with("ore_"):
			ore = o
			break
	if ore:
		var before := Game.inv.counts()
		var ore_sub: String = ore.sub
		ore.tool_hit(lp, "pick", 4, 100.0)
		await _frames(4)
		_check(Game.inv.counts() != before, "mined %s" % ore_sub)
	_log("DONE fails=%d" % _fails)
	get_tree().quit()

## Stand near creatures and photograph them winding up: --autotest=fight:<floor>
func _run_fight(a: Array) -> void:
	_start_world(12345)
	await _frames(5)
	var f := int(a[0]) if a.size() > 0 else 4
	Zones.travel_local("cave_%d" % f, null, "up")
	await _frames(5)
	var lp = Game.local_player
	var z: CaveFloor = Zones.get_zone("cave_%d" % f)
	var shots := 0
	var seen := {}
	for e in Zones.enemies.values():
		if e.zone_id != z.zone_id or seen.has(e.etype):
			continue
		seen[e.etype] = true
		lp.global_position = e.global_position + Vector3(3.5, 0, 2.0)
		lp.hp = 999.0
		Game.main.cam.snap()
		for i in 120:
			await get_tree().physics_frame
			if e.state in [Enemy.S.WINDUP, Enemy.S.EMERGE]:
				break
		await _frames(2)
		await _shot("fight_%d_%s" % [f, e.etype])
		shots += 1
		if shots >= 3:
			break
	_log("DONE")
	get_tree().quit()

## Fishing end to end without input: --autotest=fish
func _run_fish(_a: Array) -> void:
	_start_world(12345)
	await _frames(5)
	var lp = Game.local_player
	var z = Zones.get_zone("over")
	var g = z.gen
	var lake: Dictionary = g.ponds[0]
	var c: Vector2 = lake["c"]
	var r: float = lake["r"]
	lp.global_position = Vector3(c.x + r + 2.0, g.h_at(c.x + r + 2.0, c.y) + 0.5, c.y)
	lp.facing = -PI / 2.0
	lp.select_hot(5)
	await _frames(3)
	var f: Fishing = lp.fishing
	f.on_use_pressed()
	for i in 70:
		await get_tree().process_frame
	lp.aim = lp.global_position + Vector3(-6, 0, 0)
	f.on_use_released()
	for i in 90:
		await get_tree().process_frame
		if f.state == Fishing.F.WAIT:
			f.bite_at = 9999.0
			break
	_check(f.state in [Fishing.F.WAIT, Fishing.F.BITE], "bobber landed in water (state %d)" % f.state)
	f.bite_at = f.t + 0.1
	for i in 30:
		await get_tree().process_frame
		if f.state == Fishing.F.BITE:
			break
	_check(f.state == Fishing.F.BITE, "fish bit")
	f.on_use_pressed()
	if f.game:
		f.game.progress = 0.75
		f.game.has_treasure = true
		f.game.treasure_y = 200.0
		await _frames(4)
		await _shot("fishing_game")
		if f.game:
			f.game.progress = 1.5
		await _frames(5)
	await _frames(5)
	_check(Game.world["know"]["fish"].size() > 0 or Game.inv.count("old_boot") + Game.inv.count("driftwood") + Game.inv.count("river_weed") + Game.inv.count("soggy_letter") > 0, "caught something (%s)" % f.fish_id)
	_log("fish log: %s" % str(Game.world["know"]["fish"]))
	_log("DONE fails=%d" % _fails)
	get_tree().quit()

## Farmhouse interior, renovations, the journal and the map.
func _run_home(_a: Array) -> void:
	_start_world(12345)
	await _frames(10)
	var lp = Game.local_player
	var ui: UIRoot = Game.main.ui
	var over = Zones.get_zone("over")
	var door = over.objs.get("farm_door")
	_check(door != null, "farmhouse has a door")
	Game.main.on_feature(door, lp)
	await _frames(60)
	_check(lp.zone_id == "home", "walked inside (zone %s)" % lp.zone_id)
	var home: HomeZone = Zones.get_zone("home")
	_check(home.objs.has("hearth") and home.objs.has("home_door") and home.objs.has("home_journal"), "hearth, door and journal exist")
	var beds := home.objs.values().filter(func(o): return o is PlacedObj and o.obj_type == "bed")
	_check(beds.size() == 1, "starter bed inside")
	_check(not home.is_blocked(lp.global_position), "spawned on a free spot")
	await _frames(30)
	_check(abs(lp.global_position.y - home.origin.y) < 0.6, "standing on the floor (y=%.2f)" % lp.global_position.y)
	var bp: Vector3 = home.spawn_point("bed")
	_check(not home.is_blocked(bp), "bed spawn is free")
	Game.tod = 300.0
	await _frames(25)
	await _shot("home_day")
	Game.tod = 1000.0
	await _frames(25)
	await _shot("home_night")
	Game.tod = 300.0
	lp.global_position = home.objs["hearth"].global_position + Vector3(0, 0.2, 0.8)
	await _frames(3)
	Game.main.on_feature(home.objs["hearth"], lp)
	await _frames(5)
	_check(ui.current is CookWindow, "hearth opens cooking")
	ui.close()
	# furnish: place a bookshelf through the player's own placement path
	lp.global_position = home.spawn_point("") + Vector3(-1.5, 0, 0)
	Game.inv.set_slot(0, Items.make("bookshelf", 1))
	lp.select_hot(0)
	lp.aim = lp.global_position + Vector3(-2.0, 0, -1.0)
	var bpos: Vector3 = lp.place_position("bookshelf")
	_check(lp.can_place("bookshelf", bpos), "bookshelf can go indoors")
	var n_before: int = home.objs.size()
	lp._place(Game.inv.get_slot(0))
	await _frames(5)
	_check(home.objs.size() == n_before + 1, "bookshelf placed in the farmhouse")
	Game.inv.set_slot(0, Items.make("scarecrow", 1))
	_check(not lp.can_place("scarecrow", bpos + Vector3(0, 0, 2)), "outdoor-only things stay outside")
	Game.inv.set_slot(0, Items.make("hoe_0"))
	Game.chronicle("A line written by hand.", "note")
	await _frames(3)
	for t in JournalWindow.TABS:
		ui.open_journal(t)
		await _frames(4)
		_check(ui.current is JournalWindow and ui.current.tab == t, "journal tab %s opens" % t)
		if t in ["Chronicle", "Collection", "Fish", "People", "Household"]:
			await _shot("journal_" + t.to_lower())
	ui.close()
	# renovations, done overnight by the carpenter
	Net.server.add_money(20000, "")
	await _frames(2)
	Net.request("house_upgrade", {"items": [Items.make("wood", 150), Items.make("stone", 50)]})
	await _frames(3)
	_check(int(Game.world["flags"].get("house_pending", 0)) == 1, "renovation ordered")
	Net.server.start_new_day()
	await _frames(20)
	_check(int(Game.world["farm"]["level"]) == 1, "farmhouse upgraded overnight")
	_check(home.level == 1, "interior grew to level %d" % home.level)
	_check(not home.is_blocked(lp.global_position), "player not stuck after the rebuild")
	Game.tod = 300.0
	await _frames(25)
	await _shot("home_lvl1")
	Net.request("house_upgrade", {"items": [Items.make("hardwood", 40), Items.make("stone", 120), Items.make("iron_bar", 10)]})
	await _frames(3)
	Net.server.start_new_day()
	await _frames(20)
	_check(home.level == 2, "interior grew to level 2")
	Game.tod = 300.0
	lp.global_position = home.spawn_point("")
	await _frames(25)
	await _shot("home_lvl2")
	Game.main.on_feature(home.objs["home_door"], lp)
	await _frames(60)
	_check(lp.zone_id == "over", "back outside")
	Game.tod = 300.0
	Game.main.cam.target_dist = 20.0
	await _frames(40)
	await _shot("farm_lvl2")
	ui.open_map()
	await _frames(10)
	Net.request("map_pin", {"op": "add", "z": "over", "p": Vector2(lp.global_position.x + 20, lp.global_position.z + 10), "c": Color("e05a4a")})
	await _frames(10)
	_check(Game.world["know"].get("pins", []).size() == 1, "map pin dropped")
	await _shot("map_over")
	ui.close()
	Zones.travel_local("cave_1", null, "up")
	await _frames(90)
	var cave: CaveFloor = Zones.get_zone("cave_1")
	var seen := 0
	for b in cave.seen_bytes():
		seen += b
	_check(seen > 20, "cave floor partly mapped (%d cells)" % seen)
	ui.open_map()
	await _frames(10)
	await _shot("map_cave")
	ui.close()
	_log("DONE fails=%d" % _fails)
	get_tree().quit()

## Title screen panels, then a full save -> quit to title -> load round trip.
func _run_menu(_a: Array) -> void:
	var menu: MainMenu = Game.main.menu
	Game.profile["name"] = "Tester"
	DirAccess.make_dir_recursive_absolute("user://worlds")
	DirAccess.remove_absolute("user://worlds/roundtrip.hearth")
	DirAccess.remove_absolute("user://worlds/roundtrip.hearth.meta")
	menu.open()
	await _frames(20)
	await _shot("menu_title")
	menu._show_new()
	await _frames(5)
	await _shot("menu_new")
	menu._show_character()
	await _frames(20)
	await _shot("menu_character")
	menu._show_join()
	await _frames(5)
	# start a world through the same call the Begin button makes
	var err: String = Game.main.start_new_world("Roundtrip", 4242, {"season_len": 7, "loss": 0}, false, 0)
	_check(err == "", "new world started")
	await _frames(20)
	_check(not menu.visible and Game.running, "menu hidden once playing")
	var lp = Game.local_player
	Net.server.add_money(1234, "")
	Game.chronicle("We were here.", "note")
	Game.local_grant([Items.make("quartz", 7)], true)
	Net.request("map_pin", {"op": "add", "z": "over", "p": Vector2(50, 50), "c": Color.RED})
	Net.server.start_new_day()
	await _frames(10)
	var day_before := Game.day()
	var money_before := Game.money()
	var objs_before: int = Game.world["objects"].size()
	var chron_before: int = Game.world["chronicle"].size()
	lp.global_position += Vector3(3, 0, 2)
	await _frames(5)
	var pos_before: Vector3 = lp.global_position
	Game.main.leave_world()
	await _frames(10)
	_check(menu.visible and not Game.running, "back at the title")
	_check(FileAccess.file_exists("user://worlds/roundtrip.hearth") and FileAccess.file_exists("user://worlds/roundtrip.hearth.meta"), "save and meta written")
	var saves := MainMenu.list_saves()
	_check(not saves.is_empty() and saves[0]["name"] == "Roundtrip", "save listed first (%s)" % (saves[0]["name"] if not saves.is_empty() else "-"))
	await _frames(5)
	await _shot("menu_continue")
	menu._show_load()
	await _frames(5)
	await _shot("menu_load")
	err = Game.main.load_world(saves[0]["path"], false, 0)
	_check(err == "", "world loaded")
	await _frames(30)
	lp = Game.local_player
	_check(Game.day() == day_before, "day kept (%d)" % Game.day())
	_check(Game.money() == money_before, "money kept (%d)" % Game.money())
	_check(Game.world["objects"].size() == objs_before, "objects kept")
	_check(Game.world["chronicle"].size() == chron_before, "chronicle kept (%d vs %d)" % [Game.world["chronicle"].size(), chron_before])
	_check(Game.inv.count("quartz") == 7, "pack kept (quartz %d)" % Game.inv.count("quartz"))
	_check(Game.world["know"].get("pins", []).size() == 1, "map pin kept")
	_check(lp.global_position.distance_to(pos_before) < 1.0, "position kept (%.1f m away)" % lp.global_position.distance_to(pos_before))
	_check(int(Game.world["settings"]["season_len"]) == 7, "settings kept")
	_check(Game.world["explored"] is PackedByteArray and Game.world["explored"].size() > 0, "explored map kept")
	_log("DONE fails=%d" % _fails)
	get_tree().quit()

# ------------------------------------------------------------------ multiplayer (two processes)

func _wait_until(cond: Callable, secs: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while not cond.call():
		if Time.get_ticks_msec() - t0 > secs * 1000.0:
			return false
		await get_tree().process_frame
	return true

func _chron_has(text: String) -> bool:
	for e in Game.world.get("chronicle", []):
		if String(e.get("s", "")).contains(text):
			return true
	return false

func _run_mphost(a: Array) -> void:
	var port := int(a[0]) if a.size() > 0 else 24601
	Game.profile["name"] = "Host"
	var err: String = Game.main.start_new_world("MP Test", 777, {}, true, port)
	_check(err == "", "hosting on %d (%s)" % [port, err])
	_check(Net.is_online() and Net.is_server(), "online as server")
	var ok: bool = await _wait_until(func(): return Net.peers.size() >= 2, 40.0)
	_check(ok, "a friend joined (%d peers)" % Net.peers.size())
	var cid := 0
	for id in Net.peers:
		if id != Net.my_id():
			cid = id
	ok = await _wait_until(func(): return _chron_has("hello from the guest"), 20.0)
	_check(ok, "guest's request reached the host")
	ok = await _wait_until(func(): return Zones.players.has(cid), 10.0)
	_check(ok, "guest avatar spawned on host")
	var rp = Zones.players.get(cid)
	var p0: Vector3 = rp.global_position if rp else Vector3.ZERO
	Net.server.add_money(1000, "")
	ok = await _wait_until(func(): return rp != null and is_instance_valid(rp) and rp.global_position.distance_to(p0) > 3.0, 20.0)
	_check(ok, "guest movement synced to host")
	ok = await _wait_until(func(): return Zones.get_zone("cave_1") != null, 20.0)
	_check(ok, "host simulates the cave floor the guest went down to")
	ok = await _wait_until(func(): return _chron_has("guest is done"), 30.0)
	_check(ok, "guest finished")
	var guest_saved: Dictionary = Game.world["players"].get("Guest", {})
	ok = await _wait_until(func(): return Game.world["players"].get("Guest", {}).get("zone", "") == "cave_1", 10.0)
	_check(ok, "guest character data kept on host (zone %s)" % Game.world["players"].get("Guest", {}).get("zone", "?"))
	_log("DONE fails=%d" % _fails)
	await _frames(30)
	get_tree().quit()

func _run_mpclient(a: Array) -> void:
	var port := int(a[0]) if a.size() > 0 else 24601
	Game.profile["name"] = "Guest"
	await get_tree().create_timer(5.0).timeout
	var err: String = Net.join("127.0.0.1", port)
	_check(err == "", "connecting")
	var ok: bool = await _wait_until(func(): return Game.running, 30.0)
	_check(ok, "joined the host's world")
	if not ok:
		_log("DONE fails=%d" % _fails)
		get_tree().quit()
		return
	_check(int(Game.world.get("seed", 0)) == 777, "same world seed")
	_check(not Net.is_server(), "running as a client")
	ok = await _wait_until(func(): return Zones.players.size() >= 2, 10.0)
	_check(ok, "can see the host")
	Game.chronicle("hello from the guest")
	ok = await _wait_until(func(): return Game.money() >= 1500, 20.0)
	_check(ok, "shared purse updated from host (%d)" % Game.money())
	var lp = Game.local_player
	var over = Zones.get_zone("over")
	var tgt: Vector3 = over.spawn_point("") + Vector3(6, 0, 4)
	lp.global_position = Vector3(tgt.x, over.ground_y(tgt.x, tgt.z) + 0.3, tgt.z)
	await get_tree().create_timer(1.5).timeout
	# a server-validated action: till a farm tile
	var g = over.gen
	var k := Vector2i(int(g.farm_rect.get_center().x) + 6, int(g.farm_rect.get_center().y) + 12)
	Net.request("till", {"tiles": [k]})
	ok = await _wait_until(func(): return Game.world["farm"]["tiles"].has(k), 10.0)
	_check(ok, "tilled tile synced back")
	Zones.travel_local("cave_1", null, "up")
	ok = await _wait_until(func():
		for e in Zones.enemies.values():
			if is_instance_valid(e) and e.zone_id == "cave_1":
				return true
		return false, 20.0)
	_check(ok, "creatures from the host appear in the cave")
	Net.push_my_data()
	Game.chronicle("the guest is done")
	await get_tree().create_timer(2.0).timeout
	_log("DONE fails=%d" % _fails)
	get_tree().quit()

func _run_tipshot(_a: Array) -> void:
	_start_world()
	await _frames(20)
	Game.main.hud.tips._queue = ["welcome"]
	await get_tree().create_timer(1.0).timeout
	await _shot("tip")
	get_tree().quit()

## Top-down debug image of the overworld layout: --autotest=mapdump[:seed]
func _run_mapdump(a: Array) -> void:
	var seed_v := int(a[0]) if a.size() > 0 else 12345
	Game.world = Game.new_world_state("Map", seed_v, {})
	var t0 := Time.get_ticks_msec()
	var g := OverworldGen.new()
	g.generate(seed_v)
	_log("generated in %d ms; pois=%d spawns=%d forage=%d ponds=%d bridges=%d" % [Time.get_ticks_msec() - t0, g.pois.size(), g.spawns.size(), g.forage_spots.size(), g.ponds.size(), g.bridges.size()])
	var S := OverworldGen.S
	var sc := 3
	var img := Image.create(S * sc, S * sc, false, Image.FORMAT_RGBA8)
	for z in S:
		for x in S:
			var c := g.color_at(x, z)
			var h := g.heights[z * OverworldGen.N + x]
			if g.water_idx[z * S + x] != 0 and h < g.water_lvl[z * S + x]:
				c = Color("4f8ab0")
			c = c.lightened(clamp((h - 5.0) / 40.0, 0.0, 0.4))
			c.a = 1.0
			if g.core[z * S + x] == 0:
				c = c.darkened(0.18)
			img.fill_rect(Rect2i(x * sc, z * sc, sc, sc), c)
	for s in g.spawns:
		var p: Vector3 = s["p"]
		var col := Color("1f4a1f") if s["k"] in ["oak", "birch", "pine", "willow"] else Color("6a6a6a")
		if s.get("farm", false):
			col = Color("8a6a3a")
		img.fill_rect(Rect2i(int(p.x * sc) - 1, int(p.z * sc) - 1, 3, 3), col)
	for w in g.walls:
		var aa: Vector2 = w["a"]
		var bb: Vector2 = w["b"]
		for k in 200:
			var q := aa.lerp(bb, k / 199.0)
			img.fill_rect(Rect2i(int(q.x * sc) - 1, int(q.y * sc) - 1, 3, 3), Color("d0c8b0"))
	for b in ValleyLayout.BUILDINGS:
		var pos: Vector2 = b["pos"]
		var fwd: Vector2 = (Vector2(b["face"]) - pos).normalized()
		var right := Vector2(fwd.y, -fwd.x)
		for i in 40:
			for j in 40:
				var q2 := pos + right * (float(b["w"]) * (i / 39.0 - 0.5)) + fwd * (float(b["d"]) * (j / 39.0 - 0.5))
				var col2: Color = b["roof"] if b["role"] != "lot" else Color("c8b890")
				img.set_pixel(clamp(int(q2.x * sc), 0, S * sc - 1), clamp(int(q2.y * sc), 0, S * sc - 1), col2)
		var door := pos + fwd * (float(b["d"]) / 2.0 + 1.6)
		img.fill_rect(Rect2i(int(door.x * sc) - 2, int(door.y * sc) - 2, 4, 4), Color.YELLOW)
	for q in g.pois:
		var pp: Vector2 = q["pos"]
		img.fill_rect(Rect2i(int(pp.x * sc) - 4, int(pp.y * sc) - 4, 8, 8), Color.MAGENTA if q.get("wild", false) else Color.CYAN)
	for gt in g.gates:
		var gp: Vector2 = gt["p"]
		img.fill_rect(Rect2i(int(gp.x * sc) - 5, int(gp.y * sc) - 5, 10, 10), Color.RED)
	for k in ValleyLayout.STREET_NODES:
		var np: Vector2 = ValleyLayout.STREET_NODES[k]
		img.fill_rect(Rect2i(int(np.x * sc) - 2, int(np.y * sc) - 2, 4, 4), Color.WHITE)
	var cp := g.cave_pos
	img.fill_rect(Rect2i(int(cp.x * sc) - 6, int(cp.y * sc) - 6, 12, 12), Color.BLACK)
	var path := ProjectSettings.globalize_path(out_dir + "/mapdump_%d.png" % seed_v)
	img.save_png(path)
	_log("saved " + path)
	# heights along a few lines, to check the cliffs and the ramp
	var line := ""
	for z in range(56, 96, 4):
		line += "%d:%.1f " % [z, g.h_at(190, z)]
	_log("cliff at x=190: " + line)
	line = ""
	for k in 8:
		var q3: Vector2 = Vector2(ValleyLayout.HIGHLAND_RAMP[0]).lerp(ValleyLayout.HIGHLAND_RAMP[1], k / 7.0)
		line += "%.1f " % g.h_at(q3.x, q3.y)
	_log("ramp heights: " + line)
	var nc := 0
	for v in g.core:
		nc += v
	_log("core cells: %d of %d" % [nc, S * S])
	get_tree().quit()

## Screenshots around the hand-made valley: --autotest=valley
func _run_valley(_a: Array) -> void:
	_start_world(12345)
	await _frames(20)
	var lp = Game.local_player
	var z = Zones.get_zone("over")
	var cam = Game.main.cam
	Game.tod = 200.0
	var views := [
		["plaza", Vector2(190, 152), 30.0],
		["plaza_close", Vector2(186, 150), 16.0],
		["north_street", Vector2(190, 112), 22.0],
		["yard", Vector2(190, 94), 20.0],
		["farm", Vector2(110, 138), 30.0],
		["west_gate", Vector2(64, 132), 18.0],
		["falls", Vector2(246, 92), 20.0],
		["east_bridge", Vector2(244, 148), 20.0],
		["dock", Vector2(104, 204), 20.0],
		["ramp", Vector2(120, 94), 22.0],
		["highlands", Vector2(110, 52), 22.0],
		["whisperwood", Vector2(36, 150), 20.0],
		["south_street", Vector2(190, 200), 22.0],
	]
	if not _a.is_empty():
		views = views.filter(func(v): return _a.has(v[0]))
	for v in views:
		var p: Vector2 = v[1]
		lp.global_position = Vector3(p.x, z.ground_y(p.x, p.y) + 0.3, p.y)
		cam.target_dist = v[2]
		cam.snap()
		await _frames(30)
		_log("%s: area '%s'" % [v[0], z.area_name(lp.global_position)])
		await _shot("valley_" + v[0])
	get_tree().quit()

## Fate-style travel: rope up, portal back, straight to the deepest floor.
func _run_delve(_a: Array) -> void:
	_start_world(12345)
	await _frames(10)
	var lp = Game.local_player
	_check(Game.inv.count("escape_rope") == 3, "start with 3 homeward ropes")
	Game.main.travel_to_floor(4)
	await _frames(60)
	_check(lp.zone_id == "cave_4", "went down to floor 4")
	var spot: Vector3 = lp.global_position + Vector3(1.0, 0, 0)
	lp.global_position = spot
	await _frames(5)
	Game.main.escape_to_surface()
	await _frames(60)
	_check(lp.zone_id == "over", "rope brought us up")
	_check(lp.global_position.distance_to(Vector3(190, lp.global_position.y, 90)) < 6.0, "arrived in Delver's Yard")
	var over = Zones.get_zone("over")
	await _frames(40)
	_check(over.objs.has("cave_portal"), "a way back down is waiting")
	await _shot("delve_portal")
	Game.main.on_feature(over.objs["cave_portal"], lp)
	await _frames(60)
	_check(lp.zone_id == "cave_4" and lp.global_position.distance_to(spot) < 2.0, "portal returned us to the exact spot (%s, %.1f m)" % [lp.zone_id, lp.global_position.distance_to(spot)])
	_check(not Game.me.has("cave_return"), "portal used up")
	Zones.travel_local("over", null, "yard")
	await _frames(40)
	_check(not over.objs.has("cave_portal"), "portal gone once used")
	Game.main.ui.open_cave_menu()
	await _frames(5)
	await _shot("delve_menu")
	Game.main.ui.close()
	Game.main.travel_to_floor(int(Game.world["know"]["deepest"]))
	await _frames(60)
	_check(lp.zone_id == "cave_%d" % int(Game.world["know"]["deepest"]), "straight down to the deepest floor (%s)" % lp.zone_id)
	_log("DONE fails=%d" % _fails)
	get_tree().quit()

## Sanity checks for the hand-made town: --autotest=towncheck
func _run_towncheck(_a: Array) -> void:
	_start_world(12345)
	await _frames(5)
	var town: TownGen = Zones.town
	var bad_items: Array = []
	for spec in TownCast.RESIDENTS + TownCast.NEWCOMERS:
		for id in spec["loves"] + spec["likes"]:
			if not Items.has(id):
				bad_items.append("%s:%s" % [spec["key"], id])
	_check(bad_items.is_empty(), "cast tastes are real items %s" % str(bad_items))
	var inside := func(p: Vector3, margin: float) -> String:
		for b in town.buildings:
			if b["role"] == "lot":
				continue
			var local: Vector3 = Basis(Vector3.UP, b["yaw"]).inverse() * (p - b["pos"])
			if abs(local.x) < b["w"] / 2.0 + margin and abs(local.z) < b["d"] / 2.0 + margin:
				return b["id"]
		return ""
	# routes between every home, workplace and spot
	var pts: Array = []
	for b in town.buildings:
		pts.append(b["front"])
	for k in ValleyLayout.SPOTS:
		pts.append(town.spot(k))
	var hits := {}
	for i in pts.size():
		for j in pts.size():
			if i == j:
				continue
			var r := town.route(pts[i], pts[j])
			for k in range(1, r.size()):
				var seg: float = r[k - 1].distance_to(r[k])
				var n := int(seg / 0.5) + 1
				for s in n:
					var q: Vector3 = r[k - 1].lerp(r[k], float(s) / n)
					var hit: String = inside.call(q, -0.3)
					if hit != "":
						hits["%d>%d:%s" % [i, j, hit]] = true
	_check(hits.is_empty(), "walking routes never pass through buildings (%d hits) %s" % [hits.size(), str(hits.keys().slice(0, 6))])
	var clutter: Array = []
	for d in town.decor:
		if d.has("p") and inside.call(d["p"], 0.3) != "":
			clutter.append("%s@%s" % [d["k"], str(d["p"])])
	for lp in town.lamps:
		if inside.call(lp, 0.3) != "":
			clutter.append("lamp@%s" % str(lp))
	_check(clutter.is_empty(), "no trees, benches or lamps inside buildings %s" % str(clutter))
	var g = Zones.get_zone("over").gen
	var on_road: Array = []
	for b in town.buildings:
		var c: Vector3 = b["pos"]
		if g.road[g.cell(c.x, c.z)] > 120:
			on_road.append(b["id"])
	_check(on_road.is_empty(), "no building sits on a street %s" % str(on_road))
	_log("DONE fails=%d" % _fails)
	get_tree().quit()
