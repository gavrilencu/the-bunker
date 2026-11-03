class_name Interactable
extends StaticBody3D
## Anything the player can aim at and press/hold E on.
## Layer 1 = solid world, layer 4 (bit value 8) = interact-only (non-blocking).

signal used(by: Node)

const LAYER_WORLD := 1
const LAYER_INTERACT := 8

var prompt := ""
## Optional Callable -> String. Empty string hides the prompt.
var prompt_func: Callable
var hold_time := 0.0
var hold_func: Callable


func get_prompt() -> String:
	if prompt_func.is_valid():
		return prompt_func.call()
	return prompt


func get_hold_time() -> float:
	if hold_func.is_valid():
		return hold_func.call()
	return hold_time


func use(by: Node) -> void:
	used.emit(by)


## Make this body non-blocking (only the interaction ray sees it).
func set_ghost(ghost: bool) -> void:
	collision_layer = LAYER_INTERACT if ghost else (LAYER_WORLD | LAYER_INTERACT)
	collision_mask = 0
