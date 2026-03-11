extends Node

var _gambits: Dictionary = {}
var _initialized: bool = false

func _ready():
    _initialize_gambits()
    print("GambitRegistry initialized with " + str(_gambits.size()) + " gambits")

func _initialize_gambits():
    if _initialized:
        return
    
    _initialized = true
    
    # Register openings
    _register_opening_gambits()
    
    # Register tactics
    _register_tactic_gambits()
    
    # Register endgames
    _register_endgame_gambits()

func _register_opening_gambits():
    # Italian Game
    var italian = Gambit.new()
    italian.id = "italian-game"
    italian.name = "Italian Game"
    italian.category = "opening"
    italian.difficulty = 1
    italian.description = "Classical opening: 1.e4 e5 2.Nf3 Nc6 3.Bc4"
    italian.moves = ["e4", "Nf3", "Bc4"]
    italian.expected_responses = ["e5", "Nc6", "Nf6"]
    italian.for_color = "white"
    _gambits[italian.id] = italian
    
    # Sicilian Defense
    var sicilian = Gambit.new()
    sicilian.id = "sicilian-defense"
    sicilian.name = "Sicilian Defense"
    sicilian.category = "opening"
    sicilian.difficulty = 2
    sicilian.description = "Hypermodern defense: 1.e4 c5"
    sicilian.moves = ["c5"]
    sicilian.expected_responses = ["Nf3", "Nc3"]
    sicilian.for_color = "black"
    _gambits[sicilian.id] = sicilian
    
    # Ruy Lopez
    var ruy_lopez = Gambit.new()
    ruy_lopez.id = "ruy-lopez"
    ruy_lopez.name = "Ruy Lopez"
    ruy_lopez.category = "opening"
    ruy_lopez.difficulty = 2
    ruy_lopez.description = "Spanish Opening: 1.e4 e5 2.Nf3 Nc6 3.Bb5"
    ruy_lopez.moves = ["e4", "Nf3", "Bb5"]
    ruy_lopez.expected_responses = ["e5", "Nc6", "a6"]
    ruy_lopez.for_color = "white"
    _gambits[ruy_lopez.id] = ruy_lopez
    
    # Queen's Gambit
    var queens = Gambit.new()
    queens.id = "queens-gambit"
    queens.name = "Queen's Gambit"
    queens.category = "opening"
    queens.difficulty = 2
    queens.description = "1.d4 d5 2.c4"
    queens.moves = ["d4", "c4"]
    queens.expected_responses = ["d5", "dxc4"]
    queens.for_color = "white"
    _gambits[queens.id] = queens

func _register_tactic_gambits():
    # Knight Fork
    var fork = Gambit.new()
    fork.id = "knight-fork"
    fork.name = "Knight Fork"
    fork.category = "tactic"
    fork.difficulty = 2
    fork.description = "Attack two pieces simultaneously with a knight"
    fork.moves = ["Nf3+"]  # Example - would need to be dynamic
    fork.for_color = "white"
    _gambits[fork.id] = fork
    
    # Pin
    var pin = Gambit.new()
    pin.id = "pin"
    pin.name = "Pin & Skewer"
    pin.category = "tactic"
    pin.difficulty = 3
    pin.description = "Pin a piece to the king or queen"
    pin.moves = ["Bg5"]
    pin.for_color = "white"
    _gambits[pin.id] = pin
    
    # Discovered Attack
    var discovered = Gambit.new()
    discovered.id = "discovered-attack"
    discovered.name = "Discovered Attack"
    discovered.category = "tactic"
    discovered.difficulty = 4
    discovered.description = "Move one piece to reveal an attack from another"
    discovered.moves = []
    discovered.for_color = "white"
    _gambits[discovered.id] = discovered

func _register_endgame_gambits():
    # Opposition
    var opposition = Gambit.new()
    opposition.id = "opposition"
    opposition.name = "Opposition"
    opposition.category = "endgame"
    opposition.difficulty = 3
    opposition.description = "Use opposition to force pawn promotion"
    opposition.moves = ["Ke2"]
    opposition.for_color = "white"
    _gambits[opposition.id] = opposition

func get_gambit(id: String) -> Gambit:
    if _gambits.has(id):
        return _gambits[id]
    return null

func get_all_gambits() -> Array:
    return _gambits.values()

func get_gambits_by_category(category: String) -> Array:
    var result = []
    for gambit in _gambits.values():
        if gambit.category == category:
            result.append(gambit)
    return result

func get_gambits_by_color(color: String) -> Array:
    var result = []
    for gambit in _gambits.values():
        if gambit.for_color == color:
            result.append(gambit)
    return result

func search_gambits(query: String) -> Array:
    var result = []
    var lower_query = query.to_lower()
    for gambit in _gambits.values():
        if lower_query in gambit.name.to_lower() or lower_query in gambit.description.to_lower():
            result.append(gambit)
    return result
