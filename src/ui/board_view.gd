extends Node2D

signal square_clicked(pos: Vector2i)
signal piece_clicked(piece: Dictionary)

@onready var squares_node: Node2D = $Squares
@onready var pieces_node: Node2D = $Pieces
@onready var highlights_node: Node2D = $Highlights

@export var square_size: int = 80

var square_scene = preload("res://src/ui/square.tscn")
var piece_scene = preload("res://scenes/piece.tscn")

var selected_square: Vector2i = Vector2i(-1, -1)
var legal_moves: Array = []

func _ready():
    _create_board()
    
    # Connect to GameState signals
    GameState.move_made.connect(_on_move_made)
    GameState.turn_changed.connect(_on_turn_changed)
    
    # Wait a frame for GameState to be ready, then create pieces
    await get_tree().process_frame
    _refresh_pieces()

func _create_board():
    for rank in range(8):
        for file in range(8):
            var square = ColorRect.new()
            square.size = Vector2(square_size, square_size)
            square.position = Vector2(file * square_size, rank * square_size)
            
            var is_light = (file + rank) % 2 == 0
            square.color = Color(0.95, 0.95, 0.85) if is_light else Color(0.5, 0.35, 0.25)
            
            square.name = "Square_" + str(file) + "_" + str(rank)
            squares_node.add_child(square)

func _create_pieces():
    for pos in GameState.board.keys():
        _create_piece_at(pos)

func _create_piece_at(pos: Vector2i):
    var piece_data = GameState.board[pos]
    var piece = piece_scene.instantiate()
    
    piece.setup(piece_data)
    piece.position = _board_to_pixel(pos)
    piece.clicked.connect(_on_piece_clicked)
    
    piece.name = "Piece_" + str(pos.x) + "_" + str(pos.y)
    pieces_node.add_child(piece)

func _input(event):
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        var board_pos = _pixel_to_board(get_global_mouse_position())
        
        if _is_valid_board_pos(board_pos):
            _handle_click(board_pos)

func _handle_click(pos: Vector2i):
    # Check if we have a piece selected and this is a legal move
    if selected_square != Vector2i(-1, -1) and pos in legal_moves:
        # Make the move
        _execute_move(selected_square, pos)
        return
    
    # Select piece if one exists here
    if GameState.board.has(pos):
        var piece = GameState.board[pos]
        var is_white = piece.color == GameState.PieceColor.WHITE
        
        if (GameState.current_turn == "white" and is_white) or \
           (GameState.current_turn == "black" and not is_white):
            _select_square(pos)
        else:
            _clear_selection()
    else:
        _clear_selection()
    
    square_clicked.emit(pos)

func _select_square(pos: Vector2i):
    selected_square = pos
    legal_moves = GameState.get_legal_moves(pos)
    _update_highlights()

func _clear_selection():
    selected_square = Vector2i(-1, -1)
    legal_moves.clear()
    _clear_highlights()

func _update_highlights():
    _clear_highlights()
    
    # Highlight selected square
    if selected_square != Vector2i(-1, -1):
        _add_highlight(selected_square, Color(1, 1, 0, 0.5))
    
    # Highlight legal moves
    for move in legal_moves:
        var color = Color(0, 1, 0, 0.3) if not GameState.board.has(move) else Color(1, 0, 0, 0.5)
        _add_highlight(move, color)

func _add_highlight(pos: Vector2i, color: Color):
    var highlight = ColorRect.new()
    highlight.size = Vector2(square_size, square_size)
    highlight.position = _board_to_pixel(pos)
    highlight.color = color
    highlights_node.add_child(highlight)

func _clear_highlights():
    for child in highlights_node.get_children():
        child.queue_free()

func _execute_move(from: Vector2i, to: Vector2i):
    if GameState.make_move(from, to):
        animate_move({"from": from, "to": to, "piece": GameState.board[to]})
        _clear_selection()

func animate_move(move: Dictionary):
    var piece_node = pieces_node.get_node_or_null("Piece_" + str(move.from.x) + "_" + str(move.from.y))
    if piece_node:
        # Animate to new position
        var target_pos = _board_to_pixel(move.to)
        
        # Remove captured piece if any
        var captured = pieces_node.get_node_or_null("Piece_" + str(move.to.x) + "_" + str(move.to.y))
        if captured:
            captured.queue_free()
        
        # Tween animation
        var tween = create_tween()
        tween.tween_property(piece_node, "position", target_pos, 0.2)
        
        # Update piece name after animation
        await tween.finished
        piece_node.name = "Piece_" + str(move.to.x) + "_" + str(move.to.y)

func _on_move_made(move: Dictionary):
    # Refresh pieces
    _refresh_pieces()

func _on_turn_changed(color: String):
    _clear_selection()

func _refresh_pieces():
    # Clear existing pieces
    for child in pieces_node.get_children():
        child.queue_free()
    
    # Recreate from game state
    _create_pieces()

func _on_piece_clicked(piece: Dictionary):
    piece_clicked.emit(piece)

func _board_to_pixel(pos: Vector2i) -> Vector2:
    return Vector2(pos.x * square_size, pos.y * square_size)

func _pixel_to_board(pos: Vector2) -> Vector2i:
    var local_pos = to_local(pos)
    return Vector2i(int(local_pos.x / square_size), int(local_pos.y / square_size))

func _is_valid_board_pos(pos: Vector2i) -> bool:
    return pos.x >= 0 and pos.x < 8 and pos.y >= 0 and pos.y < 8
