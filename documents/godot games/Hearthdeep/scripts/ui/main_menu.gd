class_name MainMenu
extends CanvasLayer
## Title screen: start or load a world (optionally open to friends), join a
## friend's world, make your character, and adjust settings.

const SEASON_LENS := [7, 14, 28]
const SEASON_LABELS := ["Short seasons (7 days)", "Standard seasons (14 days)", "Long seasons (28 days)"]
const LOSS_LABELS := ["Keep everything when you're carried home", "Drop a few things (default)", "Drop a good share of your pack"]
const WORLD_NAMES := ["Hollowmere", "Bramblecote", "Fernwick Farm", "Lanternfield", "Mossbank", "Applewhistle", "Thistledown",
	"Stillwater Acre", "Kettlebrook", "Old Hearth", "Briar Hollow", "Larkspur Lane"]

var root: Control
var backdrop: TitleBackdrop
var side: VBoxContainer
var panel: PanelContainer
var panel_box: VBoxContainer
var status_l: Label
var _join_t := -1.0
var _confirm_delete := ""
var _preview: Doll
var _preview_vp: SubViewport

func _ready() -> void:
	layer = 50
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	backdrop = TitleBackdrop.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(backdrop)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for k in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + k, 56)
	root.add_child(margin)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 40)
	margin.add_child(h)
	side = VBoxContainer.new()
	side.add_theme_constant_override("separation", 10)
	side.custom_minimum_size = Vector2(380, 0)
	h.add_child(side)
	var title := UITheme.label("Hearthdeep", 76, Color("ffe2a8"), true)
	title.add_theme_constant_override("outline_size", 14)
	title.add_theme_color_override("font_outline_color", Color(0.2, 0.1, 0.08, 0.9))
	side.add_child(title)
	side.add_child(UITheme.label("fields above, wonders below · 1–6 friends", 19, Color("f6ead2"), true))
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 26)
	side.add_child(sp)
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.box(Color(0.15, 0.1, 0.09, 0.92), UITheme.BORDER, 12, 2, 18))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.visible = false
	h.add_child(panel)
	panel_box = VBoxContainer.new()
	panel_box.add_theme_constant_override("separation", 10)
	panel.add_child(panel_box)
	_build_side()

func open() -> void:
	visible = true
	panel.visible = false
	_join_t = -1.0
	_build_side()

func show_error(t: String) -> void:
	visible = true
	_join_t = -1.0
	if status_l:
		status_l.text = t
		status_l.add_theme_color_override("font_color", UITheme.BAD)

func _status(t: String, col: Color = UITheme.TEXT_DIM) -> void:
	if status_l:
		status_l.text = t
		status_l.add_theme_color_override("font_color", col)

func _process(delta: float) -> void:
	if not visible:
		return
	if _join_t >= 0.0:
		_join_t += delta
		if Game.running:
			_join_t = -1.0
		elif _join_t > 12.0:
			_join_t = -1.0
			Net.leave()
			show_error("No answer from that address. Check it and that the host has their world open.")
	if _preview:
		_preview.rotation.y += delta * 0.6
		_preview.animate(delta, 0.0)

# ------------------------------------------------------------------ side menu

func _side_button(text: String, cb: Callable, primary: bool = false) -> Button:
	var b := UITheme.button(text, cb, 22 if primary else 19)
	b.custom_minimum_size = Vector2(320, 50 if primary else 44)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	side.add_child(b)
	return b

func _build_side() -> void:
	while side.get_child_count() > 3:
		var c := side.get_child(side.get_child_count() - 1)
		side.remove_child(c)
		c.queue_free()
	var saves := list_saves()
	if not saves.is_empty():
		var last: Dictionary = saves[0]
		_side_button("  Continue · %s" % last["name"], func(): _load(last["path"], false, Net.DEFAULT_PORT), true)
	_side_button("  New World", _show_new, saves.is_empty())
	if not saves.is_empty():
		_side_button("  Load World", _show_load)
	_side_button("  Join a Friend", _show_join)
	_side_button("  Your Character", _show_character)
	_side_button("  Settings", _show_settings)
	_side_button("  Quit", func(): get_tree().quit())
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 8)
	side.add_child(sp)
	side.add_child(UITheme.label("Playing as %s" % Game.profile.get("name", "?"), 16, Color("f6ead2"), true))
	status_l = UITheme.label("", 16, UITheme.TEXT_DIM, true)
	status_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_l.custom_minimum_size = Vector2(340, 0)
	side.add_child(status_l)

