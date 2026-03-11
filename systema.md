# Systema - Game Development Discoveries

A catalog of lessons learned, patterns discovered, and failures analyzed during the development of Pawn Chess.

---

## The Point of Headless Testing

Headless testing is not just "testing without graphics" - it's about **verifying game logic independent of presentation**.

### What Headless Testing Catches
- **Logic errors**: Move validation, state transitions, win conditions
- **Data integrity**: Gambit registry loading, completed/failed lists
- **AI behavior**: Opponent move generation, evaluation functions
- **Game flow**: Turn phases, cleanup operations

### What Headless Testing Does NOT Catch
- **Visual bugs**: Pieces not rendering, wrong colors, misalignment
- **Input handling**: Click detection, UI responsiveness
- **Timing issues**: Race conditions between initialization order
- **Asset loading**: Missing textures, wrong file paths

### The Real Value
Headless tests prove your **game simulation** works. They don't prove your **game** works. A passing headless test with 100% coverage can still result in a black screen.

### Best Practice
Run headless tests continuously during development, but never skip **visual verification**. The ideal workflow:
1. Headless test passes → logic is sound
2. Visual test passes → presentation is sound
3. Both pass → feature is actually done

---

## Debug Log Limitations - Case Study: Missing Pieces

### The Error
Pieces didn't load on the board. The debug log showed:
```
[INFO] Standard chess position set up
[INFO] GameState initialized
```

Everything appeared correct. But the board was empty.

### Why The Debug Log Failed

**1. Logging What Should Happen vs What Did Happen**

The log recorded that `setup_standard()` was called. It did NOT verify that:
- The board actually contained 32 pieces after setup
- The pieces were rendered to the screen
- The piece nodes were children of the board node

**The fix**: Log the result, not just the action:
```gdscript
# Bad
DebugLogger.log_info("Standard chess position set up")

# Good
DebugLogger.log_info("Board setup complete: " + str(board.size()) + " pieces")
```

**2. Race Conditions Are Invisible**

The bug was a timing issue: `BoardView._ready()` ran before `GameController.start_new_game()`. The log showed both events happening, but not their **order** relative to each other.

Debug logs are sequential but don't capture the **temporal relationship** between systems.

**3. Visual Layer Is Unverified**

Even if the log showed "32 pieces created", it wouldn't catch:
- Pieces positioned off-screen
- Pieces scaled to 0
- Pieces behind the board
- Pieces with transparent textures

The debug log lives in the **logic layer**. The bug was in the **presentation layer**.

---

## Debug Log Limitations - Case Study: Misaligned Pieces

### The Hypothetical Error
Pieces render, but are offset by 10 pixels - sitting on square corners instead of centers.

### Why The Debug Log Would Fail

**1. Pixel-Perfect Issues Don't Exist in Logic**

The debug log would show:
```
[INFO] Created piece at (4, 6)
[INFO] Piece position: (320, 480)
```

These are "correct" values. The bug is that (320, 480) is the top-left corner when it should be the center, or the square size is 80 but the piece offset calculation used 90.

**2. Coordinate Systems Are Invisible**

The log shows board coordinates (4, 6) and pixel coordinates (320, 480). It doesn't show:
- Sprite anchor points (top-left vs center)
- Texture dimensions
- Parent node transforms
- Camera/viewport settings

**3. No Visual Reference**

A human eye immediately sees misalignment. The debug log has no "reference image" to compare against. It operates on data, not appearance.

---

## Lessons Learned

### 1. Layer Your Verification

| Layer | Tool | Catches |
|-------|------|---------|
| Logic | Headless tests | State, calculations, AI |
| Integration | Debug logs | Flow, timing, values |
| Visual | Eyeballs / screenshot comparison | Position, color, visibility |
| Input | Manual/Automated UI tests | Click handling, responsiveness |

### 2. Log State, Not Just Events

Don't just log "move made" - log the resulting position:
```gdscript
# Bad
DebugLogger.log_info("Move made")

# Good  
DebugLogger.log_info("After move: " + GameState.to_fen())
```

### 3. Verify at System Boundaries

The pieces bug occurred at the boundary between GameState (logic) and BoardView (presentation). Add verification at these boundaries:

```gdscript
# In BoardView after creating pieces
assert(pieces_node.get_child_count() == GameState.board.size(), 
       "Piece count mismatch!")
```

### 4. Headless Tests Need Visual Counterparts

A comprehensive test for the pieces system would include:
- **Headless**: Verify board has 32 pieces after setup
- **Visual**: Screenshot comparison of initial position
- **Interactive**: Click square, verify piece selected

### 5. Timing Bugs Are the Hardest

The initialization order bug was invisible to both tests and logs because both systems "worked" - they just worked in the wrong order.

**Pattern**: When visual elements are missing despite correct data, suspect:
- Initialization order
- Signal connection timing  
- Scene tree readiness
- Async loading (shaders, textures)

**Diagnostic**: Add explicit synchronization points:
```gdscript
await get_tree().process_frame  # Wait for frame
await get_tree().create_timer(0.1).timeout  # Wait for setup
```

---

## The Fundamental Truth

**You cannot debug what you cannot see.**

The debug log is a window into logic. Headless tests verify simulation. But only visual inspection (manual or automated) can verify that the **player experience** matches the **developer intent**.

The missing pieces weren't a logic bug - they were a **reality gap**. The game state said pieces existed. The screen said otherwise. The debug log believed the game state.

Always verify in the **domain where the bug manifests**.

---

## Recommendations for Future Projects

1. **Screenshot tests**: Capture reference images of key game states, compare in CI
2. **Debug visualization**: Press F3 to show collision boxes, anchor points, coordinates
3. **State inspectors**: In-game panel showing live game state vs rendered state
4. **Smoke tests**: Automated "does it boot and show the main screen" check
5. **Assertion layers**: `assert_rendered_piece_count_equals_state()`

The debug log is a tool. Like all tools, it has a specific domain. Do not expect a hammer to measure distance.
