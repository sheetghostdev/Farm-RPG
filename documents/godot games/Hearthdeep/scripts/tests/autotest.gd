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
		if o is ResourceNode and o.sub.begins_with("ore_"):
			ore = o
			break
	if ore:
		var before := Game.inv.counts()
		ore.tool_hit(lp, "pick", 4, 100.0)
		await _frames(4)
		_check(Game.inv.counts() != before, "mined %s" % ore.sub)
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
			f.game.progress = 1.0
		await _frames(5)
	await _frames(5)
	_check(Game.world["know"]["fish"].size() > 0 or Game.inv.count("old_boot") + Game.inv.count("driftwood") + Game.inv.count("river_weed") + Game.inv.count("soggy_letter") > 0, "caught something (%s)" % f.fish_id)
	_log("fish log: %s" % str(Game.world["know"]["fish"]))
	_log("DONE fails=%d" % _fails)
	get_tree().quit()
