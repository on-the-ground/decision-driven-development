#!/bin/bash
# ============================================================================
# DDD System Root Detection Library
# ============================================================================

find_ddd_root() {
    local ddd_root=""
    
    # Debug output
    [[ "${DDD_LOG_LEVEL:-}" == "DEBUG" ]] && echo "🔍 DEBUG: Finding DDD root..." >&2
    
    # Try to find ddd-system directory in standard locations
    if [[ -d "${HOME}/.local/share/ddd-system" ]]; then
        ddd_root="${HOME}/.local/share/ddd-system"
        [[ "${DDD_LOG_LEVEL:-}" == "DEBUG" ]] && echo "🔍 DEBUG: Found DDD root at: $ddd_root" >&2
    elif [[ -d "$(git rev-parse --show-toplevel 2>/dev/null)/ddd-system" ]]; then
        ddd_root="$(git rev-parse --show-toplevel)/ddd-system"
        [[ "${DDD_LOG_LEVEL:-}" == "DEBUG" ]] && echo "🔍 DEBUG: Found DDD root at: $ddd_root" >&2
    fi
    
    if [[ -z "$ddd_root" ]]; then
        echo "❌ ERROR: Cannot find ddd-system directory" >&2
        echo "Expected locations: ${HOME}/.local/share/ddd-system or repository/ddd-system" >&2
        return 1
    fi
    
    # Verify the directory structure
    if [[ ! -d "$ddd_root/lib" ]]; then
        echo "❌ ERROR: Invalid DDD system structure - missing lib directory in $ddd_root" >&2
        return 1
    fi
    
    echo "$ddd_root"
}