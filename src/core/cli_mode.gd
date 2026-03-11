extends Node
class_name CLIMode

# Command-line interface for Pawn Chess
# Usage: godot --headless --script src/core/cli_mode.gd -- --command "move e2e4"

var game: GameCore
var running = true
var assertions_passed = 0
var assertions_failed = 0

func _ready():
    print("Pawn Chess CLI")
    print("==============\n")
    
    game = GameCore.new()
    game.move_executed.connect(_on_move)
    game.error_occurred.connect(_on_error)
    
    # Check for --test flag
    var args = OS.get_cmdline_args()
    
    if "--test" in args:
        run_test_suite()
        get_tree().quit(0 if assertions_failed == 0 else 1)
        return
    
    if "--batch" in args:
        var idx = args.find("--batch")
        if idx + 1 < args.size():
            run_batch_file(args[idx + 1])
        get_tree().quit(0)
        return
    
    # Interactive mode
    new_game()
    print(game.render_board())
    print("\nCommands: move <from><to>, gambit <id>, board, test, quit")
    print("> ", "")
    
    # Set up stdin reading
    start_stdin_loop()

func start_stdin_loop():
    while running:
        # In Godot, we can't easily read stdin asynchronously
        # So we'll use a simple timer-based approach for interactive mode
        await get_tree().create_timer(0.1).timeout
        
        # For actual CLI usage, process commands from args
        var args = OS.get_cmdline_args()
        for arg in args:
            if arg.begins_with("--command="):
                var cmd = arg.substr(10)
                process_command(cmd)
                
        if "--quit" in args or "-q" in args:
            running = false
            get_tree().quit(0)

func new_game():
    game.new_game()
    print("New game started. White to move.\n")

func process_command(line: String) -> String:
    line = line.strip_edges()
    if line.is_empty():
        return ""
    
    var parts = line.split(" ")
    var cmd = parts[0].to_lower()
    
    match cmd:
        "new", "restart":
            new_game()
            return "OK"
        
        "move", "m":
            if parts.size() < 2:
                return "Error: move requires argument (e.g., move e2e4)"
            return do_move(parts[1])
        
        "gambit", "g":
            if parts.size() < 2:
                return "Error: gambit requires id (e.g., gambit italian-game)"
            return do_gambit(parts[1])
        
        "board", "b":
            return game.render_board()
        
        "assert":
            if parts.size() < 4:
                return "Error: assert <square> has|not_has <piece>"
            return do_assert(parts[1], parts[2], parts[3])
        
        "turn":
            return "Turn: " + game.current_turn
        
        "legal":
            if parts.size() < 2:
                return "Error: legal requires square (e.g., legal e2)"
            var moves = game.get_legal_moves(parts[1])
            return "Legal moves from " + parts[1] + ": " + str(moves)
        
        "opponent", "o":
            if game.opponent_move():
                return "Opponent moved"
            return "Opponent has no legal moves"
        
        "play":
            var num_moves = 10
            if parts.size() > 1:
                num_moves = parts[1].to_int()
            return play_game(num_moves)
        
        "test":
            run_test_suite()
            return "Tests complete: " + str(assertions_passed) + " passed, " + str(assertions_failed) + " failed"
        
        "help", "h":
            return get_help()
        
        "quit", "q", "exit":
            running = false
            get_tree().quit(0)
            return "Goodbye"
        
        _:
            return "Unknown command: " + cmd + " (type 'help' for commands)"

func do_move(arg: String) -> String:
    # Parse algebraic notation: e2e4 or e2-e4
    arg = arg.replace("-", "").replace("x", "")
    
    if arg.length() != 4:
        return "Error: Move format is 'e2e4' (from square to square)"
    
    var from_sq = arg.substr(0, 2).to_lower()
    var to_sq = arg.substr(2, 2).to_lower()
    
    if game.make_move(from_sq, to_sq):
        return "Move: " + from_sq + "-" + to_sq + "\n" + game.render_board()
    return "Move failed"

func do_gambit(id: String) -> String:
    if game.activate_gambit(id):
        return "Gambit activated: " + id
    return "Failed to activate gambit"

