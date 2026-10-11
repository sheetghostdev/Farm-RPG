class_name ValleyLayout
extends RefCounted
## The hand-designed heart of the valley. Everything here is the same in every
## world: the farm, the town of Brindlewick, the cave mouth in the north cliffs,
## the river, Heron Lake and the borders. Only the wilds beyond those borders
## (and the caves) change from world to world.
##
## Coordinates are meters on the 320 m map: x grows east, z grows south.

const TOWN_NAME := "Brindlewick"

# ------------------------------------------------------------------ the core

const CLIFF_Z := 74.0                       # the north cliffs: highlands beyond
const WEST_WALL_X := 58.0                   # hedgerow and dry-stone wall: Whisperwood beyond
const CORE_H := 5.0                         # ground level of the valley floor

const FARM_RECT := Rect2(70, 104, 64, 56)
const FARM_GATES := {"east": Vector2(134, 124), "south": Vector2(102, 160), "west": Vector2(70, 132)}

const TOWN_CENTER := Vector2(190, 146)     # the plaza and its fountain
const CAVE_POS := Vector2(190, 76)         # the cave mouth, cut into the cliffs
const FALLS := Vector2(254, 76)            # where the river tumbles down from the highlands

const LAKE := {"c": Vector2(92, 236), "r": 20.0}
const FARM_POND := {"c": Vector2(80, 151), "r": 4.6}

## The river, from the falls to the lake (smoothed when generated).
const RIVER := [Vector2(254, 72), Vector2(254, 80), Vector2(256, 100), Vector2(257, 122), Vector2(256, 146), Vector2(253, 172),
	Vector2(248, 198), Vector2(240, 220), Vector2(226, 234), Vector2(206, 240), Vector2(186, 241), Vector2(164, 240),
	Vector2(144, 238), Vector2(124, 237), Vector2(104, 236)]
const RIVER_W := [6.5, 7.0, 7.0, 7.5, 7.5, 7.5, 8.0, 8.0, 8.5, 8.5, 8.5, 8.0, 8.0, 8.5, 9.0]

## Streets and lanes. Each is a polyline; they're smoothed and painted on the ground.
const ROADS := {
	"farm_road": [Vector2(134, 124), Vector2(142, 130), Vector2(150, 139), Vector2(160, 146), Vector2(177, 146)],
	"east_street": [Vector2(203, 146), Vector2(222, 146), Vector2(240, 146), Vector2(250, 146)],
	"north_street": [Vector2(190, 133), Vector2(190, 116), Vector2(190, 100), Vector2(190, 86)],
	"south_street": [Vector2(190, 159), Vector2(190, 180), Vector2(190, 204), Vector2(190, 230)],
	"highland_lane": [Vector2(184, 90), Vector2(166, 92), Vector2(146, 92), Vector2(126, 91), Vector2(118, 88)],
	"dock_lane": [Vector2(102, 160), Vector2(104, 174), Vector2(104, 190), Vector2(101, 207)],
	"river_lane": [Vector2(190, 224), Vector2(172, 229), Vector2(160, 231), Vector2(146, 231)],
	"west_lane": [Vector2(70, 132), Vector2(58, 132)],
}
## Where a road crosses the river: [near point, broken?]
const BRIDGES := [[Vector2(256, 146), false], [Vector2(190, 241), false], [Vector2(146, 238), true]]

## The switchback trail up through a gap in the cliffs to the highlands.
const HIGHLAND_RAMP := [Vector2(118, 89), Vector2(112, 62)]