func _open_panel(title: String) -> void:
	_preview = null
	for c in panel_box.get_children():
		panel_box.remove_child(c)
		c.queue_free()
	panel.visible = true
	panel_box.add_child(UITheme.label(title, 28, UITheme.ACCENT))

func _row(label: String, ctrl: Control) -> void:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 12)
	var l := UITheme.label(label, 17)
	l.custom_minimum_size = Vector2(170, 0)
	r.add_child(l)
	ctrl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(ctrl)
	panel_box.add_child(r)

func _line(text: String, placeholder: String = "") -> LineEdit:
	var e := LineEdit.new()
	e.text = text
	e.placeholder_text = placeholder
	e.custom_minimum_size = Vector2(320, 38)
	e.add_theme_font_size_override("font_size", 17)
	return e

func _options(labels: Array, sel: int) -> OptionButton:
	var o := OptionButton.new()
	for l in labels:
		o.add_item(l)
	o.select(sel)
	o.custom_minimum_size = Vector2(320, 38)
	o.add_theme_font_size_override("font_size", 16)
	return o

## An on/off button that reads clearly with the game's theme.
static func toggle(text: String, on: bool, cb: Callable = Callable()) -> Button:
	var b := UITheme.button("", func(): pass, 16)
	b.toggle_mode = true
	b.button_pressed = on
	var upd := func(v: bool): b.text = "%s:  %s" % [text, "on" if v else "off"]
	upd.call(on)
	b.toggled.connect(func(v):
		upd.call(v)
		if cb.is_valid():
			cb.call(v))
	return b

func _host_row() -> Array:
	var host := toggle("Open to friends", false)
	var port := _line(str(Net.DEFAULT_PORT))
	port.custom_minimum_size = Vector2(120, 38)
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 12)
	r.add_child(host)
	r.add_child(UITheme.label("port", 15, UITheme.TEXT_DIM))
	r.add_child(port)
	panel_box.add_child(r)
	panel_box.add_child(UITheme.label("Friends join with your address and this port. Up to 6 can play together.", 14, UITheme.TEXT_DIM))
	return [host, port]

# ------------------------------------------------------------------ new world

func _show_new() -> void:
	_open_panel("A New World")
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var name_e := _line(WORLD_NAMES[rng.randi() % WORLD_NAMES.size()])
	_row("World name", name_e)
	var seed_e := _line("", "leave blank for a surprise")
	_row("Wilds & caves seed", seed_e)
	panel_box.add_child(UITheme.label("The valley and the town are always the same. The wilds beyond its borders and the caves below are new in every world.", 14, UITheme.TEXT_DIM))
	var season_o := _options(SEASON_LABELS, 1)
	_row("Seasons", season_o)
	var loss_o := _options(LOSS_LABELS, 1)
	_row("Carried home", loss_o)
	var hp := _host_row()
	var go := UITheme.button("Begin", func():
		var nm := name_e.text.strip_edges()
		if nm == "":
			nm = "Hearth"
		var seed_v := Game.seed_from_text(seed_e.text)
		var opts := {"season_len": SEASON_LENS[season_o.selected], "loss": loss_o.selected}
		_status("Shaping the valley...")
		await get_tree().process_frame
		await get_tree().process_frame
		var err: String = Game.main.start_new_world(nm, seed_v, opts, hp[0].button_pressed, _port(hp[1].text))
		if err != "":
			show_error(err), 22)
	go.custom_minimum_size = Vector2(220, 50)
	panel_box.add_child(go)

func _port(t: String) -> int:
	var p := int(t.strip_edges()) if t.strip_edges().is_valid_int() else Net.DEFAULT_PORT
	return clamp(p, 1024, 65535)

# ------------------------------------------------------------------ load

static func list_saves() -> Array:
	var out: Array = []
	var dir := DirAccess.open("user://worlds")
	if dir == null:
		return out
	for f in dir.get_files():
		if not f.ends_with(".hearth"):
			continue
		var path := "user://worlds/" + f
		var meta := read_meta(path)
		meta["path"] = path
		meta["mtime"] = FileAccess.get_modified_time(path)
		out.append(meta)
	out.sort_custom(func(a, b): return int(a["mtime"]) > int(b["mtime"]))
	return out

