# Pawn Chess - Godot Refactor Specification

## Overview
Complete rewrite of Pawn chess application from React/TypeScript to Godot 4.x

## Why Godot?
- Better game loop architecture
- Built-in UI system
- Native performance
- Easier state management
- Built-in testing (GUT)

## Architecture

### Scene Structure
```
Main (Node)
├── UI (CanvasLayer)
│   ├── GambitMenu (Control)
│   ├── OpponentPanel (Control)
│   ├── GameInfo (Control)
│   └── TestPanel (Control)
├── Game (Node2D)
│   ├── Board (Node2D)
│   │   └── Squares (64 Sprite2D nodes)
│   ├── Pieces (Node2D)
│   │   └── Pieces (16 Sprite2D nodes)
│   └── Highlights (Node2D)
│       └── MoveIndicators
└── Autoload
    ├── GameState (Singleton)
    ├── GambitEngine (Singleton)
    └── OpponentAI (Singleton)
```

### Core Systems

#### 1. GameState (Autoload Singleton)
Manages all game state:
```gdscript
extends Node

signal turn_changed(color: String)
signal move_made(move: Dictionary)
signal game_ended(result: String)
signal gambit_started(gambit: Gambit)
signal gambit_ended(gambit: Gambit, success: bool)

var board: Array[Piece] = []
var current_turn: String = "white"
var move_history: Array[Dictionary] = []
var game_status: String = "active"

var completed_gambits: Array[String] = []
var failed_gambits: Array[String] = []
var active_gambit: Gambit = null

func make_move(from: Vector2i, to: Vector2i) -> bool
func get_legal_moves(pos: Vector2i) -> Array[Vector2i]
func is_check() -> bool
func is_checkmate() -> bool
func is_stalemate() -> bool
func to_fen() -> String
func from_fen(fen: String)
```

#### 2. Board (Node2D)
Visual representation:
```gdscript
extends Node2D

@export var square_size: int = 80
@export var board_offset: Vector2 = Vector2(50, 50)

var squares: Array[Square] = []
var pieces: Dictionary = {}  # pos -> Piece node

func _ready()
func _draw()  # Draw board
func highlight_square(pos: Vector2i, type: String)
func clear_highlights()
func animate_piece_move(piece: Piece, from: Vector2i, to: Vector2i)
func get_square_at_mouse() -> Vector2i
```

#### 3. Piece (Sprite2D)
Individual piece:
```gdscript
extends Sprite2D

enum Type { PAWN, KNIGHT, BISHOP, ROOK, QUEEN, KING }
enum Color { WHITE, BLACK }

@export var piece_type: Type
@export var piece_color: Color
@export var board_pos: Vector2i

var has_moved: bool = false

func _ready()
func move_to(pos: Vector2i)
func get_legal_moves() -> Array[Vector2i]
func is_enemy(other: Piece) -> bool
func get_value() -> int
```

#### 4. GambitEngine (Autoload)
Gambit macro system:
```gdscript
extends Node

signal gambit_move_ready(move: Dictionary)
signal gambit_completed()
signal gambit_interrupted(reason: String)

var active_gambit: Gambit = null
var move_index: int = 0
var is_auto_executing: bool = false

func activate_gambit(gambit_id: String) -> bool
func get_next_move() -> Dictionary
func execute_next_move() -> bool
func interrupt_gambit()
func start_auto_execution(delay_ms: float)
func stop_auto_execution()
```

#### 5. Gambit (Resource)
Data structure:
```gdscript
extends Resource
class_name Gambit

@export var id: String
@export var name: String
@export var category: String  # "opening", "tactic", "endgame"
@export var difficulty: int  # 1-5
@export var description: String
@export var target_fen: String
@export var moves: Array[String]  # SAN notation
@export var conditions: Array[Dictionary]
@export var for_color: String  # "white" or "black"

func is_applicable(game_state: GameState) -> bool
func get_move_at(index: int) -> String
```

#### 6. OpponentAI (Autoload)
AI opponents:
```gdscript
extends Node

enum Difficulty { RANDOM, GREEDY, MINIMAX, EXPERT }

var current_opponent: Opponent = null
var opponent_color: String = "black"

func set_opponent(type: Difficulty, color: String)
func get_move() -> Dictionary
func on_opponent_move(move: Dictionary)
```

