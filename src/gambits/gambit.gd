extends Resource
class_name Gambit

@export var id: String = ""
@export var name: String = ""
@export var category: String = ""  # "opening", "tactic", "endgame"
@export var difficulty: int = 1  # 1-5
@export var description: String = ""
@export var target_fen: String = ""
@export var moves: Array[String] = []  # SAN notation
@export var expected_responses: Array[String] = []  # Expected opponent responses
@export var for_color: String = "white"

func is_applicable(game_state: Node) -> bool:
    # Base implementation - subclasses can override
    if not game_state is Node:
        return false
    
    # Check if it's this color's turn
    if game_state.current_turn != for_color:
        return false
    
    # Check if game phase matches
    var phase = game_state.get_game_phase()
    if category == "opening" and phase != "opening":
        return false
    
    return true

func get_move_at(index: int) -> String:
    if index >= 0 and index < moves.size():
        return moves[index]
    return ""

func get_length() -> int:
    return moves.size()

func to_dict() -> Dictionary:
    return {
        "id": id,
        "name": name,
        "category": category,
        "difficulty": difficulty,
        "description": description,
        "moves": moves,
        "for_color": for_color
    }
