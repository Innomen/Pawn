extends RefCounted
class_name SceneState

# Scene state contracts - every major scene exposes get_state() -> Dictionary
# This allows headless testing to verify visual state as data

static func get_board_state(board: Node2D) -> Dictionary:
    """Get complete state of the board scene"""
    var state = {
        "type": "Board",
        "exists": true,
        "square_size": board.square_size if "square_size" in board else 80,
    }
    
    # Squares
    var squares = board.get_node_or_null("Squares")
    if squares:
        state["squares_count"] = squares.get_child_count()
    
    # Pieces
    var pieces = board.get_node_or_null("Pieces")
    if pieces:
        state["pieces_count"] = pieces.get_child_count()
        state["pieces"] = []
        
        for piece in pieces.get_children():
            state["pieces"].append({
                "name": piece.name,
                "visible": piece.visible,
                "position": [piece.position.x, piece.position.y],
                "modulate": [piece.modulate.r, piece.modulate.g, piece.modulate.b, piece.modulate.a],
                "scale": [piece.scale.x, piece.scale.y],
            })
    else:
        state["pieces_count"] = 0
        state["pieces_error"] = "Pieces node not found"
    
    # Highlights
    var highlights = board.get_node_or_null("Highlights")
    if highlights:
        state["highlights_count"] = highlights.get_child_count()
    
    return state

static func get_game_ui_state(ui: Control) -> Dictionary:
    """Get complete state of the game UI"""
    var state = {
        "type": "GameUI",
        "exists": true,
        "visible": ui.visible,
    }
    
    # Turn label
    var turn_label = ui.get_node_or_null("GameInfo/HBoxContainer/TurnLabel")
    if turn_label:
        state["turn_text"] = turn_label.text
    
    # Phase label
    var phase_label = ui.get_node_or_null("GameInfo/HBoxContainer/PhaseLabel")
    if phase_label:
        state["phase_text"] = phase_label.text
    
    # Gambit panel
    var gambit_panel = ui.get_node_or_null("GambitPanel/GambitMenu")
    if gambit_panel:
        state["gambit_panel_visible"] = gambit_panel.visible
        
        # Count available gambits
        var openings_list = gambit_panel.get_node_or_null("ScrollContainer/VBoxContainer/OpeningsSection/OpeningsList")
        var tactics_list = gambit_panel.get_node_or_null("ScrollContainer/VBoxContainer/TacticsSection/TacticsList")
        
        state["openings_count"] = _count_buttons(openings_list)
        state["tactics_count"] = _count_buttons(tactics_list)
    
    # Buttons
    var suggest_button = ui.get_node_or_null("GambitPanel/GambitMenu/ScrollContainer/VBoxContainer/SuggestMoveButton")
    if suggest_button:
        state["suggest_button_visible"] = suggest_button.visible
        state["suggest_button_disabled"] = suggest_button.disabled
    
    return state

static func get_main_state(main: Node) -> Dictionary:
    """Get complete state of the main scene"""
    var state = {
        "type": "Main",
        "exists": true,
        "children": main.get_child_count(),
    }
    
    # Board state
    var board = main.get_node_or_null("Game/Board")
    if board:
        state["board"] = get_board_state(board)
    else:
        state["board"] = {"exists": false}
    
    # UI state
    var ui = main.get_node_or_null("UI/GameUI")
    if ui:
        state["ui"] = get_game_ui_state(ui)
    else:
        state["ui"] = {"exists": false}
    
    return state

static func get_full_game_state() -> Dictionary:
    """Get complete game state across all systems"""
    var state = {
        "timestamp": Time.get_ticks_msec(),
        "gamecore": {},
        "scene": {},
    }
    
    # GameCore state
    if GameState:
        state["gamecore"] = {
            "board_size": GameState.board.size(),
            "turn": GameState.current_turn,
            "status": GameState.game_status,
        }
    
    # Scene state
    var tree = Engine.get_main_loop()
    if tree:
        var root = tree.root
        var main = root.get_node_or_null("Main")
        if main:
            state["scene"] = get_main_state(main)
        else:
            state["scene"] = {"exists": false, "error": "Main scene not found"}
    
    return state

static func _count_buttons(container: Node) -> int:
    if not container:
        return 0
    var count = 0
    for child in container.get_children():
        if child is Button:
            count += 1
    return count

static func verify_pieces_present() -> Dictionary:
    """Specific verification that pieces are rendered correctly"""
    var result = {
        "passed": false,
        "errors": [],
        "piece_count": 0,
        "expected_count": 32,
    }
    
    var tree = Engine.get_main_loop()
    if not tree:
        result["errors"].append("No scene tree")
        return result
    
    var main = tree.root.get_node_or_null("Main")
    if not main:
        result["errors"].append("Main scene not found")
        return result
    
    var board = main.get_node_or_null("Game/Board")
    if not board:
        result["errors"].append("Board not found")
        return result
    
    var pieces = board.get_node_or_null("Pieces")
    if not pieces:
        result["errors"].append("Pieces node not found")
        return result
    
    var count = pieces.get_child_count()
    result["piece_count"] = count
    
    if count == 0:
        result["errors"].append("No pieces in Pieces node")
    elif count != 32:
        result["errors"].append("Expected 32 pieces, found " + str(count))
    
    # Check pieces are visible
    var visible_count = 0
    for piece in pieces.get_children():
        if piece.visible:
            visible_count += 1
    
    if visible_count != count:
        result["errors"].append("Only " + str(visible_count) + "/" + str(count) + " pieces visible")
    
    # Check pieces have valid positions
    var valid_positions = 0
    for piece in pieces.get_children():
        if piece.position.x >= 0 and piece.position.x <= 640 and piece.position.y >= 0 and piece.position.y <= 640:
            valid_positions += 1
    
    if valid_positions != count:
        result["errors"].append("Only " + str(valid_positions) + "/" + str(count) + " pieces in valid board area")
    
    result["passed"] = result["errors"].is_empty()
    return result
