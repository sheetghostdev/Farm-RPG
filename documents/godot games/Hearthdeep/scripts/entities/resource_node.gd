class_name ResourceNode
extends WorldObj
## Trees, rocks, ore veins, forage, loot containers and other gatherables.
## Behaviour comes from the RES table; the server rolls drops when one breaks.

# tool: axe/pick/hoe/any/hand. drops: [id, min, max, chance]. respawn: days (-1 never).
const RES := {
	"oak": {"tool": "axe", "tier": 0, "hp": 6.0, "drops": [["wood", 4, 6], ["sap", 0, 2], ["hardwood", 1, 1, 0.12]], "respawn": 9, "block": 0.45, "fall": true, "skill": "foraging", "xp": 5, "vis": 130.0, "name": "Oak"},
	"birch": {"tool": "axe", "tier": 0, "hp": 5.0, "drops": [["wood", 3, 5], ["sap", 0, 1]], "respawn": 9, "block": 0.35, "fall": true, "skill": "foraging", "xp": 4, "vis": 130.0, "name": "Birch"},
	"willow": {"tool": "axe", "tier": 0, "hp": 6.0, "drops": [["wood", 3, 5], ["fiber", 2, 4]], "respawn": 9, "block": 0.5, "fall": true, "skill": "foraging", "xp": 5, "vis": 130.0, "name": "Willow"},
	"pine": {"tool": "axe", "tier": 0, "hp": 6.0, "drops": [["wood", 4, 6], ["sap", 1, 2]], "respawn": 9, "block": 0.35, "fall": true, "skill": "foraging", "xp": 5, "vis": 130.0, "name": "Pine"},
	"dead_tree": {"tool": "axe", "tier": 0, "hp": 4.0, "drops": [["wood", 2, 3], ["hardwood", 1, 1, 0.35]], "respawn": 12, "block": 0.35, "fall": true, "skill": "foraging", "xp": 3, "vis": 110.0, "name": "Dead Tree"},
	"stump": {"tool": "axe", "tier": 1, "hp": 7.0, "drops": [["hardwood", 2, 2], ["wood", 1, 2]], "respawn": 14, "block": 0.5, "skill": "foraging", "xp": 6, "vis": 70.0, "name": "Stump"},
	"log": {"tool": "axe", "tier": 2, "hp": 16.0, "drops": [["hardwood", 8, 10]], "respawn": 20, "block": 0.0, "skill": "foraging", "xp": 15, "vis": 90.0, "name": "Large Log"},
	"rock": {"tool": "pick", "tier": 0, "hp": 3.0, "drops": [["stone", 2, 3], ["flint", 1, 1, 0.15], ["coal", 1, 1, 0.04]], "respawn": 5, "block": 0.4, "skill": "mining", "xp": 2, "vis": 70.0, "name": "Rock"},
	"rock_med": {"tool": "pick", "tier": 0, "hp": 5.0, "drops": [["stone", 4, 6], ["flint", 1, 2, 0.25], ["coal", 1, 1, 0.08]], "respawn": 6, "block": 0.65, "skill": "mining", "xp": 4, "vis": 80.0, "name": "Rock"},
	"boulder": {"tool": "pick", "tier": 2, "hp": 14.0, "drops": [["stone", 14, 20], ["geode", 1, 1, 0.4], ["iron_ore", 2, 4, 0.3]], "respawn": 20, "block": 1.4, "skill": "mining", "xp": 15, "vis": 120.0, "name": "Boulder"},
	"weed": {"tool": "any", "tier": 0, "hp": 1.0, "drops": [["fiber", 1, 1, 0.8], ["worm", 1, 1, 0.05], ["mossbloom_seeds", 1, 1, 0.02]], "respawn": 5, "block": 0.0, "skill": "foraging", "xp": 1, "vis": 50.0, "hand": true, "name": "Weeds"},
	"twig": {"tool": "any", "tier": 0, "hp": 1.0, "drops": [["wood", 1, 2]], "respawn": 6, "block": 0.0, "skill": "foraging", "xp": 1, "vis": 50.0, "hand": true, "name": "Branch"},
	"berry_bush": {"tool": "none", "hp": 1.0, "drops": [], "respawn": -2, "block": 0.0, "vis": 80.0, "name": "Berry Bush"},
	"copper_node": {"tool": "pick", "tier": 0, "hp": 5.0, "drops": [["copper_ore", 2, 3], ["stone", 1, 2]], "respawn": 3, "block": 0.45, "skill": "mining", "xp": 5, "vis": 80.0, "name": "Copper Vein"},
	"clay": {"tool": "hoe", "tier": 0, "hp": 1.0, "drops": [["clay", 1, 3]], "respawn": 2, "block": 0.0, "skill": "foraging", "xp": 2, "vis": 60.0, "name": "Clay"},
	"dig": {"tool": "hoe", "tier": 0, "hp": 1.0, "loot": "dig", "respawn": -1, "block": 0.0, "skill": "foraging", "xp": 3, "vis": 40.0, "name": "Disturbed Earth"},
	"forage": {"tool": "hand", "hp": 1.0, "drops": [], "respawn": -1, "block": 0.0, "skill": "foraging", "xp": 3, "vis": 60.0},
	"crate_loot": {"tool": "hand", "hp": 1.0, "loot": "camp_crate", "respawn": -1, "block": 0.45, "xp": 4, "skill": "foraging", "vis": 70.0, "name": "Old Crate", "open": true},
	"tower_chest": {"tool": "hand", "hp": 1.0, "loot": "watchtower", "respawn": -1, "block": 0.45, "xp": 6, "skill": "foraging", "vis": 70.0, "name": "Weathered Chest", "open": true},
	"ruin_cache": {"tool": "hoe", "hp": 1.0, "loot": "ruins", "respawn": 7, "block": 0.0, "xp": 4, "skill": "foraging", "vis": 40.0, "name": "Loose Stones"},
	# underground
	"cave_rock": {"tool": "pick", "tier": 0, "hp": 3.0, "drops": [["stone", 1, 3], ["coal", 1, 1, 0.12], ["geode", 1, 1, 0.04]], "respawn": 4, "block": 0.4, "skill": "mining", "xp": 2, "vis": 60.0, "name": "Rock"},
	"ore_copper": {"tool": "pick", "tier": 0, "hp": 4.0, "drops": [["copper_ore", 1, 3], ["stone", 0, 1]], "respawn": 5, "block": 0.45, "skill": "mining", "xp": 4, "vis": 60.0, "name": "Copper Vein", "ore": true},
	"ore_iron": {"tool": "pick", "tier": 1, "hp": 6.0, "drops": [["iron_ore", 1, 3], ["stone", 0, 1]], "respawn": 5, "block": 0.45, "skill": "mining", "xp": 6, "vis": 60.0, "name": "Iron Vein", "ore": true},
	"ore_silver": {"tool": "pick", "tier": 2, "hp": 8.0, "drops": [["silver_ore", 1, 3]], "respawn": 6, "block": 0.45, "skill": "mining", "xp": 9, "vis": 60.0, "name": "Silver Vein", "ore": true},
	"ore_gold": {"tool": "pick", "tier": 2, "hp": 10.0, "drops": [["gold_ore", 1, 2]], "respawn": 6, "block": 0.45, "skill": "mining", "xp": 12, "vis": 60.0, "name": "Gold Vein", "ore": true},
	"ore_starmetal": {"tool": "pick", "tier": 3, "hp": 14.0, "drops": [["starmetal_ore", 1, 2]], "respawn": 7, "block": 0.45, "skill": "mining", "xp": 18, "vis": 60.0, "name": "Starmetal Vein", "ore": true},
	"coal_node": {"tool": "pick", "tier": 0, "hp": 4.0, "drops": [["coal", 1, 3]], "respawn": 5, "block": 0.45, "skill": "mining", "xp": 3, "vis": 60.0, "name": "Coal Seam", "ore": true},
	"crystal_node": {"tool": "pick", "tier": 1, "hp": 5.0, "drops": [["crystal_shard", 1, 3], ["quartz", 1, 1, 0.3]], "respawn": 6, "block": 0.45, "skill": "mining", "xp": 6, "vis": 70.0, "name": "Crystal Cluster", "ore": true},
	"gem_node": {"tool": "pick", "tier": 2, "hp": 8.0, "drops": [], "gem": true, "respawn": 8, "block": 0.45, "skill": "mining", "xp": 12, "vis": 60.0, "name": "Gem Pocket", "ore": true},
	"obsidian_node": {"tool": "pick", "tier": 3, "hp": 10.0, "drops": [["obsidian", 1, 2]], "respawn": 8, "block": 0.5, "skill": "mining", "xp": 12, "vis": 60.0, "name": "Obsidian", "ore": true},
	"cracked_wall": {"tool": "pick", "tier": 1, "hp": 9.0, "drops": [["stone", 4, 6]], "respawn": -1, "block": 1.6, "skill": "mining", "xp": 10, "vis": 90.0, "name": "Cracked Wall"},
	"barrel": {"tool": "any", "tier": 0, "hp": 2.0, "loot": "barrel", "respawn": 6, "block": 0.4, "xp": 1, "skill": "combat", "vis": 60.0, "name": "Old Barrel"},
	"crate": {"tool": "any", "tier": 0, "hp": 2.0, "loot": "barrel", "respawn": 6, "block": 0.45, "xp": 1, "skill": "combat", "vis": 60.0, "name": "Old Crate"},
	"chest_wood": {"tool": "hand", "hp": 1.0, "loot": "chest_wood", "respawn": -1, "block": 0.45, "xp": 5, "skill": "mining", "vis": 70.0, "name": "Wooden Chest", "open": true},
	"chest_iron": {"tool": "hand", "hp": 1.0, "loot": "chest_iron", "respawn": -1, "block": 0.45, "xp": 10, "skill": "mining", "vis": 70.0, "name": "Iron Chest", "open": true},
	"chest_gold": {"tool": "hand", "hp": 1.0, "loot": "chest_gold", "respawn": -1, "block": 0.45, "xp": 20, "skill": "mining", "vis": 70.0, "name": "Gilded Chest", "open": true},
	"chest_hidden": {"tool": "hand", "hp": 1.0, "loot": "hidden", "respawn": -1, "block": 0.45, "xp": 25, "skill": "mining", "vis": 70.0, "name": "Forgotten Chest", "open": true},
	"minecart": {"tool": "hand", "hp": 1.0, "loot": "minecart", "respawn": 10, "block": 0.8, "xp": 5, "skill": "mining", "vis": 80.0, "name": "Abandoned Minecart", "open": true},
	"cave_plant": {"tool": "hand", "hp": 1.0, "drops": [], "respawn": 3, "block": 0.0, "skill": "foraging", "xp": 5, "vis": 60.0},
	"bones": {"tool": "hand", "hp": 1.0, "drops": [["bone", 1, 2]], "respawn": -1, "block": 0.0, "skill": "foraging", "xp": 2, "vis": 60.0, "name": "Old Remains", "note": true},
}