## Borders: walls the player can't cross, except at gates.
const WALLS := [
	{"a": Vector2(58, 72), "b": Vector2(58, 128.5), "kind": "stone"},
	{"a": Vector2(58, 135.5), "b": Vector2(58, 258), "kind": "stone"},
	{"a": Vector2(58, 258), "b": Vector2(89, 251), "kind": "stone"},
]
## Gates out to the wilds (signposted). "p" is the gateway, "out" points into the wild.
const GATES := [
	{"id": "gate_west", "p": Vector2(58, 132), "out": Vector2(-1, 0), "region": "west", "arch": true},
	{"id": "gate_highlands", "p": Vector2(118, 91), "out": Vector2(-0.22, -0.97), "region": "north", "arch": true},
	{"id": "gate_east", "p": Vector2(263, 146), "out": Vector2(1, 0), "region": "east", "arch": false},
	{"id": "gate_south", "p": Vector2(190, 249), "out": Vector2(0, 1), "region": "south", "arch": false},
	{"id": "gate_oldbridge", "p": Vector2(146, 246), "out": Vector2(0, 1), "region": "south", "arch": false},
]

const REGION_NAMES := {"core": "The Valley", "north": "The Highlands", "west": "Whisperwood", "south": "Fenmarsh", "east": "Eastmeadow"}
const REGION_BLURBS := {
	"north": "Wind, pines and old stone. The paths up here are never quite where you left them.",
	"west": "The woods shift with the seasons. Locals say the trees move when nobody's looking.",
	"south": "Reeds, willows and standing water. Lovely in spring, buggy in summer.",
	"east": "Open meadows past the river. Wildflowers, old stones and long walks.",
}

const NAMES := {"river": "Willow Run", "lake": "Heron Lake", "falls": "Willow Falls", "farm_pond": "the farm pond"}

## Quiet groves inside the valley (trees and shrubs, never on paths).
const GROVES := [
	{"c": Vector2(84, 88), "r": 14.0, "kind": "oak"},
	{"c": Vector2(232, 96), "r": 13.0, "kind": "birch"},
	{"c": Vector2(80, 188), "r": 11.0, "kind": "orchard"},
	{"c": Vector2(124, 210), "r": 9.0, "kind": "willow"},
	{"c": Vector2(152, 196), "r": 8.0, "kind": "oak"},
	{"c": Vector2(230, 196), "r": 9.0, "kind": "birch"},
	{"c": Vector2(152, 112), "r": 7.0, "kind": "oak"},
]

## Fixed points of interest inside the valley.
const CORE_POIS := [
	{"id": "clay_bank", "type": "clay_bank", "pos": Vector2(234, 220), "r": 8.0, "name": "Red Clay Bend"},
	{"id": "falls", "type": "falls", "pos": Vector2(250, 82), "r": 12.0, "name": "Willow Falls"},
	{"id": "delvers_yard", "type": "yard", "pos": Vector2(190, 88), "r": 9.0, "name": ""},
]

# ------------------------------------------------------------------ the town of Brindlewick

