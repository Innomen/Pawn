extends Control

@onready var log_text: RichTextLabel = %LogText
@onready var command_input: LineEdit = %CommandInput
@onready var test_results: VBoxContainer = %TestResults

var is_visible: bool = false

func _ready():
    visible = false
    
    # Connect signals
    HeadlessTester.test_completed.connect(_on_test_completed)
    HeadlessTester.all_tests_completed.connect(_on_all_tests_completed)
    
    # Style the log
    log_text.syntax_highlighter = CodeHighlighter.new()

func _input(event):
    if event is InputEventKey and event.pressed:
        # Toggle console with F12 or Ctrl+L
        if event.keycode == KEY_F12 or (event.ctrl_pressed and event.keycode == KEY_L):
            toggle_visibility()
        
        # Quick test shortcuts
        if event.ctrl_pressed and event.keycode == KEY_T:
            _run_quick_test()
        
        if event.ctrl_pressed and event.keycode == KEY_S:
            _simulate_game()

func toggle_visibility():
    is_visible = not is_visible
    visible = is_visible
    
    if is_visible:
        _refresh_log()
        command_input.grab_focus()

func _refresh_log():
    var log_content = DebugLogger.get_log_contents()
    log_text.text = log_content
    
    # Auto-scroll to bottom
    log_text.scroll_to_line(log_text.get_line_count() - 1)

func _on_command_entered(text: String):
    if text.is_empty():
        return
    
    DebugLogger.log_info("Console command: " + text)
    
    var parts = text.split(" ")
    var command = parts[0].to_lower()
    var args = parts.slice(1)
    
    match command:
        "test":
            _run_test_command(args)
        "simulate":
            _simulate_game_command(args)
        "clear":
            DebugLogger.clear_log()
            _refresh_log()
        "gambit":
            _test_gambit_command(args)
        "log":
            _refresh_log()
        "help":
            _show_help()
        _:
            _add_console_line("Unknown command: " + command + " (type 'help' for commands)")
    
    command_input.clear()

func _run_test_command(args: Array):
    if args.is_empty() or args[0] == "all":
        _add_console_line("[color=yellow]Running all tests...[/color]")
        _clear_test_results()
        var results = await HeadlessTester.run_all_tests()
        _display_summary(results)
    elif args[0] == "quick":
        _add_console_line("[color=yellow]Running quick sanity check...[/color]")
        _clear_test_results()
        var results = await HeadlessTester.run_quick_test()
        _display_summary(results)
    else:
        _add_console_line("[color=red]Unknown test type: " + args[0] + "[/color]")

func _simulate_game_command(args: Array):
    var moves = 20
    if args.size() > 0:
        moves = args[0].to_int()
    
    _add_console_line("[color=yellow]Simulating game (max %d moves)...[/color]" % moves)
    var result = await HeadlessTester.simulate_game(moves)
    _add_console_line("[color=green]Simulation complete: %d moves, game_over=%s[/color]" % [
        result.moves, str(result.game_over)
    ])

func _test_gambit_command(args: Array):
    if args.is_empty():
        _add_console_line("[color=red]Usage: gambit <gambit_id>[/color]")
        return
    
    var gambit_id = args[0]
    _add_console_line("[color=yellow]Testing gambit: " + gambit_id + "[/color]")
    var result = await HeadlessTester.test_gambit_scenario(gambit_id)
    
    if result.activated:
        if result.completed:
            _add_console_line("[color=green]✓ Gambit completed successfully[/color]")
        elif result.interrupted:
            _add_console_line("[color=orange]⚠ Gambit interrupted: " + result.reason + "[/color]")
        else:
            _add_console_line("[color=yellow]? Gambit test incomplete[/color]")
    else:
        _add_console_line("[color=red]✗ Failed to activate gambit[/color]")

func _show_help():
    var help_text = """
[color=cyan]=== Pawn Debug Console ===[/color]

Commands:
  [color=green]test all[/color]        - Run complete test suite
  [color=green]test quick[/color]      - Run quick sanity check
  [color=green]simulate [n][/color]     - Simulate a game (default 20 moves)
  [color=green]gambit <id>[/color]     - Test a specific gambit
  [color=green]clear[/color]           - Clear the debug log
  [color=green]log[/color]             - Refresh log display
  [color=green]help[/color]            - Show this help

Shortcuts:
  [color=yellow]F12 / Ctrl+L[/color]    - Toggle this console
  [color=yellow]Ctrl+T[/color]          - Run quick test
  [color=yellow]Ctrl+S[/color]          - Simulate game

Available Gambits:[/color]
  - italian-game
  - sicilian-defense
  - ruy-lopez
  - queens-gambit
  - knight-fork
  - pin
"""
    _add_console_line(help_text)

func _on_test_completed(test_name: String, passed: bool, results: Dictionary):
    var color = "green" if passed else "red"
    var symbol = "✓" if passed else "✗"
    _add_test_result_line("[%s] [color=%s]%s %s[/color]" % [symbol, color, test_name, "PASSED" if passed else "FAILED"])

func _on_all_tests_completed(summary: Dictionary):
    _display_summary(summary)

func _display_summary(summary: Dictionary):
    var color = "green" if summary.failed == 0 else "orange" if summary.failed < summary.total / 2 else "red"
    var summary_text = """
[color=%s]=== Test Summary ===
Passed: %d/%d (%.1f%%)
Failed: %d[/color]
""" % [color, summary.passed, summary.total, summary.success_rate * 100, summary.failed]
    
    _add_console_line(summary_text)
    _refresh_log()

func _add_console_line(text: String):
    log_text.append_text(text + "\n")
    log_text.scroll_to_line(log_text.get_line_count() - 1)

func _add_test_result_line(text: String):
    var label = Label.new()
    label.text = text
    test_results.add_child(label)

func _clear_test_results():
    for child in test_results.get_children():
        child.queue_free()

func _run_quick_test():
    toggle_visibility()
    _clear_test_results()
    _add_console_line("[color=yellow]Running quick test (Ctrl+L to view)...[/color]")
    var results = await HeadlessTester.run_quick_test()
    _display_summary(results)

func _simulate_game():
    toggle_visibility()
    _add_console_line("[color=yellow]Simulating game...[/color]")
    var result = await HeadlessTester.simulate_game(15)
    _add_console_line("[color=green]Game simulated: %d moves[/color]" % result.moves)

func _on_command_input_text_submitted(new_text: String):
    _on_command_entered(new_text)
