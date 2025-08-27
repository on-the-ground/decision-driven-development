#!/bin/bash
# ============================================================================
# Core operations for Decision-Driven Development System
# ============================================================================

# Source common utilities
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# ============================================================================
# Project Initialization
# ============================================================================

bootstrap_decision_project() {
    log_info "🚀 Bootstrapping Decision-Driven Project..."
    
    validate_git_repo || return 1
    
    # Install git hooks
    install_git_hooks || return 1
    
    log_info "✅ Decision-driven project initialized!"
    cat << EOF

💡 When you create directories with code:
   ddd init <directory>      # Initialize .decision
   ddd decision <directory> <title>  # Create decision
EOF
}

# ============================================================================
# Directory Initialization
# ============================================================================

init_decision_dir() {
    local target_dir=${1:-.}
    if [[ -z "$1" ]]; then
        log_error "Usage: init_decision_dir <directory>"
        log_info "Example: ddd init src/auth"
        return 1
    fi

    local decision_dir="$target_dir/.decision"
    
    # Check if already exists
    if [[ -d "$decision_dir" ]]; then
        log_info "✅ $decision_dir already exists"
        return 0
    fi

    # Create target directory if it doesn't exist
    if [[ ! -d "$target_dir" ]]; then
        log_info "📁 Creating directory: $target_dir"
        mkdir -p "$target_dir"
    fi

    # Create .decision directory
    mkdir -p "$decision_dir"

    # Create README.md
    local readme_file="$decision_dir/README.md"
    cat > "$readme_file" << EOF
# Decision Records for $(basename "$target_dir")

This directory contains immutable decision records for the $target_dir module.

## Usage
\`\`\`bash
# Create new decision
ddd decision $target_dir "your-decision-title"
\`\`\`

## Guidelines
- All files are immutable (readonly) 
- Create new files for new decisions
- Files cannot be modified after creation

## Format
- Filename: YYYYMMDD-HHMM-decision-title.md
- Required sections: CONTEXT, DECISION, REASONING, FILES

Created: $(date)
Directory: $target_dir
EOF

    chmod 444 "$readme_file"

    log_info "✅ Initialized $decision_dir with README.md"
    cat << EOF
💡 Next steps:
   git add $decision_dir/README.md
   ddd decision $target_dir "initial-setup"
EOF
}

# ============================================================================
# Decision Creation
# ============================================================================

create_decision() {
    local module_dir=${1:-.}
    local title=${2:-"untitled"}

    if [[ -z "$2" ]]; then
        log_error "Usage: create_decision <directory> <decision-title>"
        log_info "Example: create_decision src/auth user-authentication-method"
        return 1
    fi

    # Check if .decision directory exists
    local decision_dir="$module_dir/.decision"
    if [[ ! -d "$decision_dir" ]]; then
        log_error "Directory $module_dir has no .decision subdirectory"
        echo
        read -p "🤔 Initialize .decision directory for $module_dir? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            init_decision_dir "$module_dir" || return 1
        else
            log_info "Initialize manually with: ddd init $module_dir"
            return 1
        fi
    fi

    # Generate decision file
    local timestamp
    timestamp=$(date +"%Y%m%d-%H%M")
    local decision_file="$decision_dir/$timestamp-$title.md"
    
    # Get user info safely
    local user_name user_email
    user_name=$(git config user.name 2>/dev/null || echo "Unknown User")
    user_email=$(git config user.email 2>/dev/null || echo "unknown@example.com")

    # Create template
    cat > "$decision_file" << EOF
# $(echo "$title" | tr '-' ' ' | sed 's/\b\w/\u&/g')

**TIMESTAMP**: $(date '+%Y-%m-%d %H:%M')
**STATUS**: DRAFT
**MODULE**: $module_dir

## Context
Why is this decision needed? What problem are we solving?

## Alternatives Considered
1. Option A: 
   - Pros: 
   - Cons: 
2. Option B:
   - Pros:
   - Cons:
3. **Option C (Selected)**:
   - Pros:
   - Cons:

## Decision
What are we doing and why?

## Reasoning
Why this option over others? What are the trade-offs?

## Implementation
**FILES**: List files that will be changed
**ESTIMATED_EFFORT**: 
**DEPENDENCIES**: 

## Consequences
What becomes easier or harder after this decision?

**IMMUTABLE**: This file must never be modified after creation
**CREATED_BY**: $user_name <$user_email>
EOF

    log_info "📝 Opening decision file for editing..."
    ${EDITOR:-vim} "$decision_file"

    # Validate status change
    if grep -q "\*\*STATUS\*\*: DRAFT" "$decision_file"; then
        log_warn "Decision status is still DRAFT"
        log_info "Change STATUS to: TODO, IN_PROGRESS, or DONE"
        read -p "Continue anyway? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            rm -f "$decision_file"
            log_error "Decision file deleted"
            return 1
        fi
    fi

    # Set readonly permissions
    chmod 444 "$decision_file"

    log_info "✅ Created immutable decision: $decision_file"
    cat << EOF
💡 Next steps:
   git add $decision_file
   # Implement code changes
   # git add changed_files
   git commit
EOF
}

# ============================================================================
# Search and Analysis
# ============================================================================

search_decisions() {
    local term=${1:-""}
    if [[ -z "$term" ]]; then
        log_error "Usage: search_decisions <search_term>"
        return 1
    fi

    log_info "🔍 Searching decisions for: '$term'"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Use parallel processing for large repositories
    local -a search_commands=()
    while IFS= read -r file; do
        search_commands+=("grep -l -i '$term' '$file' && { echo '📄 $file'; grep -n -i -C2 '$term' '$file' | head -10; echo '────────────────────────────────────'; }")
    done < <(find . -path '*/.decision/*.md' -type f)
    
    if [[ ${#search_commands[@]} -gt 0 ]]; then
        run_parallel 4 "${search_commands[@]}"
    else
        log_info "No decision files found"
    fi
}

decision_timeline() {
    log_info "⏰ Decision Timeline"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    find . -path '*/.decision/*.md' -name '[0-9]*-*.md' -type f | while read -r file; do
        local timestamp module title status
        timestamp=$(basename "$file" | cut -d'-' -f1,2)
        module=$(dirname "$file" | sed 's|/.decision||' | sed 's|^\./||')
        title=$(head -1 "$file" 2>/dev/null | sed 's/^# //' || echo "Untitled")
        status=$(grep "^\*\*STATUS\*\*:" "$file" 2>/dev/null | cut -d':' -f2 | xargs || echo "UNKNOWN")
        echo "$timestamp [$status] [$module] $title"
    done | sort
}

module_progress() {
    log_info "📊 Module Progress Report"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    find . -name '.decision' -type d | while read -r decision_dir; do
        local module decision_files total done_count in_progress progress
        module=$(dirname "$decision_dir" | sed 's|^\./||')
        
        if ! decision_files=("$decision_dir"/*.md) || [[ ! -f "${decision_files[0]}" ]]; then
            continue
        fi
        
        total=$(ls "$decision_dir"/*.md 2>/dev/null | wc -l)
        done_count=$(grep -l "STATUS.*DONE" "$decision_dir"/*.md 2>/dev/null | wc -l)
        in_progress=$(grep -l "STATUS.*IN_PROGRESS" "$decision_dir"/*.md 2>/dev/null | wc -l)
        
        if [[ $total -gt 0 ]]; then
            progress=$((done_count * 100 / total))
            echo "$module: $done_count/$total done ($progress%), $in_progress in progress"
        fi
    done
}

# ============================================================================
# Commit Message Generation
# ============================================================================

generate_commit_message() {
    log_debug "Generating commit message based on decisions"
    
    local new_decisions
    new_decisions=$(git diff --cached --name-only --diff-filter=A | grep '.decision/.*\.md$' || true)

    if [[ -z "$new_decisions" ]]; then
        log_info "No new decision files found in staging area"
        return 0
    fi

    echo "# Auto-generated commit message based on decisions:"
    echo ""
    
    while IFS= read -r decision_file; do
        if [[ -z "$decision_file" ]]; then continue; fi
        
        local filename module title type context
        filename=$(basename "$decision_file")
        module=$(dirname "$decision_file" | sed 's|/.decision||' | sed 's|^\./||')
        title=$(echo "$filename" | cut -d'-' -f3- | sed 's/\.md$//' | tr '-' ' ')
        
        # Determine commit type based on context
        type="feat"
        if [[ -f "$decision_file" ]]; then
            context=$(sed -n '/## Context/,/##/p' "$decision_file" | head -n -1 | tail -n +2)
            if echo "$context" | grep -qi "bug\|error\|fix\|crash\|leak"; then
                type="fix"
            elif echo "$context" | grep -qi "performance\|memory\|speed\|optimization"; then
                type="perf"
            elif echo "$context" | grep -qi "refactor\|cleanup\|restructure"; then
                type="refactor"
            elif grep -q "EMERGENCY\|HOTFIX" "$decision_file"; then
                type="hotfix"
            fi
            echo "${type}(${module}): ${title}"
        fi
    done <<< "$new_decisions"
}