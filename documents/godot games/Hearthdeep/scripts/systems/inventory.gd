class_name Inventory
extends RefCounted
## A backpack of item stacks. Slots 0-9 are the hotbar.

const MAX_SLOTS := 42
const HOTBAR := 10

var slots: Array = []
var capacity := 30

func _init() -> void:
	slots.resize(MAX_SLOTS)
	for i in MAX_SLOTS:
		slots[i] = {}

func load_from(arr: Array, cap: int) -> void:
	capacity = cap
	slots.resize(MAX_SLOTS)
	for i in MAX_SLOTS:
		slots[i] = arr[i].duplicate(true) if i < arr.size() and arr[i] is Dictionary else {}

func get_slot(i: int) -> Dictionary:
	if i < 0 or i >= slots.size():
		return {}
	return slots[i]

func set_slot(i: int, it: Dictionary) -> void:
	if i < 0 or i >= slots.size():
		return
	if not it.is_empty() and int(it.get("n", 0)) <= 0:
		it = {}
	slots[i] = it

## Adds an item stack; returns the count that did not fit.
func add(it: Dictionary) -> int:
	if it.is_empty():
		return 0
	var left := int(it["n"])
	var mx := Items.stack_max(it["id"])
	if mx > 1 and not it.has("d"):
		for i in capacity:
			var s: Dictionary = slots[i]
			if not s.is_empty() and Items.can_stack(s, it) and int(s["n"]) < mx:
				var room: int = mx - int(s["n"])
				var put: int = min(room, left)
				s["n"] = int(s["n"]) + put
				left -= put
				if left <= 0:
					return 0
	for i in capacity:
		if slots[i].is_empty():
			var put2: int = min(mx, left)
			var ns: Dictionary = it.duplicate(true)
			ns["n"] = put2
			slots[i] = ns
			left -= put2
			if left <= 0:
				return 0
	return left

func can_add(it: Dictionary) -> bool:
	var left := int(it["n"])
	var mx := Items.stack_max(it["id"])
	for i in capacity:
		var s: Dictionary = slots[i]
		if s.is_empty():
			left -= mx
		elif Items.can_stack(s, it):
			left -= mx - int(s["n"])
		if left <= 0:
			return true
	return false

func count(id: String) -> int:
	var n := 0
	for i in capacity:
		var s: Dictionary = slots[i]
		if not s.is_empty() and s["id"] == id:
			n += int(s["n"])
	return n

func counts() -> Dictionary:
	var out := {}
	for i in capacity:
		var s: Dictionary = slots[i]
		if not s.is_empty():
			out[s["id"]] = int(out.get(s["id"], 0)) + int(s["n"])
	return out

func has_all(needs: Dictionary) -> bool:
	for id in needs:
		if count(id) < int(needs[id]):
			return false
	return true

## Removes n of id (from the end of the pack first). Returns true on success.
func remove(id: String, n: int) -> bool:
	if count(id) < n:
		return false
	var left := n
	for i in range(capacity - 1, -1, -1):
		var s: Dictionary = slots[i]
		if s.is_empty() or s["id"] != id:
			continue
		var take: int = min(left, int(s["n"]))
		s["n"] = int(s["n"]) - take
		if int(s["n"]) <= 0:
			slots[i] = {}
		left -= take
		if left <= 0:
			break
	return true

func remove_all(needs: Dictionary) -> bool:
	if not has_all(needs):
		return false
	for id in needs:
		remove(id, int(needs[id]))
	return true

func take_at(i: int, n: int) -> Dictionary:
	var s := get_slot(i)
	if s.is_empty():
		return {}
	var take: int = min(n, int(s["n"]))
	var out: Dictionary = s.duplicate(true)
	out["n"] = take
	s["n"] = int(s["n"]) - take
	if int(s["n"]) <= 0:
		slots[i] = {}
	return out

func first_index(id: String) -> int:
	for i in capacity:
		if not slots[i].is_empty() and slots[i]["id"] == id:
			return i
	return -1

func free_slots() -> int:
	var n := 0
	for i in capacity:
		if slots[i].is_empty():
			n += 1
	return n

## Sorts the non-hotbar part of the pack by category then name.
func sort_pack() -> void:
	var items: Array = []
	for i in range(HOTBAR, capacity):
		if not slots[i].is_empty():
			items.append(slots[i])
		slots[i] = {}
	var merged: Array = []
	for it in items:
		var done := false
		for m in merged:
			if Items.can_stack(m, it) and int(m["n"]) < Items.stack_max(m["id"]):
				var room: int = Items.stack_max(m["id"]) - int(m["n"])
				var put: int = min(room, int(it["n"]))
				m["n"] = int(m["n"]) + put
				it["n"] = int(it["n"]) - put
				if int(it["n"]) <= 0:
					done = true
					break
		if not done:
			merged.append(it)
	merged.sort_custom(func(a, b):
		var ca: String = Items.cat_of(a["id"])
		var cb: String = Items.cat_of(b["id"])
		if ca != cb:
			return ca < cb
		return Items.display_name(a) < Items.display_name(b))
	var idx := HOTBAR
	for it in merged:
		if idx >= capacity:
			break
		slots[idx] = it
		idx += 1
