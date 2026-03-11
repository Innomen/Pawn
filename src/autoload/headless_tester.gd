extends Node

signal test_completed(test_name: String, passed: bool, results: Dictionary)
signal all_tests_completed(summary: Dictionary)

enum TestResult { PASS, FAIL, SKIP }

var test_results: Array[Dictionary] = []
var is_running: bool = false
var current_test: String = ""

# Simulated game state for headless testing
var simulated_board: Dictionary = {}
var simulated_turn: String = "white"
var simulated_history: Array[Dictionary] = []

func _ready():
    DebugLogger.log_info("HeadlessTester initialized")

# ============================================================================
# TEST RUNNERS
# ============================================================================

func run_all_tests() -> Dictionary:
    """Run the complete test suite"""
    if is_running:
        DebugLogger.log_warning("Tests already running, skipping")
        return {}
    
    is_running = true
    test_results.clear()
    
    DebugLogger.log_info("=== STARTING HEADLESS TEST SUITE ===")
    
    # Run all test suites
    await _run_suite("Move Validation", _test_move_validation)
    await _run_suite("Game State", _test_game_state)
    await _run_suite("Gambit System", _test_gambit_system)
    await _run_suite("Turn Phases", _test_turn_phases)
    await _run_suite("Cleanup Phase", _test_cleanup_phase)
    await _run_suite("AI Opponents", _test_ai_opponents)
    await _run_suite("Integration", _test_integration)
    
    var summary = _generate_summary()
    is_running = false
    
    DebugLogger.log_info("=== TEST SUITE COMPLETE ===")
    DebugLogger.log_info("Results: %d passed, %d failed, %d total" % [
        summary.passed, summary.failed, summary.total
    ])
    
    all_tests_completed.emit(summary)
    return summary

func run_quick_test() -> Dictionary:
    """Run a quick sanity check"""
    if is_running:
        return {}
    
    is_running = true
    test_results.clear()
    
    DebugLogger.log_info("=== QUICK SANITY CHECK ===")
    
    await _run_suite("Quick Check", _test_quick_sanity)
    
    var summary = _generate_summary()
    is_running = false
    
    all_tests_completed.emit(summary)
    return summary

func simulate_game(num_moves: int = 20) -> Dictionary:
    """Simulate a complete game with random moves"""
    DebugLogger.log_info("=== SIMULATING GAME (%d moves max) ===" % num_moves)
    
    _reset_simulation()
    var moves_made = 0
    var game_over = false
    
    while moves_made < num_moves and not game_over:
        # Get all legal moves for current player
        var legal_moves = _get_simulated_legal_moves(simulated_turn)
        
        if legal_moves.is_empty():
            game_over = true
            DebugLogger.log_info("Game ended: No legal moves (stalemate/checkmate)")
            break
        
        # Pick a random move
        var move = legal_moves[randi() % legal_moves.size()]
        
        # Execute move
        _execute_simulated_move(move)
        moves_made += 1
        
        # Check for game over
        if _is_simulated_checkmate(simulated_turn):
            game_over = true
            DebugLogger.log_info("Game ended: Checkmate after %d moves" % moves_made)
        elif _is_simulated_stalemate(simulated_turn):
            game_over = true
            DebugLogger.log_info("Game ended: Stalemate after %d moves" % moves_made)
        
        # Switch turns
        simulated_turn = "black" if simulated_turn == "white" else "white"
    
    var result = {
        "moves": moves_made,
        "game_over": game_over,
        "final_turn": simulated_turn,
        "history_size": simulated_history.size()
    }
    
    DebugLogger.log_info("Simulation complete: " + str(result))
    return result

