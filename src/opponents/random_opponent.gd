extends Opponent
class_name RandomOpponent

func _init():
    id = "random"
    name = "Random Randy"
    description = "Makes completely random legal moves. Good for practicing openings."
    difficulty = 1

func get_move(game_state: Node) -> Dictionary:
    var legal_moves = OpponentAI.get_all_legal_moves(color)
    
    if legal_moves.size() == 0:
        return {}
    
    # Pick random move
    var random_index = randi() % legal_moves.size()
    return legal_moves[random_index]
