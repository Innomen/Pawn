# Pawn Chess - Godot Edition

A chess game with gambit (opening/tactic) macros built in Godot 4.x.

## Features

- **Full Chess Engine**: Complete move validation, check/checkmate detection, FEN support
- **Gambit System**: Auto-execute openings and tactics with one click
- **Multiple AI Opponents**: Random, Greedy, and Minimax-based opponents
- **Turn Phase System**: MTG-style turn phases for coherent state management
- **Cleanup Phase**: Removes stale/expired gambits every turn

## Gambits

### Openings (White)
- Italian Game - Classical development
- Ruy Lopez - Spanish Opening
- Queen's Gambit - d4 opening

### Openings (Black)
- Sicilian Defense - Hypermodern c5

### Tactics
- Knight Fork - Attack two pieces
- Pin & Skewer - Tactical motifs
- Discovered Attack - Reveal attacks

## How to Play

1. Open the project in Godot 4.x
2. Run `main.tscn`
3. Click on a piece to see legal moves
4. Click on highlighted squares to move
5. Use the Gambit Panel to auto-execute openings

## Controls

- **Left Click**: Select piece / Move
- **Gambit Buttons**: Auto-execute opening/tactic
- **Suggest Move**: Get AI suggestion when stuck

## AI Difficulty

- **Random Randy**: Makes random legal moves
- **Greedy Gary**: Captures material, weak to tactics
- **Master Minimax**: Looks 3 moves ahead
- **Expert Emma**: Looks 4 moves ahead

## Project Structure

```
Pawn/
├── project.godot          # Godot project file
├── src/
│   ├── autoload/         # Singletons (GameState, GambitEngine, etc.)
│   ├── core/             # Core game logic
│   ├── gambits/          # Gambit definitions and registry
│   ├── opponents/        # AI opponent implementations
│   ├── ui/               # UI components and scripts
│   └── utils/            # Helper functions
├── scenes/               # Godot scene files
├── test/                 # Unit tests (GUT)
└── assets/               # Images, sounds, fonts
```

## Testing

Install GUT (Godot Unit Testing) addon, then run tests from the editor or command line:

```bash
godot --path . --headless --script res://addons/gut/gut_cmdln.gd
godot --path . --headless --script res://addons/gut/gut_cmdln.gd -gdir=res://test
```

## Architecture

### Autoload Singletons

- **GameState**: Board representation, move validation, game state
- **GambitEngine**: Auto-execution of gambits, move sequences
- **OpponentAI**: AI opponent interface and implementations
- **TurnPhaseManager**: MTG-style turn phases, cleanup

### Turn Phases

1. **TURN_START**: Calculate available gambits
2. **MAIN_PHASE**: Player acts
3. **MOVE_RESOLUTION**: Execute move
4. **GAMBIT_CHECK**: Check gambit status
5. **END_PHASE**: Cleanup stale gambits
6. **TURN_END**: Switch player

## License

MIT