#### 7. Opponent (Resource)
```gdscript
extends Resource
class_name Opponent

@export var id: String
@export var name: String
@export var description: String
@export var difficulty: int

func get_move(legal_moves: Array) -> Dictionary:
    # Override in subclasses
    pass
```

### UI Scenes

#### GambitMenu (Control)
```gdscript
extends Control

@onready var opening_list: VBoxContainer = $Openings
@onready var tactic_list: VBoxContainer = $Tactics
@onready var active_panel: Panel = $ActiveGambit

func _ready()
    GameState.turn_changed.connect(_on_turn_changed)
    GameState.gambit_started.connect(_on_gambit_started)
    GameState.gambit_ended.connect(_on_gambit_ended)

func _on_turn_changed(color: String)
    _update_available_gambits()

func _update_available_gambits()
    # Clear lists
    # Query GameState for available gambits
    # Populate opening_list and tactic_list
    # Hide completed/failed gambits

func _on_gambit_clicked(gambit_id: String)
    GambitEngine.activate_gambit(gambit_id)

func _on_stop_gambit_clicked()
    GambitEngine.interrupt_gambit()
```

#### BoardView (Node2D)
```gdscript
extends Node2D

signal square_clicked(pos: Vector2i)
signal piece_clicked(piece: Piece)

@onready var squares: Node2D = $Squares
@onready var pieces: Node2D = $Pieces
@onready var highlights: Node2D = $Highlights

func _ready()
    _create_board()
    _create_pieces()

func _create_board()
    # Create 64 squares
    for rank in range(8):
        for file in range(8):
            var square = Square.new()
            square.position = _board_to_pixel(Vector2i(file, rank))
            square.color = Color.LIGHT_SQUARE if (file + rank) % 2 == 0 else Color.DARK_SQUARE
            squares.add_child(square)

func _create_pieces()
    # Create pieces from GameState
    for piece_data in GameState.board:
        var piece = PieceScene.instantiate()
        piece.setup(piece_data)
        pieces.add_child(piece)

func _input(event)
    if event is InputEventMouseButton and event.pressed:
        var board_pos = _pixel_to_board(event.position)
        square_clicked.emit(board_pos)

func highlight_legal_moves(pos: Vector2i)
    var moves = GameState.get_legal_moves(pos)
    for move in moves:
        highlights.add_child(MoveIndicator.new(move))
```

### Game Loop

```gdscript
# Main game flow

func _ready():
    GameState.setup_standard()
    _start_game()

func _start_game():
    GameState.current_turn = "white"
    _start_turn()

func _start_turn():
    # Calculate available gambits
    _update_gambit_menu()
    
    if GameState.current_turn == opponent_color:
        _opponent_turn()
    else:
        _player_turn()

func _player_turn():
    # Wait for player input
    # On click: check if valid move
    # Execute move
    # Check for gambit execution
    pass

func _opponent_turn():
    var move = OpponentAI.get_move()
    _execute_move(move)

func _execute_move(move: Dictionary):
    GameState.make_move(move.from, move.to)
    BoardView.animate_piece_move(move.piece, move.from, move.to)
    
    # Check game end
    if GameState.is_checkmate():
        _end_game("checkmate")
        return
    
    # Cleanup phase
    _run_cleanup()
    
    # Switch turn
    GameState.current_turn = "black" if GameState.current_turn == "white" else "white"
    GameState.turn_changed.emit(GameState.current_turn)

func _run_cleanup():
    # Remove completed/failed gambits from available
    # Update UI
    # Verify state integrity
    pass
```

### Turn Phase System (MTG-Style)

```gdscript
enum TurnPhase {
    TURN_START,      # Calculate available actions
    MAIN_PHASE,      # Player acts
    MOVE_RESOLUTION, # Execute move
    GAMBIT_CHECK,    # Check if gambit continues
    END_PHASE,       # Cleanup
    TURN_END         # Switch player
}

var current_phase: TurnPhase = TurnPhase.TURN_START

func _process_turn_phase():
    match current_phase:
        TurnPhase.TURN_START:
            _calculate_available_actions()
            current_phase = TurnPhase.MAIN_PHASE
            
        TurnPhase.MAIN_PHASE:
            # Wait for player input
            pass
            
        TurnPhase.MOVE_RESOLUTION:
            _execute_move(selected_move)
            current_phase = TurnPhase.GAMBIT_CHECK
            
        TurnPhase.GAMBIT_CHECK:
            if GameState.active_gambit:
                _check_gambit_status()
            current_phase = TurnPhase.END_PHASE
            
        TurnPhase.END_PHASE:
            _run_cleanup()
            current_phase = TurnPhase.TURN_END
            
        TurnPhase.TURN_END:
            _switch_player()
            current_phase = TurnPhase.TURN_START
```

