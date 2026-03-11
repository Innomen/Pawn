extends Opponent
class_name GreedyOpponent

var piece_values = [100, 320, 330, 500, 900, 0]  # P, N, B, R, Q, K

func _init():
    id = "greedy"
    name = "Greedy Gary"
    description = "Always captures material when possible. Look out for tactics!"
    difficulty = 2

func get_move(game_state: Node) -> Dictionary:
    var legal_moves = OpponentAI.get_all_legal_moves(color)
    
    if legal_moves.size() == 0:
        return {}
    
    var best_move = legal_moves[0]
    var best_score = -9999
    
    for move in legal_moves:
        var score = _evaluate_move(move, game_state)
        if score > best_score:
            best_score = score
            best_move = move
    
    return best_move

func _evaluate_move(move: Dictionary, game_state: Node) -> int:
    var score = 0
    
    # Check for captures
    if game_state.board.has(move.to):
        var captured = game_state.board[move.to]
        score += piece_values[captured.type]
    
    # Small bonus for center control
    var center_squares = [Vector2i(3, 3), Vector2i(3, 4), Vector2i(4, 3), Vector2i(4, 4)]
    if move.to in center_squares:
        score += 10
    
    # Bonus for developing pieces
    var piece = move.piece
    if piece.type == game_state.PieceType.KNIGHT or piece.type == game_state.PieceType.BISHOP:
        if not piece.has_moved:
            score += 20
    
    # Random factor
    score += randi() % 10
    
    return score
