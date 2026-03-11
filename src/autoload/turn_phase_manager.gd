extends Node

signal phase_changed(new_phase: TurnPhase)
signal turn_started(color: String)
signal turn_ended(color: String)
signal available_actions_updated(actions: Dictionary)

enum TurnPhase {
    TURN_START,      # Calculate available actions
    MAIN_PHASE,      # Player acts
    MOVE_RESOLUTION, # Execute move
    GAMBIT_CHECK,    # Check if gambit continues
    END_PHASE,       # Cleanup
    TURN_END         # Switch player
}

var current_phase: TurnPhase = TurnPhase.TURN_START
var current_turn: String = "white"
var available_actions: Dictionary = {}
var turn_number: int = 1

func _ready():
    GameState.turn_changed.connect(_on_turn_changed)
    DebugLogger.log_info("TurnPhaseManager initialized")

func start_turn(color: String):
    current_turn = color
    turn_started.emit(color)
    set_phase(TurnPhase.TURN_START)

func set_phase(phase: TurnPhase):
    current_phase = phase
    var phase_name = TurnPhase.keys()[phase]
    DebugLogger.log_phase_change(phase_name, current_turn)
    phase_changed.emit(phase)
    
    match phase:
        TurnPhase.TURN_START:
            _process_turn_start()
        TurnPhase.END_PHASE:
            _process_end_phase()
        TurnPhase.TURN_END:
            _process_turn_end()

func _process_turn_start():
    # Calculate available gambits for this turn
    _calculate_available_actions()
    
    # Move to main phase
    set_phase(TurnPhase.MAIN_PHASE)

func _calculate_available_actions():
    available_actions = {
        "openings": [],
        "tactics": [],
        "gambits": []
    }
    
    var game_phase = GameState.get_game_phase()
    var gambits = GambitRegistry.get_all_gambits()
    
    for gambit in gambits:
        # Skip if already completed or failed
        if gambit.id in GameState.completed_gambits or gambit.id in GameState.failed_gambits:
            continue
        
        # Check if applicable for current turn
        if gambit.for_color != current_turn:
            continue
        
        # Check game phase restrictions
        if gambit.category == "opening" and game_phase != "opening":
            continue
        
        # Check if applicable to current position
        if gambit.is_applicable(GameState):
            match gambit.category:
                "opening":
                    available_actions.openings.append(gambit)
                "tactic":
                    available_actions.tactics.append(gambit)
                _:
                    available_actions.gambits.append(gambit)
    
    available_actions_updated.emit(available_actions)

func _process_end_phase():
    # Run cleanup
    _run_cleanup()
    
    # Move to turn end
    set_phase(TurnPhase.TURN_END)

func _run_cleanup():
    DebugLogger.log_debug("Running cleanup phase")
    
    var cleanup_results = {
        "duplicates_removed": 0,
        "failed_cleaned": 0,
        "active_cleared": false
    }
    
    # Remove duplicates from completed_gambits
    var unique_completed: Array = []
    var dups = 0
    for id in GameState.completed_gambits:
        if not id in unique_completed:
            unique_completed.append(id)
        else:
            dups += 1
    GameState.completed_gambits = unique_completed
    cleanup_results.duplicates_removed = dups
    
    # Remove duplicates from failed_gambits
    var unique_failed: Array = []
    for id in GameState.failed_gambits:
        if not id in unique_failed:
            unique_failed.append(id)
    GameState.failed_gambits = unique_failed
    
    # Remove from failed if now in completed
    var cleaned_failed: Array = []
    for id in GameState.failed_gambits:
        if not id in GameState.completed_gambits:
            cleaned_failed.append(id)
        else:
            cleanup_results.failed_cleaned += 1
    GameState.failed_gambits = cleaned_failed
    
    # Verify active gambit state
    if GameState.active_gambit:
        if GameState.active_gambit.id in GameState.completed_gambits:
            GameState.active_gambit = null
            GambitEngine.active_gambit = null
            cleanup_results.active_cleared = true
        elif GameState.active_gambit.id in GameState.failed_gambits:
            GameState.active_gambit = null
            GambitEngine.active_gambit = null
            cleanup_results.active_cleared = true
    
    DebugLogger.log_cleanup_results(cleanup_results)

func _process_turn_end():
    turn_ended.emit(current_turn)
    
    # Switch turn
    if current_turn == "white":
        current_turn = "black"
    else:
        current_turn = "white"
        turn_number += 1
    
    GameState.switch_turn()

func _on_turn_changed(new_color: String):
    # Start new turn
    start_turn(new_color)

func can_activate_gambit(gambit_id: String) -> bool:
    # Check if gambit is in available actions
    for gambit in available_actions.openings + available_actions.tactics + available_actions.gambits:
        if gambit.id == gambit_id:
            return true
    return false

func get_available_openings() -> Array:
    return available_actions.get("openings", [])

func get_available_tactics() -> Array:
    return available_actions.get("tactics", [])