### Testing (GUT - Godot Unit Testing)

```gdscript
# test/test_game_state.gd
extends GutTest

func test_pawn_move():
    var game = GameState.new()
    game.setup_standard()
    
    # Move e2 pawn to e4
    assert_true(game.make_move(Vector2i(4, 6), Vector2i(4, 4)))
    assert_eq(game.board[4][4].type, Piece.Type.PAWN)

func test_knight_move():
    var game = GameState.new()
    game.setup_standard()
    
    # Knight b1 to c3
    assert_true(game.make_move(Vector2i(1, 7), Vector2i(2, 5)))

func test_gambit_cleanup():
    var game = GameState.new()
    game.completed_gambits = ["italian-game", "italian-game"]  # Duplicate
    
    _run_cleanup()
    
    assert_eq(game.completed_gambits.size(), 1)
    assert_false(game.completed_gambits.has("italian-game"))
```

## File Structure

```
Pawn/
├── project.godot
├── README.md
├── .gitignore
├── assets/
│   ├── pieces/
│   │   ├── white_king.svg
│   │   ├── white_queen.svg
│   │   └── ...
│   ├── sounds/
│   └── fonts/
├── src/
│   ├── autoload/
│   │   ├── game_state.gd
│   │   ├── gambit_engine.gd
│   │   └── opponent_ai.gd
│   ├── core/
│   │   ├── board.gd
│   │   ├── piece.gd
│   │   ├── move_validator.gd
│   │   └── fen_parser.gd
│   ├── gambits/
│   │   ├── gambit.gd
│   │   ├── gambit_registry.gd
│   │   └── definitions/
│   │       ├── openings.gd
│   │       └── tactics.gd
│   ├── opponents/
│   │   ├── opponent.gd
│   │   ├── random_opponent.gd
│   │   ├── greedy_opponent.gd
│   │   └── minimax_opponent.gd
│   ├── ui/
│   │   ├── gambit_menu.gd
│   │   ├── board_view.gd
│   │   ├── piece_sprite.gd
│   │   └── game_controls.gd
│   └── utils/
│       └── helpers.gd
├── scenes/
│   ├── main.tscn
│   ├── board.tscn
│   ├── piece.tscn
│   ├── gambit_menu.tscn
│   └── ui.tscn
└── test/
    ├── test_game_state.gd
    ├── test_gambit_engine.gd
    ├── test_move_validator.gd
    └── test_opponents.gd
```

## Migration Plan

### Phase 1: Core Engine (1-2 days)
1. GameState singleton with board representation
2. Piece movement validation
3. FEN import/export
4. Basic game loop

### Phase 2: Visuals (1 day)
1. Board scene with squares
2. Piece sprites
3. Move highlighting
4. Click handling

### Phase 3: Gambits (1 day)
1. Gambit resource definition
2. GambitEngine singleton
3. Auto-execution system
4. Gambit menu UI

### Phase 4: Opponents (1 day)
1. OpponentAI singleton
2. Random opponent
3. Greedy opponent
4. Minimax opponent

### Phase 5: Polish (1 day)
1. Turn phase system
2. Cleanup phase
3. Sound effects
4. Animations

### Phase 6: Testing (ongoing)
1. GUT setup
2. Unit tests for core
3. Integration tests
4. Automated test runner

## Benefits of Godot Version

1. **Performance**: Native C++ engine vs JavaScript VM
2. **State Management**: Built-in node/scene system vs React hooks
3. **Testing**: GUT for unit tests, built-in debugging
4. **Deployment**: Export to Windows, Mac, Linux, Web, Mobile
5. **Animation**: Built-in tweening and animation system
6. **Audio**: Built-in audio engine
7. **Modding**: Easy to extend with GDScript
