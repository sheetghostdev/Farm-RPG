class_name Loot
extends RefCounted
## Loot tables and equipment generation. Results are arrays of item stacks;
## {"id": "$money", "n": X} entries become shared money on the server.

static func roll(table: String, depth: int, rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	match table:
		"camp_crate":
			_pick_n(out, rng, 2, [["campfire_bread", 2, 4, 3], ["bandage", 1, 3, 3], ["torch", 3, 6, 2], ["$money", 40, 120, 2], ["worm", 4, 8, 2], ["escape_rope", 1, 1, 1]])
			if rng.randf() < 0.35:
				out.append(Items.make(_curio(rng)))
			if rng.randf() < 0.25:
				out.append(equipment(1, rng))
		"watchtower":
			out.append(Items.make(_curio(rng)))
			out.append(Items.make("$money", rng.randi_range(80, 200)))
			out.append(equipment(2, rng, "gear"))
		"ruins":
			_pick_n(out, rng, 1, [["ancient_coin", 1, 1, 2], ["carved_figure", 1, 1, 1], ["old_locket", 1, 1, 1], ["$money", 30, 90, 2]])
		"dig":
			_pick_n(out, rng, 1, [["worm", 2, 4, 10], ["clay", 1, 2, 6], ["bone", 1, 1, 2], ["stone", 2, 4, 3], ["flint", 1, 2, 3],
				["ancient_coin", 1, 1, 1], ["fossil_shell", 1, 1, 1], ["miners_tag", 1, 1, 1], ["rusty_key", 1, 1, 1],
				["turnip_seeds", 2, 4, 2], ["wheat_seeds", 2, 4, 2], ["mossbloom_seeds", 1, 2, 1]])
		"barrel":
			_pick_n(out, rng, rng.randi_range(1, 2), [["coal", 1, 3, 4], ["torch", 2, 4, 3], ["arrow", 5, 12, 2], ["campfire_bread", 1, 2, 2], ["cave_mushroom", 1, 3, 2], ["$money", 10, 40, 3], ["bandage", 1, 2, 2]])
		"minecart":
			var ore := ore_for_depth(depth, rng)
			out.append(Items.make(ore, rng.randi_range(5, 12)))
			out.append(Items.make("coal", rng.randi_range(2, 6)))
			if rng.randf() < 0.3:
				out.append(Items.make("geode", rng.randi_range(1, 2)))
		"chest_wood":
			_pick_n(out, rng, 2, [[ore_for_depth(depth, rng), 3, 6, 4], ["torch", 3, 8, 2], ["$money", 30 + depth * 10, 80 + depth * 20, 3],
				["brew_vigor_0", 1, 2, 2], ["escape_rope", 1, 1, 2], ["glowgrub", 2, 5, 2], ["geode", 1, 2, 2], ["trail_mix", 1, 3, 2]])
			if rng.randf() < 0.18:
				out.append(equipment(tier_for_depth(depth), rng))
		"chest_iron":
			_pick_n(out, rng, 2, [[bar_for_depth(depth), 2, 4, 3], [gem_for_depth(depth, rng), 1, 2, 3], ["$money", 80 + depth * 15, 160 + depth * 30, 3],
				["brew_vigor_1", 1, 2, 2], ["deluxe_bait", 3, 6, 1], ["geode", 2, 3, 2]])
			if rng.randf() < 0.45:
				out.append(equipment(tier_for_depth(depth), rng))
			if rng.randf() < 0.3:
				out.append(Items.make(_curio(rng)))
		"chest_gold":
			out.append(equipment(min(5, tier_for_depth(depth) + 1), rng))
			_pick_n(out, rng, 2, [[gem_for_depth(depth, rng), 2, 3, 3], [bar_for_depth(depth), 3, 6, 2], ["$money", 200 + depth * 30, 400 + depth * 50, 3], [_rare_seed(rng), 1, 2, 2]])
			out.append(Items.make(_curio(rng)))
		"hidden":
			out.append(equipment(min(5, tier_for_depth(depth) + 1), rng))
			_pick_n(out, rng, 2, [[gem_for_depth(depth, rng), 2, 4, 2], ["$money", 150 + depth * 25, 300 + depth * 40, 2], [_rare_seed(rng), 1, 2, 2], ["heartstone", 1, 1, 1 if depth >= 26 else 0]])
	return out

static func _pick_n(out: Array, rng: RandomNumberGenerator, n: int, table: Array) -> void:
	var pool := table.duplicate()
	for i in n:
		var total := 0
		for e in pool:
			total += int(e[3])
		if total <= 0:
			return
		var r := rng.randi() % total
		for j in pool.size():
			r -= int(pool[j][3])
			if r < 0:
				var e: Array = pool[j]
				out.append(Items.make(e[0], rng.randi_range(e[1], e[2])))
				pool.remove_at(j)
				break

static func _curio(rng: RandomNumberGenerator) -> String:
	var c := ["ancient_coin", "fossil_shell", "old_locket", "carved_figure", "rusty_key", "star_map", "clockwork_bird", "strange_idol", "miners_tag", "dragon_tooth"]
	var w := [5, 4, 4, 3, 3, 2, 1, 1, 4, 1]
	var total := 0
	for x in w:
		total += x
	var r := rng.randi() % total
	for i in c.size():
		r -= w[i]
		if r < 0:
			return c[i]
	return c[0]

static func _rare_seed(rng: RandomNumberGenerator) -> String:
	return ["glowcap_seeds", "crystalbloom_seeds", "deepmoss_seeds", "emberlily_seeds", "ghostbloom_seeds", "lumenfruit_sapling", "starfern_seeds"][min(6, int(pow(rng.randf(), 1.6) * 7.0))]

static func tier_for_depth(depth: int) -> int:
	return clamp(1 + depth / 6, 1, 5)

static func ore_for_depth(depth: int, rng: RandomNumberGenerator) -> String:
	if depth <= 4:
		return "copper_ore" if rng.randf() < 0.8 else "iron_ore"
	if depth <= 10:
		return "iron_ore" if rng.randf() < 0.7 else "copper_ore"
	if depth <= 16:
		return "silver_ore" if rng.randf() < 0.6 else "iron_ore"
	if depth <= 24:
		return "gold_ore" if rng.randf() < 0.55 else "silver_ore"
	return "starmetal_ore" if rng.randf() < 0.5 else "gold_ore"

static func bar_for_depth(depth: int) -> String:
	if depth <= 6:
		return "copper_bar"
	if depth <= 12:
		return "iron_bar"
	if depth <= 18:
		return "silver_bar"
	if depth <= 25:
		return "gold_bar"
	return "starmetal_bar"

static func gem_for_depth(depth: int, rng: RandomNumberGenerator) -> String:
	var pool := ["quartz", "quartz", "amethyst"]
	if depth > 5:
		pool.append_array(["amethyst", "topaz"])
	if depth > 10:
		pool.append_array(["aquamarine", "topaz"])
	if depth > 16:
		pool.append_array(["ruby", "emerald"])
	if depth > 25:
		pool.append_array(["ruby", "emerald", "heartstone"])
	return pool[rng.randi() % pool.size()]

## A piece of found equipment with one or two understandable traits.
static func equipment(tier: int, rng: RandomNumberGenerator, force: String = "") -> Dictionary:
	var kind := force
	if kind == "":
		kind = "weapon" if rng.randf() < 0.55 else ("gear" if rng.randf() < 0.75 else "tool")
	var id := ""
	match kind:
		"weapon":
			var w = ["sword", "spear", "hammer", "dagger", "bow"][rng.randi() % 5]
			id = "%s_%d" % [w, clamp(tier + rng.randi_range(-1, 0), 0, 5)]
		"gear":
			var gear := ["straw_hat", "miners_helmet", "angler_cap", "leather_cap", "explorer_hat", "leather_boots", "work_boots", "featherstep_boots",
				"copper_ring", "silver_ring", "gold_ring", "fish_charm", "bone_charm", "prospector_pendant", "lantern_pendant", "seed_pouch"]
			id = gear[rng.randi() % gear.size()]
		_:
			var t = ["pick", "axe", "rod", "can"][rng.randi() % 4]
			id = "%s_%d" % [t, clamp(tier - 1, 1, 4)]
	var n_traits := 1 if rng.randf() < 0.7 else 2
	var tr := Items.random_traits(id, rng, n_traits)
	for t in Items.def(id).get("traits", []):
		tr.erase(t)
	if tr.is_empty():
		return Items.make(id)
	return Items.make(id, 1, {"tr": tr, "nm": Items.traited_name(id, tr)})

static func enemy_drops(enemy: String, depth: int, rng: RandomNumberGenerator, scavenger: bool) -> Array:
	var out: Array = []
	var mat: String = {"bat": "bat_wing", "slime": "slime_gel", "burrower": "mole_claw", "beetle": "beetle_shell",
		"spitter": "spore_sac", "golem": "golem_core", "salamander": "ember_scale", "sentinel": "ancient_cog"}.get(enemy, "")
	var chance := 0.55 + (0.25 if scavenger else 0.0)
	if mat != "" and rng.randf() < chance:
		out.append(Items.make(mat, 1 + (1 if scavenger and rng.randf() < 0.5 else 0)))
	if rng.randf() < 0.18:
		out.append(Items.make(ore_for_depth(depth, rng), rng.randi_range(1, 3)))
	if rng.randf() < 0.12:
		out.append(Items.make("$money", rng.randi_range(5, 15 + depth * 3)))
	if rng.randf() < 0.04 + depth * 0.001:
		out.append(equipment(tier_for_depth(depth), rng))
	if enemy in ["golem", "sentinel"] and rng.randf() < 0.3:
		out.append(Items.make(gem_for_depth(depth, rng)))
	return out
