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
    
    # Check for .decision patterns that are NOT in comments
    local violation_found=false
    while IFS= read -r gitignore_file; do
        while IFS= read -r line || [[ -n "$line" ]]; do
            # Skip empty lines
            [[ -z "$line" ]] && continue
            # Skip comment lines (lines starting with # after optional whitespace)
            [[ "$line" =~ ^[[:space:]]*# ]] && continue
            # Check if remaining line contains .decision
            if [[ "$line" == *".decision"* ]]; then
                log_error "POLICY VIOLATION: .gitignore contains forbidden '.decision' pattern: $line"
                violation_found=true
            fi
        done < "$gitignore_file"
    done < <(find . -name '.gitignore' -type f 2>/dev/null)
    
    if [[ "$violation_found" == true ]]; then
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
        
        # Resolve file path (handle both absolute and relative paths)  
        local resolved_file="$file"
        
        # If file doesn't exist as is, try from git root
        if [[ ! -f "$resolved_file" ]]; then
            local git_root
            git_root=$(get_git_root 2>/dev/null || echo ".")
            if [[ -f "$git_root/$file" ]]; then
                resolved_file="$git_root/$file"
            fi
        fi
        
        # Ensure file exists before validation
        if [[ ! -f "$resolved_file" ]]; then
            log_error "Decision file not found: $file (tried: $resolved_file)"
            return 1
        fi
        
        # Set readonly permissions for new decision files
        if [[ -w "$resolved_file" ]]; then
            log_debug "Setting readonly permissions for: $resolved_file"  
            chmod 444 "$resolved_file"
        fi
        
        # Validate file permissions
        if ! validate_file_permissions "$resolved_file"; then
            return 1
        fi
    done
    
    log_debug "Decision file immutability validation passed"
    return 0
}

validate_decision_only_commits() {
    local -a non_decision_files=()
    local -a decision_files=()
    
    mapfile -t staged_files < <(get_staged_files)
    
    for file in "${staged_files[@]}"; do
        if is_decision_file "$file"; then
            decision_files+=("$file")
        elif should_validate_file "$file"; then
            non_decision_files+=("$file")
        fi
    done
    
    log_debug "Non-decision changes: ${#non_decision_files[@]} files, Decision changes: ${#decision_files[@]} files"
    
    if [[ ${#non_decision_files[@]} -eq 0 && ${#decision_files[@]} -gt 0 ]]; then
        log_error "POLICY VIOLATION: Decision-only commits are not allowed"
        log_info "Create decisions together with actual changes"
        return 1
    fi
    
    return 0
}

validate_per_file_decisions() {
    log_debug "Validating per-file decision requirements"
    
    local -a staged_files files_to_validate decision_files
    mapfile -t staged_files < <(get_staged_files)
    
    for file in "${staged_files[@]}"; do
        if is_decision_file "$file"; then
            decision_files+=("$file")
        elif should_validate_file "$file"; then
            files_to_validate+=("$file")
        fi
    done
    
    if [[ ${#files_to_validate[@]} -eq 0 ]]; then
        log_debug "No files to validate"
        return 0
    fi
    
    # Get directories that have .decision subdirectories in staged files
    local -A decision_exempted_dirs=()
    for decision_file in "${decision_files[@]}"; do
        if [[ "$decision_file" == *"/.decision/"* ]]; then
            # Extract the parent directory that contains .decision
            local parent_dir="${decision_file%%/.decision/*}"
            decision_exempted_dirs["$parent_dir"]=1
        fi
    done
    
    local missing_any=false
    local -a report=()
    
    for file in "${files_to_validate[@]}"; do
        # Check if this file is under a directory that has .decision changes
        local file_exempted=false
        for exempt_dir in "${!decision_exempted_dirs[@]}"; do
            if [[ "$file" == "$exempt_dir"/* ]]; then
                file_exempted=true
                break
            fi
        done
        
        # If file is exempted, skip validation
        if [[ "$file_exempted" == true ]]; then
            continue
        fi
        
        local decision_dir
        decision_dir=$(find_nearest_decision_dir "$file")
        
        # Check if file should be ignored based on ignore patterns
        # First check nearest decision directory
        local should_skip=false
        if should_ignore_file "$file" "$decision_dir"; then
            log_debug "Skipping ignored file (local): $file"
            should_skip=true
        fi
        
        # Also check root-level ignore if it exists and we haven't already decided to skip
        if [[ "$should_skip" == false ]]; then
            local git_root
            git_root=$(get_git_root 2>/dev/null || echo ".")
            local root_decision_dir="$git_root/.decision"
            if [[ -d "$root_decision_dir" && "$root_decision_dir" != "$decision_dir" ]]; then
                if should_ignore_file "$file" "$root_decision_dir"; then
                    log_debug "Skipping ignored file (root): $file"
                    should_skip=true
                fi
            fi
        fi
        
        if [[ "$should_skip" == true ]]; then
            continue
        fi
        
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
    
    # Get directories that have .decision subdirectories in this range
    local -A decision_exempted_dirs=()
    while IFS=$'\t' read -r status p1 p2; do
        case "$status" in
            A*|C*|R*)
                local path="${p2:-$p1}"
                if [[ "$path" == *"/.decision/"* ]]; then
                    # Extract the parent directory that contains .decision
                    local parent_dir="${path%%/.decision/*}"
                    decision_exempted_dirs["$parent_dir"]=1
                    log_debug "Added to decision_exempted_dirs: '$parent_dir' (from path: $path)"
                elif [[ "$path" == ".decision/"* ]]; then
                    # Handle root-level .decision directory
                    decision_exempted_dirs["."]=1
                    log_debug "Added to decision_exempted_dirs: '.' (root from path: $path)"
                fi
                ;;
        esac
    done < <(git diff --name-status "$from_ref..$to_ref" 2>/dev/null || true)
    
    # Debug: show all exempted directories
    if [[ ${#decision_exempted_dirs[@]} -gt 0 ]]; then
        log_debug "Decision exempted directories: ${!decision_exempted_dirs[*]}"
    else
        log_debug "No decision exempted directories found"
    fi
    
    local -a errors=()
    for file in "${changed_files[@]}"; do
        should_validate_file "$file" || continue
        
        # Check if this file is under a directory that has .decision changes
        local file_exempted=false
        for exempt_dir in "${!decision_exempted_dirs[@]}"; do
            if [[ "$exempt_dir" == "." ]]; then
                # Root directory exempts all files
                file_exempted=true
                log_debug "File $file is exempted by root directory"
                break
            elif [[ "$file" == "$exempt_dir"/* ]]; then
                file_exempted=true
                log_debug "File $file is exempted by directory: $exempt_dir"
                break
            fi
        done
        
        # If file is exempted, skip validation
        if [[ "$file_exempted" == true ]]; then
            continue
        fi
        
        log_debug "File $file is NOT exempted, proceeding with validation"
        
        local decision_dir
        decision_dir=$(find_nearest_decision_dir "$file")
        
        # Check if decision directory exists in new tree
        if ! git ls-tree -d --name-only "$to_ref" -- "$decision_dir" >/dev/null 2>&1; then
            errors+=(" - $file ➜ missing nearest decision dir in tree: $decision_dir")
            continue
        fi
        
        # Check if file should be ignored based on ignore patterns
        # For range validation, we need to check the ignore file in the to_ref
        local ignore_content
        ignore_content=$(git show "$to_ref:$decision_dir/ignore" 2>/dev/null || echo "")
        if [[ -n "$ignore_content" ]]; then
            local parent_dir="${decision_dir%/.decision}"
            local should_ignore=false
            while IFS= read -r pattern || [[ -n "$pattern" ]]; do
                [[ -z "$pattern" ]] && continue
                [[ "$pattern" =~ ^[[:space:]]*# ]] && continue
                pattern="${pattern#"${pattern%%[![:space:]]*}"}"
                pattern="${pattern%"${pattern##*[![:space:]]}"}"
                local full_pattern="$parent_dir/$pattern"
                if [[ "$file" == $full_pattern ]]; then
                    should_ignore=true
                    break
                fi
            done <<< "$ignore_content"
            
            if [[ "$should_ignore" == true ]]; then
                log_debug "Skipping ignored file in range: $file"
                continue
            fi
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

validate_existing_decision_permissions() {
    log_debug "Validating existing decision file permissions"
    
    local error_found=false
    while IFS= read -r decision_file; do
        if [[ -f "$decision_file" ]]; then
            if ! validate_file_permissions "$decision_file"; then
                error_found=true
            fi
        fi
    done < <(find . -name "*.md" -path "*/.decision/*" -type f 2>/dev/null || true)
    
    if [[ "$error_found" == true ]]; then
        log_error "POLICY VIOLATION: Existing decision files have wrong permissions"
        return 1
    fi
    
    log_debug "Existing decision permissions validation passed"
    return 0
}