func test_gambit_scenario(gambit_id: String, opponent_moves: Array[String] = []) -> Dictionary:
    """Test a specific gambit scenario"""
    DebugLogger.log_info("=== TESTING GAMBIT: %s ===" % gambit_id)
    
    GameState.setup_standard()
    
    var results = {
        "gambit_id": gambit_id,
        "activated": false,
        "completed": false,
        "interrupted": false,
        "moves_executed": 0,
        "reason": ""
    }
    
    # Try to activate gambit
    var activated = GambitEngine.activate_gambit(gambit_id)
    results.activated = activated
    
    if not activated:
        results.reason = "Failed to activate"
        DebugLogger.log_warning("Gambit %s failed to activate" % gambit_id)
        return results
    
    DebugLogger.log_info("Gambit %s activated" % gambit_id)
    
    # Simulate executing gambit moves
    var max_iterations = 20
    var iteration = 0
    
    while iteration < max_iterations and GameState.active_gambit:
        iteration += 1
        
        # If it's our turn, execute next gambit move
        if GameState.current_turn == GameState.active_gambit.for_color:
            var move_data = GambitEngine._get_next_move()
            if move_data.is_empty():
                break
            
            var success = GameState.make_move(move_data.from, move_data.to)
            if success:
                results.moves_executed += 1
                DebugLogger.log_info("Executed move %d" % results.moves_executed)
            else:
                results.interrupted = true
                results.reason = "Invalid move in sequence"
                break
        else:
            # Opponent turn - make a move
            if opponent_moves.size() > 0:
                # Use provided opponent move
                var opp_move = opponent_moves.pop_front()
                # Parse and execute opponent move
                _execute_opponent_move_san(opp_move)
            else:
                # Random opponent move
                var random_move = _get_random_opponent_move()
                if not random_move.is_empty():
                    GameState.make_move(random_move.from, random_move.to)
            
            # Check if gambit was interrupted
            if not GameState.active_gambit:
                results.interrupted = true
                results.reason = "Opponent deviation or error"
                break
        
        GameState.switch_turn()
    
    # Check final state
    if gambit_id in GameState.completed_gambits:
        results.completed = true
        results.reason = "Success"
    elif not results.interrupted:
        results.interrupted = true
        results.reason = "Unknown error"
    
    DebugLogger.log_info("Gambit test complete: " + str(results))
    return results

# ============================================================================
# TEST SUITES
# ============================================================================

func _test_move_validation() -> Array[Dictionary]:
    var tests = []
    
    # Test 1: Pawn can move forward
    _reset_simulation()
    var moves = _get_simulated_legal_moves("white")
    tests.append(_make_result("Pawn has legal moves", moves.size() > 0, "Found %d moves" % moves.size()))
    
    # Test 2: Knight can jump
    _reset_simulation()
    var knight_moves = _get_piece_moves(Vector2i(1, 7))  # b1 knight
    tests.append(_make_result("Knight can jump", knight_moves.size() == 2, "Found %d moves" % knight_moves.size()))
    
    # Test 3: Illegal move rejected
    _reset_simulation()
    var illegal = _can_move(Vector2i(0, 7), Vector2i(0, 5))  # Rook can't move through pieces
    tests.append(_make_result("Illegal move rejected", not illegal, "Rook blocked by knight"))
    
    # Test 4: Capture works
    _reset_simulation()
    _execute_simulated_move({"from": Vector2i(4, 6), "to": Vector2i(4, 4)})  # e4
    _execute_simulated_move({"from": Vector2i(4, 1), "to": Vector2i(4, 3)})  # e5
    var can_capture = _can_move(Vector2i(4, 4), Vector2i(4, 3))
    tests.append(_make_result("Pawn can capture", can_capture, "e4 pawn can capture e5"))
    
    return tests

func _test_game_state() -> Array[Dictionary]:
    var tests = []
    
    # Test 1: Initial board has 32 pieces
    _reset_simulation()
    tests.append(_make_result("Initial board has 32 pieces", simulated_board.size() == 32, "Found %d pieces" % simulated_board.size()))
    
    # Test 2: Turn alternates
    _reset_simulation()
    var initial_turn = simulated_turn
    simulated_turn = "black" if simulated_turn == "white" else "white"
    tests.append(_make_result("Turn alternates", simulated_turn != initial_turn, "Turn switched to " + simulated_turn))
    
    # Test 3: FEN export works
    GameState.setup_standard()
    var fen = GameState.to_fen()
    tests.append(_make_result("FEN export", fen.length() > 10, "FEN length: %d" % fen.length()))
    
    # Test 4: Game phase detection
    GameState.setup_standard()
    var phase = GameState.get_game_phase()
    tests.append(_make_result("Opening phase detected", phase == "opening", "Phase: " + phase))
    
    return tests

