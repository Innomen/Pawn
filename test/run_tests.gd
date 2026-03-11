@tool
extends EditorScript

# Run this from Godot Editor: Project > Tools > Run Tests
# Or from command line: godot --headless --script test/run_tests.gd

func _run():
    print("="*50)
    print("PAWN CHESS - HEADLESS TEST RUNNER")
    print("="*50)
    print("")
    
    # Wait for autoloads to be ready
    await Engine.get_main_loop().create_timer(0.5).timeout
    
    # Run all tests
    print("Starting test execution...")
    print("")
    
    var results = await HeadlessTester.run_all_tests()
    
    # Print results
    print("")
    print("="*50)
    print("TEST SUMMARY")
    print("="*50)
    print("Total:  %d" % results.total)
    print("Passed: %d" % results.passed)
    print("Failed: %d" % results.failed)
    print("Rate:   %.1f%%" % (results.success_rate * 100))
    print("")
    
    # Print failed tests
    if results.failed > 0:
        print("FAILED TESTS:")
        for r in results.results:
            if not r.passed:
                print("  ✗ [%s] %s - %s" % [r.suite, r.name, r.message])
        print("")
    
    # Exit with appropriate code
    var exit_code = 0 if results.failed == 0 else 1
    
    print("Exiting with code: %d" % exit_code)
    
    # Save log
    var log_path = "user://test_run_" + str(Time.get_unix_time_from_system()) + ".log"
    var log_file = FileAccess.open(log_path, FileAccess.WRITE)
    if log_file:
        log_file.store_line("Test Run: " + str(Time.get_datetime_dict_from_system()))
        log_file.store_line("Results: %d/%d passed" % [results.passed, results.total])
        log_file.close()
        print("Log saved to: " + log_path)
    
    # Quit
    if Engine.is_editor_hint():
        print("(Running in editor - not quitting)")
    else:
        get_tree().quit(exit_code)
