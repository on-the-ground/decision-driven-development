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
    
    # Create decision with correct permissions
    mkdir -p src/.decision
    echo "# Good Decision" > src/.decision/good.md
    chmod 444 src/.decision/good.md
    
    assert_true 'validate_existing_decision_permissions' "Correct permissions should pass"
    
    # Create decision with wrong permissions
    echo "# Bad Decision" > src/.decision/bad.md
    chmod 644 src/.decision/bad.md
    
    assert_false 'validate_existing_decision_permissions' "Wrong permissions should fail"
    
    # Clean up
    rm -rf src/
}

# ============================================================================
# Integration Tests
# ============================================================================

test_full_validation_flow() {
    echo "Testing full validation flow..."
    
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
    
    # Clean up
    git reset HEAD >/dev/null 2>&1
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
    
    test_gitignore_policy
    test_decision_file_immutability
    test_decision_only_commits
    test_per_file_decisions
    test_range_decisions
    test_existing_decision_permissions
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