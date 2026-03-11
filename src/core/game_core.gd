class_name GameCore
extends RefCounted

# Pure game logic - no UI dependencies
# Can be used by GUI, CLI, or tests

signal move_executed(move: Dictionary)
signal turn_changed(color: String)
signal game_ended(result: String, winner: String)
signal gambit_activated(gambit: Gambit)
signal gambit_completed(gambit: Gambit, success: bool)
signal error_occurred(message: String)

var board: Dictionary = {}
var current_turn: String = "white"
var move_history: Array = []
var game_status: String = "active"
var completed_gambits: Array = []
var failed_gambits: Array = []
var active_gambit: Gambit = null
var current_opponent = null

func _init():
    pass

func new_game():
    board.clear()
    move_history.clear()
    current_turn = "white"
    game_status = "active"
    completed_gambits.clear()
    failed_gambits.clear()
    active_gambit = null
    
    _setup_standard_position()
    turn_changed.emit(current_turn)

func _setup_standard_position():
    # Pawns
    for file in range(8):
        _add_piece(file, 6, "pawn", "white")
        _add_piece(file, 1, "pawn", "black")
    
    # Back ranks
    var pieces = ["rook", "knight", "bishop", "queen", "king", "bishop", "knight", "rook"]
    for file in range(8):
        _add_piece(file, 7, pieces[file], "white")
        _add_piece(file, 0, pieces[file], "black")

func _add_piece(file: int, rank: int, type: String, color: String):
    var sq = _coords_to_square(file, rank)
    board[sq] = {
        "type": type,
        "color": color,
        "square": sq,
        "has_moved": false
    }

func get_piece(square: String) -> Dictionary:
    if board.has(square):
        return board[square]
    return {}

func make_move(from_sq: String, to_sq: String) -> bool:
    # Validate
    if not board.has(from_sq):
        error_occurred.emit("No piece at " + from_sq)
        return false
    
    var piece = board[from_sq]
    if piece.color != current_turn:
        error_occurred.emit("Not " + piece.color + "'s turn")
        return false
    
    # Check if move is legal
    var legal = get_legal_moves(from_sq)
    if not to_sq in legal:
        error_occurred.emit("Illegal move: " + from_sq + " to " + to_sq)
        return false
    
    # Execute
    var captured = null
    if board.has(to_sq):
        captured = board[to_sq]
    
    board.erase(from_sq)
    board[to_sq] = piece
    piece.square = to_sq
    piece.has_moved = true
    
    var move_record = {
        "from": from_sq,
        "to": to_sq,
        "piece": piece.duplicate(),
        "captured": captured,
        "turn": current_turn
    }
    move_history.append(move_record)
    
    move_executed.emit(move_record)
    
    # Check for game end
    _check_game_end()
    
    if game_status == "active":
        _switch_turn()
    
    return true

func get_legal_moves(square: String) -> Array:
    if not board.has(square):
        return []
    
    var piece = board[square]
    var moves: Array = []
    
    match piece.type:
        "pawn":
            moves = _get_pawn_moves(square, piece.color)
        "knight":
            moves = _get_knight_moves(square, piece.color)
        "bishop":
            moves = _get_bishop_moves(square, piece.color)
        "rook":
            moves = _get_rook_moves(square, piece.color)
        "queen":
            moves = _get_queen_moves(square, piece.color)
        "king":
            moves = _get_king_moves(square, piece.color)
    
    return moves

func _get_pawn_moves(sq: String, color: String) -> Array:
    var moves: Array = []
    var f = _file(sq)
    var r = _rank(sq)
    var dir = -1 if color == "white" else 1
    var start_rank = 6 if color == "white" else 1
    
    # Forward
    var one_fwd = _coords_to_square(f, r + dir)
    if one_fwd != "" and not board.has(one_fwd):
        moves.append(one_fwd)
        
        # Two from start
        if r == start_rank:
            var two_fwd = _coords_to_square(f, r + 2 * dir)
            if two_fwd != "" and not board.has(two_fwd):
                moves.append(two_fwd)
    
    # Captures
    for df in [-1, 1]:
        var cap_sq = _coords_to_square(f + df, r + dir)
        if cap_sq != "" and board.has(cap_sq):
            if board[cap_sq].color != color:
                moves.append(cap_sq)
    
    return moves

