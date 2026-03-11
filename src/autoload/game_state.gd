extends Node

signal turn_changed(color: String)
signal move_made(move: Dictionary)
signal game_ended(result: String, winner: String)
signal gambit_started(gambit: Gambit)
signal gambit_ended(gambit: Gambit, success: bool, reason: String)
signal piece_captured(piece: Dictionary, color: String)
signal check_detected(color: String)
signal checkmate_detected(color: String)
signal stalemate_detected()

enum PieceType { PAWN, KNIGHT, BISHOP, ROOK, QUEEN, KING }
enum PieceColor { WHITE, BLACK }

var board: Dictionary = {}  # Vector2i -> Piece
var current_turn: String = "white"
var move_history: Array[Dictionary] = []
var game_status: String = "active"  # active, checkmate, stalemate, draw

var completed_gambits: Array[String] = []
var failed_gambits: Array[String] = []
var active_gambit: Gambit = null

var white_king_pos: Vector2i = Vector2i(4, 7)
var black_king_pos: Vector2i = Vector2i(4, 0)

func _ready():
    print("GameState initialized")

func setup_standard():
    board.clear()
    move_history.clear()
    current_turn = "white"
    game_status = "active"
    completed_gambits.clear()
    failed_gambits.clear()
    active_gambit = null
    
    # Set up standard chess position
    _setup_pawns()
    _setup_pieces()
    
    print("Standard chess position set up")

func _setup_pawns():
    for file in range(8):
        _add_piece(Vector2i(file, 6), PieceType.PAWN, PieceColor.WHITE)
        _add_piece(Vector2i(file, 1), PieceType.PAWN, PieceColor.BLACK)

func _setup_pieces():
    var back_rank = [PieceType.ROOK, PieceType.KNIGHT, PieceType.BISHOP, PieceType.QUEEN, 
                     PieceType.KING, PieceType.BISHOP, PieceType.KNIGHT, PieceType.ROOK]
    for file in range(8):
        _add_piece(Vector2i(file, 7), back_rank[file], PieceColor.WHITE)
        _add_piece(Vector2i(file, 0), back_rank[file], PieceColor.BLACK)

func _add_piece(pos: Vector2i, type: int, color: int):
    var piece = {
        "type": type,
        "color": color,
        "pos": pos,
        "has_moved": false
    }
    board[pos] = piece
    if type == PieceType.KING:
        if color == PieceColor.WHITE:
            white_king_pos = pos
        else:
            black_king_pos = pos

func get_piece(pos: Vector2i) -> Dictionary:
    if board.has(pos):
        return board[pos]
    return {}

func make_move(from: Vector2i, to: Vector2i) -> bool:
    if not board.has(from):
        return false
    
    var piece = board[from]
    var is_white = piece.color == PieceColor.WHITE
    
    # Check if it's this piece's turn
    if (current_turn == "white" and not is_white) or (current_turn == "black" and is_white):
        return false
    
    # Validate move
    if not is_valid_move(from, to):
        return false
    
    # Check for capture
    var captured = null
    if board.has(to):
        captured = board[to]
        piece_captured.emit(captured, "white" if captured.color == PieceColor.WHITE else "black")
    
    # Execute move
    board.erase(from)
    board[to] = piece
    piece.pos = to
    piece.has_moved = true
    
    # Update king position
    if piece.type == PieceType.KING:
        if is_white:
            white_king_pos = to
        else:
            black_king_pos = to
    
    # Record move
    var move_record = {
        "from": from,
        "to": to,
        "piece": piece.duplicate(),
        "captured": captured,
        "turn": current_turn
    }
    move_history.append(move_record)
    
    move_made.emit(move_record)
    
    # Check game state
    _check_game_state()
    
    return true

func is_valid_move(from: Vector2i, to: Vector2i) -> bool:
    if not board.has(from):
        return false
    
    var piece = board[from]
    var legal = get_legal_moves(from)
    
    return to in legal

func get_legal_moves(pos: Vector2i) -> Array[Vector2i]:
    if not board.has(pos):
        return []
    
    var piece = board[pos]
    var pseudo_legal = _get_pseudo_legal_moves(piece, pos)
    var legal = []
    
    for move in pseudo_legal:
        if _is_move_legal(pos, move):
            legal.append(move)
    
    return legal

