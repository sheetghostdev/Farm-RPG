class_name Feature
extends WorldObj
## A fixed interactable with a named action handled by the game controller:
## doors, the cave mouth, ladders, the shipping bin, wells, notice boards...

var action := ""
var label := ""
var args := {}

func setup(id: String, act: String, text: String, pos: Vector3, r: float = 1.2, a: Dictionary = {}) -> Feature:
	oid = id
	kind = "feature"
	sub = act
	action = act
	label = text
	position = pos
	radius = r
	args = a
	return self

func prompt(_player) -> String:
	return label

func interact(player) -> void:
	if Game.main:
		Game.main.on_feature(self, player)

func accepts_tool(t: String) -> bool:
	return action == "well" and t == "can"