var hp := 1.0
var data := {}
var depth := 0
var berries_ready := false

static func info(k: String) -> Dictionary:
	return RES.get(k, {})

func setup(id: String, k: String, pos: Vector3, rot: float, variant: int, scl: float = 1.0, extra: Dictionary = {}) -> void:
	oid = id
	kind = "res"
	sub = k
	data = extra
	depth = int(extra.get("depth", 0))
	position = pos
	var r := info(k)
	hp = float(r.get("hp", 1.0))
	radius = max(0.45, float(r.get("block", 0.0)) + 0.25)
	var mesh := _mesh_for(k, variant)
	var vis: float = r.get("vis", 80.0)
	set_mesh(mesh, vis, rot, scl)
	var blk: float = r.get("block", 0.0)
	if k == "log":
		add_box_blocker(Vector3(3.4 + variant * 0.8, 0.8, 0.8), Vector3.ZERO, 0.0)
		mesh_inst.rotation.y = 0.0
		body.rotation.y = rot
		mesh_inst.rotation.y = rot
		radius = 1.6
	elif blk > 0.0:
		add_blocker(blk * scl, 2.5 if r.get("fall", false) else 1.2)
	if k == "cracked_wall":
		radius = 1.8
	if k == "berry_bush":
		_update_berries()

