#!/bin/bash
# ============================================================================
# Test suite for validation functions
# ============================================================================

set -euo pipefail

# Test framework setup
TEST_DIR="$(dirname "${BASH_SOURCE[0]}")"
LIB_DIR="$TEST_DIR/../lib"
TEMP_TEST_DIR=""

# Source the libraries under test
source "$LIB_DIR/validation.sh"

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0

# Import test utilities from test_common.sh
source "$TEST_DIR/test_common.sh"

# ============================================================================
# Test Cases for Validation
# ============================================================================

test_gitignore_policy() {
    echo "Testing .gitignore policy validation..."
    
    # Test valid .gitignore (no .decision patterns)
    cat > .gitignore << 'EOF'
node_modules/
*.log
# This is a comment about .decision
dist/
EOF
    
    assert_true 'validate_gitignore_policy' "Valid .gitignore should pass"
    
    # Test invalid .gitignore (contains .decision pattern)
    cat > .gitignore << 'EOF'
node_modules/
.decision/
*.log
EOF
    
    assert_false 'validate_gitignore_policy' "Invalid .gitignore with .decision should fail"
    
    # Clean up
    rm -f .gitignore
}

test_decision_file_immutability() {
    echo "Testing decision file immutability validation..."
    
    # Create decision directory structure
    mkdir -p src/.decision
    
    # Test new decision file (should pass)
    echo "# New Decision" > src/.decision/20240101-1200-new.md
    chmod 444 src/.decision/20240101-1200-new.md
    git add src/.decision/20240101-1200-new.md
    
    assert_true 'validate_decision_file_immutability' "New decision file should pass"
    
    # Commit the file so it exists in HEAD
    git commit -m "Add decision file" >/dev/null 2>&1
    
    # Test modifying existing decision file (should fail)
    # First make it writable to simulate someone trying to modify it
    chmod 644 src/.decision/20240101-1200-new.md
    echo "# Modified Decision" > src/.decision/20240101-1200-new.md
    git add src/.decision/20240101-1200-new.md
    
    assert_false 'validate_decision_file_immutability' "Modified decision file should fail"
    
    # Reset
    git reset HEAD~1 --hard >/dev/null 2>&1
}

test_decision_only_commits() {
    echo "Testing decision-only commit validation..."
    
    # Create decision directory
    mkdir -p src/.decision
    
    # Test decision-only commit (should fail)
    echo "# Decision Only" > src/.decision/20240101-1300-decision-only.md
    chmod 444 src/.decision/20240101-1300-decision-only.md
    git add src/.decision/20240101-1300-decision-only.md
    
    assert_false 'validate_decision_only_commits' "Decision-only commit should fail"
    
    # Test decision + code commit (should pass)
    echo "console.log('hello');" > src/code.js
    git add src/code.js
    
    assert_true 'validate_decision_only_commits' "Decision + code commit should pass"
    
    # Clean up
    git reset HEAD >/dev/null 2>&1
}

test_per_file_decisions() {
    echo "Testing per-file decision validation..."
    
    # Create structure
    mkdir -p src/.decision
    
    # Test code file without decision (should fail)
    echo "function test() {}" > src/test.js
    git add src/test.js
    
    assert_false 'validate_per_file_decisions' "Code without decision should fail"
    
    # Test code file with decision that mentions it (should pass)
    cat > src/.decision/20240101-1400-test-function.md << 'EOF'
# Test Function Implementation

## Files
- src/test.js
EOF
    chmod 444 src/.decision/20240101-1400-test-function.md
    git add src/.decision/20240101-1400-test-function.md
    
    assert_true 'validate_per_file_decisions' "Code with relevant decision should pass"
    
    # Clean up
    git reset HEAD >/dev/null 2>&1
}

test_range_decisions() {
    echo "Testing range decision validation..."
    
    # Create initial state
    mkdir -p src/.decision
    echo "# Initial" > initial.md
    git add initial.md
    git commit -m "Initial commit" >/dev/null 2>&1
    
    local initial_commit
    initial_commit=$(git rev-parse HEAD)
    
    # Make changes
    echo "function newFeature() {}" > src/feature.js
    cat > src/.decision/20240101-1500-new-feature.md << 'EOF'
# New Feature

## Files
- src/feature.js
EOF
    chmod 444 src/.decision/20240101-1500-new-feature.md
    git add src/feature.js src/.decision/20240101-1500-new-feature.md
    git commit -m "Add new feature" >/dev/null 2>&1
    
    local feature_commit
    feature_commit=$(git rev-parse HEAD)
    
    # Test range validation
    assert_true 'validate_range_decisions "$initial_commit" "$feature_commit"' "Range with proper decisions should pass"
}

