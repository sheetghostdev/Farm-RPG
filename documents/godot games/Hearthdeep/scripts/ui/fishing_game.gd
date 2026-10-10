class_name FishingGame
extends Control
## The reeling minigame: hold to lift your catch zone, release to let it sink,
## keep the fish inside it. Every species moves in its own way.

signal finished(success: bool, treasure: bool, perfect: bool)

const BAR_H := 380.0
const BAR_W := 46.0

var fish_id := ""
var diff := 20
var behavior := "smooth"
var zone_h := 90.0
var has_treasure := false
var steady := false
var fish_y := 0.3
var fish_target := 0.3
var fish_vel := 0.0
var retarget_t := 0.0
var mode := ""
var zone_y := 0.0
var zone_v := 0.0
var progress := 0.3
var perfect := true
var treasure_y := -1.0
var treasure_t := 0.0
var treasure_got := false
var t := 0.0
var _done := false
var _tick_t := 0.0

func setup(fid: String, d: int, beh: String, zh: float, treasure: bool, is_steady: bool) -> void:
	fish_id = fid
	diff = d
	behavior = beh
	zone_h = clamp(zh, 50.0, 220.0)
	has_treasure = treasure
	steady = is_steady
	mode = beh
	zone_y = 0.0
	fish_y = randf_range(0.2, 0.5)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(150, BAR_H + 70)
	var vs := get_viewport_rect().size
	position = Vector2(vs.x * 0.5 + 140, vs.y * 0.5 - size.y * 0.5 - 20)
	Sfx.play("reel", -4.0)

func _process(delta: float) -> void:
	if _done:
		return
	t += delta
	var holding := Input.is_action_pressed("use") or Input.is_key_pressed(KEY_SPACE)
	zone_v += (1350.0 if holding else -1150.0) * delta
	zone_v = clamp(zone_v, -480.0, 480.0)
	zone_y += zone_v * delta
	if zone_y < 0.0:
		zone_y = 0.0
		zone_v = -zone_v * 0.3
	elif zone_y > BAR_H - zone_h:
		zone_y = BAR_H - zone_h
		zone_v = -zone_v * 0.3
	_move_fish(delta)
	var fish_px := fish_y * (BAR_H - 20.0) + 10.0
	var in_zone := fish_px >= zone_y and fish_px <= zone_y + zone_h
	if in_zone:
		progress += 0.3 * delta
		_tick_t -= delta
		if _tick_t <= 0.0:
			_tick_t = 0.18
			Sfx.play("reel", -16.0)
	else:
		progress -= (0.15 if steady else 0.22) * delta
		perfect = false
	if has_treasure and not treasure_got:
		if treasure_y < 0.0 and t > 1.2:
			treasure_y = randf_range(30.0, BAR_H - 30.0)
		if treasure_y >= 0.0 and treasure_y >= zone_y and treasure_y <= zone_y + zone_h:
			treasure_t += delta
			if treasure_t >= 1.3:
				treasure_got = true
				Sfx.play("chest_open", -4.0)
	if progress >= 1.0:
		_end(true)
	elif progress <= 0.0:
		_end(false)
	queue_redraw()

func _move_fish(delta: float) -> void:
	var speed := 0.4 + diff / 100.0 * 1.7
	retarget_t -= delta
	if retarget_t <= 0.0:
		var m := behavior
		if behavior == "mixed":
			m = ["smooth", "dart", "sinker", "floater"][randi() % 4]
		mode = m
		match m:
			"smooth":
				fish_target = clamp(fish_y + randf_range(-0.35, 0.35), 0.0, 1.0)
				retarget_t = randf_range(1.0, 2.2) / max(0.6, speed)
			"dart":
				fish_target = randf()
				retarget_t = randf_range(0.35, 1.1) / max(0.6, speed * 0.8)
			"sinker":
				fish_target = clamp(randf() * 0.55, 0.0, 1.0)
				retarget_t = randf_range(0.7, 1.6)
			"floater":
				fish_target = clamp(0.45 + randf() * 0.55, 0.0, 1.0)
				retarget_t = randf_range(0.7, 1.6)
	var accel := 2.5 if mode != "dart" else 6.0
	fish_vel = lerp(fish_vel, (fish_target - fish_y) * speed * accel, 1.0 - exp(-delta * 5.0))
	fish_y = clamp(fish_y + fish_vel * delta, 0.0, 1.0)

func _end(success: bool) -> void:
	_done = true
	finished.emit(success, treasure_got and success, perfect)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	tw.tween_callback(queue_free)

func _draw() -> void:
	var font := get_theme_default_font()
	var panel := Rect2(Vector2.ZERO, size)
	draw_style_box(UITheme.box(Color(0.12, 0.09, 0.08, 0.92), UITheme.BORDER, 12, 2, 0), panel)
	var bar := Rect2(18, 18, BAR_W, BAR_H)
	draw_rect(bar, Color(0.16, 0.32, 0.42, 0.95))
	for i in 6:
		var y := bar.position.y + bar.size.y * (i + 0.5) / 6.0
		draw_line(Vector2(bar.position.x + 4, y), Vector2(bar.end.x - 4, y), Color(1, 1, 1, 0.06), 1.0)
	# catch zone
	var zr := Rect2(bar.position.x + 2, bar.end.y - zone_y - zone_h, BAR_W - 4, zone_h)
	draw_rect(zr, Color(0.55, 0.95, 0.5, 0.45))
	draw_rect(zr, Color(0.7, 1.0, 0.6, 0.9), false, 2.0)
	# treasure
	if has_treasure and treasure_y >= 0.0 and not treasure_got:
		var tr := Rect2(bar.position.x + 8, bar.end.y - treasure_y - 15, 30, 30)
		IconPainter.draw_shape(self, "chest", tr, Color("c8963e"), Color("f2c94c"))
		draw_rect(Rect2(bar.end.x + 4, bar.end.y - treasure_y - 15, 6, 30 * clamp(treasure_t / 1.3, 0.0, 1.0)), Color("f2c94c"))
	# fish
	var fy := bar.end.y - (fish_y * (BAR_H - 20.0) + 10.0)
	var fr := Rect2(bar.position.x + 3, fy - 20, 40, 40)
	if Items.has(fish_id):
		var ic: Array = Items.def(fish_id)["icon"]
		var c: Color = ic[1] if Game.is_seen(fish_id) else Color(0.15, 0.15, 0.2)
		IconPainter.draw_shape(self, "fish", fr, c, ic[2] if ic.size() > 2 else c)
	# progress
	var pb := Rect2(bar.end.x + 22, bar.position.y, 16, BAR_H)
	draw_rect(pb, Color(0.08, 0.06, 0.05, 0.9))
	var ph = BAR_H * clamp(progress, 0.0, 1.0)
	draw_rect(Rect2(pb.position.x + 2, pb.end.y - ph, 12, ph), Color(1.0 - progress, 0.4 + 0.5 * progress, 0.3))
	draw_string(font, Vector2(14, size.y - 18), "Hold to reel", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UITheme.TEXT_DIM)