static func read_meta(path: String) -> Dictionary:
	var mf := FileAccess.open(path + ".meta", FileAccess.READ)
	if mf:
		var m = str_to_var(mf.get_as_text())
		if m is Dictionary:
			return m
	return {"name": path.get_file().get_basename().capitalize(), "date": "", "players": []}

func _show_load() -> void:
	_open_panel("Your Worlds")
	var hp := _host_row()
	panel_box.add_child(HSeparator.new())
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(640, 380)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel_box.add_child(sc)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	sc.add_child(list)
	for s in list_saves():
		var sv: Dictionary = s
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", UITheme.box(Color(0.24, 0.17, 0.14, 0.95), Color(0.45, 0.34, 0.24), 8, 1, 10))
		list.add_child(row)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		row.add_child(h)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(UITheme.label(sv.get("name", "?"), 20, UITheme.ACCENT))
		var info: Array = []
		if sv.get("date", "") != "":
			info.append(sv["date"])
		var pl: Array = sv.get("players", [])
		if not pl.is_empty():
			info.append(", ".join(PackedStringArray(pl)))
		if sv.get("saved_at", "") != "":
			info.append("saved " + String(sv["saved_at"]).replace("T", " ").substr(0, 16))
		v.add_child(UITheme.label(" · ".join(PackedStringArray(info)), 14, UITheme.TEXT_DIM))
		h.add_child(v)
		var play := UITheme.button("Play", func(): _load(sv["path"], hp[0].button_pressed, _port(hp[1].text)), 17)
		play.custom_minimum_size = Vector2(90, 40)
		h.add_child(play)
		var del := UITheme.button("Really delete?" if _confirm_delete == sv["path"] else "Delete", func():
			if _confirm_delete == sv["path"]:
				DirAccess.remove_absolute(sv["path"])
				DirAccess.remove_absolute(sv["path"] + ".meta")
				_confirm_delete = ""
				_build_side()
				if list_saves().is_empty():
					panel.visible = false
				else:
					_show_load()
			else:
				_confirm_delete = sv["path"]
				_show_load(), 15)
		del.custom_minimum_size = Vector2(120, 40)
		h.add_child(del)

func _load(path: String, host: bool, port: int) -> void:
	_status("Opening the gate...")
	await get_tree().process_frame
	await get_tree().process_frame
	var err: String = Game.main.load_world(path, host, port)
	if err != "":
		show_error(err)

# ------------------------------------------------------------------ join

func _show_join() -> void:
	_open_panel("Join a Friend")
	panel_box.add_child(UITheme.label("Ask the host for their address. On the same network it looks like 192.168.x.x.", 15, UITheme.TEXT_DIM))
	var addr := _line(str(Game.profile.get("last_addr", "127.0.0.1")))
	_row("Address", addr)
	var port := _line(str(Game.profile.get("last_port", Net.DEFAULT_PORT)))
	_row("Port", port)
	var go := UITheme.button("Knock on the door", func():
		var a := addr.text.strip_edges()
		if a == "":
			return
		Game.profile["last_addr"] = a
		Game.profile["last_port"] = _port(port.text)
		Game.save_profile()
		var err: String = Net.join(a, _port(port.text))
		if err != "":
			show_error(err)
			return
		_join_t = 0.0
		_status("Knocking..."), 20)
	go.custom_minimum_size = Vector2(240, 48)
	panel_box.add_child(go)
	panel_box.add_child(UITheme.label("You'll arrive as %s with your own pack. Progress is shared with the household." % Game.profile.get("name", "?"), 14, UITheme.TEXT_DIM))

# ------------------------------------------------------------------ character

