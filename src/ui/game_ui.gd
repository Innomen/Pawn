extends Control

@onready var turn_label: Label = %TurnLabel
@onready var phase_label: Label = %PhaseLabel
@onready var gambit_label: Label = %GambitLabel
@onready var opponent_selector: OptionButton = %OpponentSelector
@onready var gambit_menu: Control = $GambitPanel/GambitMenu

func _ready():
    opponent_selector.item_selected.connect(_on_opponent_selected)
    
    # Connect buttons
    $OpponentPanel/VBoxContainer/RestartButton.pressed.connect(_on_restart)
    
    update_display()

func update_display():
    update_turn(GameState.current_turn)
    update_phase(GameState.get_game_phase())
    update_gambit_status()

func update_turn(color: String):
    turn_label.text = color.capitalize() + " to move"
    
    if color == "white":
        turn_label.modulate = Color(1, 1, 1)
    else:
        turn_label.modulate = Color(0.3, 0.3, 0.3)

func update_phase(phase: String):
    phase_label.text = phase.capitalize() + " Phase"

func update_gambit_status():
    if GameState.active_gambit:
        var progress = GambitEngine.get_gambit_progress()
        gambit_label.text = GameState.active_gambit.name + " (" + str(progress.current_move + 1) + "/" + str(progress.total_moves) + ")"
    else:
        gambit_label.text = "No active gambit"

func show_gambit_completed(gambit):
    var dialog = AcceptDialog.new()
    dialog.title = "Gambit Completed!"
    dialog.dialog_text = "Successfully completed: " + gambit.name
    add_child(dialog)
    dialog.popup_centered()
    
    update_gambit_status()

func show_gambit_interrupted(gambit, reason):
    var dialog = AcceptDialog.new()
    dialog.title = "Gambit Interrupted"
    dialog.dialog_text = gambit.name + " was interrupted: " + reason
    add_child(dialog)
    dialog.popup_centered()
    
    update_gambit_status()

func show_game_over(result: String, winner: String):
    var message = ""
    match result:
        "checkmate":
            message = "Checkmate! " + winner.capitalize() + " wins!"
        "stalemate":
            message = "Stalemate! It's a draw."
        "draw":
            message = "Game drawn."
    
    var dialog = AcceptDialog.new()
    dialog.title = "Game Over"
    dialog.dialog_text = message
    dialog.confirmed.connect(_on_restart)
    add_child(dialog)
    dialog.popup_centered()

func _on_opponent_selected(index: int):
    var controller = get_node("/root/Main")
    controller.set_opponent_type(index)

func _on_restart():
    var controller = get_node("/root/Main")
    controller.restart_game()
