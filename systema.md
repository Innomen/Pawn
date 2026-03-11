# Systema - Game Development Discoveries

A catalog of lessons learned, patterns discovered, and failures analyzed.

---

## The Real Purpose of Testing

### What I Did Wrong

I wrote tests that check internal variables:
```gdscript
# This is NOT a real test
assert(GameState.board.size() == 32)
assert(GambitRegistry.get_all_gambits().size() > 0)
```

These verify data structures, not **behavior**. The game could pass all these tests and still be completely broken for players.

### What Testing Should Be

Tests should simulate a **player interacting with the game**:

```gdscript
# This IS a real test
await tester.click_square("e2")
await tester.click_square("e4")
assert_piece_at("e4", "white_pawn")
assert_square_highlighted("e4", "selected")
```

Or at the CLI level:
```bash
$ pawn cli --move "e2e4"
> White pawn moved from e2 to e4
> Black's turn

$ pawn cli --gambit "italian-game"
> Gambit activated: Italian Game
> Executing: 1.e4 e5 2.Nf3 Nc6 3.Bc4
```

### The Parallel Mode Architecture

Every game needs two modes that share the same core:

```
┌─────────────────────────────────────────┐
│           Game Core (Logic)             │
│  - Board state                          │
│  - Move validation                      │
│  - Gambit execution                     │
│  - Turn management                      │
└─────────────────────────────────────────┘
                   ▲
     ┌─────────────┴─────────────┐
     │                           │
┌────┴────┐               ┌─────┴──────┐
│ GUI Mode │               │ CLI Mode   │
│          │               │            │
│ - Click  │               │ - Commands │
│ - Render │               │ - Text out │
│ - Sounds │               │ - Batch    │
└─────────┘               └────────────┘
```

**Both modes must exercise the same code paths.** If the CLI can play a complete game, the GUI will work. If the CLI breaks, the GUI is broken too.

---

## Why The Debug Log Failed (Twice)

### Missing Pieces Bug

**What the log showed:**
```
[INFO] Standard chess position set up
[INFO] Board has 32 pieces
```

**The reality:** Pieces existed in `GameState.board` but never spawned in the scene tree.

**Why the log lied:**
- It logged the *intent* ("set up board")
- It didn't verify the *result* (nodes in scene tree)
- It couldn't see the *presentation layer* at all

### Misaligned Pieces Bug

**What the log showed:**
```
[INFO] Piece created at (320, 480)
```

**The reality:** (320, 480) is the top-left of the square. The piece anchor point was also top-left. Result: piece sits at the corner of the square, not centered.

**Why the log lied:**
- It logged pixel coordinates
- It didn't know about anchor points
- It couldn't "see" that the piece was offset

### The Root Problem

The debug log is a **logic-layer tool**. Both bugs were in the **presentation layer**:

| Bug | Layer | Tool Needed |
|-----|-------|-------------|
| Pieces not spawning | Scene tree | Scene hierarchy inspection |
| Pieces misaligned | Sprite positioning | Visual comparison |
| Button clicks ignored | Input handling | Event simulation |

**Lesson:** You need different tools for different layers. A log file is a hammer - it can't measure temperature.

---

## What Real Testing Looks Like

### Level 1: Unit Tests (Internal State)
```gdscript
func test_pawn_can_move_two_squares_from_start():
    var board = Board.new()
    board.set_square("e2", white_pawn())
    var moves = board.get_legal_moves("e2")
    assert("e4" in moves)
```

### Level 2: Integration Tests (System Interaction)
```gdscript
func test_click_selects_piece():
    var game = GameController.new()
    game.start()
    
    # Simulate player clicking e2
    game.input.click(Vector2(320, 480))
    
    assert(game.selected_square == "e2")
    assert(game.legal_moves.contains("e4"))
```

### Level 3: CLI Mode (Full Game Loop)
```bash
$ echo -e "move e2e4\ngambit italian-game\nexit" | pawn --cli

Pawn Chess CLI
==============
Board: rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w

> move e2e4
Move: e2-e4
Board: rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b

> gambit italian-game
Gambit: Italian Game (3 moves)
Executing...
1.e4 e5 2.Nf3 Nc6 3.Bc4 Bc5
Gambit complete!

> exit
```

