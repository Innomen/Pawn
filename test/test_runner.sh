#!/bin/bash

# Pawn Chess Test Runner Script
# Usage: ./test/test_runner.sh [options]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
GODOT_BIN="godot"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Pawn Chess - Test Runner${NC}"
echo "=========================="
echo ""

# Check for Godot
if ! command -v $GODOT_BIN &> /dev/null; then
    echo -e "${RED}Error: Godot not found in PATH${NC}"
    echo "Please install Godot 4.x and add it to your PATH"
    exit 1
fi

echo "Godot version:"
$GODOT_BIN --version
echo ""

# Parse arguments
TEST_TYPE="all"
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --quick|-q)
            TEST_TYPE="quick"
            shift
            ;;
        --simulate|-s)
            TEST_TYPE="simulate"
            shift
            ;;
        --gambit|-g)
            TEST_TYPE="gambit"
            GAMBIT_ID="$2"
            shift 2
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --quick, -q       Run quick sanity check only"
            echo "  --simulate, -s    Run game simulation"
            echo "  --gambit ID, -g   Test specific gambit"
            echo "  --verbose, -v     Verbose output"
            echo "  --help, -h        Show this help"
            echo ""
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# Change to project directory
cd "$PROJECT_DIR"

echo "Running tests from: $PROJECT_DIR"
echo "Test type: $TEST_TYPE"
echo ""

# Run tests based on type
case $TEST_TYPE in
    all)
        echo -e "${YELLOW}Running full test suite...${NC}"
        $GODOT_BIN --headless --path . --script test/run_tests.gd
        ;;
    quick)
        echo -e "${YELLOW}Running quick sanity check...${NC}"
        $GODOT_BIN --headless --path . -s "HeadlessTester.run_quick_test()"
        ;;
    simulate)
        echo -e "${YELLOW}Running game simulation...${NC}"
        $GODOT_BIN --headless --path . -s "HeadlessTester.simulate_game(30)"
        ;;
    gambit)
        if [ -z "$GAMBIT_ID" ]; then
            echo -e "${RED}Error: No gambit ID specified${NC}"
            echo "Usage: $0 --gambit <gambit_id>"
            exit 1
        fi
        echo -e "${YELLOW}Testing gambit: $GAMBIT_ID${NC}"
        $GODOT_BIN --headless --path . -s "HeadlessTester.test_gambit_scenario('$GAMBIT_ID')"
        ;;
esac

echo ""
echo -e "${GREEN}Test run complete${NC}"
