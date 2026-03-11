extends Control

@onready var openings_section: VBoxContainer = %OpeningsSection
@onready var openings_list: VBoxContainer = %OpeningsList
@onready var tactics_section: VBoxContainer = %TacticsSection
@onready var tactics_list: VBoxContainer = %TacticsList
@onready var no_gambits_label: Label = %NoGambitsLabel
@onready var suggest_button: Button = %SuggestMoveButton
@onready var active_panel: Panel = %ActiveGambitPanel
@onready var active_name_label: Label = %ActiveNameLabel
@onready var active_progress_label: Label = %ActiveProgressLabel

var gambit_button_scene = preload("res://src/ui/gambit_button.tscn")

func _ready():
    TurnPhaseManager.available_actions_updated.connect(_on_available_actions_updated)
    GameState.gambit_started.connect(_on_gambit_started)
    GameState.gambit_ended.connect(_on_gambit_ended)
    GameState.turn_changed.connect(_on_turn_changed)
    
    suggest_button.pressed.connect(_on_suggest_move)
    
    _update_display()

func _on_available_actions_updated(actions: Dictionary):
    _update_display()

func _on_gambit_started(gambit):
    _show_active_gambit(gambit)

func _on_gambit_ended(gambit, success, reason):
    _hide_active_gambit()
    _update_display()

func _on_turn_changed(color: String):
    _update_display()

func _update_display():
    _clear_lists()
    
    var has_gambits = false
    
    # Update openings
    var openings = TurnPhaseManager.get_available_openings()
    if openings.size() > 0:
        has_gambits = true
        openings_section.visible = true
        for gambit in openings:
            _add_gambit_button(gambit, openings_list)
    else:
        openings_section.visible = false
    
    # Update tactics
    var tactics = TurnPhaseManager.get_available_tactics()
    if tactics.size() > 0:
        has_gambits = true
        tactics_section.visible = true
        for gambit in tactics:
            _add_gambit_button(gambit, tactics_list)
    else:
        tactics_section.visible = false
    
    # Show/hide no gambits message
    no_gambits_label.visible = not has_gambits
    
    # Show active gambit if any
    if GameState.active_gambit:
        _show_active_gambit(GameState.active_gambit)
    else:
        _hide_active_gambit()

func _clear_lists():
    for child in openings_list.get_children():
        child.queue_free()
    for child in tactics_list.get_children():
        child.queue_free()

func _add_gambit_button(gambit: Gambit, parent: Node):
    var button = Button.new()
    button.text = gambit.name
    button.tooltip_text = gambit.description
    button.pressed.connect(func(): _on_gambit_clicked(gambit))
    
    # Style based on difficulty
    match gambit.difficulty:
        1: button.modulate = Color(0.8, 1, 0.8)
        2: button.modulate = Color(0.9, 1, 0.8)
        3: button.modulate = Color(1, 1, 0.8)
        4: button.modulate = Color(1, 0.9, 0.6)
        5: button.modulate = Color(1, 0.7, 0.7)
    
    parent.add_child(button)

func _on_gambit_clicked(gambit: Gambit):
    if TurnPhaseManager.can_activate_gambit(gambit.id):
        GambitEngine.activate_gambit(gambit.id)
        GambitEngine.start_auto_execution()

func _show_active_gambit(gambit: Gambit):
    active_panel.visible = true
    active_name_label.text = gambit.name
    
    var progress = GambitEngine.get_gambit_progress()
    if not progress.is_empty():
        active_progress_label.text = "Move " + str(progress.current_move + 1) + " of " + str(progress.total_moves)
    
    # Connect stop button
    var stop_button = active_panel.get_node("VBoxContainer/StopButton")
    stop_button.pressed.connect(_on_stop_gambit, CONNECT_ONE_SHOT)

func _hide_active_gambit():
    active_panel.visible = false

func _on_stop_gambit():
    GambitEngine.interrupt_gambit("User stopped")

func _on_suggest_move():
    # Get a suggested move based on simple heuristics
    var suggested = _get_suggested_move()
    
    if not suggested.is_empty():
        # Highlight the suggested move on the board
        var dialog = AcceptDialog.new()
        dialog.title = "Suggested Move"
        dialog.dialog_text = "Consider: " + suggested.san
        add_child(dialog)
        dialog.popup_centered()

func _get_suggested_move() -> Dictionary:
    var moves = OpponentAI.get_all_legal_moves(GameState.current_turn)
    
    if moves.size() == 0:
        return {}
    
    var piece_values = [100, 320, 330, 500, 900, 0]
    var best_move = moves[0]
    var best_score = -9999
    
    for move in moves:
        var score = 0
        
        # Check for captures
        if GameState.board.has(move.to):
            var captured = GameState.board[move.to]
            score += piece_values[captured.type]
        
        # Center control bonus
        var center = [Vector2i(3, 3), Vector2i(3, 4), Vector2i(4, 3), Vector2i(4, 4)]
        if move.to in center:
            score += 30
        
        # Development bonus
        var piece = move.piece
        if not piece.has_moved:
            if piece.type == GameState.PieceType.KNIGHT or piece.type == GameState.PieceType.BISHOP:
                score += 25
        
        if score > best_score:
            best_score = score
            best_move = move
    
    var san = _move_to_san(best_move)
    
    return {
        "move": best_move,
        "san": san,
        "score": best_score
    }

func _move_to_san(move: Dictionary) -> String:
    var piece_chars = ["", "N", "B", "R", "Q", "K"]
    var san = ""
    
    if move.piece.type != GameState.PieceType.PAWN:
        san += piece_chars[move.piece.type]
    
    san += char(97 + move.to.x)
    san += str(8 - move.to.y)
    
    return san
