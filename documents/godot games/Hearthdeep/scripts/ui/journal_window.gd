class_name JournalWindow
extends UIWin
## Journal (placeholder until the journal milestone).

func _init(_tab: String = "") -> void:
	super._init("Journal", Vector2(400, 200))
	kind = "journal"