func _mesh_for(k: String, v: int) -> Mesh:
	match k:
		"oak", "pine", "birch", "willow", "dead_tree":
			return Props.get_mesh(k, v % 4)
		"stump", "log", "rock", "rock_med", "boulder", "weed", "twig":
			return Props.get_mesh(k, v % 3)
		"berry_bush":
			return Props.get_mesh("bush" if not berries_ready else "berry_bush", 0)
		"copper_node":
			return CaveProps.get_mesh("ore_rock", 0)
		"clay":
			return Props.get_mesh("clay_mound", 0)
		"dig", "ruin_cache":
			return Props.get_mesh("dig_spot", 0)
		"forage":
			return ItemModels.forage_mesh(data.get("item", "wild_herbs"))
		"cave_plant":
			return ItemModels.forage_mesh(data.get("item", "cave_mushroom"))
		"crate_loot", "tower_chest":
			return CaveProps.get_mesh("chest", 0)
		"cave_rock":
			return CaveProps.get_mesh("cave_rock", v % 4 + int(data.get("biome", 0)) * 4)
		"ore_copper":
			return CaveProps.get_mesh("ore_rock", 0)
		"ore_iron":
			return CaveProps.get_mesh("ore_rock", 1)
		"ore_silver":
			return CaveProps.get_mesh("ore_rock", 2)
		"ore_gold":
			return CaveProps.get_mesh("ore_rock", 3)
		"ore_starmetal":
			return CaveProps.get_mesh("ore_rock", 4)
		"coal_node":
			return CaveProps.get_mesh("ore_rock", 5)
		"gem_node":
			return CaveProps.get_mesh("ore_rock", 6)
		"obsidian_node":
			return CaveProps.get_mesh("ore_rock", 7)
		"crystal_node":
			return CaveProps.get_mesh("crystal_cluster", v % 3)
		"cracked_wall":
			return CaveProps.get_mesh("cracked_wall", int(data.get("biome", 0)))
		"barrel":
			return Props.get_mesh("barrel_prop", 0)
		"crate":
			return Props.get_mesh("crate_prop", 0)
		"chest_wood":
			return CaveProps.get_mesh("chest", 0)
		"chest_iron":
			return CaveProps.get_mesh("chest", 1)
		"chest_gold", "chest_hidden":
			return CaveProps.get_mesh("chest", 2)
		"minecart":
			return Props.get_mesh("cart", 1)
		"bones":
			return CaveProps.get_mesh("bones", 0)
	return Props.get_mesh("rock", 0)

