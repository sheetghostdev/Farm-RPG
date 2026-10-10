class_name Tips
extends PanelContainer
## Gentle one-time hints that appear the first time something becomes relevant.
## Remembered per player profile, so they never repeat across worlds.

const TIPS := {
	"welcome": "Welcome home. WASD to walk, E to interact, left click to use what's in your hand. Number keys pick from your hotbar.",
	"ship": "Anything you drop in the shipping bin by the house is sold overnight. The purse is shared by the whole household.",
	"hoe": "Click soil with the hoe to till it. Water tilled soil with the can (refill at the well or any water), then plant seeds.",
	"seeds": "Seeds go on tilled soil. Watered crops grow a little every morning, and some only grow in certain seasons.",
	"rod": "Hold to wind up a cast and release to throw. When something bites, click, then hold to keep the fish inside the green zone.",
	"weapon": "Red markings on the ground show where an attack will land. Space to dodge through it. Every weapon swings differently.",
	"town": "The townsfolk have jobs, families and opinions. Talk, bring gifts, and check the request board in the plaza.",
	"home": "Furniture placed indoors stays where you put it. The hearth cooks proper meals, and the lectern holds the household journal.",
	"cave": "Each floor goes deeper. Find the way down, or the ladder back up. The map fills in as you explore (M).",
	"night": "Night is falling. Sleep in a bed and time rushes once everyone is resting. Nobody has to, though.",
	"journal": "J opens the household journal: everything found, caught, cooked and the chronicle of what you've done together. M opens the map.",
	"craft": "C opens field crafting for simple things anywhere. A workbench knows more, and new finds teach new plans.",
	"hurt": "Food in your hotbar heals when you use it. If you go down, a friend can help you up; otherwise you'll wake up at home.",
	"deep": "Waystones hum on some floors. Touch one and you can return straight to that depth from the cave mouth.",
	"friends": "Friends share the purse, chests, the farm and the chronicle. Each of you keeps your own pack.",
	"ore": "Ore smelts into bars at a furnace. The blacksmith in town can turn bars into better tools.",
}

var label: RichTextLabel
var _queue: Array = []
var _showing := ""
var _show_t := 0.0
var _check_t := 0.0
var _run_t := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", UITheme.box(Color(0.12, 0.09, 0.08, 0.88), Color(0.6, 0.48, 0.32), 10, 1, 12))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	add_child(h)
	var dot := UITheme.label("✦", 20, UITheme.ACCENT)
	dot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(dot)
	label = UITheme.rich("", 16)
	label.custom_minimum_size = Vector2(380, 0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(label)
	modulate.a = 0.0
	visible = false

func seen(id: String) -> bool:
	return Game.profile.get("tips", {}).has(id)

func trigger(id: String) -> void:
	if not TIPS.has(id) or seen(id) or _queue.has(id) or _showing == id or Game.autotest != "":
		return
	_queue.append(id)

func _process(delta: float) -> void:
	if not Game.running:
		return
	_run_t += delta
	_check_t -= delta
	if _check_t <= 0.0:
		_check_t = 0.5
		_check()
	if _showing != "":
		_show_t -= delta
		if _show_t <= 0.0:
			_showing = ""
			var tw := create_tween()
			tw.tween_property(self, "modulate:a", 0.0, 0.5)
			tw.tween_callback(func(): visible = false)
	elif not _queue.is_empty() and not Game.main.ui.any_open():
		_showing = _queue.pop_front()
		if not Game.profile.has("tips"):
			Game.profile["tips"] = {}
		Game.profile["tips"][_showing] = true
		Game.save_profile()
		label.text = TIPS[_showing]
		visible = true
		reset_size()
		_show_t = 7.0 + TIPS[_showing].length() * 0.04
		var tw2 := create_tween()
		tw2.tween_property(self, "modulate:a", 1.0, 0.4)

func _check() -> void:
	var lp = Game.local_player
	if lp == null:
		return
	if _run_t > 2.0:
		trigger("welcome")
	if _run_t > 25.0:
		trigger("ship")
	if _run_t > 70.0:
		trigger("journal")
	if _run_t > 180.0:
		trigger("craft")
	var held: Dictionary = lp.held_item()
	var id: String = held.get("id", "")
	var cat := Items.cat_of(id) if id != "" and Items.has(id) else ""
	if id.begins_with("hoe_") or id.begins_with("can_"):
		trigger("hoe")
	elif cat == "seed":
		trigger("seeds")
	elif id.begins_with("rod_"):
		trigger("rod")
	elif cat != "" and Items.def(id).has("weapon"):
		trigger("weapon")
	if cat == "ore":
		trigger("ore")
	var z = lp.zone()
	if z == null:
		return
	if z is Overworld:
		if (z as Overworld).gen.town_rect.grow(4.0).has_point(Vector2(lp.global_position.x, lp.global_position.z)):
			trigger("town")
		if Game.is_night():
			trigger("night")
	elif z is HomeZone:
		trigger("home")
	elif z is CaveFloor:
		trigger("cave")
		if (z as CaveFloor).floor_n >= 4:
			trigger("deep")
	if lp.hp < lp.max_hp() * 0.5:
		trigger("hurt")
	if Net.peers.size() > 1:
		trigger("friends")
