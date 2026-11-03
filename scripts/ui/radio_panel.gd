class_name RadioPanel
extends UIPanel

var list: VBoxContainer


func _init() -> void:
	super("Stația radio R-105", 880.0)


func build() -> void:
	var pending := State.pending_radio()
	if pending.is_empty():
		body.add_child(UITheme.label("Doar paraziți pe toate frecvențele... Încearcă mâine.", 18, UITheme.TEXT_DIM))
	else:
		for msg in pending:
			State.mark_radio_heard(msg)
		var last: Dictionary = pending.back()
		HUD.subtitle(last.from, last.text, 12.0)
	list = scroll_box(480)
	Audio.ambient("radio", "radio_static", -14.0, 0.5)
	closed.connect(func() -> void: Audio.ambient("radio", "", 0.0, 0.6))


func refresh() -> void:
	clear(list)
	var heard: Array = []
	for msg in ItemDB.RADIO:
		if State.radio_heard.has(msg.id):
			heard.append(msg)
	heard.reverse()
	for msg in heard:
		var p := row_panel()
		var v := VBoxContainer.new()
		p.add_child(v)
		v.add_child(UITheme.label("ZIUA %d  ·  %s" % [msg.day, msg.from.to_upper()], 15, UITheme.RADIO, "bold"))
		var t := UITheme.label(msg.text, 18, UITheme.TEXT)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.custom_minimum_size.x = 820
		v.add_child(t)
		list.add_child(p)
