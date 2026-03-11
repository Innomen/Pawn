extends Node

signal opponent_move_ready(move: Dictionary)

enum Difficulty { RANDOM, GREEDY, MINIMAX, EXPERT }

var current_opponent: Opponent = null
var opponent_color: String = "black"
var difficulty: Difficulty = Difficulty.RANDOM

var thinking_timer: Timer = null

func _ready():
    thinking_timer = Timer.new()
    thinking_timer.one_shot = true
    thinking_timer.timeout.connect(_on_thinking_timeout)
    add_child(thinking_timer)
    
    print("OpponentAI initialized")

func set_opponent(type: Difficulty, color: String):
    difficulty = type
    opponent_color = color
    
    match type:
        Difficulty.RANDOM:
            current_opponent = RandomOpponent.new()
        Difficulty.GREEDY:
            current_opponent = GreedyOpponent.new()
        Difficulty.MINIMAX:
            current_opponent = MinimaxOpponent.new()
        Difficulty.EXPERT:
            current_opponent = MinimaxOpponent.new()
            current_opponent.search_depth = 4
    
    current_opponent.color = color
    print("Opponent set: " + str(type) + " playing as " + color)

func request_move():
    if not current_opponent:
        push_error("No opponent set")
        return
    
    if GameState.is_game_over():
        return
    
    # Add a small delay for thinking time
    thinking_timer.start(randf_range(0.5, 1.5))

func _on_thinking_timeout():
    var move = _calculate_move()
    opponent_move_ready.emit(move)

func _calculate_move() -> Dictionary:
    if not current_opponent:
        return {}
    
    return current_opponent.get_move(GameState)

func get_all_legal_moves(color: String) -> Array[Dictionary]:
    var moves = []
    var target_color = GameState.PieceColor.WHITE if color == "white" else GameState.PieceColor.BLACK
    
    for pos in GameState.board.keys():
        var piece = GameState.board[pos]
        if piece.color == target_color:
            var legal = GameState.get_legal_moves(pos)
            for to in legal:
                moves.append({
                    "from": pos,
                    "to": to,
                    "piece": piece
                })
    
    return moves

func evaluate_position(game_state: GameState = GameState) -> int:
    if game_state.is_game_over():
        if game_state.game_status == "checkmate":
            var winner = "black" if game_state.current_turn == "white" else "white"
            if winner == opponent_color:
                return 10000  # We won
            else:
                return -10000  # We lost
        return 0  # Draw
    
    var score = 0
    var piece_values = [100, 320, 330, 500, 900, 20000]  # P, N, B, R, Q, K
    
    for pos in game_state.board.keys():
        var piece = game_state.board[pos]
        var value = piece_values[piece.type]
        
        if piece.color == GameState.PieceColor.WHITE:
            if opponent_color == "white":
                score += value
            else:
                score -= value
        else:
            if opponent_color == "black":
                score += value
            else:
                score -= value
    
    return score
