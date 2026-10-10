class_name CaveFloor
extends Zone
## One floor of the caves (placeholder).

var floor_n := 1

func _init() -> void:
	super._init()
	kind = "cave"