func _get_knight_moves(sq: String, color: String) -> Array:
    var moves: Array = []
    var f = _file(sq)
    var r = _rank(sq)
    var offsets = [[2,1], [2,-1], [-2,1], [-2,-1], [1,2], [1,-2], [-1,2], [-1,-2]]
    
    for off in offsets:
        var target = _coords_to_square(f + off[0], r + off[1])
        if target != "":
            if not board.has(target) or board[target].color != color:
                moves.append(target)
    
    return moves

func _get_sliding_moves(sq: String, color: String, directions: Array) -> Array:
    var moves: Array = []
    var f = _file(sq)
    var r = _rank(sq)
    
    for dir in directions:
        var cf = f
        var cr = r
        while true:
            cf += dir[0]
            cr += dir[1]
            var target = _coords_to_square(cf, cr)
            if target == "":
                break
            if not board.has(target):
                moves.append(target)
            else:
                if board[target].color != color:
                    moves.append(target)
                break
    
    return moves

func _get_bishop_moves(sq: String, color: String) -> Array:
    return _get_sliding_moves(sq, color, [[1,1], [1,-1], [-1,1], [-1,-1]])

func _get_rook_moves(sq: String, color: String) -> Array:
    return _get_sliding_moves(sq, color, [[1,0], [-1,0], [0,1], [0,-1]])

func _get_queen_moves(sq: String, color: String) -> Array:
    return _get_bishop_moves(sq, color) + _get_rook_moves(sq, color)

func _get_king_moves(sq: String, color: String) -> Array:
    var moves: Array = []
    var f = _file(sq)
    var r = _rank(sq)
    
    for df in [-1, 0, 1]:
        for dr in [-1, 0, 1]:
            if df == 0 and dr == 0:
                continue
            var target = _coords_to_square(f + df, r + dr)
            if target != "":
                if not board.has(target) or board[target].color != color:
                    moves.append(target)
    
    return moves

func _switch_turn():
    current_turn = "black" if current_turn == "white" else "white"
    turn_changed.emit(current_turn)

func _check_game_end():
    # Simplified - would check for checkmate/stalemate
    pass

func activate_gambit(gambit_id: String) -> bool:
    var gambit = GambitRegistry.get_gambit(gambit_id)
    if not gambit:
        error_occurred.emit("Gambit not found: " + gambit_id)
        return false
    
    if gambit_id in completed_gambits:
        error_occurred.emit("Gambit already completed")
        return false
    
    if gambit_id in failed_gambits:
        error_occurred.emit("Gambit already failed")
        return false
    
    if gambit.for_color != current_turn:
        error_occurred.emit("Not your turn to play this gambit")
        return false
    
    active_gambit = gambit
    gambit_activated.emit(gambit)
    return true

func get_all_legal_moves(color: String) -> Array:
    var moves: Array = []
    for sq in board.keys():
        var piece = board[sq]
        if piece.color == color:
            var legal = get_legal_moves(sq)
            for to in legal:
                moves.append({"from": sq, "to": to, "piece": piece})
    return moves

func opponent_move() -> bool:
    # Make a random legal move for current player
    var moves = get_all_legal_moves(current_turn)
    if moves.is_empty():
        return false
    
    var move = moves[randi() % moves.size()]
    return make_move(move.from, move.to)

# Utility functions
func _coords_to_square(file: int, rank: int) -> String:
    if file < 0 or file > 7 or rank < 0 or rank > 7:
        return ""
    return char(97 + file) + str(8 - rank)

func _file(sq: String) -> int:
    return sq.unicode_at(0) - 97

func _rank(sq: String) -> int:
    return 8 - int(sq[1])

func render_board() -> String:
    var out = "  a b c d e f g h\n"
    for rank in range(8):
        var r = 8 - rank
        out += str(r) + " "
        for file in range(8):
            var sq = _coords_to_square(file, rank)
            if board.has(sq):
                var piece = board[sq]
                out += _piece_symbol(piece) + " "
            else:
                out += ". "
        out += str(r) + "\n"
    out += "  a b c d e f g h"
    return out

func _piece_symbol(piece: Dictionary) -> String:
    var symbols = {
        "white": {"king": "♔", "queen": "♕", "rook": "♖", "bishop": "♗", "knight": "♘", "pawn": "♙"},
        "black": {"king": "♚", "queen": "♛", "rook": "♜", "bishop": "♝", "knight": "♞", "pawn": "♟"}
    }
    return symbols[piece.color][piece.type]

func get_game_state() -> Dictionary:
    return {
        "board": board.duplicate(),
        "turn": current_turn,
        "status": game_status,
        "move_count": move_history.size(),
        "active_gambit": active_gambit.name if active_gambit else null
    }