func display() -> String:
	if sub == "forage" or sub == "cave_plant":
		return Items.def(data.get("item", ""))["name"] if Game.is_seen(data.get("item", "")) else "Something growing"
	return info(sub).get("name", sub.capitalize())

func prompt(_player) -> String:
	var r := info(sub)
	match sub:
		"berry_bush":
			return "Pick berries" if berries_ready else ""
		"forage", "cave_plant":
			return "Pick up %s" % display()
		"weed":
			return "Pull weeds"
		"twig":
			return "Pick up branch"
	if r.get("open", false):
		return "Open %s" % display()
	if r.get("note", false):
		return "Search %s" % display()
	return ""

func interact(player) -> void:
	var r := info(sub)
	if sub == "berry_bush":
		if berries_ready:
			Net.request("harvest_node", {"z": zone.zone_id, "id": oid, "berry": true})
		return
	if r.get("tool", "") == "hand" or r.get("hand", false):
		player.play_gather()
		Net.request("harvest_node", {"z": zone.zone_id, "id": oid})

func accepts_tool(t: String) -> bool:
	var need: String = info(sub).get("tool", "none")
	if need == "any":
		return true
	return need == t

func tool_hit(player, t: String, tier: int, power: float) -> void:
	var r := info(sub)
	if not accepts_tool(t):
		return
	if tier < int(r.get("tier", 0)):
		shake(0.03)
		Sfx.play_at("clank", global_position)
		Game.say("Your %s isn't strong enough for this." % {"pick": "pickaxe", "axe": "axe", "hoe": "hoe"}.get(t, "tool"), Color("ffb08a"))
		return
	hp -= power
	shake(0.1 if r.get("fall", false) else 0.05)
	_chips(r)
	if hp <= 0.0:
		var bonus := 1
		if r.get("ore", false) and randf() < 0.2 * Game.trait_count("prospector") + 0.25 * Game.buff("mining") + 0.25 * Game.buff("prospect"):
			bonus = 2
		if r.get("fall", false) and Game.has_trait("woodsman"):
			bonus = 2
		Net.request("harvest_node", {"z": zone.zone_id, "id": oid, "mult": bonus})
		Game.add_xp(r.get("skill", "foraging"), float(r.get("xp", 1)))