func _show_character() -> void:
	_open_panel("Your Character")
	var look: Dictionary = Game.profile.get("look", {}).duplicate(true)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 20)
	panel_box.add_child(h)
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.custom_minimum_size = Vector2(260, 360)
	h.add_child(svc)
	_preview_vp = SubViewport.new()
	_preview_vp.own_world_3d = true
	_preview_vp.transparent_bg = true
	_preview_vp.msaa_3d = Viewport.MSAA_2X
	svc.add_child(_preview_vp)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.25, 3.6)
	cam.rotation_degrees = Vector3(-8, 0, 0)
	cam.fov = 40
	_preview_vp.add_child(cam)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 30, 0)
	sun.light_energy = 1.2
	_preview_vp.add_child(sun)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.9, 0.85, 0.8)
	env.ambient_light_energy = 0.7
	we.environment = env
	_preview_vp.add_child(we)
	_preview = Doll.new()
	_preview_vp.add_child(_preview)
	_preview.setup(look)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	h.add_child(v)
	var name_e := _line(Game.profile.get("name", "Wanderer"))
	name_e.max_length = 18
	v.add_child(UITheme.label("Name", 16, UITheme.TEXT_DIM))
	v.add_child(name_e)
	var refresh_doll := func():
		_preview.setup(look)
	_swatches(v, "Skin", Doll.SKIN_TONES, look, "skin", refresh_doll)
	_swatches(v, "Hair", Doll.HAIR_COLORS, look, "hair", refresh_doll)
	_stepper(v, "Hair style", look, "hair_style", 7, refresh_doll)
	_swatches(v, "Shirt", Doll.CLOTH_COLORS, look, "shirt", refresh_doll)
	_swatches(v, "Trousers", [Color("4a4a5a"), Color("5a4a3a"), Color("3a4a6a"), Color("6a5a4a"), Color("4a5a3a"), Color("7a6a5a"), Color("2a2a30")], look, "pants", refresh_doll)
	_stepper(v, "Hat", look, "hat", 5, refresh_doll, -1)
	var beard := toggle("Beard", look.get("beard", false), func(on):
		look["beard"] = on
		refresh_doll.call())
	beard.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(beard)
	var bh := HBoxContainer.new()
	bh.add_theme_constant_override("separation", 10)
	v.add_child(bh)
	bh.add_child(UITheme.button("Surprise me", func():
		var r := RandomNumberGenerator.new()
		r.randomize()
		var nl := Doll.random_look(r)
		for k in nl:
			look[k] = nl[k]
		_show_character_with(look, name_e.text), 16))
	bh.add_child(UITheme.button("Keep this look", func():
		var nm := name_e.text.strip_edges()
		Game.profile["name"] = nm if nm != "" else "Wanderer"
		Game.profile["look"] = look
		Game.save_profile()
		_status("Looking good, %s." % Game.profile["name"], UITheme.GOOD)
		_build_side(), 16))

func _show_character_with(look: Dictionary, nm: String) -> void:
	var old_look: Dictionary = Game.profile["look"]
	var old_name: String = Game.profile["name"]
	Game.profile["look"] = look
	Game.profile["name"] = nm
	_show_character()
	Game.profile["look"] = old_look
	Game.profile["name"] = old_name

func _swatches(parent: Control, label: String, cols: Array, look: Dictionary, key: String, cb: Callable) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	var l := UITheme.label(label, 15, UITheme.TEXT_DIM)
	l.custom_minimum_size = Vector2(90, 0)
	h.add_child(l)
	for c in cols:
		var col: Color = c
		var b := Button.new()
		b.custom_minimum_size = Vector2(28, 28)
		b.focus_mode = Control.FOCUS_NONE
		var sel := look.get(key, Color.BLACK) is Color and (look[key] as Color).is_equal_approx(col)
		b.add_theme_stylebox_override("normal", UITheme.box(col, UITheme.ACCENT if sel else Color(0, 0, 0, 0.6), 6, 3 if sel else 1, 0))
		b.add_theme_stylebox_override("hover", UITheme.box(col.lightened(0.15), UITheme.ACCENT, 6, 2, 0))
		b.add_theme_stylebox_override("pressed", UITheme.box(col, UITheme.ACCENT, 6, 3, 0))
		b.pressed.connect(func():
			look[key] = col
			cb.call()
			for sib in h.get_children():
				if sib is Button:
					var sc: Color = sib.get_theme_stylebox("normal").bg_color
					var on := sc.is_equal_approx(col)
					sib.add_theme_stylebox_override("normal", UITheme.box(sc, UITheme.ACCENT if on else Color(0, 0, 0, 0.6), 6, 3 if on else 1, 0)))
		h.add_child(b)
	parent.add_child(h)

