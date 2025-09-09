#!/bin/bash
# ============================================================================
# Decision-Driven Development System - Main Entry Point
# Modularized and enhanced version with comprehensive error handling,
# logging, performance optimizations, and security validations
# ============================================================================

set -euo pipefail

# System configuration
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
DDD_SYSTEM_DIR="$SCRIPT_DIR"

# Validate DDD system installation
if [[ ! -d "$DDD_SYSTEM_DIR/lib" ]]; then
    echo "❌ ERROR: DDD system libraries not found at $DDD_SYSTEM_DIR/lib"
    echo "   Please ensure you're running this script from the ddd-system directory."
    exit 1
fi

# Source core libraries
source "$DDD_SYSTEM_DIR/lib/common.sh"
source "$DDD_SYSTEM_DIR/lib/validation.sh"
source "$DDD_SYSTEM_DIR/lib/operations.sh"

# Source hooks installation
source "$DDD_SYSTEM_DIR/hooks/install.sh"

# ============================================================================
# Enhanced GitHub Workflow Creation
# ============================================================================

create_github_workflow() {
    log_info "🔧 Creating GitHub Actions workflow..."
    
    local github_dir=".github/workflows"
    local workflow_file="$github_dir/decision-policy.yml"
    local source_workflow="$DDD_SYSTEM_DIR/workflows/decision-policy.yml"
    
    # Create directory only if it doesn't exist
    if [[ ! -d "$github_dir" ]]; then
        log_info "Creating workflow directory: $github_dir"
        mkdir -p "$github_dir"
    fi
    
    # Check if source workflow exists
    if [[ ! -f "$source_workflow" ]]; then
        log_error "Source workflow file not found: $source_workflow"
        return 1
    fi
    
    # Copy workflow only if it doesn't exist or is different
    if [[ ! -f "$workflow_file" ]] || ! cmp -s "$source_workflow" "$workflow_file" 2>/dev/null; then
        log_info "Creating/updating workflow file: $workflow_file"
        cp "$source_workflow" "$workflow_file"
        log_info "✅ GitHub Actions workflow created at $workflow_file"
    else
        log_info "✅ GitHub Actions workflow is already up to date"
    fi
}

# ============================================================================
# System Status and Health Checks
# ============================================================================

