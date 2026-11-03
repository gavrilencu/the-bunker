class_name UITheme
extends RefCounted
## Builds the shared UI theme (dark translucent panels, amber accent).

const ACCENT := Color(0.96, 0.66, 0.22)
const ACCENT_DIM := Color(0.62, 0.42, 0.15)
const TEXT := Color(0.92, 0.9, 0.85)
const TEXT_DIM := Color(0.62, 0.62, 0.58)
const PANEL := Color(0.045, 0.05, 0.048, 0.92)
const PANEL_LIGHT := Color(0.09, 0.1, 0.095, 0.92)
const GOOD := Color(0.55, 0.85, 0.4)
const WARN := Color(0.98, 0.78, 0.25)
const DANGER := Color(0.95, 0.3, 0.25)
const RADIO := Color(0.55, 0.8, 0.95)

static var _theme: Theme


static func get_theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = Assets.font("body")
	t.default_font_size = 20

	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.6))
	t.set_constant("shadow_offset_x", "Label", 1)
	t.set_constant("shadow_offset_y", "Label", 1)

	var panel := flat(PANEL, 1, Color(1, 1, 1, 0.08), 3)
	panel.content_margin_left = 18
	panel.content_margin_right = 18
	panel.content_margin_top = 14
	panel.content_margin_bottom = 14
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)

	var b_normal := flat(Color(0.1, 0.11, 0.1, 0.95), 1, Color(1, 1, 1, 0.1), 2)
	var b_hover := flat(Color(0.2, 0.15, 0.07, 0.98), 1, ACCENT, 2)
	var b_pressed := flat(Color(0.3, 0.2, 0.06, 1.0), 1, ACCENT, 2)
	var b_disabled := flat(Color(0.07, 0.07, 0.07, 0.8), 1, Color(1, 1, 1, 0.04), 2)
	for sb in [b_normal, b_hover, b_pressed, b_disabled]:
		sb.content_margin_left = 16
		sb.content_margin_right = 16
		sb.content_margin_top = 8
		sb.content_margin_bottom = 8
	t.set_stylebox("normal", "Button", b_normal)
	t.set_stylebox("hover", "Button", b_hover)
	t.set_stylebox("pressed", "Button", b_pressed)
	t.set_stylebox("disabled", "Button", b_disabled)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", ACCENT)
	t.set_color("font_pressed_color", "Button", ACCENT)
	t.set_color("font_disabled_color", "Button", Color(0.4, 0.4, 0.38))
	t.set_font("font", "Button", Assets.font("bold"))
	t.set_font_size("font_size", "Button", 20)

	var bar_bg := flat(Color(0, 0, 0, 0.55), 0, Color.TRANSPARENT, 1)
	var bar_fg := flat(ACCENT, 0, Color.TRANSPARENT, 1)
	t.set_stylebox("background", "ProgressBar", bar_bg)
	t.set_stylebox("fill", "ProgressBar", bar_fg)

	var slider_bg := flat(Color(0, 0, 0, 0.6), 0, Color.TRANSPARENT, 2)
	slider_bg.content_margin_top = 3
	slider_bg.content_margin_bottom = 3
	t.set_stylebox("slider", "HSlider", slider_bg)
	t.set_stylebox("grabber_area", "HSlider", flat(ACCENT_DIM, 0, Color.TRANSPARENT, 2))
	t.set_stylebox("grabber_area_highlight", "HSlider", flat(ACCENT, 0, Color.TRANSPARENT, 2))

	var sc_bg := flat(Color(0, 0, 0, 0.3), 0, Color.TRANSPARENT, 2)
	t.set_stylebox("scroll", "VScrollBar", sc_bg)
	t.set_stylebox("grabber", "VScrollBar", flat(Color(1, 1, 1, 0.18), 0, Color.TRANSPARENT, 2))
	t.set_stylebox("grabber_highlight", "VScrollBar", flat(ACCENT_DIM, 0, Color.TRANSPARENT, 2))
	t.set_stylebox("grabber_pressed", "VScrollBar", flat(ACCENT, 0, Color.TRANSPARENT, 2))

	t.set_color("font_color", "CheckBox", TEXT)
	t.set_color("font_hover_color", "CheckBox", ACCENT)
	t.set_stylebox("normal", "CheckBox", StyleBoxEmpty.new())
	t.set_stylebox("hover", "CheckBox", StyleBoxEmpty.new())
	t.set_stylebox("pressed", "CheckBox", StyleBoxEmpty.new())
	t.set_stylebox("focus", "CheckBox", StyleBoxEmpty.new())

	t.set_stylebox("normal", "OptionButton", b_normal)
	t.set_stylebox("hover", "OptionButton", b_hover)
	t.set_stylebox("pressed", "OptionButton", b_pressed)
	t.set_stylebox("focus", "OptionButton", StyleBoxEmpty.new())
	t.set_stylebox("panel", "PopupMenu", panel)
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", ACCENT)
	t.set_stylebox("hover", "PopupMenu", flat(Color(0.2, 0.15, 0.07, 1), 0, Color.TRANSPARENT, 0))

	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_font("normal_font", "RichTextLabel", Assets.font("body"))
	t.set_font("bold_font", "RichTextLabel", Assets.font("bold"))
	t.set_font_size("normal_font_size", "RichTextLabel", 20)
	t.set_font_size("bold_font_size", "RichTextLabel", 20)
	_theme = t
	return t


static func flat(bg: Color, border: int, border_color: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_border_width_all(border)
	sb.border_color = border_color
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing = true
	return sb


static func label(text: String, size := 20, color := TEXT, kind := "body") -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", Assets.font(kind))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func heading(text: String, size := 34, color := ACCENT) -> Label:
	var l := label(text.to_upper(), size, color, "heading")
	return l


static func button(text: String, cb: Callable, min_w := 0) -> Button:
	var b := Button.new()
	b.text = text
	if min_w > 0:
		b.custom_minimum_size.x = min_w
	b.pressed.connect(func() -> void:
		Audio.ui("ui_click")
		cb.call())
	b.mouse_entered.connect(func() -> void:
		if not b.disabled:
			Audio.ui("ui_hover"))
	return b


static func bar(color: Color, h := 8.0) -> ProgressBar:
	var p := ProgressBar.new()
	p.show_percentage = false
	p.custom_minimum_size = Vector2(0, h)
	p.max_value = 100
	p.add_theme_stylebox_override("fill", flat(color, 0, Color.TRANSPARENT, 1))
	return p


static func spacer(h := 8) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c
