#!/bin/bash
# ============================================================================
# Git Hooks Installation for Decision-Driven Development System
# ============================================================================

# Source common utilities
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "$SCRIPT_DIR/../lib/common.sh"

install_git_hooks() {
    log_info "🔧 Installing Git hooks for decision enforcement..."
    
    validate_git_repo || return 1
    
    local git_root hooks_dir
    git_root=$(get_git_root)
    hooks_dir="$git_root/.git/hooks"
    
    mkdir -p "$hooks_dir"
    
    # Install hooks
    install_pre_commit_hook "$hooks_dir" || return 1
    install_pre_push_hook "$hooks_dir" || return 1
    install_pre_receive_hook "$hooks_dir" || return 1
    
    log_info "✅ Git hooks installed successfully"
}

install_pre_commit_hook() {
    local hooks_dir="$1"
    local hook_file="$hooks_dir/pre-commit"
    
    log_debug "Installing pre-commit hook"
    
    # Copy the pre-commit hook template
    cp "$SCRIPT_DIR/pre-commit" "$hook_file"
    chmod +x "$hook_file"
    
    log_debug "Pre-commit hook installed"
}

install_pre_push_hook() {
    local hooks_dir="$1"
    local hook_file="$hooks_dir/pre-push"
    
    log_debug "Installing pre-push hook"
    
    # Copy the pre-push hook template
    cp "$SCRIPT_DIR/pre-push" "$hook_file"
    chmod +x "$hook_file"
    
    log_debug "Pre-push hook installed"
}

install_pre_receive_hook() {
    local hooks_dir="$1"
    local hook_file="$hooks_dir/pre-receive"
    
    log_debug "Installing pre-receive hook"
    
    # Copy the pre-receive hook template
    cp "$SCRIPT_DIR/pre-receive" "$hook_file"
    chmod +x "$hook_file"
    
    log_debug "Pre-receive hook installed"
}

# Main execution when script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_git_hooks "$@"
fi