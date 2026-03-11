extends Node

signal gambit_activated(gambit: Gambit)
signal gambit_move_ready(move: Dictionary)
signal gambit_completed(gambit: Gambit)
signal gambit_interrupted(gambit: Gambit, reason: String)
signal move_executed()
signal auto_execution_stopped()

var active_gambit: Gambit = null
var move_index: int = 0
var is_auto_executing: bool = false
var auto_execute_timer: Timer = null
var expected_opponent_move: String = ""

func _ready():
    auto_execute_timer = Timer.new()
    auto_execute_timer.one_shot = true
    auto_execute_timer.timeout.connect(_on_auto_execute_timeout)
    add_child(auto_execute_timer)
    
    GameState.move_made.connect(_on_move_made)
    DebugLogger.log_info("GambitEngine initialized")

func activate_gambit(gambit_id: String) -> bool:
    DebugLogger.log_debug("Attempting to activate gambit: " + gambit_id)
    
    if GameState.is_game_over():
        DebugLogger.log_warning("Cannot activate gambit - game over")
        return false
    
    var gambit = GambitRegistry.get_gambit(gambit_id)
    if not gambit:
        DebugLogger.log_error("Gambit not found: " + gambit_id)
        return false
    
    # Check if already completed or failed
    if gambit_id in GameState.completed_gambits:
        DebugLogger.log_warning("Gambit already completed: " + gambit_id)
        return false
    
    if gambit_id in GameState.failed_gambits:
        DebugLogger.log_warning("Gambit already failed: " + gambit_id)
        return false
    
    # Check if applicable
    if not gambit.is_applicable(GameState):
        DebugLogger.log_warning("Gambit not applicable in current position: " + gambit_id)
        return false
    
    # Check if another gambit is active
    if active_gambit != null:
        DebugLogger.log_info("Interrupting active gambit for new activation")
        interrupt_gambit("New gambit activated")
    
    # Activate gambit
    active_gambit = gambit
    move_index = 0
    expected_opponent_move = ""
    GameState.active_gambit = gambit
    
    DebugLogger.log_gambit_activated(gambit_id, gambit.name)
    
    gambit_activated.emit(gambit)
    GameState.gambit_started.emit(gambit)
    
    return true

func start_auto_execution(delay_ms: float = 800.0):
    if not active_gambit:
        push_warning("No active gambit to execute")
        return
    
    is_auto_executing = true
    _execute_next_auto_move()

func stop_auto_execution():
    is_auto_executing = false
    auto_execution_stopped.emit()

func _execute_next_auto_move():
    if not is_auto_executing or not active_gambit:
        return
    
    var move_data = _get_next_move()
    if move_data.is_empty():
        stop_auto_execution()
        return
    
    # Check if it's our turn
    if GameState.current_turn != active_gambit.for_color:
        # Wait for opponent - timer will restart after their move
        return
    
    # Execute the move
    var success = GameState.make_move(move_data.from, move_data.to)
    if success:
        move_executed.emit()
        move_index += 1
        
        # Check if gambit is complete
        if move_index >= active_gambit.moves.size():
            _complete_gambit()
            return
        
        # Schedule next move
        auto_execute_timer.start(0.8)
    else:
        push_error("Failed to execute gambit move")
        interrupt_gambit("Invalid move")

func _on_auto_execute_timeout():
    _execute_next_auto_move()

func _get_next_move() -> Dictionary:
    if not active_gambit or move_index >= active_gambit.moves.size():
        return {}
    
    var san = active_gambit.moves[move_index]
    var parsed = _parse_san(san)
    
    return parsed

func _parse_san(san: String) -> Dictionary:
    # Simple SAN parsing - this is a basic implementation
    # In a full implementation, you'd need proper SAN parsing
    var result = {
        "san": san,
        "from": Vector2i(-1, -1),
        "to": Vector2i(-1, -1)
    }
    
    # Find the piece that can make this move
    var piece_type = _san_to_piece_type(san)
    var target_square = _san_to_square(san)
    
    # Search for a piece that can legally move to that square
    for pos in GameState.board.keys():
        var piece = GameState.board[pos]
        if piece.type == piece_type:
            if piece.color == (GameState.PieceColor.WHITE if active_gambit.for_color == "white" else GameState.PieceColor.BLACK):
                var legal = GameState.get_legal_moves(pos)
                if target_square in legal:
                    result.from = pos
                    result.to = target_square
                    return result
    
    return result

func _san_to_piece_type(san: String) -> int:
    var first_char = san[0]
    
    if first_char == "N":
        return GameState.PieceType.KNIGHT
    elif first_char == "B":
        return GameState.PieceType.BISHOP
    elif first_char == "R":
        return GameState.PieceType.ROOK
    elif first_char == "Q":
        return GameState.PieceType.QUEEN
    elif first_char == "K":
        return GameState.PieceType.KING
    else:
        # Pawn move or capture
        return GameState.PieceType.PAWN

func _san_to_square(san: String) -> Vector2i:
    # Extract the destination square from SAN
    # This is simplified - real SAN parsing is more complex
    var files = "abcdefgh"
    var ranks = "87654321"
    
    # Look for the last file-rank pattern in the string
    for i in range(san.length() - 1, 0, -1):
        if san[i] in files and i + 1 < san.length() and san[i + 1] in ranks:
            var file = files.find(san[i])
            var rank = ranks.find(san[i + 1])
            return Vector2i(file, rank)
    
    return Vector2i(-1, -1)

func _on_move_made(move: Dictionary):
    if not active_gambit:
        return
    
    # Check if this was an opponent move
    var is_opponent = (move.piece.color == GameState.PieceColor.WHITE and active_gambit.for_color != "white") or \
                      (move.piece.color == GameState.PieceColor.BLACK and active_gambit.for_color != "black")
    
    if is_opponent:
        # Check if they followed the expected line
        if expected_opponent_move != "":
            var move_san = _move_to_san(move)
            if move_san != expected_opponent_move:
                interrupt_gambit("Opponent deviated from expected line")
                return
        
        # Continue auto-execution if enabled
        if is_auto_executing:
            auto_execute_timer.start(0.8)
    else:
        # Our move - update expected opponent move
        if move_index < active_gambit.expected_responses.size():
            expected_opponent_move = active_gambit.expected_responses[move_index]

func _move_to_san(move: Dictionary) -> String:
    # Simplified move to SAN conversion
    var piece = move.piece
    var piece_chars = ["", "N", "B", "R", "Q", "K"]
    
    var san = ""
    if piece.type != GameState.PieceType.PAWN:
        san += piece_chars[piece.type]
    
    san += char(97 + move.to.x)  # file
    san += str(8 - move.to.y)    # rank
    
    return san

func interrupt_gambit(reason: String = ""):
    if not active_gambit:
        return
    
    DebugLogger.log_gambit_completed(active_gambit.id, false, reason)
    
    GameState.failed_gambits.append(active_gambit.id)
    
    gambit_interrupted.emit(active_gambit, reason)
    GameState.gambit_ended.emit(active_gambit, false, reason)
    
    _clear_active_gambit()

func _complete_gambit():
    if not active_gambit:
        return
    
    DebugLogger.log_gambit_completed(active_gambit.id, true, "completed")
    
    GameState.completed_gambits.append(active_gambit.id)
    
    gambit_completed.emit(active_gambit)
    GameState.gambit_ended.emit(active_gambit, true, "completed")
    
    _clear_active_gambit()

func _clear_active_gambit():
    active_gambit = null
    GameState.active_gambit = null
    move_index = 0
    expected_opponent_move = ""
    is_auto_executing = false

func get_gambit_progress() -> Dictionary:
    if not active_gambit:
        return {}
    
    return {
        "gambit": active_gambit,
        "current_move": move_index,
        "total_moves": active_gambit.moves.size(),
        "progress_percent": float(move_index) / active_gambit.moves.size() * 100.0
    }
