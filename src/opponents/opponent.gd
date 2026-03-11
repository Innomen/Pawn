extends Resource
class_name Opponent

@export var id: String = ""
@export var name: String = ""
@export var description: String = ""
@export var difficulty: int = 1

var color: String = "black"

func get_move(game_state: Node) -> Dictionary:
    # Override in subclasses
    push_warning("get_move not implemented in base Opponent class")
    return {}

func to_dict() -> Dictionary:
    return {
        "id": id,
        "name": name,
        "description": description,
        "difficulty": difficulty
    }