func _stepper(parent: Control, label: String, look: Dictionary, key: String, count: int, cb: Callable, start: int = 0) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var l := UITheme.label(label, 15, UITheme.TEXT_DIM)
	l.custom_minimum_size = Vector2(90, 0)
	h.add_child(l)
	var val := UITheme.label("", 16)
	val.custom_minimum_size = Vector2(80, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var show := func():
		var x := int(look.get(key, start))
		val.text = "none" if x < 0 else "%d" % (x + 1)
	var step := func(d: int):
		var x := int(look.get(key, start)) - start
		x = posmod(x + d, count)
		look[key] = x + start
		show.call()
		cb.call()
	h.add_child(UITheme.button("◀", func(): step.call(-1), 15))
	h.add_child(val)
	h.add_child(UITheme.button("▶", func(): step.call(1), 15))
	show.call()
	parent.add_child(h)

# ------------------------------------------------------------------ settings

func _show_settings() -> void:
	_open_panel("Settings")
	for bus in ["Master", "Music", "SFX", "Ambience"]:
		var sl := HSlider.new()
		sl.min_value = 0.0
		sl.max_value = 1.0
		sl.step = 0.05
		sl.custom_minimum_size = Vector2(300, 28)
		var idx := AudioServer.get_bus_index(bus)
		sl.value = float(Game.profile.get("vol", {}).get(bus, 1.0)) if idx >= 0 else 1.0
		var b: String = bus
		sl.value_changed.connect(func(v):
			Sfx.set_bus_volume(b, v)
			if not Game.profile.has("vol"):
				Game.profile["vol"] = {}
			Game.profile["vol"][b] = v
			Game.save_profile())
		_row({"Master": "Volume", "Music": "Music", "SFX": "Sounds", "Ambience": "Ambience"}[bus], sl)
	var fs := toggle("Fullscreen", DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN, func(on):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED))
	fs.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	panel_box.add_child(fs)
	panel_box.add_child(UITheme.label("Controls", 20, UITheme.ACCENT))
	var c := UITheme.label("WASD move · Shift walk · Space dodge · Left click use / attack / cast\nE or right click interact · Tab pack · C field crafting · M map · J journal\n1-0 or wheel hotbar · G drop · T rotate placement · Q/R turn camera · +/- zoom\nEnter chat · Esc pause", 15, UITheme.TEXT)
	panel_box.add_child(c)

static func apply_saved_volumes() -> void:
	var vol: Dictionary = Game.profile.get("vol", {})
	for b in vol:
		Sfx.set_bus_volume(b, float(vol[b]))


