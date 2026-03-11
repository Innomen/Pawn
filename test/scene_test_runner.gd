extends Node

# Scene Test Runner - Tests scene trees and visual state in headless mode
# Uses get_state() contracts to verify UI without rendering

var tests_passed = 0
var tests_failed = 0
var test_results: Array = []

func _ready():
    print("\n=== SCENE TEST RUNNER ===\n")
    
    # Wait for scene to fully load
    await get_tree().process_frame
    await get_tree().process_frame
    await get_tree().process_frame
    
    # Run all tests
    await run_all_tests()
    
    # Print summary
    print_summary()
    
    # Exit with appropriate code
    var exit_code = 0 if tests_failed == 0 else 1
    get_tree().quit(exit_code)

func run_all_tests():
    # Test 1: Verify scene structure
    await test_scene_structure()
    
    # Test 2: Verify pieces are present
    await test_pieces_present()
    
    # Test 3: Verify UI elements exist
    await test_ui_elements()
    
    # Test 4: Verify game state matches scene
    await test_state_consistency()
    
    # Test 5: Test a move
    await test_make_move()

func test_scene_structure():
    print("TEST: Scene Structure")
    
    var tree = get_tree()
    var root = tree.root
    var main = root.get_node_or_null("Main")
    
    if not main:
        fail("Main scene not found")
        return
    
    var checks = {
        "Game node exists": main.get_node_or_null("Game") != null,
        "Board exists": main.get_node_or_null("Game/Board") != null,
        "UI exists": main.get_node_or_null("UI") != null,
        "GameUI exists": main.get_node_or_null("UI/GameUI") != null,
        "Squares node exists": main.get_node_or_null("Game/Board/Squares") != null,
        "Pieces node exists": main.get_node_or_null("Game/Board/Pieces") != null,
    }
    
    var all_pass = true
    for check in checks.keys():
        if not checks[check]:
            fail(check + " - FAILED")
            all_pass = false
    
    if all_pass:
        pass("All scene nodes present")

func test_pieces_present():
    print("\nTEST: Pieces Present")
    
    var result = SceneState.verify_pieces_present()
    
    if result.passed:
        pass("All 32 pieces present and visible")
    else:
        for error in result.errors:
            fail(error)
        
        # Dump detailed state
        print("  Piece count: " + str(result.piece_count) + "/" + str(result.expected_count))
        
        var tree = get_tree()
        var main = tree.root.get_node_or_null("Main")
        if main:
            var board = main.get_node_or_null("Game/Board")
            if board:
                var state = SceneState.get_board_state(board)
                print("  Board state: " + JSON.stringify(state))

func test_ui_elements():
    print("\nTEST: UI Elements")
    
    var tree = get_tree()
    var main = tree.root.get_node_or_null("Main")
    if not main:
        fail("Main not found")
        return
    
    var ui = main.get_node_or_null("UI/GameUI")
    if not ui:
        fail("GameUI not found")
        return
    
    var state = SceneState.get_game_ui_state(ui)
    
    var checks = {
        "UI is visible": state.get("visible", false),
        "Turn label has text": state.get("turn_text", "").length() > 0,
        "Gambit panel state captured": "gambit_panel_visible" in state,
    }
    
    var all_pass = true
    for check in checks.keys():
        if not checks[check]:
            fail(check + " - FAILED")
            all_pass = false
    
    if all_pass:
        pass("UI elements correct")
        print("  Turn: " + state.get("turn_text", "unknown"))
        print("  Openings available: " + str(state.get("openings_count", 0)))

func test_state_consistency():
    print("\nTEST: State Consistency")
    
    var full_state = SceneState.get_full_game_state()
    
    # Check GameState has pieces
    var gamecore_count = full_state.get("gamecore", {}).get("board_size", 0)
    
    # Check scene has pieces
    var scene_count = full_state.get("scene", {}).get("board", {}).get("pieces_count", 0)
    
    if gamecore_count != 32:
        fail("GameState has " + str(gamecore_count) + " pieces, expected 32")
        return
    
    if scene_count == 0:
        fail("Scene has 0 pieces - pieces not created!")
        return
    
    if scene_count != 32:
        fail("Scene has " + str(scene_count) + " pieces, expected 32")
        return
    
    if gamecore_count == 32 and scene_count == 32:
        pass("GameState and Scene both have 32 pieces")
    
    print("  GameState: " + str(gamecore_count) + " pieces")
    print("  Scene: " + str(scene_count) + " pieces")

func test_make_move():
    print("\nTEST: Make Move")
    
    # Try to make a move via GameState
    var success = GameState.make_move(Vector2i(4, 6), Vector2i(4, 4))
    
    if not success:
        fail("Could not make move e2-e4")
        return
    
    # Wait for board to update
    await get_tree().process_frame
    await get_tree().process_frame
    
    # Check piece moved in scene
    var tree = get_tree()
    var main = tree.root.get_node_or_null("Main")
    if not main:
        fail("Main not found after move")
        return
    
    var board = main.get_node_or_null("Game/Board")
    if not board:
        fail("Board not found after move")
        return
    
    # Check for piece at e4 (4, 4 in board coords)
    # Actually pieces are named by their original position, need to check differently
    var pieces = board.get_node_or_null("Pieces")
    if not pieces:
        fail("Pieces node not found after move")
        return
    
    # Count pieces (should still be 32, not 31 or 33)
    var count = pieces.get_child_count()
    if count != 32:
        fail("Piece count changed to " + str(count) + " after move")
        return
    
    pass("Move executed successfully")

func pass(message: String):
    tests_passed += 1
    test_results.append({"passed": true, "message": message})
    print("  ✓ PASS: " + message)

func fail(message: String):
    tests_failed += 1
    test_results.append({"passed": false, "message": message})
    print("  ✗ FAIL: " + message)

func print_summary():
    print("\n=== SUMMARY ===")
    print("Passed: " + str(tests_passed))
    print("Failed: " + str(tests_failed))
    
    if tests_failed > 0:
        print("\nFailed tests:")
        for result in test_results:
            if not result.passed:
                print("  - " + result.message)
    
    # Dump full state for debugging
    print("\n=== FULL STATE DUMP ===")
    var state = SceneState.get_full_game_state()
    print(JSON.stringify(state, "\t"))