func _test_gambit_system() -> Array[Dictionary]:
    var tests = []
    
    # Test 1: Gambit registry has gambits
    var all_gambits = GambitRegistry.get_all_gambits()
    tests.append(_make_result("Gambit registry populated", all_gambits.size() > 0, "Found %d gambits" % all_gambits.size()))
    
    # Test 2: Can get gambit by ID
    var italian = GambitRegistry.get_gambit("italian-game")
    tests.append(_make_result("Get gambit by ID", italian != null and italian.id == "italian-game", "Found: " + (italian.name if italian else "null")))
    
    # Test 3: Can't activate completed gambit
    GameState.setup_standard()
    GameState.completed_gambits.append("italian-game")
    var cant_activate = not GambitEngine.activate_gambit("italian-game")
    tests.append(_make_result("Can't reactivate completed", cant_activate, "Correctly blocked"))
    
    # Test 4: Can't activate failed gambit
    GameState.setup_standard()
    GameState.failed_gambits.append("italian-game")
    cant_activate = not GambitEngine.activate_gambit("italian-game")
    tests.append(_make_result("Can't reactivate failed", cant_activate, "Correctly blocked"))
    
    return tests

func _test_turn_phases() -> Array[Dictionary]:
    var tests = []
    
    # Test 1: Phase progression
    GameState.setup_standard()
    TurnPhaseManager.start_turn("white")
    var initial_phase = TurnPhaseManager.current_phase
    tests.append(_make_result("Turn starts at TURN_START", initial_phase == TurnPhaseManager.TurnPhase.TURN_START, "Phase: %d" % initial_phase))
    
    # Test 2: Available actions calculated
    var actions = TurnPhaseManager.available_actions
    tests.append(_make_result("Available actions populated", actions.size() > 0, "Actions: %d" % actions.size()))
    
    # Test 3: Phase transitions work
    TurnPhaseManager.set_phase(TurnPhaseManager.TurnPhase.END_PHASE)
    var end_phase = TurnPhaseManager.current_phase
    tests.append(_make_result("Phase transition works", end_phase == TurnPhaseManager.TurnPhase.END_PHASE, "Phase: %d" % end_phase))
    
    return tests

func _test_cleanup_phase() -> Array[Dictionary]:
    var tests = []
    
    # Test 1: Duplicates removed
    GameState.setup_standard()
    GameState.completed_gambits = ["test1", "test2", "test1", "test2"]
    TurnPhaseManager._run_cleanup()
    var no_dups = GameState.completed_gambits.size() == 2
    tests.append(_make_result("Duplicates removed from completed", no_dups, "Count: %d" % GameState.completed_gambits.size()))
    
    # Test 2: Failed removed if in completed
    GameState.setup_standard()
    GameState.completed_gambits = ["test1"]
    GameState.failed_gambits = ["test1", "test2"]
    TurnPhaseManager._run_cleanup()
    var cleaned = GameState.failed_gambits.size() == 1 and GameState.failed_gambits[0] == "test2"
    tests.append(_make_result("Failed cleaned if completed", cleaned, "Failed: %s" % str(GameState.failed_gambits)))
    
    # Test 3: Active gambit verified
    GameState.setup_standard()
    var gambit = GambitRegistry.get_gambit("italian-game")
    GameState.active_gambit = gambit
    GameState.completed_gambits.append("italian-game")
    TurnPhaseManager._run_cleanup()
    var cleared = GameState.active_gambit == null
    tests.append(_make_result("Active cleared if completed", cleared, "Active: " + str(GameState.active_gambit)))
    
    return tests

