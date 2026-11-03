class_name LootContainer
extends Interactable
## Searchable container. Bunker containers persist (State.containers); surface
## ones are generated per visit.

var key := ""
var title := "Raft"
var items := {}
var persistent := true
var searched := false


func setup(p_key: String, p_title: String, p_items: Dictionary, p_persistent := true) -> LootContainer:
	key = p_key
	title = p_title
	items = p_items
	persistent = p_persistent
	hold_time = 0.8
	if persistent and State.containers.get(key, false):
		searched = true
	prompt_func = func() -> String:
		return ("%s — Gol" % title) if searched else ("%s — Caută" % title)
	hold_func = func() -> float: return 0.0 if searched else 0.8
	used.connect(_on_used)
	return self


func _on_used(_by: Node) -> void:
	if searched:
		return
	searched = true
	if persistent:
		State.containers[key] = true
	Audio.sfx("pickup", -3.0)
	if items.is_empty():
		HUD.toast("%s: nimic util." % title, "info")
		return
	for id in items:
		State.add(id, int(items[id]), false, persistent)
	items = {}