func do_assert(square: String, condition: String, expected: String) -> String:
    square = square.to_lower()
    var piece = game.get_piece(square)
    var has_piece = not piece.is_empty()
    
    var expected_color = ""
    var expected_type = ""
    
    if expected.begins_with("white_"):
        expected_color = "white"
        expected_type = expected.substr(6)
    elif expected.begins_with("black_"):
        expected_color = "black"
        expected_type = expected.substr(6)
    
    var passed = false
    var actual = "empty"
    
    if has_piece:
        actual = piece.color + "_" + piece.type
    
    match condition:
        "has":
            passed = has_piece and piece.color == expected_color and piece.type == expected_type
        "not_has":
            passed = not has_piece or piece.color != expected_color or piece.type != expected_type
        "is_empty", "empty":
            passed = not has_piece
    
    if passed:
        assertions_passed += 1
        return "PASS: " + square + " " + condition + " " + expected
    else:
        assertions_failed += 1
        return "FAIL: " + square + " expected " + condition + " " + expected + " but was " + actual

func play_game(max_moves: int) -> String:
    var output = "Playing " + str(max_moves) + " moves...\n"
    
    for i in range(max_moves):
        var moves = game.get_all_legal_moves(game.current_turn)
        if moves.is_empty():
            output += "Game over at move " + str(i) + "\n"
            break
        
        var move = moves[randi() % moves.size()]
        if game.make_move(move.from, move.to):
            output += str(i+1) + ". " + move.from + "-" + move.to + " "
            if game.current_turn == "white":
                output += "\n"
        else:
            output += "Invalid move!\n"
            break
    
    output += "\n" + game.render_board()
    return output

func run_test_suite():
    print("\n=== RUNNING TEST SUITE ===\n")
    
    var tests = [
        ["new", "OK"],
        ["assert e2 has white_pawn", "PASS"],
        ["assert e7 has black_pawn", "PASS"],
        ["move e2e4", "Move:"],
        ["assert e4 has white_pawn", "PASS"],
        ["assert e2 is_empty", "PASS"],
        ["turn", "black"],
        ["move e7e5", "Move:"],
        ["assert e5 has black_pawn", "PASS"],
        ["legal g1", "[f3, h3]"],
        ["gambit italian-game", "activated"],
        ["assert e4 has white_pawn", "PASS"],
    ]
    
    game.new_game()
    
    for test in tests:
        var cmd = test[0]
        var expected = test[1]
        var result = process_command(cmd)
        
        if expected in result or result.begins_with(expected):
            print("✓ " + cmd)
            assertions_passed += 1
        else:
            print("✗ " + cmd)
            print("  Expected: " + expected)
            print("  Got: " + result)
            assertions_failed += 1
    
    print("\n=== RESULTS ===")
    print(str(assertions_passed) + " passed, " + str(assertions_failed) + " failed")
    
    if assertions_failed == 0:
        print("ALL TESTS PASSED ✓")

func run_batch_file(path: String):
    print("Running batch file: " + path + "\n")
    
    if not FileAccess.file_exists(path):
        print("Error: File not found: " + path)
        return
    
    var file = FileAccess.open(path, FileAccess.READ)
    while not file.eof_reached():
        var line = file.get_line().strip_edges()
        if line.is_empty() or line.begins_with("#"):
            continue
        
        print("> " + line)
        var result = process_command(line)
        if not result.is_empty():
            print(result)
        print("")

func get_help() -> String:
    return """
Commands:
  new                    Start new game
  move <from><to>        Make a move (e.g., move e2e4)
  gambit <id>            Activate gambit (e.g., gambit italian-game)
  board                  Show current board
  assert <sq> has <p>    Verify piece at square (e.g., assert e2 has white_pawn)
  assert <sq> is_empty   Verify square is empty
  turn                   Show whose turn it is
  legal <square>         Show legal moves from square
  opponent               Make opponent move
  play [n]               Play n random moves (default 10)
  test                   Run test suite
  help                   Show this help
  quit                   Exit

Examples:
  > move e2e4
  > assert e4 has white_pawn
  > gambit italian-game
  > play 20
"""

func _on_move(move: Dictionary):
    pass  # Already printed in do_move

func _on_error(msg: String):
    print("Error: " + msg)
