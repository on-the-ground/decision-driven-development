#!/bin/bash
# ============================================================================
# Test suite for common utilities
# ============================================================================

set -euo pipefail

# Test framework setup
TEST_DIR="$(dirname "${BASH_SOURCE[0]}")"
LIB_DIR="$TEST_DIR/../lib"
TEMP_TEST_DIR=""

# Source the library under test
source "$LIB_DIR/common.sh"

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0

# Test utilities
test_setup() {
    TEMP_TEST_DIR=$(mktemp -d)
    cd "$TEMP_TEST_DIR"
    git init >/dev/null 2>&1
    git config user.name "Test User"
    git config user.email "test@example.com"
    
    # Copy library files to temp directory (using absolute path)
    cp -r "/workspaces/github-com-on-the-ground-decision-driven-develop/lib" .
}

test_teardown() {
    cd /
    [[ -n "$TEMP_TEST_DIR" && -d "$TEMP_TEST_DIR" ]] && rm -rf "$TEMP_TEST_DIR"
}

assert_equals() {
    local expected="$1"
    local actual="$2"
    local test_name="${3:-unnamed test}"
    
    if [[ "$expected" == "$actual" ]]; then
        echo "✅ PASS: $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "❌ FAIL: $test_name"
        echo "   Expected: '$expected'"
        echo "   Actual: '$actual'"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

assert_true() {
    local condition="$1"
    local test_name="${2:-unnamed test}"
    
    if eval "$condition"; then
        echo "✅ PASS: $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "❌ FAIL: $test_name (condition was false)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

assert_false() {
    local condition="$1"
    local test_name="${2:-unnamed test}"
    
    if ! eval "$condition"; then
        echo "✅ PASS: $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "❌ FAIL: $test_name (condition was true)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# ============================================================================
# Test Cases
# ============================================================================

test_logging_levels() {
    echo "Testing logging levels..."
    
    # Test with different log levels
    DDD_LOG_LEVEL="ERROR"
    
    # Redirect stderr to capture log output
    local log_output
    log_output=$(log "DEBUG" "debug message" 2>&1 || true)
    assert_equals "" "$log_output" "DEBUG message filtered out when level is ERROR"
    
    log_output=$(log "ERROR" "error message" 2>&1 || true)
    if [[ -n "$log_output" ]]; then
        echo "✅ PASS: ERROR message shown when level is ERROR"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "❌ FAIL: ERROR message shown when level is ERROR (no output)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

test_file_permissions_validation() {
    echo "Testing file permissions validation..."
    
    # Create test file with wrong permissions
    echo "test content" > test_file.txt
    chmod 644 test_file.txt
    
    assert_false 'validate_file_permissions test_file.txt' "File with 644 permissions should fail"
    
    # Fix permissions
    chmod 444 test_file.txt
    assert_true 'validate_file_permissions test_file.txt' "File with 444 permissions should pass"
    
    # Test symlink rejection
    ln -s test_file.txt test_symlink.txt
    assert_false 'validate_file_permissions test_symlink.txt' "Symlinks should be rejected"
}

test_git_utilities() {
    echo "Testing git utilities..."
    
    # Test git repo validation
    assert_true 'validate_git_repo' "Should detect git repository"
    
    # Test get_git_root
    local git_root
    git_root=$(get_git_root)
    assert_equals "$TEMP_TEST_DIR" "$git_root" "Should return correct git root"
    
    # Test has_head (no commits yet)
    assert_false 'has_head' "Should return false when no commits exist"
    
    # Create initial commit
    echo "initial" > initial.txt
    git add initial.txt
    git commit -m "Initial commit" >/dev/null 2>&1
    
    assert_true 'has_head' "Should return true when commits exist"
}

test_decision_file_utilities() {
    echo "Testing decision file utilities..."
    
    # Test is_decision_file
    assert_true 'is_decision_file "src/.decision/20240101-1200-test.md"' "Should recognize decision file"
    assert_false 'is_decision_file "src/code.js"' "Should not recognize code file as decision"
    
    # Test should_validate_file
    assert_true 'should_validate_file "src/code.js"' "Should recognize code file for validation"
    assert_false 'should_validate_file "src/.decision/20240101-1200-test.md"' "Should not validate decision file"
    
    # Test find_nearest_decision_dir
    local decision_dir
    decision_dir=$(find_nearest_decision_dir "src/auth/login.js")
    assert_equals "src/auth/.decision" "$decision_dir" "Should find correct decision directory"
}

test_temp_file_management() {
    echo "Testing temporary file management..."
    
    # Create temp files
    local temp_file1 temp_file2
    temp_file1=$(mktemp)
    temp_file2=$(mktemp)
    
    register_temp_file "$temp_file1"
    register_temp_file "$temp_file2"
    
    # Verify files exist
    assert_true '[[ -f "$temp_file1" ]]' "Temp file 1 should exist"
    assert_true '[[ -f "$temp_file2" ]]' "Temp file 2 should exist"
    
    # Cleanup
    cleanup_temp_files
    
    # Verify files are cleaned up
    assert_false '[[ -f "$temp_file1" ]]' "Temp file 1 should be cleaned up"
    assert_false '[[ -f "$temp_file2" ]]' "Temp file 2 should be cleaned up"
}

test_file_mentions_in_content() {
    echo "Testing file mention detection..."
    
    local content="This decision affects src/auth/login.js and also modifies utils.js"
    
    assert_true 'file_mentions_in_content "src/auth/login.js" "$content"' "Should find full path mention"
    assert_true 'file_mentions_in_content "src/other/utils.js" "$content"' "Should find basename mention"
    assert_false 'file_mentions_in_content "src/missing.js" "$content"' "Should not find missing file"
}

# ============================================================================
# Test Runner
# ============================================================================

run_all_tests() {
    echo "🧪 Running DDD Common Utilities Tests..."
    echo "======================================"
    
    test_setup
    
    # Disable error handling temporarily for tests
    set +e
    
    test_logging_levels
    test_file_permissions_validation
    test_git_utilities
    test_decision_file_utilities
    test_temp_file_management
    test_file_mentions_in_content
    
    # Re-enable error handling
    set -e
    
    test_teardown
    
    echo "======================================"
    echo "Tests completed: $((TESTS_PASSED + TESTS_FAILED))"
    echo "✅ Passed: $TESTS_PASSED"
    echo "❌ Failed: $TESTS_FAILED"
    
    if [[ $TESTS_FAILED -gt 0 ]]; then
        exit 1
    fi
}

# Run tests when script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_all_tests "$@"
fi