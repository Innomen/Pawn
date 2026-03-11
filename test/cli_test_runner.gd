extends SceneTree

# CLI Test Runner - Entry point for headless testing
# Usage: godot --headless --script test/cli_test_runner.gd

var cli_mode: CLIMode

func _initialize():
    # Add autoloads manually since we're running as a script
    _setup_autoloads()
    
    # Create and run CLI mode
    cli_mode = CLIMode.new()
    root.add_child(cli_mode)
    
    # Check for test flag
    var args = OS.get_cmdline_args()
    
    if "--test" in args:
        # Run test suite and exit
        cli_mode.run_test_suite()
        await get_tree().create_timer(0.5).timeout
        quit(0 if cli_mode.assertions_failed == 0 else 1)
    elif "--batch" in args:
        var idx = args.find("--batch")
        if idx + 1 < args.size():
            cli_mode.run_batch_file(args[idx + 1])
        await get_tree().create_timer(0.5).timeout
        quit(0)
    else:
        # Interactive mode
        cli_mode._ready()

func _setup_autoloads():
    # Load and instantiate autoloads
    var DebugLoggerScript = load("res://src/autoload/debug_logger.gd")
    var GambitRegistryScript = load("res://src/gambits/gambit_registry.gd")
    
    if DebugLoggerScript:
        var dl = DebugLoggerScript.new()
        dl.name = "DebugLogger"
        root.add_child(dl)
    
    if GambitRegistryScript:
        var gr = GambitRegistryScript.new()
        gr.name = "GambitRegistry"
        root.add_child(gr)