## Buildings: id, role, center, the point the front door faces, size, floors, roof style
## (0 gable, 1 hip, 2 flat), timber framing, wall and roof colors.
const BUILDINGS := [
	{"id": "hall", "role": "mayor", "pos": Vector2(174.5, 130.5), "face": TOWN_CENTER, "w": 10.0, "d": 7.5, "floors": 2, "style": 1, "timber": false, "wall": Color("e8dcc8"), "roof": Color("6a4a5a")},
	{"id": "store", "role": "merchant", "pos": Vector2(205.5, 130.5), "face": TOWN_CENTER, "w": 8.5, "d": 7.0, "floors": 2, "style": 0, "timber": true, "wall": Color("f1dfb8"), "roof": Color("b5523b")},
	{"id": "tavern", "role": "innkeeper", "pos": Vector2(174.5, 161.5), "face": TOWN_CENTER, "w": 9.5, "d": 7.5, "floors": 2, "style": 0, "timber": true, "wall": Color("e0c8b8"), "roof": Color("8a5a8a")},
	{"id": "smithy", "role": "smith", "pos": Vector2(205.5, 161.5), "face": TOWN_CENTER, "w": 8.5, "d": 7.0, "floors": 1, "style": 0, "timber": false, "wall": Color("c8c0b0"), "roof": Color("4f6a7a")},
	{"id": "apothecary", "role": "herbalist", "pos": Vector2(226, 134), "face": Vector2(226, 146), "w": 7.0, "d": 6.0, "floors": 1, "style": 0, "timber": true, "wall": Color("d8e0c8"), "roof": Color("5f8a4f")},
	{"id": "workshop", "role": "carpenter", "pos": Vector2(204.5, 101), "face": Vector2(190, 101), "w": 8.5, "d": 7.0, "floors": 1, "style": 0, "timber": true, "wall": Color("d0b898"), "roof": Color("a8743f")},
	{"id": "tackle", "role": "angler", "pos": Vector2(177, 216), "face": Vector2(190, 216), "w": 7.0, "d": 5.5, "floors": 1, "style": 0, "timber": false, "wall": Color("c8d8e0"), "roof": Color("4a7ab0")},
	{"id": "curio", "role": "curio_hall", "pos": Vector2(226, 159), "face": Vector2(226, 146), "w": 9.0, "d": 6.5, "floors": 1, "style": 1, "timber": false, "wall": Color("e8dcc8"), "roof": Color("4a5a6a")},
	# homes
	{"id": "h_thatcher", "role": "house", "pos": Vector2(177, 114), "face": Vector2(190, 114), "w": 6.5, "d": 6.0, "floors": 2, "style": 0, "timber": true, "wall": Color("f0e6d6"), "roof": Color("b5523b")},
	{"id": "h_underhill", "role": "house", "pos": Vector2(177, 101), "face": Vector2(190, 101), "w": 5.5, "d": 5.5, "floors": 1, "style": 0, "timber": false, "wall": Color("c8c0b0"), "roof": Color("6a7fa8")},
	{"id": "h_larkspur", "role": "house", "pos": Vector2(203.5, 116), "face": Vector2(190, 116), "w": 6.5, "d": 6.0, "floors": 1, "style": 1, "timber": false, "wall": Color("f1dfb8"), "roof": Color("c07a3a")},
	{"id": "h_cobble", "role": "house", "pos": Vector2(157, 133), "face": Vector2(157, 146), "w": 7.0, "d": 6.0, "floors": 2, "style": 0, "timber": true, "wall": Color("e8d0b0"), "roof": Color("5f8a4f")},
	{"id": "h_tanner", "role": "house", "pos": Vector2(158, 159), "face": Vector2(158, 146), "w": 6.0, "d": 5.5, "floors": 1, "style": 0, "timber": false, "wall": Color("e0c8b8"), "roof": Color("b5523b")},
	{"id": "h_reed", "role": "house", "pos": Vector2(177, 181), "face": Vector2(190, 181), "w": 6.5, "d": 6.0, "floors": 1, "style": 0, "timber": true, "wall": Color("d8c8a8"), "roof": Color("8a5a8a")},
	{"id": "h_holloway", "role": "house", "pos": Vector2(203, 182), "face": Vector2(190, 182), "w": 6.5, "d": 6.0, "floors": 2, "style": 1, "timber": false, "wall": Color("f0e6d6"), "roof": Color("a8743f")},
	{"id": "h_pike", "role": "house", "pos": Vector2(177, 196), "face": Vector2(190, 196), "w": 5.5, "d": 5.0, "floors": 1, "style": 0, "timber": false, "wall": Color("c8d0c0"), "roof": Color("4f6a7a")},
	{"id": "h_quaile", "role": "house", "pos": Vector2(240, 134), "face": Vector2(240, 146), "w": 6.0, "d": 5.5, "floors": 1, "style": 0, "timber": true, "wall": Color("e8d0b0"), "roof": Color("c07a3a")},
	{"id": "h_fenwick", "role": "house", "pos": Vector2(241, 158.5), "face": Vector2(241, 146), "w": 5.5, "d": 5.5, "floors": 1, "style": 1, "timber": false, "wall": Color("d0b898"), "roof": Color("6a7fa8")},
	# empty lots: new neighbors move in as the town grows
	{"id": "lot_a", "role": "lot", "pos": Vector2(203, 197), "face": Vector2(190, 197), "w": 6.0, "d": 5.5, "floors": 1, "style": 0, "timber": true, "wall": Color("f0e6d6"), "roof": Color("5f8a4f")},
	{"id": "lot_b", "role": "lot", "pos": Vector2(141, 158), "face": Vector2(146, 146), "w": 6.0, "d": 5.5, "floors": 1, "style": 0, "timber": false, "wall": Color("e8d0b0"), "roof": Color("8a5a8a")},
	{"id": "lot_c", "role": "lot", "pos": Vector2(220, 114), "face": Vector2(220, 126), "w": 6.0, "d": 5.5, "floors": 2, "style": 1, "timber": false, "wall": Color("d8c8a8"), "roof": Color("b5523b")},
	{"id": "lot_d", "role": "lot", "pos": Vector2(163, 184), "face": Vector2(176, 184), "w": 5.5, "d": 5.0, "floors": 1, "style": 0, "timber": true, "wall": Color("c8d0c0"), "roof": Color("a8743f")},
]

