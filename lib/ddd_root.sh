#!/bin/bash
# ============================================================================
# DDD System Root Detection Library
# ============================================================================

find_ddd_root() {
    local ddd_root=""
    
    # Try to find ddd-system directory in standard locations
    if [[ -d "${HOME}/.local/share/ddd-system" ]]; then
        ddd_root="${HOME}/.local/share/ddd-system"
    elif [[ -d "$(git rev-parse --show-toplevel 2>/dev/null)/ddd-system" ]]; then
        ddd_root="$(git rev-parse --show-toplevel)/ddd-system"
    fi
    
    if [[ -z "$ddd_root" ]]; then
        echo "❌ ERROR: Cannot find ddd-system directory" >&2
        echo "Expected locations: ${HOME}/.local/share/ddd-system or repository/ddd-system" >&2
        return 1
    fi
    
    echo "$ddd_root"
}