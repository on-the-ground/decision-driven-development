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
    local source_hook="$SCRIPT_DIR/pre-commit"
    
    log_debug "Installing pre-commit hook"
    
    # Check if source hook exists
    if [[ ! -f "$source_hook" ]]; then
        log_error "Source pre-commit hook not found: $source_hook"
        return 1
    fi
    
    # Install hook only if it doesn't exist or is different
    if [[ ! -f "$hook_file" ]] || ! cmp -s "$source_hook" "$hook_file" 2>/dev/null; then
        log_debug "Creating/updating pre-commit hook"
        cp "$source_hook" "$hook_file"
        chmod +x "$hook_file"
        log_debug "Pre-commit hook installed"
    else
        log_debug "Pre-commit hook is already up to date"
    fi
}

install_pre_push_hook() {
    local hooks_dir="$1"
    local hook_file="$hooks_dir/pre-push"
    local source_hook="$SCRIPT_DIR/pre-push"
    
    log_debug "Installing pre-push hook"
    
    # Check if source hook exists
    if [[ ! -f "$source_hook" ]]; then
        log_error "Source pre-push hook not found: $source_hook"
        return 1
    fi
    
    # Install hook only if it doesn't exist or is different
    if [[ ! -f "$hook_file" ]] || ! cmp -s "$source_hook" "$hook_file" 2>/dev/null; then
        log_debug "Creating/updating pre-push hook"
        cp "$source_hook" "$hook_file"
        chmod +x "$hook_file"
        log_debug "Pre-push hook installed"
    else
        log_debug "Pre-push hook is already up to date"
    fi
}

install_pre_receive_hook() {
    local hooks_dir="$1"
    local hook_file="$hooks_dir/pre-receive"
    local source_hook="$SCRIPT_DIR/pre-receive"
    
    log_debug "Installing pre-receive hook"
    
    # Check if source hook exists
    if [[ ! -f "$source_hook" ]]; then
        log_error "Source pre-receive hook not found: $source_hook"
        return 1
    fi
    
    # Install hook only if it doesn't exist or is different
    if [[ ! -f "$hook_file" ]] || ! cmp -s "$source_hook" "$hook_file" 2>/dev/null; then
        log_debug "Creating/updating pre-receive hook"
        cp "$source_hook" "$hook_file"
        chmod +x "$hook_file"
        log_debug "Pre-receive hook installed"
    else
        log_debug "Pre-receive hook is already up to date"
    fi
}

# Main execution when script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_git_hooks "$@"
fi