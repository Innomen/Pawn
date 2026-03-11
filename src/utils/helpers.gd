class_name Helpers

static func board_pos_to_algebraic(pos: Vector2i) -> String:
    var file = char(97 + pos.x)  # 'a' to 'h'
    var rank = 8 - pos.y          # 8 to 1
    return file + str(rank)

static func algebraic_to_board_pos(algebraic: String) -> Vector2i:
    if algebraic.length() < 2:
        return Vector2i(-1, -1)
    
    var file = algebraic[0].to_lower()
    var rank = algebraic[1]
    
    var x = file.unicode_at(0) - 97  # 'a' = 0
    var y = 8 - int(rank)             # '8' = 0
    
    return Vector2i(x, y)

static func get_piece_char(type: int, color: int) -> String:
    var chars = ["♙", "♘", "♗", "♖", "♕", "♔"]  # White
    if color == 1:  # Black
        chars = ["♟", "♞", "♝", "♜", "♛", "♚"]
    
    if type >= 0 and type < 6:
        return chars[type]
    return "?"

static func format_time(seconds: float) -> String:
    var mins = int(seconds / 60)
    var secs = int(seconds) % 60
    return str(mins).pad_zeros(2) + ":" + str(secs).pad_zeros(2)
