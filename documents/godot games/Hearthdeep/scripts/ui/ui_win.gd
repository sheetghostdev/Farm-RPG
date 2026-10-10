class_name UIWin
extends PanelContainer
## Base window: title bar, close button, content box and helpers for slot grids.

signal closed

var kind := ""
var content: VBoxContainer
var title_l: Label
var obj = null           # world object this window is attached to (chest, kettle...)

func _init(title: String = "", min_size: Vector2 = Vector2(420, 200)) -> void:
	custom_minimum_size = min_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	var bar := HBoxContainer.new()
	v.add_child(bar)
	title_l = UITheme.label(title, 22, UITheme.ACCENT)
	title_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(title_l)
	var x := UITheme.button("✕", func(): close_win(), 16)
	x.custom_minimum_size = Vector2(34, 30)
	bar.add_child(x)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	v.add_child(content)

func close_win() -> void:
	closed.emit()

## Called when something it shows may have changed.
func refresh() -> void:
	pass

func clear_box(b: Node) -> void:
	for c in b.get_children():
		b.remove_child(c)
		c.queue_free()

func slot_grid(cols: int) -> GridContainer:
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", 4)
	g.add_theme_constant_override("v_separation", 4)
	return g

func make_slot(it: Dictionary, src: String, idx: int, size: float = 52.0) -> ItemSlot:
	var s := ItemSlot.new(size)
	s.source = src
	s.index = idx
	s.set_item(it)
	s.pressed.connect(func(sl, b): Game.main.ui.slot_clicked(sl, b))
	s.hovered.connect(func(sl, on): Game.main.hud.show_tooltip(ItemSlot.describe(sl.item) if on else ""))
	return s

## The player's pack as a grid of slots (hotbar row first).
func inventory_grid(cols: int = 10, size: float = 50.0) -> GridContainer:
	var g := slot_grid(cols)
	for i in Inventory.MAX_SLOTS:
		var s := make_slot(Game.inv.get_slot(i), "inv", i, size)
		if i < 10:
			s.hotkey = str((i + 1) % 10)
		if i >= Game.inv.capacity:
			s.dim = true
			s.mouse_filter = Control.MOUSE_FILTER_IGNORE
			s.modulate.a = 0.35
		g.add_child(s)
	return g

func need_row(needs: Dictionary, counts: Dictionary) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	for id in needs:
		var have := int(counts.get(id, 0))
		var need := int(needs[id])
		var s := ItemSlot.new(30)
		s.set_item(Items.make(id))
		s.mouse_filter = Control.MOUSE_FILTER_PASS
		s.hovered.connect(func(sl, on): Game.main.hud.show_tooltip(ItemSlot.describe(sl.item) if on else ""))
		h.add_child(s)
		h.add_child(UITheme.label("%d/%d" % [have, need], 15, UITheme.GOOD if have >= need else UITheme.BAD))
	return h
