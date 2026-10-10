class_name Projectile
extends Node3D
## Arrow / spit (placeholder).

var kind := ""
var velocity := Vector3.ZERO
var damage := 1.0
var owner_peer := 0
var zone: Zone
var extra := {}

func setup() -> void:
	pass
