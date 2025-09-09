#!/bin/bash
# ============================================================================
# Test suite for root-level .decision/ignore functionality
# ============================================================================

set -euo pipefail

# Test framework setup
TEST_DIR="$(dirname "${BASH_SOURCE[0]}")"
LIB_DIR="$TEST_DIR/../lib"
TEMP_TEST_DIR=""

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0

# Import test utilities from test_common.sh
source "$TEST_DIR/test_common.sh"

# ============================================================================
# Test Cases for Root-Level Ignore
# ============================================================================

test_root_level_glob_ignore() {
    echo "Testing root-level .decision/ignore with glob patterns..."
    
    # Run this test in completely isolated environment to avoid lib file conflicts
    local old_dir="$(pwd)"
    local isolated_dir=$(mktemp -d)
    cd "$isolated_dir"
    git init >/dev/null 2>&1
    git config user.name "Test User"
    git config user.email "test@example.com"
    
    # Copy lib files to parent directory (outside git repo) so they don't get staged
    mkdir -p ../lib
    cp -r "/workspaces/github-com-on-the-ground-decision-driven-develop/lib"/* ../lib/
    source ../lib/validation.sh
    
    # Create root-level .decision directory with ignore file
    mkdir -p .decision
    echo "**/build.gradle.kts" > .decision/ignore
    
    # Create nested gradle files that should be ignored
    mkdir -p composeApp
    echo "// Compose app gradle" > composeApp/build.gradle.kts
    
    mkdir -p nested/deep/project
    echo "// Deep nested gradle" > nested/deep/project/build.gradle.kts
    
    # Create some other code files that need decisions
    echo "fun main() {}" > composeApp/Main.kt
    echo "class Utils" > nested/Utils.kt
    
    # Create a decision that covers the non-gradle files
    cat > .decision/20240101-1200-kotlin-files.md << 'EOF'
# Kotlin Files Decision

## Files
- composeApp/Main.kt  
- nested/Utils.kt
EOF
    chmod 444 .decision/20240101-1200-kotlin-files.md
    
    # Stage everything
    git add .
    
    # Validation should pass - gradle files should be ignored
    if validate_per_file_decisions; then
        echo "✅ PASS: Root glob pattern should ignore nested gradle files"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "❌ FAIL: Root glob pattern should ignore nested gradle files"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    
    # Clean up and return to original directory
    cd "$old_dir"
    rm -rf "$isolated_dir"
}

test_simple_direct_test() {
    echo "Testing simple direct case..."
    
    # Run this test in completely isolated environment 
    local old_dir="$(pwd)"
    local isolated_dir=$(mktemp -d)
    cd "$isolated_dir"
    git init >/dev/null 2>&1
    git config user.name "Test User"
    git config user.email "test@example.com"
    
    # Copy lib files to parent directory (outside git repo) so they don't get staged
    mkdir -p ../lib
    cp -r "/workspaces/github-com-on-the-ground-decision-driven-develop/lib"/* ../lib/
    source ../lib/validation.sh
    
    # Enable debug logging 
    export DDD_LOG_LEVEL="DEBUG"
    
    # Create root-level .decision directory with ignore file
    mkdir -p .decision
    echo "**/build.gradle.kts" > .decision/ignore
    
    # Create single gradle file that should be ignored
    mkdir -p composeApp
    echo "// gradle file" > composeApp/build.gradle.kts
    
    # Stage only the gradle file and ignore file
    git add composeApp/build.gradle.kts .decision/
    
    # Validation should pass - gradle file should be ignored
    local validation_output
    validation_output=$(validate_per_file_decisions 2>&1 || echo "VALIDATION_FAILED")
    
    # Reset log level
    export DDD_LOG_LEVEL="ERROR"
    
    if [[ "$validation_output" != *"VALIDATION_FAILED"* ]]; then
        echo "✅ PASS: Simple direct case should ignore gradle file"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "❌ FAIL: Simple direct case should ignore gradle file"
        echo "   Output: $validation_output"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    
    # Clean up and return to original directory
    cd "$old_dir"
    rm -rf "$isolated_dir"
}

# ============================================================================
# Test Runner
# ============================================================================

run_root_ignore_tests() {
    echo "🧪 Running Root-Level Ignore Tests..."
    echo "===================================="
    
    # Disable error handling temporarily for tests
    set +e
    
    test_root_level_glob_ignore
    test_simple_direct_test
    
    # Re-enable error handling
    set -e
    
    echo "===================================="
    echo "Root ignore tests completed: $((TESTS_PASSED + TESTS_FAILED))"
    echo "✅ Passed: $TESTS_PASSED"
    echo "❌ Failed: $TESTS_FAILED"
    
    if [[ $TESTS_FAILED -gt 0 ]]; then
        exit 1
    fi
}

# Run tests when script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_root_ignore_tests "$@"
fi