test_existing_decision_permissions() {
    echo "Testing existing decision permissions validation..."
    
    # Clean up any existing files first
    rm -rf src/ test_permissions/
    
    # Test 1: Only good permissions
    mkdir -p test_permissions/.decision
    echo "# Good Decision" > test_permissions/.decision/good.md
    chmod 444 test_permissions/.decision/good.md
    
    cd test_permissions
    assert_true 'validate_existing_decision_permissions' "Correct permissions should pass"
    cd ..
    
    # Test 2: Add bad permissions  
    echo "# Bad Decision" > test_permissions/.decision/bad.md
    chmod 644 test_permissions/.decision/bad.md
    
    cd test_permissions
    assert_false 'validate_existing_decision_permissions' "Wrong permissions should fail"
    cd ..
    
    # Clean up
    rm -rf test_permissions/
}

# ============================================================================
# Integration Tests
# ============================================================================

test_full_validation_flow() {
    echo "Testing full validation flow..."
    
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
    
    # Setup complete scenario
    mkdir -p src/auth/.decision src/utils/.decision
    
    # Create proper decision structure
    cat > src/auth/.decision/20240101-1600-auth-system.md << 'EOF'
# Authentication System

## Files
- src/auth/login.js
- src/auth/auth.js
EOF
    chmod 444 src/auth/.decision/20240101-1600-auth-system.md
    
    # Create code files
    echo "module.exports = { login: () => {} };" > src/auth/login.js
    echo "module.exports = { authenticate: () => {} };" > src/auth/auth.js
    
    # Stage everything
    git add .
    
    # All validations should pass
    assert_true 'validate_gitignore_policy' "Full scenario: gitignore policy"
    assert_true 'validate_decision_file_immutability' "Full scenario: file immutability"  
    assert_true 'validate_decision_only_commits' "Full scenario: not decision-only"
    assert_true 'validate_per_file_decisions' "Full scenario: per-file decisions"
    
    # Clean up and return to original directory
    cd "$old_dir"
    rm -rf "$isolated_dir"
}

# ============================================================================
# Test Runner Override
# ============================================================================

run_validation_tests() {
    echo "🧪 Running DDD Validation Tests..."
    echo "================================="
    
    test_setup
    
    # Disable error handling temporarily for tests
    set +e
    
    # Clean up between tests
    rm -rf src/ test_permissions/ .gitignore 2>/dev/null || true
    git reset --hard HEAD 2>/dev/null || true
    git clean -fd 2>/dev/null || true
    
    test_gitignore_policy
    
    rm -rf src/ test_permissions/ .gitignore 2>/dev/null || true
    git reset --hard HEAD 2>/dev/null || true
    git clean -fd 2>/dev/null || true
    
    test_decision_file_immutability
    
    rm -rf src/ test_permissions/ .gitignore 2>/dev/null || true
    git reset --hard HEAD 2>/dev/null || true
    git clean -fd 2>/dev/null || true
    
    test_decision_only_commits
    
    rm -rf src/ test_permissions/ .gitignore 2>/dev/null || true
    git reset --hard HEAD 2>/dev/null || true
    git clean -fd 2>/dev/null || true
    
    test_per_file_decisions
    
    rm -rf src/ test_permissions/ .gitignore 2>/dev/null || true
    git reset --hard HEAD 2>/dev/null || true
    git clean -fd 2>/dev/null || true
    
    test_range_decisions
    
    rm -rf src/ test_permissions/ .gitignore 2>/dev/null || true
    git reset --hard HEAD 2>/dev/null || true
    git clean -fd 2>/dev/null || true
    
    test_existing_decision_permissions
    
    rm -rf src/ test_permissions/ .gitignore 2>/dev/null || true
    git reset --hard HEAD 2>/dev/null || true
    git clean -fd 2>/dev/null || true
    
    test_full_validation_flow
    
    # Re-enable error handling
    set -e
    
    test_teardown
    
    echo "================================="
    echo "Validation tests completed: $((TESTS_PASSED + TESTS_FAILED))"
    echo "✅ Passed: $TESTS_PASSED"
    echo "❌ Failed: $TESTS_FAILED"
    
    if [[ $TESTS_FAILED -gt 0 ]]; then
        exit 1
    fi
}

# Run tests when script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_validation_tests "$@"
fi