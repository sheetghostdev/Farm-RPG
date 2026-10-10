class_name ChestWindow
extends UIWin
## Shared storage (chests, sheds) and the shipping bin, shown above the backpack.

var top_box: VBoxContainer
var inv_box: VBoxContainer
var shipping := false

func _init(o, is_shipping: bool = false) -> void:
	shipping = is_shipping
	super._init("Shipping Bin" if is_shipping else "Storage", Vector2(700, 520))
	kind = "shipping" if is_shipping else "chest"
	obj = o
	top_box = VBoxContainer.new()
	content.add_child(top_box)
	content.add_child(HSeparator.new())
	inv_box = VBoxContainer.new()
	content.add_child(inv_box)
	refresh()

func items() -> Array:
	if shipping:
		return Game.world.get("shipping", [])
	if obj == null or not is_instance_valid(obj):
		return []
	return obj.data().get("items", [])

func capacity() -> int:
	if shipping:
		return 60
	return PlacedObj.CAPACITY.get(obj.obj_type, 36)

func refresh() -> void:
	clear_box(top_box)
	var its := items()
	if shipping:
		var total := 0
		for it in its:
			total += Items.sell_price(it) * int(it["n"])
		top_box.add_child(UITheme.label("Anything left here is sold overnight. Tonight's total: %d coins" % total, 15, UITheme.ACCENT))
	else:
		title_l.text = "%s  (%d/%d)" % ["Shed Storage" if obj.obj_type == "shed" else "Chest", its.size(), capacity()]
	var cols := 12
	var g := slot_grid(cols)
	var shown: int = max(capacity() if not shipping else max(12, its.size() + 1), 12)
	shown = min(shown, 72)
	for i in shown:
		var it: Dictionary = its[i] if i < its.size() else {}
		g.add_child(make_slot(it, "ship" if shipping else "chest", i, 50))
	if not shipping and capacity() > 72:
		var sc := ScrollContainer.new()
		sc.custom_minimum_size = Vector2(640, 230)
		sc.add_child(g)
		top_box.add_child(sc)
	else:
		top_box.add_child(g)
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 8)
	if not shipping:
		btns.add_child(UITheme.button("Sort", func(): Net.request("chest_sort", {"id": obj.oid}), 15))
		btns.add_child(UITheme.button("Stack matching items", _deposit_matching, 15))
		btns.add_child(UITheme.button("Take all", _take_all, 15))
	top_box.add_child(btns)
	clear_box(inv_box)
	inv_box.add_child(UITheme.label("Backpack — shift-click to move items %s" % ("into the bin" if shipping else "into storage"), 14, UITheme.TEXT_DIM))
	inv_box.add_child(inventory_grid(10, 50))

## Puts every pack item that already has a stack in this chest into it.
func _deposit_matching() -> void:
	var present := {}
	for it in items():
		present[it["id"]] = true
	var moved := 0
	for i in range(Inventory.HOTBAR, Game.inv.capacity):
		var s: Dictionary = Game.inv.get_slot(i)
		if s.is_empty() or not present.has(s["id"]) or s.has("d"):
			continue
		var out := Game.inv.take_at(i, int(s["n"]))
		Net.request("chest_put", {"id": obj.oid, "item": out})
		moved += 1
	Game.inventory_changed.emit()
	if moved > 0:
		Sfx.play("place", -6.0)

func _take_all() -> void:
	var its := items()
	for i in range(its.size() - 1, -1, -1):
		if not Game.inv.can_add(its[i]):
			continue
		Net.request("chest_take", {"id": obj.oid, "idx": i, "n": int(its[i]["n"]), "expect": its[i]["id"]})
