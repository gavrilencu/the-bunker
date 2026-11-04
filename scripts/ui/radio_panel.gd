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
	if State.radio_heard.has("r5") and State.day >= 8:
		body.add_child(UITheme.button("Cheamă-l pe Moș Petru — schimb de marfă", _trade, 420))
	list = scroll_box(480)
	Audio.ambient("radio", "radio_static", -14.0, 0.5)
	closed.connect(func() -> void: Audio.ambient("radio", "", 0.0, 0.6))


## Moș Petru's barter: [give, n, get, m]. He leaves the goods at exit 4; they land in the stash.
const TRADES := [
	["scrap", 10, "fuel_can", 1], ["canned_meat", 4, "medkit", 1], ["ammo_9mm", 15, "antirad", 2],
	["electronics", 3, "mask_filter", 2], ["water_bottle", 6, "gunpowder", 2], ["cloth", 8, "seeds_tomato", 2],
]


func _trade() -> void:
	var opts: Array = []
	for t in TRADES:
		var give: String = t[0]
		var n: int = t[1]
		var get_id: String = t[2]
		var m: int = t[3]
		opts.append({"text": "%s ×%d  →  %s ×%d" % [ItemDB.item_name(give), n, ItemDB.item_name(get_id), m],
			"enabled": State.available(give) >= n, "cb": func() -> void:
				State.take(give, n)
				State.add(get_id, m, false, true)
				Audio.sfx("pickup", -3.0)
				HUD.toast("Moș Petru: „Plăcere să fac afaceri.” %s ×%d în depozit." % [ItemDB.item_name(get_id), m], "good")})
	close()
	HUD.choose("Moș Petru", "„Hehe, șoarecii de buncăr. Las marfa la ieșirea 4, voi lăsați plata acolo. Fac schimb cinstit... aproape cinstit.”", opts)


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
		v.add_child(UITheme.label("%s  ·  %s" % [("ZIUA %d" % msg.day) if int(msg.day) > 0 else "RĂSPUNS", msg.from.to_upper()], 15, UITheme.RADIO, "bold"))
		var t := UITheme.label(msg.text, 18, UITheme.TEXT)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.custom_minimum_size.x = 820
		v.add_child(t)
		list.add_child(p)
