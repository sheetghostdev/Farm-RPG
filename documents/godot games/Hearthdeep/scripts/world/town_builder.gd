class_name TownBuilder
extends Node3D
## Builds the generated town (placeholder until the town milestone).

var over: Overworld

func build(o: Overworld) -> void:
	over = o

func on_new_day() -> void:
	pass

func on_change(_k: String, _ch: Dictionary) -> void:
	pass
