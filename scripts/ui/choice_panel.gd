class_name ChoicePanel
extends UIPanel
## Generic menu: a short description and a list of action buttons.

var info := ""
var options: Array = []


func _init(p_title: String, p_info: String, p_options: Array) -> void:
	super(p_title, 640.0)
	info = p_info
	options = p_options


func build() -> void:
	if info != "":
		var l := UITheme.label(info, 19, UITheme.TEXT_DIM)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 600
		body.add_child(l)
		body.add_child(UITheme.spacer(4))
	for o in options:
		var cb: Callable = o.cb
		var b := UITheme.button(o.text, func() -> void:
			close()
			cb.call())
		b.disabled = not o.get("enabled", true)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		body.add_child(b)
		if o.has("desc"):
			var d := UITheme.label("    " + o.desc, 16, UITheme.TEXT_DIM)
			d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			d.custom_minimum_size.x = 600
			body.add_child(d)
