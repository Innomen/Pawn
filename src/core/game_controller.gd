extends Node

@onready var board: Node2D = $Game/Board
@onready var ui: Control = $UI/GameUI

var opponent_type: int = OpponentAI.Difficulty.RANDOM

func _ready():
    print("GameController ready")
    
    # Connect signals
    GameState.turn_changed.connect(_on_turn_changed)
    GameState.game_ended.connect(_on_game_ended)
    GameState.move_made.connect(_on_move_made)
    GambitEngine.gambit_completed.connect(_on_gambit_completed)
    GambitEngine.gambit_interrupted.connect(_on_gambit_interrupted)
    OpponentAI.opponent_move_ready.connect(_on_opponent_move)
    TurnPhaseManager.phase_changed.connect(_on_phase_changed)
    
    # Start game
    start_new_game()

func start_new_game():
    print("Starting new game")
    
    # Set up game state
    GameState.setup_standard()
    
    # Set opponent
    OpponentAI.set_opponent(opponent_type, "black")
    
    # Start turn phase
    TurnPhaseManager.start_turn("white")
    
    # Update UI
    ui.update_display()

func _on_turn_changed(color: String):
    ui.update_turn(color)
    
    # Check for opponent turn
    if color == "black" and not GameState.is_game_over():
        OpponentAI.request_move()

func _on_game_ended(result: String, winner: String):
    print("Game ended: " + result + " - Winner: " + winner)
    ui.show_game_over(result, winner)

func _on_move_made(move: Dictionary):
    ui.update_display()
    
    # Check for phase transition
    if TurnPhaseManager.current_phase == TurnPhaseManager.TurnPhase.MOVE_RESOLUTION:
        TurnPhaseManager.set_phase(TurnPhaseManager.TurnPhase.GAMBIT_CHECK)

func _on_gambit_completed(gambit):
    print("Gambit completed: " + gambit.name)
    ui.show_gambit_completed(gambit)

func _on_gambit_interrupted(gambit, reason):
    print("Gambit interrupted: " + gambit.name + " - " + reason)
    ui.show_gambit_interrupted(gambit, reason)

func _on_opponent_move(move: Dictionary):
    if move.is_empty():
        return
    
    GameState.make_move(move.from, move.to)
    board.animate_move(move)

func _on_phase_changed(phase):
    match phase:
        TurnPhaseManager.TurnPhase.GAMBIT_CHECK:
            _process_gambit_check()
        TurnPhaseManager.TurnPhase.END_PHASE:
            TurnPhaseManager.set_phase(TurnPhaseManager.TurnPhase.TURN_END)

func _process_gambit_check():
    # Move to end phase
    TurnPhaseManager.set_phase(TurnPhaseManager.TurnPhase.END_PHASE)

func set_opponent_type(type: int):
    opponent_type = type
    OpponentAI.set_opponent(type, "black")

func restart_game():
    start_new_game()
