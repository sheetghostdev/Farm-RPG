class_name Enemy
extends Node3D
## Creature (placeholder).

var eid := 0
var etype := ""
var level := 1
var zone_id := ""
var zone: Zone
var elite := false
var authority := false
var hp := 10.0
var dead := false
var state_t := 0.0

static func base_hp(_t: String, lvl: int, elite_v: bool) -> float:
	return 10.0 * lvl * (3.0 if elite_v else 1.0)

func setup(h: float) -> void:
	hp = h

func state_code() -> int:
	return 0

func apply_snapshot(_p: Vector3, _yaw: float, _st: int, _hp: float, _t: float) -> void:
	pass

func server_take_hit(dmg: float, _kb: Vector3, _fx: Dictionary, _peer: int) -> float:
	hp -= dmg
	return dmg

func hit_fx(_d: float, _kb: Vector3, _c: bool) -> void:
	pass

func die_fx() -> void:
	queue_free()

var radius := 0.6

func untargetable() -> bool:
	return false

func facing_away_from(_p: Vector3) -> bool:
	return false
