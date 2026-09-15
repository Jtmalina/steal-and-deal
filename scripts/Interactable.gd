extends Node3D
class_name Interactable

var prompt: String = "[E] Use"
var action: Callable = Callable()

func _ready() -> void:
	add_to_group("interactable")

func get_prompt() -> String:
	return prompt

func interact(player: Node) -> void:
	if action.is_valid():
		action.call(player)