## A painted dusk over the valley: hills, the farmhouse, the cave's glow, fireflies.
class TitleBackdrop extends Control:
	var t := 0.0
	var flies: Array = []
	var stars: Array = []
	var clouds: Array = []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var r := RandomNumberGenerator.new()
		r.seed = 7
		for i in 40:
			flies.append([r.randf(), r.randf_range(0.55, 0.95), r.randf() * TAU, r.randf_range(0.5, 1.4)])
		for i in 90:
			stars.append([r.randf(), r.randf() * 0.45, r.randf_range(0.6, 2.0), r.randf() * TAU])
		for i in 6:
			clouds.append([r.randf(), r.randf_range(0.08, 0.3), r.randf_range(120, 260), r.randf_range(4.0, 10.0)])

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _hill(base: float, amp: float, freq: float, phase: float, col: Color) -> void:
		var w := size.x
		var h := size.y
		var pts := PackedVector2Array()
		pts.append(Vector2(0, h))
		var n := 64
		for i in n + 1:
			var x := w * i / float(n)
			var y := h * base - amp * h * (0.5 + 0.5 * sin(x / w * freq + phase)) - amp * h * 0.35 * sin(x / w * freq * 2.7 + phase * 1.7)
			pts.append(Vector2(x, y))
		pts.append(Vector2(w, h))
		draw_colored_polygon(pts, col)

	func _hill_y(base: float, amp: float, freq: float, phase: float, x: float) -> float:
		var w := size.x
		var h := size.y
		return h * base - amp * h * (0.5 + 0.5 * sin(x / w * freq + phase)) - amp * h * 0.35 * sin(x / w * freq * 2.7 + phase * 1.7)

	func _draw() -> void:
		var w := size.x
		var h := size.y
		# sky
		var bands := 90
		for i in bands:
			var k := i / float(bands)
			var c := Color("1d2340").lerp(Color("6a4a78"), k).lerp(Color("f0a070"), pow(k, 2.4))
			draw_rect(Rect2(0, h * 0.75 * k, w, h * 0.75 / bands + 1), c)
		for s in stars:
			var a := 0.4 + 0.4 * sin(t * s[2] + s[3])
			draw_circle(Vector2(s[0] * w, s[1] * h), 1.2, Color(1, 0.95, 0.85, a * (1.0 - s[1] * 1.6)))
		draw_circle(Vector2(w * 0.78, h * 0.2), 34, Color(1.0, 0.95, 0.85, 0.9))
		draw_circle(Vector2(w * 0.78 + 12, h * 0.2 - 6), 30, Color("2a2a4a").lerp(Color("5a4070"), 0.5))
		for c in clouds:
			var cx := fposmod(c[0] * w + t * c[3], w + 600) - 300
			var cy: float = c[1] * h
			draw_set_transform(Vector2(cx, cy), 0.0, Vector2(3.2, 0.55))
			for j in 5:
				draw_circle(Vector2((j - 2) * c[2] * 0.09, sin(j * 1.7) * 6), c[2] * (0.16 - abs(j - 2) * 0.03), Color(0.95, 0.72, 0.78, 0.07))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# distant mountains
		_hill(0.62, 0.18, 9.0, 1.0, Color("4a3a5e"))
		_hill(0.7, 0.12, 6.0, 2.4, Color("3a3050"))
		# cave mouth glow on the far hill
		var cxp := w * 0.86
		var cyp := _hill_y(0.7, 0.12, 6.0, 2.4, cxp) + 18
		for i in 6:
			draw_circle(Vector2(cxp, cyp), 46 - i * 7, Color(1.0, 0.6, 0.25, 0.05 + 0.02 * i + 0.01 * sin(t * 2.0)))
		draw_circle(Vector2(cxp, cyp + 6), 13, Color("1a1020"))
		# mid hills with trees
		_hill(0.8, 0.08, 4.0, 0.3, Color("2c3a3e"))
		var r := RandomNumberGenerator.new()
		r.seed = 3
		for i in 46:
			var x := r.randf() * w
			var y := _hill_y(0.8, 0.08, 4.0, 0.3, x) + 6
			var th := r.randf_range(26, 54)
			draw_colored_polygon(PackedVector2Array([Vector2(x - th * 0.32, y), Vector2(x + th * 0.32, y), Vector2(x, y - th)]), Color("1f2c2e"))
		# near field with the farmhouse
		_hill(0.92, 0.05, 3.0, 4.0, Color("1c2424"))
		var fx := w * 0.62
		var fy := _hill_y(0.92, 0.05, 3.0, 4.0, fx) + 4
		draw_rect(Rect2(fx - 70, fy - 62, 140, 62), Color("15191a"))
		draw_colored_polygon(PackedVector2Array([Vector2(fx - 84, fy - 60), Vector2(fx + 84, fy - 60), Vector2(fx, fy - 118)]), Color("121516"))
		draw_rect(Rect2(fx + 34, fy - 130, 16, 40), Color("121516"))
		var glow := 0.85 + 0.15 * sin(t * 3.1) * sin(t * 1.7)
		for wx in [-44, 22]:
			draw_rect(Rect2(fx + wx - 4, fy - 46 - 4, 30, 26), Color(1.0, 0.65, 0.3, 0.18 * glow))
			draw_rect(Rect2(fx + wx, fy - 46, 22, 18), Color(1.0, 0.78, 0.42, glow))
			draw_rect(Rect2(fx + wx + 10, fy - 46, 2, 18), Color("15191a"))
		draw_rect(Rect2(fx - 8, fy - 34, 18, 34), Color(1.0, 0.7, 0.35, 0.55 * glow))
		# chimney smoke
		for i in 7:
			var k := fmod(t * 0.25 + i / 7.0, 1.0)
			draw_circle(Vector2(fx + 42 + sin(k * 6.0 + i) * 10 + k * 40, fy - 134 - k * 120), 6 + k * 16, Color(0.8, 0.75, 0.8, 0.18 * (1.0 - k)))
		# fireflies
		for f in flies:
			var px: float = fposmod(f[0] * w + sin(t * 0.3 * f[3] + f[2]) * 40 + t * 6 * f[3], w)
			var py: float = f[1] * h + sin(t * 0.8 * f[3] + f[2] * 2.0) * 14
			var a := 0.5 + 0.5 * sin(t * 2.5 * f[3] + f[2])
			draw_circle(Vector2(px, py), 6, Color(1.0, 0.9, 0.4, 0.08 * a))
			draw_circle(Vector2(px, py), 2, Color(1.0, 0.95, 0.6, 0.85 * a))
		# soft vignette on the left for the menu
		for i in 16:
			draw_rect(Rect2(0, 0, w * 0.5 * (1.0 - i / 16.0), h), Color(0.05, 0.03, 0.04, 0.035))