## The street network townsfolk walk along: named points and the links between them.
const STREET_NODES := {
	"pw": Vector2(177, 146), "pe": Vector2(203, 146), "pn": Vector2(190, 133), "ps": Vector2(190, 159),
	"pnw": Vector2(180.8, 136.8), "pne": Vector2(199.2, 136.8), "psw": Vector2(180.8, 155.2), "pse": Vector2(199.2, 155.2),
	"w1": Vector2(160, 146), "w2": Vector2(150, 139), "w3": Vector2(142, 130), "farm": Vector2(136, 125),
	"e1": Vector2(214, 146), "e2": Vector2(226, 146), "e3": Vector2(240, 146), "bridge_e": Vector2(249, 146),
	"n1": Vector2(190, 122), "n2": Vector2(190, 108), "n3": Vector2(190, 98), "yard": Vector2(190, 88),
	"s1": Vector2(190, 170), "s2": Vector2(190, 188), "s3": Vector2(190, 202), "s4": Vector2(190, 222), "bridge_s": Vector2(190, 230),
	"hl1": Vector2(166, 92), "hl2": Vector2(146, 92),
	"rl1": Vector2(174, 228), "rl2": Vector2(160, 231),
	"lane_ne": Vector2(217, 124), "lane_se": Vector2(214, 173),
}
const STREET_LINKS := [
	["pw", "pnw"], ["pnw", "pn"], ["pn", "pne"], ["pne", "pe"], ["pe", "pse"], ["pse", "ps"], ["ps", "psw"], ["psw", "pw"],
	["pw", "w1"], ["w1", "w2"], ["w2", "w3"], ["w3", "farm"],
	["pe", "e1"], ["e1", "e2"], ["e2", "e3"], ["e3", "bridge_e"],
	["pn", "n1"], ["n1", "n2"], ["n2", "n3"], ["n3", "yard"], ["yard", "hl1"], ["hl1", "hl2"],
	["ps", "s1"], ["s1", "s2"], ["s2", "s3"], ["s3", "s4"], ["s4", "bridge_s"], ["s4", "rl1"], ["rl1", "rl2"],
	["e1", "lane_ne"], ["s1", "lane_se"],
]

## Places townsfolk spend their days.
const SPOTS := {
	"garden": Vector2(209, 214), "watch": Vector2(183, 93), "dock": Vector2(104, 205), "school": Vector2(178, 140),
	"riverbank": Vector2(166, 230), "meadow": Vector2(232, 186), "workshop_yard": Vector2(198, 108),
}