func _chips(r: Dictionary) -> void:
	var col := Color("8f8d88")
	var snd := "mine"
	if r.get("tool", "") == "axe":
		col = Color("c8a070")
		snd = "chop"
	elif sub == "weed" or sub == "twig":
		col = Color("6aa84a")
		snd = "rustle"
	elif sub.begins_with("ore_") or sub == "crystal_node" or sub == "gem_node":
		col = Color("d8c8a0")
	Fx.burst(zone.fx_root, global_position + Vector3(0, 0.7, 0), col, 8, 3.0)
	Sfx.play_at(snd, global_position)

## Server side: what this node yields.
func roll_drops(rng: RandomNumberGenerator, mult: int) -> Array:
	var r := info(sub)
	var out: Array = []
	if sub == "forage" or sub == "cave_plant":
		var item: String = data.get("item", "wild_herbs")
		out.append(Items.make(item, 1 + (1 if rng.randf() < 0.15 else 0)))
		var seed_id := item + "_seeds"
		if Items.has(seed_id) and Items.crops.has(item) and Items.crops[item]["perennial"] and rng.randf() < 0.35:
			out.append(Items.make(seed_id))
		if item == "glowcap" and rng.randf() < 0.3:
			out.append(Items.make("glowgrub", rng.randi_range(1, 3)))
		return out
	if sub == "berry_bush":
		out.append(Items.make(data.get("berry", "bramble_berry"), rng.randi_range(2, 4)))
		return out
	if r.has("loot"):
		return Loot.roll(r["loot"], depth, rng)
	if r.get("gem", false):
		out.append(Items.make(Loot.gem_for_depth(depth, rng), 1))
		return out
	for d in r.get("drops", []):
		var chance: float = d[3] if d.size() > 3 else 1.0
		if rng.randf() > chance:
			continue
		var n: int = rng.randi_range(d[1], d[2])
		if r.get("ore", false) and Items.cat_of(d[0]) in ["ore", "material", "mineral"]:
			n *= mult
		elif r.get("fall", false) and d[0] == "wood":
			n = int(n * (1.5 if mult > 1 else 1.0))
		if n > 0:
			out.append(Items.make(d[0], n))
	return out

func shares_loot() -> bool:
	return info(sub).has("loot")

func on_removed() -> void:
	vanish(info(sub).get("fall", false))

func _update_berries() -> void:
	var s := Game.season()
	var in_season := s == 1 or s == 2
	var picked_ok := zone == null or zone.node_present("b:" + oid, 3)
	var ready := in_season and picked_ok
	if ready != berries_ready or mesh_inst == null:
		berries_ready = ready
		set_mesh(_mesh_for(sub, 0), 80.0, _base_rot)

func refresh() -> void:
	if sub == "berry_bush":
		_update_berries()