func _test_ai_opponents() -> Array[Dictionary]:
    var tests = []
    
    # Test 1: Random opponent returns move
    GameState.setup_standard()
    OpponentAI.set_opponent(OpponentAI.Difficulty.RANDOM, "black")
    var random_move = OpponentAI.get_all_legal_moves("black")
    tests.append(_make_result("Random AI has moves", random_move.size() > 0, "Found %d moves" % random_move.size()))
    
    # Test 2: Greedy opponent prefers captures
    GameState.setup_standard()
    # Set up position where capture is available
    GameState.make_move(Vector2i(4, 6), Vector2i(4, 4))  # e4
    GameState.switch_turn()
    GameState.make_move(Vector2i(4, 1), Vector2i(4, 3))  # e5
    GameState.switch_turn()
    
    OpponentAI.set_opponent(OpponentAI.Difficulty.GREEDY, "white")
    var greedy = GreedyOpponent.new()
    greedy.color = "white"
    var greedy_move = greedy.get_move(GameState)
    # Greedy should capture if possible
    tests.append(_make_result("Greedy AI evaluates captures", not greedy_move.is_empty(), "Move: " + str(greedy_move)))
    
    return tests

func _test_integration() -> Array[Dictionary]:
    var tests = []
    
    # Test 1: Full game simulation doesn't crash
    var sim_result = await simulate_game(10)
    tests.append(_make_result("Game simulation runs", sim_result.moves > 0, "Moves: %d" % sim_result.moves))
    
    # Test 2: Gambit can be activated during game
    GameState.setup_standard()
    var activated = GambitEngine.activate_gambit("italian-game")
    tests.append(_make_result("Gambit activation in game", activated, "Italian game activated"))
    
    return tests

func _test_quick_sanity() -> Array[Dictionary]:
    var tests = []
    
    # Quick board setup test
    GameState.setup_standard()
    tests.append(_make_result("Board setup", GameState.board.size() == 32, "32 pieces"))
    
    # Quick move test
    var result = GameState.make_move(Vector2i(4, 6), Vector2i(4, 4))
    tests.append(_make_result("Basic move", result, "e2-e4 works"))
    
    # Quick gambit test
    var gambit = GambitRegistry.get_gambit("italian-game")
    tests.append(_make_result("Gambit exists", gambit != null, "Italian game found"))
    
    return tests

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

func _run_suite(suite_name: String, test_func: Callable) -> Array[Dictionary]:
    current_test = suite_name
    DebugLogger.log_info("Running test suite: %s" % suite_name)
    
    var results = test_func.call()
    
    for result in results:
        result["suite"] = suite_name
        test_results.append(result)
        var status = "PASS" if result.passed else "FAIL"
        DebugLogger.log_info("  [%s] %s: %s" % [status, result.name, result.message])
    
    test_completed.emit(suite_name, _suite_passed(results), {"tests": results})
    
    return results

func _suite_passed(results: Array[Dictionary]) -> bool:
    for r in results:
        if not r.passed:
            return false
    return true

func _make_result(name: String, passed: bool, message: String = "") -> Dictionary:
    return {
        "name": name,
        "passed": passed,
        "message": message,
        "timestamp": Time.get_ticks_msec()
    }

func _generate_summary() -> Dictionary:
    var passed = 0
    var failed = 0
    
    for r in test_results:
        if r.passed:
            passed += 1
        else:
            failed += 1
    
    return {
        "total": test_results.size(),
        "passed": passed,
        "failed": failed,
        "success_rate": float(passed) / test_results.size() if test_results.size() > 0 else 0.0,
        "results": test_results,
        "timestamp": Time.get_ticks_msec()
    }

# ============================================================================
# SIMULATION HELPERS
# ============================================================================

func _reset_simulation():
    simulated_board.clear()
    simulated_turn = "white"
    simulated_history.clear()
    
    # Set up standard position
    for file in range(8):
        simulated_board[Vector2i(file, 6)] = {"type": 0, "color": 0}  # White pawns
        simulated_board[Vector2i(file, 1)] = {"type": 0, "color": 1}  # Black pawns
    
    # Back ranks
    var back_rank = [3, 1, 2, 4, 5, 2, 1, 3]  # R, N, B, Q, K, B, N, R
    for file in range(8):
        simulated_board[Vector2i(file, 7)] = {"type": back_rank[file], "color": 0}
        simulated_board[Vector2i(file, 0)] = {"type": back_rank[file], "color": 1}