## Benches, trees, flower beds, crates and fences that make the town feel lived in.
const TOWN_DECOR := [
	{"k": "bench", "p": Vector2(181, 140), "r": 0.8}, {"k": "bench", "p": Vector2(199, 140), "r": -0.8},
	{"k": "bench", "p": Vector2(181, 152), "r": 2.35}, {"k": "bench", "p": Vector2(199, 152), "r": -2.35},
	{"k": "bench", "p": Vector2(170, 210), "r": PI / 2}, {"k": "bench", "p": Vector2(110, 204), "r": 0.0},
	{"k": "tree", "p": Vector2(168, 141), "v": 0}, {"k": "tree", "p": Vector2(212, 141), "v": 1},
	{"k": "tree", "p": Vector2(168, 151), "v": 2}, {"k": "tree", "p": Vector2(212, 151), "v": 0},
	{"k": "tree", "p": Vector2(183, 122), "v": 1}, {"k": "tree", "p": Vector2(197, 122), "v": 2},
	{"k": "tree", "p": Vector2(183, 172), "v": 0}, {"k": "tree", "p": Vector2(197, 172), "v": 1},
	{"k": "tree", "p": Vector2(233, 140), "v": 3}, {"k": "tree", "p": Vector2(233, 153), "v": 1},
	{"k": "tree", "p": Vector2(183, 205), "v": 3}, {"k": "tree", "p": Vector2(197, 207), "v": 0},
	{"k": "tree", "p": Vector2(165, 125), "v": 2}, {"k": "tree", "p": Vector2(215, 168), "v": 1},
	{"k": "flower_bed", "p": Vector2(181, 125), "r": 0.8}, {"k": "flower_bed", "p": Vector2(168, 135), "r": 0.8},
	{"k": "flower_bed", "p": Vector2(219, 140), "r": 0.0}, {"k": "flower_bed", "p": Vector2(170, 108), "r": PI / 2},
	{"k": "crate", "p": Vector2(214, 125), "r": 0.3}, {"k": "crate", "p": Vector2(212, 170), "r": 1.1},
	{"k": "crate", "p": Vector2(183, 219), "r": 0.6}, {"k": "crate", "p": Vector2(212, 98), "r": 0.2},
	{"k": "crate", "p": Vector2(182, 86), "r": 0.9},
	{"k": "allotment", "p": Vector2(209, 216), "r": 0.0},
	{"k": "fence_run", "a": Vector2(201, 208), "b": Vector2(218, 208)},
	{"k": "fence_run", "a": Vector2(201, 224), "b": Vector2(218, 224)},
	{"k": "fence_run", "a": Vector2(218, 208), "b": Vector2(218, 224)},
]

const TOWN_LAMPS := [Vector2(183, 132.5), Vector2(197, 132.5), Vector2(183, 159.5), Vector2(197, 159.5),
	Vector2(193, 110), Vector2(194, 94), Vector2(186, 81), Vector2(193, 190), Vector2(193, 218),
	Vector2(165, 149.5), Vector2(215, 149.5), Vector2(244, 149.5), Vector2(139, 136)]

# ------------------------------------------------------------------ helpers

## Where the farm's front porch is.
static func farmhouse_pos() -> Vector2:
	return Vector2(FARM_RECT.get_center().x, FARM_RECT.position.y + 6.5)

static func smooth_polyline(pts: Array, step: float = 2.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	if pts.size() < 2:
		for p in pts:
			out.append(p)
		return out
	for i in pts.size() - 1:
		var p0: Vector2 = pts[max(i - 1, 0)]
		var p1: Vector2 = pts[i]
		var p2: Vector2 = pts[i + 1]
		var p3: Vector2 = pts[min(i + 2, pts.size() - 1)]
		var n := int(max(1.0, ceil(p1.distance_to(p2) / step)))
		for k in n:
			var t := float(k) / n
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	out.append(pts[pts.size() - 1])
	return out
