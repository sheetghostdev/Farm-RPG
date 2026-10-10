class_name AutoTest
extends Node
## Command-line driven tests: --autotest=<name>. Used for headless checks and screenshots.

var out_dir := "res://tests_out"

func run(name: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
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
