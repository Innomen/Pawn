extends Node

# Main Scene Test - Loads the actual main.tscn and tests it
# Run with: godot --headless test/main_scene_test.tscn

var tests_passed = 0
var tests_failed = 0

func _ready():
    print("=== MAIN SCENE TEST ===\n")
    
    # Wait for autoloads to initialize
    await get_tree().process_frame
    
    # Find GameState (might be at root or as child)
    var game_state = get_node_or_null("/root/GameState")
    if not game_state:
        game_state = get_node_or_null("GameState")  # As child of this scene
    
    if not game_state:
        print("FAIL: GameState not found")
        get_tree().quit(1)
        return
    
    print("GameState found: " + str(game_state.board.size()) + " pieces\n")
    
    # Load and instance the main scene
    var main_scene = load("res://scenes/main.tscn")
    if not main_scene:
        print("FAIL: Could not load main.tscn")
        get_tree().quit(1)
        return
    
    var instance = main_scene.instantiate()
    get_tree().root.add_child(instance)
    
    # Wait for _ready() to complete
    await get_tree().process_frame
    await get_tree().process_frame
    await get_tree().process_frame
    await get_tree().process_frame
    await get_tree().process_frame
    
    print("Main scene loaded, running tests...\n")
    
    # Run tests
    test_scene_structure(instance)
    test_pieces_count(instance)
    test_ui_elements(instance)
    test_game_state_consistency(instance, game_state)
    
    # Print summary
    print("\n=== SUMMARY ===")
    print("Passed: " + str(tests_passed))
    print("Failed: " + str(tests_failed))
    
    # Dump state if failures
    if tests_failed > 0:
        print("\n=== DEBUG STATE ===")
        dump_debug_state(instance, game_state)
    
    # Cleanup
    instance.queue_free()
    
    # Exit
    get_tree().quit(0 if tests_failed == 0 else 1)

func test_scene_structure(instance: Node):
    print("TEST: Scene Structure")
    
    var game = instance.get_node_or_null("Game")
    check("Game node exists", game != null)
    
    if game:
        var board = game.get_node_or_null("Board")
        check("Board exists", board != null)
        
        if board:
            check("Squares node exists", board.get_node_or_null("Squares") != null)
            check("Pieces node exists", board.get_node_or_null("Pieces") != null)
            check("Highlights node exists", board.get_node_or_null("Highlights") != null)
    
    var ui = instance.get_node_or_null("UI")
    check("UI node exists", ui != null)
    
    if ui:
        check("GameUI exists", ui.get_node_or_null("GameUI") != null)

func test_pieces_count(instance: Node):
    print("\nTEST: Pieces Count")
    
    var board = instance.get_node_or_null("Game/Board")
    if not board:
        fail("Board not found")
        return
    
    var pieces = board.get_node_or_null("Pieces")
    if not pieces:
        fail("Pieces node not found")
        return
    
    var count = pieces.get_child_count()
    print("  Pieces in scene: " + str(count))
    
    # Check each piece
    var visible_count = 0
    var valid_pos_count = 0
    
    for piece in pieces.get_children():
        if piece.visible:
            visible_count += 1
        
        # Check position is within board (0-640, 0-640 for 80px squares)
        # With offset for centering: 40-680, 40-680
        if piece.position.x >= 0 and piece.position.x <= 700:
            if piece.position.y >= 0 and piece.position.y <= 700:
                valid_pos_count += 1
        
        # Print first few pieces for debugging
        if pieces.get_children().find(piece) < 3:
            print("    " + piece.name + ": pos=" + str(piece.position) + " visible=" + str(piece.visible))
    
    check("Has 32 pieces", count == 32)
    check("All pieces visible", visible_count == 32)
    check("All pieces in valid positions", valid_pos_count == 32)

func test_ui_elements(instance: Node):
    print("\nTEST: UI Elements")
    
    var ui = instance.get_node_or_null("UI/GameUI")
    if not ui:
        fail("GameUI not found")
        return
    
    check("GameInfo exists", ui.get_node_or_null("GameInfo") != null)
    check("GambitPanel exists", ui.get_node_or_null("GambitPanel") != null)
    
    var gambit_menu = ui.get_node_or_null("GambitPanel/GambitMenu")
    if gambit_menu:
        check("GambitMenu exists", true)
        
        # Check for buttons
        var suggest_btn = gambit_menu.get_node_or_null("ScrollContainer/VBoxContainer/SuggestMoveButton")
        check("SuggestMoveButton exists", suggest_btn != null)
    else:
        fail("GambitMenu not found")

func test_game_state_consistency(instance: Node, game_state: Node):
    print("\nTEST: Game State Consistency")
    
    var board = instance.get_node_or_null("Game/Board")
    if not board:
        fail("Board not found")
        return
    
    var pieces = board.get_node_or_null("Pieces")
    if not pieces:
        fail("Pieces node not found")
        return
    
    var scene_count = pieces.get_child_count()
    var state_count = game_state.board.size()
    
    print("  Scene pieces: " + str(scene_count))
    print("  GameState pieces: " + str(state_count))
    
    if scene_count != state_count:
        fail("Mismatch: Scene has " + str(scene_count) + " but GameState has " + str(state_count))
    else:
        check("Scene and GameState match", true)

func dump_debug_state(instance: Node, game_state: Node):
    print("\nGameState board size: " + str(game_state.board.size()))
    print("Current turn: " + game_state.current_turn)
    
    var board = instance.get_node_or_null("Game/Board")
    if board:
        var pieces = board.get_node_or_null("Pieces")
        if pieces:
            print("Pieces node child count: " + str(pieces.get_child_count()))
            print("Pieces node children:")
            for child in pieces.get_children():
                print("  - " + child.name + " (" + child.get_class() + ") visible=" + str(child.visible) + " pos=" + str(child.position))

func check(message: String, condition: bool):
    if condition:
        tests_passed += 1
        print("  ✓ " + message)
    else:
        tests_failed += 1
        print("  ✗ " + message)

func fail(message: String):
    tests_failed += 1
    print("  ✗ " + message)
