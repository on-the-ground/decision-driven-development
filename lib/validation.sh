#!/bin/bash
# ============================================================================
# Validation library for Decision-Driven Development System
# ============================================================================

# Source common utilities
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# ============================================================================
# Core Validation Functions
# ============================================================================

validate_gitignore_policy() {
    log_debug "Validating .gitignore policy"
    
    if find . -name '.gitignore' -type f | xargs grep -RIn '\.decision' 2>/dev/null \
        | awk -F: '!($3 ~ /^[[:space:]]*#/) {found=1; exit} END{exit !found}'; then
        log_error "POLICY VIOLATION: .gitignore contains forbidden '.decision' pattern"
        return 1
    fi
    
    log_debug ".gitignore policy validation passed"
    return 0
}

validate_decision_file_immutability() {
    local -a decision_files=()
    mapfile -t decision_files < <(get_staged_files | grep '\.decision/.*\.md$' || true)
    
    if [[ ${#decision_files[@]} -eq 0 ]]; then
        log_debug "No decision files to validate"
        return 0
    fi
    
    log_debug "Validating immutability of ${#decision_files[@]} decision files"
    
    local has_head
    has_head && has_head=true || has_head=false
    
    for file in "${decision_files[@]}"; do
        # Check if file is being modified (exists in HEAD)
        if $has_head && git cat-file -e HEAD:"$file" 2>/dev/null; then
            log_error "POLICY VIOLATION: Attempting to modify immutable decision file: $file"
            log_info "Decision files are immutable. Add a NEW file instead."
            return 1
        fi
        
        # Validate new file
        if ! validate_file_permissions "$file"; then
            return 1
        fi
    done
    
    log_debug "Decision file immutability validation passed"
    return 0
}

validate_decision_only_commits() {
    local -a code_files=()
    local -a decision_files=()
    
    mapfile -t staged_files < <(get_staged_files)
    
    for file in "${staged_files[@]}"; do
        if is_decision_file "$file"; then
            decision_files+=("$file")
        elif is_code_file "$file"; then
            code_files+=("$file")
        fi
    done
    
    log_debug "Code changes: ${#code_files[@]} files, Decision changes: ${#decision_files[@]} files"
    
    if [[ ${#code_files[@]} -eq 0 && ${#decision_files[@]} -gt 0 ]]; then
        log_error "POLICY VIOLATION: Decision-only commits are not allowed"
        log_info "Create decisions together with actual code changes"
        return 1
    fi
    
    return 0
}

validate_per_file_decisions() {
    log_debug "Validating per-file decision requirements"
    
    local -a staged_files code_files decision_files
    mapfile -t staged_files < <(get_staged_files)
    
    for file in "${staged_files[@]}"; do
        if is_decision_file "$file"; then
            decision_files+=("$file")
        elif is_code_file "$file"; then
            code_files+=("$file")
        fi
    done
    
    if [[ ${#code_files[@]} -eq 0 ]]; then
        log_debug "No code files to validate"
        return 0
    fi
    
    local missing_any=false
    local -a report=()
    
    for file in "${code_files[@]}"; do
        local decision_dir
        decision_dir=$(find_nearest_decision_dir "$file")
        
        # Check if .decision directory exists
        if [[ ! -d "$decision_dir" ]]; then
            missing_any=true
            report+=(" - $file ➜ missing nearest decision dir: $decision_dir")
            continue
        fi
        
        # Check if any new decision in this directory mentions this file
        local found_ref=false
        for decision_file in "${decision_files[@]}"; do
            if [[ "$(dirname "$decision_file")" == "$decision_dir" ]]; then
                local content
                content=$(get_decision_content "$decision_file")
                if file_mentions_in_content "$file" "$content"; then
                    found_ref=true
                    break
                fi
            fi
        done
        
        if [[ "$found_ref" == false ]]; then
            missing_any=true
            report+=(" - $file ➜ no new decision in $decision_dir mentions this file")
        fi
    done
    
    if [[ "$missing_any" == true ]]; then
        log_error "POLICY VIOLATION: Per-file decision missing"
        printf '%s\n' "${report[@]}" >&2
        log_info "For each changed file, create a decision under its nearest '.decision' dir and mention the file path"
        return 1
    fi
    
    log_debug "Per-file decision validation passed"
    return 0
}

# ============================================================================
# Range-based Validation (for push/receive hooks)
# ============================================================================

validate_range_decisions() {
    local from_ref="$1"
    local to_ref="$2"
    
    log_debug "Validating decisions for range $from_ref..$to_ref"
    
    # Get changed files (using new path for renames)
    local -a changed_files
    mapfile -t changed_files < <(get_changed_files_in_range "$from_ref" "$to_ref")
    
    if [[ ${#changed_files[@]} -eq 0 ]]; then
        log_debug "No files changed in range"
        return 0
    fi
    
    # Get added decision directories
    local -A added_decision_dirs=()
    while IFS=$'\t' read -r status p1 p2; do
        case "$status" in
            A*|C*|R*)
                local path="${p2:-$p1}"
                if is_decision_file "$path"; then
                    added_decision_dirs["$(dirname "$path")"]=1
                fi
                ;;
        esac
    done < <(git diff --name-status "$from_ref..$to_ref" 2>/dev/null || true)
    
    local -a errors=()
    for file in "${changed_files[@]}"; do
        is_code_file "$file" || continue
        
        local decision_dir
        decision_dir=$(find_nearest_decision_dir "$file")
        
        # Check if decision directory exists in new tree
        if ! git ls-tree -d --name-only "$to_ref" -- "$decision_dir" >/dev/null 2>&1; then
            errors+=(" - $file ➜ missing nearest decision dir in tree: $decision_dir")
            continue
        fi
        
        # Check if new decision was added to this directory
        if [[ -z "${added_decision_dirs["$decision_dir"]+x}" ]]; then
            errors+=(" - $file ➜ no new decision added under $decision_dir in this range")
            continue
        fi
        
        # Check if the new decisions mention this file
        local mentioned=false
        while IFS=$'\t' read -r s pp1 pp2; do
            case "$s" in
                A*|C*|R*)
                    local dec_path="${pp2:-$pp1}"
                    [[ "$(dirname "$dec_path")" != "$decision_dir" ]] && continue
                    
                    local content
                    content="$(git show "$to_ref:$dec_path" 2>/dev/null || true)"
                    if file_mentions_in_content "$file" "$content"; then
                        mentioned=true
                        break
                    fi
                    ;;
            esac
        done < <(git diff --name-status "$from_ref..$to_ref" 2>/dev/null || true)
        
        if [[ "$mentioned" == false ]]; then
            errors+=(" - $file ➜ new decisions under $decision_dir do not mention this file")
        fi
    done
    
    if [[ ${#errors[@]} -gt 0 ]]; then
        log_error "RANGE VALIDATION FAILED: Per-file decision requirement not satisfied"
        printf '%s\n' "${errors[@]}" >&2
        return 1
    fi
    
    log_debug "Range decision validation passed"
    return 0
}

# ============================================================================
# CI/CD Validation
# ============================================================================

validate_existing_decision_permissions() {
    log_debug "Validating permissions of existing decision files"
    
    # Only check staged .decision files for proper permissions
    local -a staged_decision_files
    mapfile -t staged_decision_files < <(get_staged_files | grep '^\.decision/.*\.md$' || true)
    
    if [[ ${#staged_decision_files[@]} -eq 0 ]]; then
        log_debug "No staged decision files to check"
        return 0
    fi
    
    for file in "${staged_decision_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            continue
        fi
        
        # Check if file has readonly permissions
        if [[ ! -r "$file" ]] || [[ -w "$file" ]]; then
            log_warn "Decision file should be readonly: $file"
            log_info "Setting readonly permissions..."
            chmod 444 "$file"
        fi
    done
    
    log_debug "Existing decision permissions validation passed"
    return 0
}