extends Sprite2D

signal clicked(piece: Dictionary)

var piece_data: Dictionary = {}
var piece_color: int = 0
var piece_type: int = 0

func setup(data: Dictionary):
    piece_data = data
    piece_type = data.type
    piece_color = data.color
    
    _load_texture()

func _load_texture():
    var color_name = "white" if piece_color == GameState.PieceColor.WHITE else "black"
    var type_name = _get_type_name(piece_type)
    var texture_path = "res://assets/pieces/" + color_name + "_" + type_name + ".svg"
    
    # Check if texture exists, otherwise use placeholder
    if FileAccess.file_exists(texture_path):
        texture = load(texture_path)
    else:
        # Create a simple colored rectangle as placeholder
        _create_placeholder()
    
    # Set up click area
    _setup_click_area()

func _create_placeholder():
    var color = Color.WHITE if piece_color == GameState.PieceColor.WHITE else Color.BLACK
    var type_chars = ["♟", "♞", "♝", "♜", "♛", "♚"]
    var char = type_chars[piece_type]
    
    # Create a label to show the piece
    var label = Label.new()
    label.text = char
    label.modulate = color
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", 60)
    label.custom_minimum_size = Vector2(80, 80)
    
    # Center the label on the square (relative to parent Sprite2D center)
    add_child(label)
    label.position = Vector2(-40, -40)  # Offset by half the label size to center it

func _setup_click_area():
    var area = Area2D.new()
    var collision = CollisionShape2D.new()
    var shape = RectangleShape2D.new()
    
    shape.size = Vector2(80, 80)
    collision.shape = shape
    
    area.add_child(collision)
    add_child(area)
    
    area.input_event.connect(_on_input_event)

func _on_input_event(viewport, event, shape_idx):
    if event is InputEventMouseButton and event.pressed:
        clicked.emit(piece_data)

func _get_type_name(type: int) -> String:
    match type:
        GameState.PieceType.PAWN: return "pawn"
        GameState.PieceType.KNIGHT: return "knight"
        GameState.PieceType.BISHOP: return "bishop"
        GameState.PieceType.ROOK: return "rook"
        GameState.PieceType.QUEEN: return "queen"
        GameState.PieceType.KING: return "king"
    return "pawn"
