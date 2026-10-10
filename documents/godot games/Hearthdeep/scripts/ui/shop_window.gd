class_name ShopWindow
extends UIWin
## A shop: click to buy (shift for five), and sell from your pack below.

var shop := ""
var top: VBoxContainer
var inv_box: VBoxContainer

func _init(shop_id: String, title: String) -> void:
	shop = shop_id
	super._init(title, Vector2(680, 560))
	kind = "shop"
	top = VBoxContainer.new()
	content.add_child(top)
	content.add_child(HSeparator.new())
	inv_box = VBoxContainer.new()
	content.add_child(inv_box)
	refresh()

func refresh() -> void:
	clear_box(top)
	top.add_child(UITheme.label("Click to buy (shift: ×5) · %d coins" % Game.money(), 15, UITheme.ACCENT))
	var g := slot_grid(10)
	for id in TownLogic.stock(shop):
		if not Items.has(id):
			continue
		var s := make_slot(Items.make(id), "shop", 0, 54)
		s.price = TownLogic.buy_price_for(id, shop, Game.profile["name"])
		g.add_child(s)
	top.add_child(g)
	clear_box(inv_box)
	inv_box.add_child(UITheme.label("Your pack — click to sell one, shift-click to sell the stack. Specialty goods sell for a little more here.", 14, UITheme.TEXT_DIM))
	inv_box.add_child(inventory_grid(10, 48))
