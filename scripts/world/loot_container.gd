class_name LootContainer
extends Interactable
## Searchable container. Bunker containers persist (State.containers). Town furniture
## on the surface persists too, but refills after `respawn_days` (scavengers, wind...).

var key := ""
var title := "Raft"
var items := {}
var persistent := true
var searched := false
## 0 = stays empty forever once searched; > 0 = days until it can hold something again
var respawn_days := 0
## Moving parts (door leaves, drawers, lids): [{node, rot: Vector3} | {node, pos: Vector3}]
var openers: Array = []
var _open := 0.0


## Searched containers stay open: set the parts without animating.
func set_open_instant() -> void:
	_set_open(1.0)


func _set_open(k: float) -> void:
	_open = k
	for o in openers:
		var n: Node3D = o.node
		if not is_instance_valid(n):
			continue
		if o.has("rot"):
			n.rotation = (o.rot as Vector3) * k
		if o.has("pos"):
			n.position = (o.get("base", n.position) as Vector3) + (o.pos as Vector3) * k


## The door swings / the drawer slides out as the search starts.
func open_anim() -> void:
	if openers.is_empty() or _open > 0.5:
		return
	for o in openers:
		if o.has("pos") and not o.has("base"):
			o["base"] = (o.node as Node3D).position
	var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_method(_set_open, 0.0, 1.0, 0.45)


func setup(p_key: String, p_title: String, p_items: Dictionary, p_persistent := true) -> LootContainer:
	key = p_key
	title = p_title
	items = p_items
	persistent = p_persistent
	hold_time = 0.8
	if persistent and State.containers.has(key):
		var v = State.containers[key]
		if typeof(v) == TYPE_BOOL:
			searched = v
		else:
			searched = respawn_days <= 0 or State.day - int(v) < respawn_days
	prompt_func = func() -> String:
		return ("%s — Gol" % title) if searched else ("%s — Caută" % title)
	hold_func = func() -> float: return 0.0 if searched else 0.8
	used.connect(_on_used)
	return self


func _on_used(_by: Node) -> void:
	if searched:
		return
	searched = true
	open_anim()
	if persistent:
		State.containers[key] = State.day if respawn_days > 0 else true
	Audio.sfx("pickup", -3.0)
	if items.is_empty():
		HUD.toast("%s: nimic util." % title, "info")
		return
	# bunker shelves fill the bunker stash; whatever is found outside goes into the backpack
	var to_stash := persistent and State.context == "bunker"
	for id in items:
		State.add(id, int(items[id]), false, to_stash)
	items = {}