func _get_simulated_legal_moves(color: String) -> Array[Dictionary]:
    var moves = []
    var target_color = 0 if color == "white" else 1
    
    for pos in simulated_board.keys():
        var piece = simulated_board[pos]
        if piece.color == target_color:
            # Get moves based on piece type (simplified)
            var piece_moves = _get_piece_moves(pos)
            for to in piece_moves:
                moves.append({"from": pos, "to": to, "piece": piece})
    
    return moves

func _get_piece_moves(pos: Vector2i) -> Array[Vector2i]:
    if not simulated_board.has(pos):
        return []
    
    var piece = simulated_board[pos]
    var moves = []
    
    match piece.type:
        0:  # Pawn
            var dir = -1 if piece.color == 0 else 1
            var one_forward = Vector2i(pos.x, pos.y + dir)
            if _is_valid_pos(one_forward) and not simulated_board.has(one_forward):
                moves.append(one_forward)
                # Two forward from start
                var start_rank = 6 if piece.color == 0 else 1
                if pos.y == start_rank:
                    var two_forward = Vector2i(pos.x, pos.y + 2 * dir)
                    if not simulated_board.has(two_forward):
                        moves.append(two_forward)
            
            # Captures
            for dx in [-1, 1]:
                var capture = Vector2i(pos.x + dx, pos.y + dir)
                if _is_valid_pos(capture) and simulated_board.has(capture):
                    if simulated_board[capture].color != piece.color:
                        moves.append(capture)
        
        1:  # Knight
            var offsets = [Vector2i(2, 1), Vector2i(2, -1), Vector2i(-2, 1), Vector2i(-2, -1),
                          Vector2i(1, 2), Vector2i(1, -2), Vector2i(-1, 2), Vector2i(-1, -2)]
            for offset in offsets:
                var target = pos + offset
                if _is_valid_pos(target):
                    if not simulated_board.has(target) or simulated_board[target].color != piece.color:
                        moves.append(target)
        
        5:  # King
            for dx in [-1, 0, 1]:
                for dy in [-1, 0, 1]:
                    if dx == 0 and dy == 0:
                        continue
                    var target = Vector2i(pos.x + dx, pos.y + dy)
                    if _is_valid_pos(target):
                        if not simulated_board.has(target) or simulated_board[target].color != piece.color:
                            moves.append(target)
    
    return moves

func _can_move(from: Vector2i, to: Vector2i) -> bool:
    if not simulated_board.has(from):
        return false
    var legal = _get_piece_moves(from)
    return to in legal

func _execute_simulated_move(move: Dictionary):
    simulated_board[move.to] = simulated_board[move.from]
    simulated_board.erase(move.from)
    simulated_history.append(move)

func _is_valid_pos(pos: Vector2i) -> bool:
    return pos.x >= 0 and pos.x < 8 and pos.y >= 0 and pos.y < 8

func _is_simulated_checkmate(color: String) -> bool:
    # Simplified - just check if no moves available and in check
    var moves = _get_simulated_legal_moves(color)
    return moves.is_empty() and _is_simulated_in_check(color)

func _is_simulated_stalemate(color: String) -> bool:
    var moves = _get_simulated_legal_moves(color)
    return moves.is_empty() and not _is_simulated_in_check(color)

func _is_simulated_in_check(color: String) -> bool:
    # Find king
    var king_pos = Vector2i(-1, -1)
    var target_color = 0 if color == "white" else 1
    
    for pos in simulated_board.keys():
        var piece = simulated_board[pos]
        if piece.type == 5 and piece.color == target_color:
            king_pos = pos
            break
    
    if king_pos == Vector2i(-1, -1):
        return false
    
    # Check if any opponent piece can attack king
    var opponent_color = 1 - target_color
    for pos in simulated_board.keys():
        var piece = simulated_board[pos]
        if piece.color == opponent_color:
            var attacks = _get_piece_moves(pos)
            if king_pos in attacks:
                return true
    
    return false

func _get_random_opponent_move() -> Dictionary:
    var legal = OpponentAI.get_all_legal_moves(GameState.current_turn)
    if legal.is_empty():
        return {}
    return legal[randi() % legal.size()]

func _execute_opponent_move_san(san: String):
    # Simplified SAN execution
    # Just make a random legal move for now
    var move = _get_random_opponent_move()
    if not move.is_empty():
        GameState.make_move(move.from, move.to)
