#!/bin/bash
# ============================================================================
# Test runner for DDD System
# ============================================================================

set -euo pipefail

TEST_DIR="$(dirname "${BASH_SOURCE[0]}")"
cd "$TEST_DIR"

echo "🧪 Running DDD System Test Suite"
echo "==============================="

# Set test environment
export DDD_LOG_LEVEL="ERROR"  # Reduce noise during tests
export DDD_LOG_FILE="/tmp/ddd-test.log"

total_passed=0
total_failed=0
test_suites_failed=0

run_test_suite() {
    local test_script="$1"
    local test_name="$(basename "$test_script" .sh)"
    
    echo ""
    echo "📋 Running $test_name..."
    echo "----------------------------------------"
    
    if ./"$test_script"; then
        echo "✅ $test_name: ALL TESTS PASSED"
    else
        echo "❌ $test_name: SOME TESTS FAILED"
        test_suites_failed=$((test_suites_failed + 1))
    fi
    
    echo "----------------------------------------"
}

# Run all test suites
run_test_suite "test_common.sh"
run_test_suite "test_validation.sh"

# Summary
echo ""
echo "==============================="
echo "🎯 Test Suite Summary"
echo "==============================="

if [[ $test_suites_failed -eq 0 ]]; then
    echo "✅ ALL TEST SUITES PASSED"
    echo "   The DDD system is working correctly!"
else
    echo "❌ $test_suites_failed TEST SUITE(S) FAILED"
    echo "   Please check the test output above for details."
fi

# Cleanup
rm -f /tmp/ddd-test.log

# Exit with proper code
if [[ $test_suites_failed -gt 0 ]]; then
    exit 1
fi