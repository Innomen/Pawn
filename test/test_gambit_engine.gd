extends GutTest

func test_gambit_registry():
    var gambit = GambitRegistry.get_gambit("italian-game")
    assert_not_null(gambit)
    assert_eq(gambit.name, "Italian Game")

func test_gambit_activation():
    GameState.setup_standard()
    
    var result = GambitEngine.activate_gambit("italian-game")
    assert_true(result)
    assert_eq(GambitEngine.active_gambit.id, "italian-game")

func test_cannot_activate_completed_gambit():
    GameState.setup_standard()
    GameState.completed_gambits.append("italian-game")
    
    var result = GambitEngine.activate_gambit("italian-game")
    assert_false(result)

func test_cannot_activate_failed_gambit():
    GameState.setup_standard()
    GameState.failed_gambits.append("italian-game")
    
    var result = GambitEngine.activate_gambit("italian-game")
    assert_false(result)

func test_gambit_completion():
    GameState.setup_standard()
    
    GambitEngine.activate_gambit("italian-game")
    assert_true(GambitEngine.active_gambit != null)
    
    # Simulate completing all moves
    GambitEngine._complete_gambit()
    
    assert_true("italian-game" in GameState.completed_gambits)
    assert_null(GambitEngine.active_gambit)

func test_gambit_interruption():
    GameState.setup_standard()
    
    GambitEngine.activate_gambit("italian-game")
    
    GambitEngine.interrupt_gambit("Test interruption")
    
    assert_true("italian-game" in GameState.failed_gambits)
    assert_null(GambitEngine.active_gambit)