func _get_pseudo_legal_moves(piece: Dictionary, pos: Vector2i) -> Array[Vector2i]:
    var moves = []
    
    match piece.type:
        PieceType.PAWN:
            moves = _get_pawn_moves(piece, pos)
        PieceType.KNIGHT:
            moves = _get_knight_moves(piece, pos)
        PieceType.BISHOP:
            moves = _get_bishop_moves(piece, pos)
        PieceType.ROOK:
            moves = _get_rook_moves(piece, pos)
        PieceType.QUEEN:
            moves = _get_queen_moves(piece, pos)
        PieceType.KING:
            moves = _get_king_moves(piece, pos)
    
    return moves

func _get_pawn_moves(piece: Dictionary, pos: Vector2i) -> Array[Vector2i]:
    var moves = []
    var direction = -1 if piece.color == PieceColor.WHITE else 1
    var start_rank = 6 if piece.color == PieceColor.WHITE else 1
    
    # Forward one square
    var one_forward = Vector2i(pos.x, pos.y + direction)
    if _is_on_board(one_forward) and not board.has(one_forward):
        moves.append(one_forward)
        
        # Forward two squares from start
        if pos.y == start_rank:
            var two_forward = Vector2i(pos.x, pos.y + 2 * direction)
            if not board.has(two_forward):
                moves.append(two_forward)
    
    # Captures
    for dx in [-1, 1]:
        var capture_pos = Vector2i(pos.x + dx, pos.y + direction)
        if _is_on_board(capture_pos) and board.has(capture_pos):
            var target = board[capture_pos]
            if target.color != piece.color:
                moves.append(capture_pos)
    
    return moves

func _get_knight_moves(piece: Dictionary, pos: Vector2i) -> Array[Vector2i]:
    var offsets = [
        Vector2i(2, 1), Vector2i(2, -1), Vector2i(-2, 1), Vector2i(-2, -1),
        Vector2i(1, 2), Vector2i(1, -2), Vector2i(-1, 2), Vector2i(-1, -2)
    ]
    return _get_moves_from_offsets(piece, pos, offsets)

func _get_bishop_moves(piece: Dictionary, pos: Vector2i) -> Array[Vector2i]:
    return _get_sliding_moves(piece, pos, [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)])

func _get_rook_moves(piece: Dictionary, pos: Vector2i) -> Array[Vector2i]:
    return _get_sliding_moves(piece, pos, [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)])

func _get_queen_moves(piece: Dictionary, pos: Vector2i) -> Array[Vector2i]:
    var bishop_moves = _get_bishop_moves(piece, pos)
    var rook_moves = _get_rook_moves(piece, pos)
    return bishop_moves + rook_moves

func _get_king_moves(piece: Dictionary, pos: Vector2i) -> Array[Vector2i]:
    var offsets = [
        Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
        Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)
    ]
    return _get_moves_from_offsets(piece, pos, offsets)

func _get_moves_from_offsets(piece: Dictionary, pos: Vector2i, offsets: Array[Vector2i]) -> Array[Vector2i]:
    var moves = []
    for offset in offsets:
        var target = pos + offset
        if _is_on_board(target):
            if not board.has(target) or board[target].color != piece.color:
                moves.append(target)
    return moves

func _get_sliding_moves(piece: Dictionary, pos: Vector2i, directions: Array[Vector2i]) -> Array[Vector2i]:
    var moves = []
    
    for dir in directions:
        var target = pos + dir
        while _is_on_board(target):
            if not board.has(target):
                moves.append(target)
            else:
                if board[target].color != piece.color:
                    moves.append(target)
                break
            target += dir
    
    return moves

func _is_on_board(pos: Vector2i) -> bool:
    return pos.x >= 0 and pos.x < 8 and pos.y >= 0 and pos.y < 8

func _is_move_legal(from: Vector2i, to: Vector2i) -> bool:
    # Would need to check if move puts/leaves king in check
    # For now, just check basic validity
    var piece = board[from]
    
    # Make temporary move
    var saved_piece = null
    if board.has(to):
        saved_piece = board[to].duplicate()
    
    board[to] = piece
    board.erase(from)
    
    var king_in_check = _is_king_in_check(piece.color)
    
    # Undo move
    board[from] = piece
    board.erase(to)
    if saved_piece:
        board[to] = saved_piece
    
    return not king_in_check

