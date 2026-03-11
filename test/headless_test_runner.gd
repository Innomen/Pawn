extends Node

# Headless test runner - run with:
# godot --headless --path . --scene test/headless_test_runner.tscn

func _ready():
    print("\n==================================================")
    print("PAWN CHESS - HEADLESS TEST RUNNER")
    print("==================================================\n")
    
    # Run all tests
    print("Starting test execution...\n")
    
    var results = await HeadlessTester.run_all_tests()
    
    # Print results
    print("\n==================================================")
    print("TEST SUMMARY")
    print("==================================================")
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
                print("  [X] [%s] %s - %s" % [r.suite, r.name, r.message])
        print("")
    
    # Exit with appropriate code
    var exit_code = 0 if results.failed == 0 else 1
    
    print("Exiting with code: %d\n" % exit_code)
    
    get_tree().quit(exit_code)
