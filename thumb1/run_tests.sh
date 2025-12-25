#!/bin/bash
# Regression test runner for Thumb-1 core tests
# Runs all tests in tests/ directory and reports results

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "========================================"
echo "Thumb-1 Core Regression Test Suite"
echo "========================================"
echo ""

# Build the simulation once
echo "Building simulation..."
if iverilog -g2012 -o sim.out core/tb.sv core/tiny_thumb_core.sv core/tiny_mem_model.sv 2>&1; then
    echo -e "${GREEN}Build successful${NC}"
else
    echo -e "${RED}Build failed${NC}"
    exit 1
fi
echo ""

# Find all test directories
TEST_DIRS=$(find tests -mindepth 1 -maxdepth 1 -type d | sort)

# Track results
PASSED=0
FAILED=0
FAILED_TESTS=()

# Run each test
for test_dir in $TEST_DIRS; do
    test_name=$(basename "$test_dir")

    # Check if test has both required files
    if [ ! -f "$test_dir/prog.hex" ]; then
        echo -e "${YELLOW}SKIP${NC} $test_name (no prog.hex)"
        continue
    fi
    if [ ! -f "$test_dir/expected.txt" ]; then
        echo -e "${YELLOW}SKIP${NC} $test_name (no expected.txt)"
        continue
    fi

    # Set up symlinks
    ln -sf "$test_dir/prog.hex" prog.hex
    ln -sf "$test_dir/expected.txt" expected.txt

    # Run test and capture output
    echo -n "Running $test_name... "
    if output=$(vvp sim.out 2>&1); then
        # Check if test actually passed (look for "PASS" in output)
        if echo "$output" | grep -q "^PASS:"; then
            echo -e "${GREEN}PASS${NC}"
            PASSED=$((PASSED + 1))
        else
            echo -e "${RED}FAIL${NC} (unexpected output)"
            FAILED=$((FAILED + 1))
            FAILED_TESTS+=("$test_name")
            echo "$output"
        fi
    else
        echo -e "${RED}FAIL${NC}"
        FAILED=$((FAILED + 1))
        FAILED_TESTS+=("$test_name")
        echo "$output"
    fi
done

# Print summary
echo ""
echo "========================================"
echo "Test Summary"
echo "========================================"
echo -e "Passed: ${GREEN}$PASSED${NC}"
echo -e "Failed: ${RED}$FAILED${NC}"
echo "Total:  $((PASSED + FAILED))"

if [ $FAILED -gt 0 ]; then
    echo ""
    echo "Failed tests:"
    for test in "${FAILED_TESTS[@]}"; do
        echo -e "  ${RED}✗${NC} $test"
    done
    echo ""
    exit 1
else
    echo ""
    echo -e "${GREEN}All tests passed!${NC}"
    echo ""
    exit 0
fi