func _is_king_in_check(color: int) -> bool:
    var king_pos = white_king_pos if color == PieceColor.WHITE else black_king_pos
    
    # Check all opponent pieces to see if any can attack the king
    for pos in board.keys():
        var piece = board[pos]
        if piece.color != color:
            var attacks = _get_pseudo_legal_moves(piece, pos)
            if king_pos in attacks:
                return true
    
    return false

func _check_game_state():
    var current_color = PieceColor.WHITE if current_turn == "white" else PieceColor.BLACK
    
    if _is_king_in_check(current_color):
        check_detected.emit(current_turn)
        
        if _is_checkmate(current_color):
            game_status = "checkmate"
            var winner = "black" if current_turn == "white" else "white"
            game_ended.emit("checkmate", winner)
            checkmate_detected.emit(current_turn)
    elif _is_stalemate(current_color):
        game_status = "stalemate"
        game_ended.emit("stalemate", "draw")
        stalemate_detected.emit()

func _is_checkmate(color: int) -> bool:
    if not _is_king_in_check(color):
        return false
    
    return not _has_any_legal_moves(color)

func _is_stalemate(color: int) -> bool:
    if _is_king_in_check(color):
        return false
    
    return not _has_any_legal_moves(color)

func _has_any_legal_moves(color: int) -> bool:
    for pos in board.keys():
        var piece = board[pos]
        if piece.color == color:
            var moves = get_legal_moves(pos)
            if moves.size() > 0:
                return true
    return false

func switch_turn():
    current_turn = "black" if current_turn == "white" else "white"
    turn_changed.emit(current_turn)

func is_game_over() -> bool:
    return game_status in ["checkmate", "stalemate", "draw"]

func get_game_phase() -> String:
    var move_count = move_history.size()
    
    if move_count < 20:
        return "opening"
    elif move_count < 60:
        return "middlegame"
    else:
        # Check piece count for endgame
        var piece_count = board.size()
        if piece_count <= 10:
            return "endgame"
        return "middlegame"

func to_fen() -> String:
    var fen = ""
    
    for rank in range(8):
        var empty_count = 0
        for file in range(8):
            var pos = Vector2i(file, rank)
            if board.has(pos):
                if empty_count > 0:
                    fen += str(empty_count)
                    empty_count = 0
                fen += _piece_to_fen(board[pos])
            else:
                empty_count += 1
        
        if empty_count > 0:
            fen += str(empty_count)
        
        if rank < 7:
            fen += "/"
    
    # Add turn
    fen += " " + current_turn[0]
    
    # Castling (simplified - not tracked)
    fen += " KQkq"
    
    # En passant
    fen += " -"
    
    # Halfmove and fullmove clocks
    fen += " 0 " + str(int(move_history.size() / 2) + 1)
    
    return fen

func _piece_to_fen(piece: Dictionary) -> String:
    var chars = ["p", "n", "b", "r", "q", "k"]
    var char = chars[piece.type]
    if piece.color == PieceColor.WHITE:
        char = char.to_upper()
    return char

func from_fen(fen: String):
    board.clear()
    
    var parts = fen.split(" ")
    var ranks = parts[0].split("/")
    
    for rank_idx in range(8):
        var file_idx = 0
        for char in ranks[rank_idx]:
            if char.is_valid_int():
                file_idx += int(char)
            else:
                var type = _fen_to_type(char.to_lower())
                var color = PieceColor.WHITE if char == char.to_upper() else PieceColor.BLACK
                _add_piece(Vector2i(file_idx, rank_idx), type, color)
                file_idx += 1
    
    # Set turn
    if parts.size() > 1:
        current_turn = "white" if parts[1] == "w" else "black"

func _fen_to_type(char: String) -> int:
    match char:
        "p": return PieceType.PAWN
        "n": return PieceType.KNIGHT
        "b": return PieceType.BISHOP
        "r": return PieceType.ROOK
        "q": return PieceType.QUEEN
        "k": return PieceType.KING
    return PieceType.PAWN
