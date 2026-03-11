extends Node

# DebugOverlay - Serializes game state to stdout for agent visibility
# Prints JSON every frame in debug builds

var frame_count = 0
var last_state = {}

func _ready():
    print("DebugOverlay initialized")

func _process(_delta):
    frame_count += 1
    
    # Only print every 30 frames to avoid spam, or on significant changes
    if frame_count % 30 == 0 or _state_changed():
        var state = _gather_state()
        last_state = state
        
        # Print as JSON for machine parsing
        print("DEBUG_STATE: " + JSON.stringify(state))

func _state_changed() -> bool:
    var current = _gather_state()
    return not current.is_empty() and current.hash() != last_state.hash()

func _gather_state() -> Dictionary:
    var state = {
        "timestamp": Time.get_ticks_msec(),
        "frame": frame_count,
        "scene": _get_current_scene_name(),
    }
    
    # Game state
    if GameState:
        state["game"] = {
            "board_piece_count": GameState.board.size() if GameState.board else 0,
            "current_turn": GameState.current_turn if GameState.current_turn else "unknown",
            "game_status": GameState.game_status if GameState.game_status else "unknown",
            "completed_gambits": GameState.completed_gambits.size() if GameState.completed_gambits else 0,
            "failed_gambits": GameState.failed_gambits.size() if GameState.failed_gambits else 0,
            "active_gambit": GameState.active_gambit.name if GameState.active_gambit else null,
        }
    
    # Scene tree state - check if Board exists and has pieces
    var tree = get_tree()
    if tree:
        var root = tree.root
        var main = root.get_node_or_null("Main")
        if main:
            state["main_exists"] = true
            
            var board = main.get_node_or_null("Game/Board")
            if board:
                state["board"] = _get_board_state(board)
            else:
                state["board"] = {"exists": false}
            
            var ui = main.get_node_or_null("UI/GameUI")
            if ui:
                state["ui"] = _get_ui_state(ui)
        else:
            state["main_exists"] = false
    
    return state

func _get_board_state(board: Node) -> Dictionary:
    var state = {
        "exists": true,
        "pieces_node_exists": false,
        "piece_count": 0,
        "pieces": [],
    }
    
    var pieces_node = board.get_node_or_null("Pieces")
    if pieces_node:
        state["pieces_node_exists"] = true
        state["piece_count"] = pieces_node.get_child_count()
        
        # Detail first 5 pieces
        for i in range(min(5, pieces_node.get_child_count())):
            var piece = pieces_node.get_child(i)
            state["pieces"].append({
                "name": piece.name,
                "visible": piece.visible,
                "position": [piece.position.x, piece.position.y],
                "has_sprite": piece is Sprite2D and piece.texture != null,
            })
    
    return state

func _get_ui_state(ui: Node) -> Dictionary:
    var state = {
        "exists": true,
        "visible": ui.visible,
    }
    
    # Check gambit panel
    var gambit_panel = ui.get_node_or_null("GambitPanel/GambitMenu")
    if gambit_panel:
        state["gambit_panel"] = {
            "visible": gambit_panel.visible,
            "openings_count": _count_buttons_in_container(gambit_panel.get_node_or_null("ScrollContainer/VBoxContainer/OpeningsSection/OpeningsList")),
            "tactics_count": _count_buttons_in_container(gambit_panel.get_node_or_null("ScrollContainer/VBoxContainer/TacticsSection/TacticsList")),
        }
    
    return state

func _count_buttons_in_container(container: Node) -> int:
    if not container:
        return 0
    var count = 0
    for child in container.get_children():
        if child is Button:
            count += 1
    return count

func _get_current_scene_name() -> String:
    var tree = get_tree()
    if tree and tree.current_scene:
        return tree.current_scene.name
    return "none"

# Public API for forcing a state dump
func dump_state():
    var state = _gather_state()
    print("DEBUG_STATE_DUMP: " + JSON.stringify(state, "\t"))