### Level 4: Automated Player (Bot)
```gdscript
func test_bot_can_complete_game():
    var bot = ChessBot.new()
    bot.play_game(
        white_opponent = RandomAI,
        black_opponent = RandomAI,
        max_moves = 100
    )
    
    assert(game.is_game_over())
    assert(game.move_history.size() > 0)
```

---

## The CLI Mode Design

### Why CLI Mode Matters

1. **Testability**: Run 1000 games overnight, find edge cases
2. **Debuggability**: Reproduce bugs with exact commands
3. **Scriptability**: Hook into chess engines, analyze openings
4. **Accessibility**: Play without graphics, screen readers

### Architecture

```gdscript
# game_cli.gd
extends Node

var game: GameCore

func _ready():
    game = GameCore.new()
    game.move_made.connect(_on_move)
    game.gambit_completed.connect(_on_gambit)
    
    if OS.has_feature("standalone"):
        run_interactive()
    else:
        run_test_suite()

func run_interactive():
    while true:
        var line = await OS.read_stdin_line()
        var result = parse_command(line)
        print(result)

func parse_command(line: String) -> String:
    var parts = line.split(" ")
    match parts[0]:
        "move":
            return do_move(parts[1])  # "e2e4"
        "gambit":
            return do_gambit(parts[1])  # "italian-game"
        "board":
            return render_board()
        "test":
            return run_test()
        _:
            return "Unknown command"
```

### Usage

```bash
# Interactive play
$ pawn --cli
> board
  a b c d e f g h
8 ♜ ♞ ♝ ♛ ♚ ♝ ♞ ♜
7 ♟ ♟ ♟ ♟ ♟ ♟ ♟ ♟
...
> move e2e4
Pawn e2-e4
> gambit italian-game
Gambit activated!
...

# Batch testing
$ cat test_game.txt | pawn --cli --verify
Running 50 commands...
All assertions passed.

# Headless testing (what I should have done)
$ pawn --cli --test-all
Test Suite: 47/47 passed
```

---

## What I Should Build

### Immediate Fix

1. **CLI Mode** that can:
   - Load a game
   - Execute moves by command
   - Activate gambits
   - Print board state
   - Verify assertions

2. **Automated Test Runner** that:
   - Feeds commands to CLI mode
   - Checks outputs
   - Runs 100 game simulations
   - Reports failures

3. **Visual Smoke Test** that:
   - Opens the GUI
   - Takes a screenshot
   - Compares to reference
   - Fails if pixels don't match

### Example Test Script

```bash
#!/bin/bash
# test_full_game.sh

echo "Testing complete game flow..."

# Test 1: Basic moves
./pawn --cli << 'EOF'
assert board e2 has white_pawn
move e2 e4
assert board e4 has white_pawn
assert turn is black
EOF

# Test 2: Gambit activation
./pawn --cli << 'EOF'
gambit italian-game
assert active_gambit is "italian-game"
assert board e4 has white_pawn
assert board e5 has black_pawn
assert board f3 has white_knight
EOF

# Test 3: Complete random game
./pawn --cli --simulation --moves 50
assert game_over
```

---

## Updated Testing Philosophy

### Old (Broken) Approach
```
Test internal state directly
↓
State is correct
↓
Assume game works
↓
User reports bugs
```

### New (Correct) Approach
```
Test through the same interface as users
↓
CLI mode tests commands
GUI mode tests clicks
↓
Both use same GameCore
↓
If CLI works, GUI works
↓
Bugs caught before release
```

---

## The Fundamental Insight

**You cannot test a GUI by testing its data model.**

A game has three layers:
1. **Data** (GameState, board array)
2. **Logic** (move validation, turn order)
3. **Interface** (clicks, rendering, buttons)

My tests covered #1 and #2. The bugs were in #3.

**The fix:** Build a CLI mode that exercises #1 and #2 through commands. Then either:
- Use screenshot comparison for #3, OR
- Accept that GUI bugs need visual testing

But never, ever assume that "the data is correct" means "the game works."

---

## Action Items

1. [ ] Create CLI mode (`--cli` flag)
2. [ ] Implement commands: `move`, `gambit`, `board`, `assert`
3. [ ] Create test script runner
4. [ ] Run 1000 automated games
5. [ ] Fix button clicks (input handling bug)
6. [ ] Add screenshot comparison for visual tests
