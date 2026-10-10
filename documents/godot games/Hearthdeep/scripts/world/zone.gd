class_name Zone
extends Node3D
## Base class for a loaded area of the world: the overworld, the farmhouse
## interior, or one cave floor. Zones live side by side at different offsets
## inside one 3D world so a host can simulate several at once.

var zone_id := ""
var kind := ""
var origin := Vector3.ZERO
var objs := {}                 # oid -> WorldObj
var _grid := {}                # Vector2i(4 m cell) -> Array[WorldObj]
var nodes_root: Node3D
var objects_root: Node3D
var enemies_root: Node3D
var pickups_root: Node3D
var fx_root: Node3D
var built := false

const GRID := 4.0

func _init() -> void:
	nodes_root = Node3D.new()
	nodes_root.name = "Nodes"
	objects_root = Node3D.new()
	objects_root.name = "Objects"
	enemies_root = Node3D.new()
	enemies_root.name = "Enemies"
	pickups_root = Node3D.new()
	pickups_root.name = "Pickups"
	fx_root = Node3D.new()
	fx_root.name = "Fx"

func _ready() -> void:
	for n in [nodes_root, objects_root, enemies_root, pickups_root, fx_root]:
		add_child(n)
	Game.changed.connect(_on_change)

func build() -> void:
	built = true

func underground() -> bool:
	return false

## Ground height at a global x/z.
func ground_y(_x: float, _z: float) -> float:
	return origin.y

## Is this global position impassable on foot (deep water, chasm)?
func is_blocked(_p: Vector3) -> bool:
	return false

## Water under/at a global position: {} or {"kind", "lvl", "name", "id"}.
func water_at(_p: Vector3) -> Dictionary:
	return {}

func spawn_point(_tag: String = "") -> Vector3:
	return origin + Vector3(0, 1, 0)

func display_name() -> String:
	return zone_id

func env_profile() -> String:
	return "surface"

func on_new_day() -> void:
	pass

func _on_change(kind_s: String, ch: Dictionary) -> void:
	pass

# ------------------------------------------------------------------ object registry

func _cell(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / GRID), floori(p.z / GRID))

func register(o: WorldObj) -> void:
	objs[o.oid] = o
	o.zone = self
	var c := _cell(o.global_position if o.is_inside_tree() else o.position)
	o.grid_cell = c
	if not _grid.has(c):
		_grid[c] = []
	_grid[c].append(o)

func unregister(o: WorldObj) -> void:
	objs.erase(o.oid)
	if _grid.has(o.grid_cell):
		_grid[o.grid_cell].erase(o)

func remove_obj(oid: String, animate: bool = true) -> void:
	var o: WorldObj = objs.get(oid)
	if o == null:
		return
	unregister(o)
	if animate:
		o.vanish()
	else:
		o.queue_free()

func query(p: Vector3, radius: float) -> Array:
	var out: Array = []
	var c0 := _cell(p - Vector3(radius, 0, radius))
	var c1 := _cell(p + Vector3(radius, 0, radius))
	for cz in range(c0.y, c1.y + 1):
		for cx in range(c0.x, c1.x + 1):
			var arr = _grid.get(Vector2i(cx, cz))
			if arr == null:
				continue
			for o in arr:
				if is_instance_valid(o):
					var d: Vector3 = o.global_position - p
					d.y = 0
					if d.length() <= radius + o.radius:
						out.append(o)
	return out

func nearest(p: Vector3, radius: float, filter: Callable) -> WorldObj:
	var best: WorldObj = null
	var bd := 1e9
	for o in query(p, radius):
		if not filter.call(o):
			continue
		var d: float = (o.global_position - p).length() - o.radius
		if d < bd:
			bd = d
			best = o
	return best

## Is the footprint around p free of blocking objects (for placement)?
func area_free(p: Vector3, half: Vector2) -> bool:
	for o in query(p, max(half.x, half.y) + 1.0):
		if o.blocking or o.kind == "placed":
			var d: Vector3 = o.global_position - p
			if abs(d.x) < half.x + o.radius * 0.7 and abs(d.z) < half.y + o.radius * 0.7:
				return false
	return true

func removed_day(oid: String) -> int:
	var r: Dictionary = Game.world.get("removed", {}).get(zone_id, {})
	return int(r.get(oid, -1000))

## True if a node with this id should currently exist given its respawn time.
func node_present(oid: String, respawn_days: int) -> bool:
	var rd := removed_day(oid)
	if rd < -999:
		return true
	if respawn_days < 0:
		return false
	return Game.day() - rd >= respawn_days
