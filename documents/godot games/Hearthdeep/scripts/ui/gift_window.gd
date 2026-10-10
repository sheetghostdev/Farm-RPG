class_name GiftWindow
extends UIWin
## Pick something from your pack to give to (or ask about with) a townsperson.

var npc: NPC
var mode := "gift"
var grid_box: VBoxContainer

func _init(n: NPC, m: String) -> void:
	npc = n
	mode = m
	super._init(("Give %s a gift" if m == "gift" else "Ask %s about...") % n.data["first"], Vector2(600, 330))
	kind = "gift"
	grid_box = VBoxContainer.new()
	content.add_child(grid_box)
	refresh()

func refresh() -> void:
	clear_box(grid_box)
	if mode == "identify":
		grid_box.add_child(UITheme.label("Things nobody in the group understands yet are marked with ?", 14, UITheme.TEXT_DIM))
	else:
		grid_box.add_child(UITheme.label("One gift per person per day. People love things that match what they care about.", 14, UITheme.TEXT_DIM))
	grid_box.add_child(inventory_grid(10, 48))

func pick(i: int) -> void:
	var s: Dictionary = Game.inv.get_slot(i)
	if s.is_empty():
		return
	var c := Items.cat_of(s["id"])
	if mode == "identify":
		Net.request("identify", {"npc": npc.data["id"], "item": s["id"]})
		Game.main.ui.close()
		TownUI.open_dialogue(Game.main.ui, npc)
		return
	if c in ["tool", "quest"] or (s.has("d") and c != "gear" and c != "weapon"):
		Game.say("You can't give that away.", UITheme.BAD)
		return
	var one := Game.inv.take_at(i, 1)
	Game.inventory_changed.emit()
	Net.request("gift", {"npc": npc.data["id"], "item": one["id"]})
	Game.add_stat("gifts_given")
	Game.main.ui.close()
	TownUI.open_dialogue(Game.main.ui, npc)
