#!/bin/bash
# ============================================================================
# Decision-Driven Development System - Easy Installation Script
# ============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
INSTALL_DIR="${DDD_INSTALL_DIR:-$HOME/.local/share/ddd-system}"
BIN_DIR="${DDD_BIN_DIR:-$HOME/.local/bin}"
GITHUB_REPO="https://github.com/on-the-ground/decision-driven-development"
TEMP_DIR=""

# Utility functions
log() {
    echo -e "${GREEN}[DDD INSTALLER]${NC} $*"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*"
    exit 1
}

cleanup() {
    if [[ -n "${TEMP_DIR:-}" && -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
}

trap cleanup EXIT

# Check prerequisites
check_prerequisites() {
    log "🔍 Checking prerequisites..."
    
    # Check if git is available
    if ! command -v git >/dev/null 2>&1; then
        error "Git is required but not installed. Please install git first."
    fi
    
    # Check if we're in a terminal that supports colors
    if [[ ! -t 1 ]]; then
        RED=""
        GREEN=""
        YELLOW=""
        BLUE=""
        NC=""
    fi
    
    log "✅ Prerequisites check passed"
}

# Download DDD system
download_system() {
    log "📥 Downloading DDD system..."
    
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    
    # Try to download from GitHub
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "${GITHUB_REPO}/archive/main.tar.gz" | tar -xz --strip-components=1
    elif command -v wget >/dev/null 2>&1; then
        wget -qO- "${GITHUB_REPO}/archive/main.tar.gz" | tar -xz --strip-components=1
    else
        # Fallback to git clone
        git clone --depth=1 "$GITHUB_REPO.git" .
    fi
    
    if [[ ! -f "ddd-system.sh" ]]; then
        error "Failed to download DDD system. Please check your internet connection."
    fi
    
    log "✅ DDD system downloaded successfully"
}

# Install the system
install_system() {
    log "🔧 Installing DDD system..."
    
    # Create installation directories only if they don't exist
    if [[ ! -d "$INSTALL_DIR" ]]; then
        log "Creating installation directory: $INSTALL_DIR"
        mkdir -p "$INSTALL_DIR"
    else
        log "Installation directory already exists: $INSTALL_DIR"
    fi
    
    if [[ ! -d "$BIN_DIR" ]]; then
        log "Creating binary directory: $BIN_DIR"
        mkdir -p "$BIN_DIR"
    else
        log "Binary directory already exists: $BIN_DIR"
    fi
    
    # Copy files only if they don't exist or are different
    local files_updated=0
    for file in *; do
        [[ "$file" == "*" ]] && continue  # Skip if no files match
        
        local target="$INSTALL_DIR/$file"
        if [[ ! -e "$target" ]] || ! cmp -s "$file" "$target" 2>/dev/null; then
            if [[ -d "$file" ]]; then
                cp -r "$file" "$INSTALL_DIR/"
            else
                cp "$file" "$INSTALL_DIR/"
            fi
            files_updated=$((files_updated + 1))
        fi
    done
    
    if [[ $files_updated -gt 0 ]]; then
        log "Updated $files_updated files/directories"
    else
        log "All files are up to date"
    fi
    
    # Make scripts executable only if needed
    if find "$INSTALL_DIR" -name "*.sh" ! -executable | grep -q .; then
        find "$INSTALL_DIR" -name "*.sh" ! -executable -exec chmod +x {} \;
        log "Made shell scripts executable"
    fi
    
    # Create wrapper script only if it doesn't exist or is different
    local wrapper_script="$BIN_DIR/ddd"
    local expected_content="#!/bin/bash
exec \"$INSTALL_DIR/ddd-system.sh\" \"\$@\""
    
    if [[ ! -f "$wrapper_script" ]] || [[ "$(cat "$wrapper_script" 2>/dev/null)" != "$expected_content" ]]; then
        log "Creating/updating wrapper script"
        cat > "$wrapper_script" << EOF
#!/bin/bash
exec "$INSTALL_DIR/ddd-system.sh" "\$@"
EOF
        chmod +x "$wrapper_script"
    else
        log "Wrapper script is up to date"
    fi
    
    log "✅ DDD system installed to $INSTALL_DIR"
}

# Setup PATH if needed
setup_path() {
    local shell_rc=""
    local current_shell=""
    
    # Detect shell
    if [[ -n "${BASH_VERSION:-}" ]]; then
        current_shell="bash"
        shell_rc="$HOME/.bashrc"
    elif [[ -n "${ZSH_VERSION:-}" ]]; then
        current_shell="zsh"
        shell_rc="$HOME/.zshrc"
    else
        current_shell="unknown"
    fi
    
    # Check if BIN_DIR is in PATH
    if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
        warn "$BIN_DIR is not in your PATH"
        
        if [[ -n "$shell_rc" && -f "$shell_rc" ]]; then
            # Check if PATH export already exists in shell rc
            local path_export="export PATH=\"\$HOME/.local/bin:\$PATH\""
            if ! grep -Fq "$path_export" "$shell_rc" 2>/dev/null; then
                echo ""
                echo -e "${BLUE}To add it to your PATH, run:${NC}"
                echo "  echo '$path_export' >> $shell_rc"
                echo "  source $shell_rc"
                echo ""
                echo -e "${BLUE}Or run this one-liner:${NC}"
                echo "  echo '$path_export' >> $shell_rc && source $shell_rc"
            else
                echo ""
                echo -e "${BLUE}PATH export already exists in $shell_rc but may need to be sourced:${NC}"
                echo "  source $shell_rc"
            fi
        else
            echo ""
            echo -e "${BLUE}Add this to your shell profile:${NC}"
            echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
        fi
        echo ""
    fi
}

# Verify installation
verify_installation() {
    log "🧪 Verifying installation..."
    
    if [[ ! -x "$BIN_DIR/ddd" ]]; then
        error "Installation verification failed. ddd command not found at $BIN_DIR/ddd"
    fi
    
    # Test basic functionality
    if "$BIN_DIR/ddd" --help >/dev/null 2>&1; then
        log "✅ Installation verification passed"
    else
        warn "Installation completed but ddd command may not work properly"
    fi
}

# Show usage information
show_usage() {
    cat << EOF

🎯 Decision-Driven Development System Installed!

QUICK START:
  ddd bootstrap                     # Initialize DDD in current project
  ddd init src/auth                 # Create .decision directory for a module
  ddd decision src/auth "jwt-impl"  # Create a decision document
  ddd status                        # Check system health

EXAMPLES:
  # Start using DDD in your project
  cd /path/to/your/project
  ddd bootstrap

  # Create your first decision
  ddd init src/
  ddd decision src "initial-architecture"

  # Search and analyze decisions
  ddd search "authentication"
  ddd timeline
  ddd progress

HELP:
  ddd --help                        # Show all available commands

DOCUMENTATION:
  https://github.com/on-the-ground/decision-driven-development

EOF
}

# Main installation process
main() {
    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                                                                  ║${NC}"
    echo -e "${BLUE}║  🎯 Decision-Driven Development System Installer                ║${NC}"
    echo -e "${BLUE}║                                                                  ║${NC}"
    echo -e "${BLUE}║  Transform your codebase with systematic decision tracking      ║${NC}"
    echo -e "${BLUE}║                                                                  ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    check_prerequisites
    download_system
    install_system
    verify_installation
    setup_path
    show_usage
    
    echo -e "${GREEN}🚀 Ready to revolutionize your development process!${NC}"
    echo ""
}

# Handle command line arguments
case "${1:-install}" in
    "install"|"")
        main
        ;;
    "uninstall")
        log "🗑️  Uninstalling DDD system..."
        rm -rf "$INSTALL_DIR"
        rm -f "$BIN_DIR/ddd"
        log "✅ DDD system uninstalled"
        ;;
    "reinstall")
        log "🔄 Reinstalling DDD system..."
        rm -rf "$INSTALL_DIR"
        rm -f "$BIN_DIR/ddd"
        main
        ;;
    "help"|"--help"|"-h")
        echo "DDD System Installer"
        echo ""
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  install      Install DDD system (default)"
        echo "  uninstall    Remove DDD system"
        echo "  reinstall    Clean reinstall"
        echo "  help         Show this help"
        echo ""
        echo "Environment variables:"
        echo "  DDD_INSTALL_DIR    Installation directory (default: ~/.local/share/ddd-system)"
        echo "  DDD_BIN_DIR        Binary directory (default: ~/.local/bin)"
        ;;
    *)
        error "Unknown command: $1. Use 'install', 'uninstall', 'reinstall', or 'help'."
        ;;
esac