extends Node

const LOG_FILE_PATH = "user://debug_log.txt"
const MAX_LOG_SIZE = 1024 * 1024  # 1MB max log size

enum LogLevel { DEBUG, INFO, WARNING, ERROR }

var log_file: FileAccess = null
var session_start_time: int = 0

func _ready():
    session_start_time = Time.get_ticks_msec()
    _initialize_log()
    log_info("=== Pawn Chess Debug Log Started ===")
    log_info("Session ID: " + str(session_start_time))

func _initialize_log():
    # Clear existing log on new session
    log_file = FileAccess.open(LOG_FILE_PATH, FileAccess.WRITE)
    if log_file:
        log_file.store_line("=== Pawn Chess Debug Log ===")
        log_file.store_line("Started: " + _get_timestamp())
        log_file.store_line("")
        log_file.flush()

func _get_timestamp() -> String:
    var dt = Time.get_datetime_dict_from_system()
    return "%04d-%02d-%02d %02d:%02d:%02d" % [dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second]

func _get_elapsed() -> String:
    var elapsed = Time.get_ticks_msec() - session_start_time
    return "+%dms" % elapsed

func _format_message(level: String, message: String) -> String:
    return "[%s] %s [%s] %s" % [_get_timestamp(), _get_elapsed(), level, message]

func _write(level: String, message: String):
    var formatted = _format_message(level, message)
    print(formatted)
    
    if log_file:
        log_file.store_line(formatted)
        log_file.flush()
        
        # Check file size and rotate if needed
        _check_log_size()

func _check_log_size():
    if log_file:
        var pos = log_file.get_position()
        if pos > MAX_LOG_SIZE:
            # Rotate log - start fresh
            log_file.close()
            log_file = FileAccess.open(LOG_FILE_PATH, FileAccess.WRITE)
            log_file.store_line("=== Log rotated (previous exceeded 1MB) ===")
            log_file.store_line("Restarted: " + _get_timestamp())
            log_file.flush()

func log_debug(message: String):
    _write("DEBUG", message)

func log_info(message: String):
    _write("INFO", message)

func log_warning(message: String):
    _write("WARN", message)

func log_error(message: String):
    _write("ERROR", message)

func log_game_event(event_type: String, details: Dictionary = {}):
    var msg = "GAME_EVENT: " + event_type
    if not details.is_empty():
        msg += " | " + str(details)
    log_info(msg)

func log_move(from_pos: Vector2i, to_pos: Vector2i, piece_type: String, color: String):
    log_game_event("MOVE", {
        "from": "%c%d" % [char(97 + from_pos.x), 8 - from_pos.y],
        "to": "%c%d" % [char(97 + to_pos.x), 8 - to_pos.y],
        "piece": piece_type,
        "color": color
    })

func log_gambit_activated(gambit_id: String, gambit_name: String):
    log_game_event("GAMBIT_ACTIVATED", {
        "id": gambit_id,
        "name": gambit_name
    })

func log_gambit_completed(gambit_id: String, success: bool, reason: String = ""):
    log_game_event("GAMBIT_ENDED", {
        "id": gambit_id,
        "success": success,
        "reason": reason
    })

func log_phase_change(phase: String, turn: String):
    log_game_event("PHASE_CHANGE", {
        "phase": phase,
        "turn": turn
    })

func log_cleanup_results(results: Dictionary):
    log_game_event("CLEANUP", results)

func log_error_with_stack(message: String):
    var stack = get_stack()
    var stack_str = ""
    for frame in stack:
        stack_str += "\n  at %s:%d (%s)" % [frame.source, frame.line, frame.function]
    log_error(message + stack_str)

func get_log_path() -> String:
    return LOG_FILE_PATH

func get_log_contents() -> String:
    if FileAccess.file_exists(LOG_FILE_PATH):
        return FileAccess.get_file_as_string(LOG_FILE_PATH)
    return ""

func clear_log():
    _initialize_log()
    log_info("=== Log manually cleared ===")