system_status() {
    log_info "🔍 DDD System Status"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Git repository check
    if validate_git_repo; then
        echo "✅ Git repository detected"
    else
        echo "❌ Not in a git repository"
        return 1
    fi
    
    # Git hooks status
    local git_root hooks_dir
    git_root=$(get_git_root)
    hooks_dir="$git_root/.git/hooks"
    
    local hooks_installed=0
    for hook in pre-commit pre-push pre-receive; do
        if [[ -x "$hooks_dir/$hook" ]]; then
            echo "✅ $hook hook installed"
            hooks_installed=$((hooks_installed + 1))
        else
            echo "⚠️  $hook hook not installed"
        fi
    done
    
    # Decision directories count
    local decision_dirs
    decision_dirs=$(find . -name '.decision' -type d | wc -l)
    echo "📊 Decision directories: $decision_dirs"
    
    # Decision files count
    local decision_files
    decision_files=$(find . -path '*/.decision/*.md' -type f | wc -l)
    echo "📄 Decision files: $decision_files"
    
    # Recent decisions
    echo ""
    log_info "📅 Recent Decisions (last 5)"
    find . -path '*/.decision/*.md' -name '[0-9]*-*.md' -type f -exec stat -f "%m %N" {} + 2>/dev/null \
        | sort -rn | head -5 | while read -r timestamp file; do
        local date_str
        date_str=$(date -r "$timestamp" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "unknown")
        echo "   $date_str - $(basename "$file")"
    done
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# ============================================================================
# System Maintenance
# ============================================================================

system_cleanup() {
    log_info "🧹 DDD System Cleanup"
    
    # Clean up temporary files
    cleanup_temp_files
    
    # Clean up old log files (keep last 10)
    if [[ -f "$DDD_LOG_FILE" ]]; then
        local log_lines
        log_lines=$(wc -l < "$DDD_LOG_FILE")
        if [[ $log_lines -gt 1000 ]]; then
            log_info "Rotating log file ($log_lines lines)"
            tail -500 "$DDD_LOG_FILE" > "${DDD_LOG_FILE}.tmp"
            mv "${DDD_LOG_FILE}.tmp" "$DDD_LOG_FILE"
        fi
    fi
    
    log_info "✅ Cleanup completed"
}

system_validate() {
    log_info "🔎 Running system validation..."
    
    local validation_errors=0
    
    # Check for orphaned code files (files without decisions)
    log_info "Checking for orphaned code files..."
    local orphaned_files=0
    
    find . -type f \( -name "*.js" -o -name "*.ts" -o -name "*.py" -o -name "*.java" -o -name "*.go" \) \
        ! -path '*/.git/*' ! -path '*/node_modules/*' ! -path '*/.decision/*' | while read -r file; do
        local decision_dir
        decision_dir=$(find_nearest_decision_dir "$file")
        
        if [[ ! -d "$decision_dir" ]]; then
            echo "⚠️  Orphaned file: $file (no decision directory at $decision_dir)"
            orphaned_files=$((orphaned_files + 1))
        fi
    done
    
    if [[ $validation_errors -eq 0 ]]; then
        log_info "✅ System validation passed"
    else
        log_error "❌ System validation failed with $validation_errors errors"
        return 1
    fi
}

# ============================================================================
# Testing
# ============================================================================

run_tests() {
    log_info "🧪 Running DDD system tests..."
    
    if [[ ! -x "$DDD_SYSTEM_DIR/tests/run_tests.sh" ]]; then
        log_error "Test runner not found or not executable"
        return 1
    fi
    
    cd "$DDD_SYSTEM_DIR/tests"
    ./run_tests.sh
    cd - >/dev/null
}

# ============================================================================
# Usage Information
# ============================================================================

show_usage() {
    cat << EOF
🎯 Decision-Driven Development System v2.0

Usage:
  $0 <command> [arguments...]

CORE COMMANDS:
  init                         # Initialize project with DDD system
  init <dir>                   # Initialize .decision for specific directory
  decision <dir> <title>       # Create new decision document

ANALYSIS COMMANDS:
  search <term>                # Search decisions for term
  timeline                     # Show chronological decision timeline
  progress                     # Show module-wise progress report

SYSTEM COMMANDS:
  status                       # Show system status and health
  validate                     # Run system validation checks
  cleanup                      # Clean up temporary files and logs
  test                         # Run comprehensive test suite

UTILITIES:
  commit-msg                   # Generate commit message from decisions
  github                       # Create GitHub Actions workflow
  uninstall                    # Uninstall DDD system

EXAMPLES:
  $0 init                      # Setup project-level decision tracking
  $0 init src/auth             # Initialize .decision for src/auth directory
  $0 decision src/auth "jwt-implementation"  # Create decision in src/auth
  $0 search "apollo federation" # Search all decisions
  $0 status                    # View system health
  $0 validate                  # Check system integrity

ENVIRONMENT VARIABLES:
  DDD_LOG_LEVEL               # Set log level (DEBUG, INFO, WARN, ERROR)
  DDD_LOG_FILE                # Set log file path (default: /tmp/ddd-system.log)

For more information, see: README.md
EOF
}

# ============================================================================
# Main Command Router
# ============================================================================

main() {
    local command="${1:-}"
    
    if [[ -z "$command" ]]; then
        show_usage
        return 0
    fi
    
    case "$command" in
        # Core operations
        "init")
            if [[ -z "${2:-}" ]]; then
                init_decision_project
            else
                init_decision_dir "${2:-}"
            fi
            ;;
        "decision")
            create_decision "${2:-}" "${3:-}"
            ;;
        
        # Analysis operations
        "search")
            search_decisions "${2:-}"
            ;;
        "timeline")
            decision_timeline
            ;;
        "progress")
            module_progress
            ;;
        
        # System operations
        "status")
            system_status
            ;;
        "validate")
            system_validate
            ;;
        "cleanup")
            system_cleanup
            ;;
        "test")
            run_tests
            ;;
        
        # Utilities
        "commit-msg")
            generate_commit_message
            ;;
        "github")
            create_github_workflow
            ;;
        "uninstall")
            "$DDD_SYSTEM_DIR/install.sh" uninstall
            ;;
        
        # Help and unknown commands
        "help"|"-h"|"--help")
            show_usage
            ;;
        *)
            log_error "Unknown command: $command"
            echo ""
            show_usage
            exit 1
            ;;
    esac
}

# ============================================================================
# Script Entry Point
# ============================================================================

# Only run main when script is executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi