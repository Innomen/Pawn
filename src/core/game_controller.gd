extends Node

# Game Controller - bridges GameCore with the GUI
# All game logic is in GameCore, this handles presentation

@onready var board: Node2D = $Game/Board
@onready var ui: Control = $UI/GameUI

var game: GameCore
var opponent_type: int = 0  # 0=random, 1=greedy, etc.

func _ready():
    print("GameController ready")
    
    # Create game core
    game = GameCore.new()
    game.move_executed.connect(_on_move_executed)
    game.turn_changed.connect(_on_turn_changed)
    game.gambit_activated.connect(_on_gambit_activated)
    game.gambit_completed.connect(_on_gambit_completed)
    game.error_occurred.connect(_on_error)
    
    # Start game
    start_new_game()

func start_new_game():
    print("Starting new game")
    game.new_game()
    
    # Sync board with game state
    _sync_board_to_game()
    
    # Update UI
    ui.update_display(game)

func _sync_board_to_game():
    # Clear existing pieces
    for child in board.pieces_node.get_children():
        child.queue_free()
    
    # Create pieces from game state
    for sq in game.board.keys():
        var piece_data = game.board[sq]
        var pos = _square_to_coords(sq)
        board._create_piece_at(pos, piece_data)

func make_move(from_sq: String, to_sq: String) -> bool:
    var success = game.make_move(from_sq, to_sq)
    if success:
        # Animate on board
        var from_pos = _square_to_coords(from_sq)
        var to_pos = _square_to_coords(to_sq)
        board.animate_move({"from": from_sq, "to": to_sq, "from_pos": from_pos, "to_pos": to_pos})
        
        # Update UI
        ui.update_display(game)
    return success

func activate_gambit(gambit_id: String) -> bool:
    return game.activate_gambit(gambit_id)

func _on_move_executed(move: Dictionary):
    # Handle post-move logic
    pass

func _on_turn_changed(color: String):
    ui.update_turn(color)
    
    # If opponent's turn, request move
    if color == "black":
        await get_tree().create_timer(0.5).timeout
        _make_opponent_move()

func _on_gambit_activated(gambit: Gambit):
    ui.show_gambit_activated(gambit)

func _on_gambit_completed(gambit: Gambit, success: bool):
    ui.show_gambit_completed(gambit, success)

func _on_error(msg: String):
    print("Game error: " + msg)

func _make_opponent_move():
    # Simple random opponent for now
    var moves = game.get_all_legal_moves("black")
    if moves.is_empty():
        return
    
    var move = moves[randi() % moves.size()]
    make_move(move.from, move.to)

func _square_to_coords(sq: String) -> Vector2i:
    var file = sq.unicode_at(0) - 97
    var rank = 8 - int(sq[1])
    return Vector2i(file, rank)

func restart_game():
    start_new_game()
