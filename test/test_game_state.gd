extends GutTest

var game_state = null

func before_each():
    game_state = GameState
    game_state.setup_standard()

func test_standard_setup():
    # Check that board has 32 pieces
    assert_eq(game_state.board.size(), 32)
    
    # Check kings are in correct positions
    assert_true(game_state.board.has(Vector2i(4, 7)))  # White king
    assert_true(game_state.board.has(Vector2i(4, 0)))  # Black king

func test_pawn_move():
    # e2 pawn to e4
    var result = game_state.make_move(Vector2i(4, 6), Vector2i(4, 4))
    assert_true(result)
    
    # Check piece moved
    assert_false(game_state.board.has(Vector2i(4, 6)))
    assert_true(game_state.board.has(Vector2i(4, 4)))

func test_knight_move():
    # Knight b1 to c3
    var result = game_state.make_move(Vector2i(1, 7), Vector2i(2, 5))
    assert_true(result)
    
    # Check piece moved
    assert_false(game_state.board.has(Vector2i(1, 7)))
    assert_true(game_state.board.has(Vector2i(2, 5)))

func test_illegal_move():
    # Try to move piece out of turn
    var result = game_state.make_move(Vector2i(4, 1), Vector2i(4, 3))  # Black pawn
    assert_false(result)  # Should fail - white to move

func test_turn_switch():
    assert_eq(game_state.current_turn, "white")
    
    game_state.make_move(Vector2i(4, 6), Vector2i(4, 4))  # e4
    game_state.switch_turn()
    
    assert_eq(game_state.current_turn, "black")

func test_fen_export():
    var fen = game_state.to_fen()
    assert_true(fen.begins_with("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR"))

func test_game_phase():
    # New game should be opening
    assert_eq(game_state.get_game_phase(), "opening")

func test_legal_moves():
    # Pawn should have 2 moves from starting position
    var moves = game_state.get_legal_moves(Vector2i(4, 6))  # e2 pawn
    assert_eq(moves.size(), 2)
    
    # Knight should have 2 moves from starting position
    moves = game_state.get_legal_moves(Vector2i(1, 7))  # b1 knight
    assert_eq(moves.size(), 2)

func test_completed_gambits_cleanup():
    game_state.completed_gambits = ["test1", "test2", "test1", "test3", "test2"]
    
    # Run cleanup via TurnPhaseManager
    TurnPhaseManager._run_cleanup()
    
    assert_eq(game_state.completed_gambits.size(), 3)
    assert_true("test1" in game_state.completed_gambits)
    assert_true("test2" in game_state.completed_gambits)
    assert_true("test3" in game_state.completed_gambits)
