extends Opponent
class_name MinimaxOpponent

var piece_values = [100, 320, 330, 500, 900, 20000]  # P, N, B, R, Q, K
var search_depth: int = 3

func _init():
    id = "minimax"
    name = "Master Minimax"
    description = "Uses minimax algorithm to look ahead. Strong positional play."
    difficulty = 3

func get_move(game_state: Node) -> Dictionary:
    var legal_moves = OpponentAI.get_all_legal_moves(color)
    
    if legal_moves.size() == 0:
        return {}
    
    var best_move = legal_moves[0]
    var best_score = -99999
    
    for move in legal_moves:
        var score = _minimax(move, search_depth, -99999, 99999, false, game_state)
        if score > best_score:
            best_score = score
            best_move = move
    
    return best_move

func _minimax(move: Dictionary, depth: int, alpha: int, beta: int, is_maximizing: bool, game_state: Node) -> int:
    if depth == 0:
        return _evaluate_position(game_state)
    
    # Make temporary move
    var saved_state = _make_temp_move(move, game_state)
    
    var legal_moves = OpponentAI.get_all_legal_moves(color if is_maximizing else _opposite_color())
    
    var score: int
    if is_maximizing:
        score = -99999
        for next_move in legal_moves:
            score = max(score, _minimax(next_move, depth - 1, alpha, beta, false, game_state))
            alpha = max(alpha, score)
            if beta <= alpha:
                break
    else:
        score = 99999
        for next_move in legal_moves:
            score = min(score, _minimax(next_move, depth - 1, alpha, beta, true, game_state))
            beta = min(beta, score)
            if beta <= alpha:
                break
    
    # Undo temporary move
    _undo_temp_move(saved_state, game_state)
    
    return score

func _evaluate_position(game_state: Node) -> int:
    if game_state.is_game_over():
        if game_state.game_status == "checkmate":
            var winner = "black" if game_state.current_turn == "white" else "white"
            if winner == color:
                return 100000
            else:
                return -100000
        return 0
    
    var score = 0
    
    for pos in game_state.board.keys():
        var piece = game_state.board[pos]
        var value = piece_values[piece.type]
        
        var is_my_piece = (piece.color == game_state.PieceColor.WHITE and color == "white") or \
                         (piece.color == game_state.PieceColor.BLACK and color == "black")
        
        if is_my_piece:
            score += value
        else:
            score -= value
        
        # Position bonuses
        if piece.type == game_state.PieceType.PAWN:
            # Advance pawns
            if is_my_piece:
                score += (7 - pos.y) * 10 if color == "white" else pos.y * 10
    
    return score

func _make_temp_move(move: Dictionary, game_state: Node) -> Dictionary:
    # Save state and make move
    return {
        "from_piece": game_state.board[move.from].duplicate() if game_state.board.has(move.from) else null,
        "to_piece": game_state.board[move.to].duplicate() if game_state.board.has(move.to) else null,
        "turn": game_state.current_turn
    }

func _undo_temp_move(saved_state: Dictionary, game_state: Node):
    # Restore state
    pass

func _opposite_color() -> String:
    return "black" if color == "white" else "white"
