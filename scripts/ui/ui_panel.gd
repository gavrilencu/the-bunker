class_name UIPanel
extends Control
## Base for modal panels (inventory, crafting, map...). Subclasses override build()/refresh().

signal closed

var title := ""
var panel_width := 760.0
var frame: PanelContainer
var body: VBoxContainer
var header: HBoxContainer
var dim: ColorRect


func _init(p_title := "", p_width := 760.0) -> void:
	title = p_title
	panel_width = p_width
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = UITheme.get_theme()
	dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	frame = PanelContainer.new()
	frame.custom_minimum_size.x = panel_width
	center.add_child(frame)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	frame.add_child(v)
	header = HBoxContainer.new()
	v.add_child(header)
	var t := UITheme.heading(title, 30)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(t)
	header.add_child(UITheme.button("ÎNCHIDE  [Esc]", close))
	var line := ColorRect.new()
	line.color = UITheme.ACCENT_DIM
	line.custom_minimum_size = Vector2(0, 2)
	v.add_child(line)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	v.add_child(body)


func _ready() -> void:
	build()
	refresh()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.15)


## Override to create the static layout.
func build() -> void:
	pass


## Override to (re)populate dynamic content.
func refresh() -> void:
	pass


func close() -> void:
	HUD.close_panel(self)


func clear(c: Node) -> void:
	for ch in c.get_children():
		ch.queue_free()


func scroll_box(height := 460.0) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, height)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 6)
	sc.add_child(v)
	return v


func row_panel() -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _row_style())
	return p


static func _row_style() -> StyleBoxFlat:
	var sb := UITheme.flat(UITheme.PANEL_LIGHT, 0, Color.TRANSPARENT, 2)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb
