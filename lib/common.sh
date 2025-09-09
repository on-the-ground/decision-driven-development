#!/bin/bash
# ============================================================================
# Common utilities for Decision-Driven Development System
# ============================================================================

set -euo pipefail

# Global variables
declare -a TEMP_FILES=()
DDD_LOG_LEVEL=${DDD_LOG_LEVEL:-"INFO"}
DDD_LOG_FILE=${DDD_LOG_FILE:-"/tmp/ddd-system.log"}

# ============================================================================
# Logging System
# ============================================================================

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    
    # Log levels: DEBUG=0, INFO=1, WARN=2, ERROR=3
    declare -A LOG_LEVELS=([DEBUG]=0 [INFO]=1 [WARN]=2 [ERROR]=3)
    local current_level=${LOG_LEVELS[$DDD_LOG_LEVEL]:-1}
    local msg_level=${LOG_LEVELS[$level]:-1}
    
    if [[ $msg_level -ge $current_level ]]; then
        local color=""
        case "$level" in
            DEBUG) color="\033[0;36m" ;;  # Cyan
            INFO)  color="\033[0;32m" ;;  # Green
            WARN)  color="\033[0;33m" ;;  # Yellow
            ERROR) color="\033[0;31m" ;;  # Red
        esac
        
        # Console output
        echo -e "${color}[$timestamp] [$level] $message\033[0m" >&2
        
        # File logging
        echo "[$timestamp] [$level] $message" >> "$DDD_LOG_FILE"
    fi
}

log_debug() { log "DEBUG" "$@"; }
log_info()  { log "INFO" "$@"; }
log_warn()  { log "WARN" "$@"; }
log_error() { log "ERROR" "$@"; }

# ============================================================================
# Error Handling
# ============================================================================

cleanup_temp_files() {
    if [[ ${#TEMP_FILES[@]} -gt 0 ]]; then
        log_debug "Cleaning up ${#TEMP_FILES[@]} temporary files"
        for file in "${TEMP_FILES[@]}"; do
            [[ -f "$file" ]] && rm -f "$file"
        done
        TEMP_FILES=()
    fi
}

register_temp_file() {
    local file="$1"
    TEMP_FILES+=("$file")
}

cleanup_on_error() {
    local line="$1"
    local command="$2"
    log_error "Command failed on line $line: $command"
    cleanup_temp_files
    exit 1
}

setup_error_handling() {
    trap 'cleanup_on_error $LINENO "$BASH_COMMAND"' ERR
    trap 'cleanup_temp_files' EXIT
}

# ============================================================================
# Validation Utilities
# ============================================================================

validate_file_permissions() {
    local file="$1"
    
    if [[ ! -f "$file" ]]; then
        log_error "File does not exist: $file"
        return 1
    fi
    
    if [[ -L "$file" ]]; then
        log_error "Symlinks not allowed: $file"
        return 1
    fi
    
    local actual_perms
    if command -v stat >/dev/null 2>&1; then
        actual_perms=$(stat -c "%a" "$file" 2>/dev/null || stat -f "%Lp" "$file" 2>/dev/null || echo "???")
    else
        log_warn "Cannot check file permissions (stat command not available)"
        return 0
    fi
    
    # Accept both 444 (r--r--r--) and 555 (r-xr-xr-x) - both are read-only
    if [[ "$actual_perms" != "444" && "$actual_perms" != "555" ]]; then
        log_error "Wrong permissions: $file ($actual_perms, expected: 444 or 555 - read-only)"
        return 1
    fi
    
    log_debug "File permissions validated: $file ($actual_perms)"
    return 0
}

validate_git_repo() {
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        log_error "Not in a git repository"
        return 1
    fi
    return 0
}

# ============================================================================
# Git Utilities
# ============================================================================

get_git_root() {
    git rev-parse --show-toplevel
}

has_head() {
    git rev-parse --verify HEAD >/dev/null 2>&1
}

get_staged_files() {
    git diff --cached --name-only
}

get_changed_files_in_range() {
    local from="$1"
    local to="$2"
    local -a changed=()
    
    while IFS=$'\t' read -r status p1 p2; do
        local path
        case "$status" in
            R*|C*) path="${p2:-$p1}" ;;
            *)     path="$p1" ;;
        esac
        [[ -n "${path:-}" ]] && changed+=("$path")
    done < <(git diff --name-status "$from..$to" 2>/dev/null || true)
    
    printf '%s\n' "${changed[@]}"
}

# ============================================================================
# Decision File Utilities
# ============================================================================

is_decision_file() {
    local file="$1"
    [[ "$file" == */.decision/* && "$file" == *.md ]]
}

should_validate_file() {
    local file="$1"
    # Skip files under .decision directory (including root level)
    [[ "$file" == .decision/* ]] && return 1
    [[ "$file" == */.decision/* ]] && return 1
    # Skip git internal files
    [[ "$file" == .git/* ]] && return 1
    # Check if file should be ignored based on .decision/ignore patterns
    local decision_dir
    decision_dir=$(find_nearest_decision_dir "$file")
    if should_ignore_file "$file" "$decision_dir"; then
        log_debug "File $file is ignored by .decision/ignore"
        return 1  # Don't validate ignored files
    fi
    # All other files should be validated
    return 0
}

find_nearest_decision_dir() {
    local file="$1"
    local dir=$(dirname "$file")
    echo "$dir/.decision"
}

get_decision_content() {
    local file="$1"
    if git show ":$file" >/dev/null 2>&1; then
        git show ":$file"
    else
        cat "$file" 2>/dev/null || true
    fi
}

file_mentions_in_content() {
    local file="$1"
    local content="$2"
    local basename_file=$(basename "$file")
    
    grep -Fq -- "$file" <<<"$content" || grep -Fq -- "$basename_file" <<<"$content"
}

should_ignore_file() {
    local file="$1"
    local decision_dir="$2"
    
    log_debug "Checking if file $file should be ignored using $decision_dir"
    
    # Check if ignore file exists
    local ignore_file="$decision_dir/ignore"
    if [[ ! -f "$ignore_file" ]]; then
        log_debug "No ignore file found at $ignore_file"
        return 1  # Don't ignore
    fi
    
    # Get the parent directory of .decision
    local parent_dir="${decision_dir%/.decision}"
    # Handle root-level .decision directory
    if [[ "$decision_dir" == ".decision" ]]; then
        parent_dir="."
    fi
    
    # Read patterns from ignore file
    while IFS= read -r pattern || [[ -n "$pattern" ]]; do
        # Skip empty lines and comments
        [[ -z "$pattern" ]] && continue
        [[ "$pattern" =~ ^[[:space:]]*# ]] && continue
        
        # Trim whitespace
        pattern="${pattern#"${pattern%%[![:space:]]*}"}"
        pattern="${pattern%"${pattern##*[![:space:]]}"}"
        
        # Handle ** recursive glob patterns
        if [[ "$pattern" == **/* ]]; then
            local base_pattern="${pattern#**/}"
            log_debug "Processing ** pattern: $pattern, base: $base_pattern, parent_dir: $parent_dir, file: $file"
            
            # For ** patterns, check if file matches the base pattern recursively
            local file_to_check="$file"
            # If parent_dir is root (.), file is already in correct format
            if [[ "$parent_dir" == "." ]]; then
                file_to_check="$file"
                log_debug "Root directory case: file_to_check=$file_to_check"
            else
                # For non-root directories, file should always be relative to parent_dir
                # Since we're checking root-level ignore, file is already relative
                file_to_check="$file"
                log_debug "Non-root directory case: using file as-is, file_to_check=$file_to_check"
            fi
            
            log_debug "Checking file_to_check: $file_to_check against base_pattern: $base_pattern"
            
            # Enable globstar for ** matching
            shopt -s globstar 2>/dev/null || true
            # Check both patterns: **/$base_pattern and $base_pattern (for root level files)
            if [[ "$file_to_check" == **/$base_pattern ]] || [[ "$file_to_check" == $base_pattern ]]; then
                shopt -u globstar 2>/dev/null || true
                log_debug "File $file matches recursive ignore pattern: $pattern"
                return 0  # Should ignore
            else
                log_debug "File $file_to_check does NOT match pattern: $base_pattern or **/$base_pattern"
            fi
            shopt -u globstar 2>/dev/null || true
        else
            # Build the full path pattern relative to parent directory
            local full_pattern="$parent_dir/$pattern"
            
            # Check if file matches the pattern using bash pattern matching
            if [[ "$file" == $full_pattern ]]; then
                log_debug "File $file matches ignore pattern: $pattern"
                return 0  # Should ignore
            fi
        fi
    done < "$ignore_file"
    
    return 1  # Don't ignore
}

# ============================================================================
# Performance Utilities
# ============================================================================

run_parallel() {
    local max_jobs=${1:-4}
    shift
    local -a pids=()
    
    for cmd in "$@"; do
        if [[ ${#pids[@]} -ge $max_jobs ]]; then
            wait "${pids[0]}"
            pids=("${pids[@]:1}")
        fi
        
        eval "$cmd" &
        pids+=($!)
    done
    
    # Wait for remaining jobs
    for pid in "${pids[@]}"; do
        wait "$pid"
    done
}

# ============================================================================
# Initialization
# ============================================================================

# Automatically setup error handling when sourced
setup_error_handling

log_debug "Common utilities loaded"