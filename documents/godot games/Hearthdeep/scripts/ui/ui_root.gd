class_name UIRoot
extends CanvasLayer
## Window manager (placeholder; filled in with the inventory milestone).

var top: Control
var paused := false

func _ready() -> void:
	layer = 10
	top = Control.new()
	top.set_anchors_preset(Control.PRESET_FULL_RECT)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)

func any_open() -> bool:
	return false

func chat_focused() -> bool:
	return false

func mouse_over() -> bool:
	return false

func slot_clicked(_s, _b) -> void:
	pass

func close_all() -> void:
	pass

func show_note(_i: int) -> void:
	pass

func show_message(t: String) -> void:
	Game.say(t)

func open_cave_menu(_w: bool = false) -> void:
	Game.main.travel_to_floor(1)

func open_shipping() -> void:
	pass

func open_journal(_tab: String = "") -> void:
	pass

func on_feature(_f) -> void:
	pass

func on_tell(_k: String, _d: Dictionary) -> void:
	pass

func open_chest(_o) -> void:
	pass

func open_craft(_k: String, _o = null) -> void:
	pass

func open_furnace(_o) -> void:
	pass

func open_kettle(_o) -> void:
	pass

func open_cook(_o, _c: bool) -> void:
	pass
