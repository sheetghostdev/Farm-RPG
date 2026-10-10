class_name UITheme
extends RefCounted
## Warm, cozy UI styling shared by every panel.

const BG := Color(0.17, 0.12, 0.10, 0.94)
const BG_LIGHT := Color(0.27, 0.2, 0.16, 0.96)
const BORDER := Color("c8965a")
const TEXT := Color("f6ead2")
const TEXT_DIM := Color("c8b89a")
const ACCENT := Color("ffd27a")
const GOOD := Color("9ae68a")
const BAD := Color("ff9a7a")
const SLOT := Color(0.32, 0.24, 0.19, 0.95)
const SLOT_HI := Color(0.45, 0.34, 0.24, 1.0)

static var _theme: Theme

static func box(bg: Color, border: Color = BORDER, radius: int = 10, bw: int = 2, pad: int = 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad * 0.7
	s.content_margin_bottom = pad * 0.7
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 4
	return s

static func get_theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font_size = 18
	t.set_stylebox("panel", "Panel", box(BG))
	t.set_stylebox("panel", "PanelContainer", box(BG))
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.6))
	t.set_constant("outline_size", "Label", 0)
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		var c := BG_LIGHT
		if st == "hover":
			c = Color(0.38, 0.28, 0.2, 1.0)
		elif st == "pressed":
			c = Color(0.5, 0.36, 0.22, 1.0)
		elif st == "disabled":
			c = Color(0.2, 0.16, 0.14, 0.8)
		var b := box(c, BORDER if st != "disabled" else Color(0.4, 0.32, 0.25), 8, 2, 8)
		if st == "focus":
			b.bg_color = Color(0, 0, 0, 0)
			b.border_color = ACCENT
		t.set_stylebox(st, "Button", b)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", ACCENT)
	t.set_color("font_pressed_color", "Button", ACCENT)
	t.set_color("font_disabled_color", "Button", Color(0.6, 0.55, 0.5))
	var le := box(Color(0.1, 0.08, 0.07, 0.95), BORDER, 6, 2, 8)
	t.set_stylebox("normal", "LineEdit", le)
	t.set_stylebox("focus", "LineEdit", box(Color(0.12, 0.09, 0.08, 0.95), ACCENT, 6, 2, 8))
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_stylebox("panel", "TooltipPanel", box(Color(0.12, 0.09, 0.08, 0.97), BORDER, 6, 1, 8))
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_stylebox("background", "ProgressBar", box(Color(0.1, 0.08, 0.07, 0.9), Color(0, 0, 0, 0.6), 6, 1, 0))
	t.set_stylebox("fill", "ProgressBar", box(Color("d8584a"), Color(0, 0, 0, 0), 6, 0, 0))
	t.set_stylebox("panel", "TabContainer", box(BG))
	t.set_stylebox("tab_selected", "TabContainer", box(BG_LIGHT, ACCENT, 6, 2, 8))
	t.set_stylebox("tab_unselected", "TabContainer", box(Color(0.14, 0.1, 0.08, 0.9), BORDER, 6, 1, 8))
	t.set_stylebox("tab_hovered", "TabContainer", box(Color(0.3, 0.22, 0.17, 0.95), BORDER, 6, 1, 8))
	t.set_color("font_selected_color", "TabContainer", ACCENT)
	t.set_color("font_unselected_color", "TabContainer", TEXT_DIM)
	t.set_color("font_hovered_color", "TabContainer", TEXT)
	t.set_stylebox("normal", "RichTextLabel", StyleBoxEmpty.new())
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_stylebox("panel", "ItemList", box(Color(0.1, 0.08, 0.07, 0.9), BORDER, 6, 1, 6))
	t.set_color("font_color", "ItemList", TEXT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.3, 0.22, 0.17, 0.8)
	sb.set_corner_radius_all(4)
	t.set_stylebox("scroll", "VScrollBar", sb)
	var gr := StyleBoxFlat.new()
	gr.bg_color = BORDER
	gr.set_corner_radius_all(4)
	t.set_stylebox("grabber", "VScrollBar", gr)
	t.set_stylebox("grabber_highlight", "VScrollBar", gr)
	t.set_stylebox("grabber_pressed", "VScrollBar", gr)
	_theme = t
	return t

static func label(text: String, size: int = 18, col: Color = TEXT, outline: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if outline:
		l.add_theme_constant_override("outline_size", 6)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	return l

static func button(text: String, cb: Callable, size: int = 18) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.pressed.connect(cb)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func(): Sfx.play("click", -8.0))
	return b

static func rich(bb: String, size: int = 17) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.text = bb
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_font_size_override("bold_font_size", size)
	return r

static func hex(c: Color) -> String:
	return c.to_html(false)
