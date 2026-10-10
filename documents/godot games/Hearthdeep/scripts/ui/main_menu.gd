class_name MainMenu
extends CanvasLayer
## Title screen (placeholder).

func open() -> void:
	visible = true

func show_error(t: String) -> void:
	push_warning(t)
