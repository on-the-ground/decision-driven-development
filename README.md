# 🎯 Decision-Driven Development System

**Transform your codebase with systematic decision tracking and enforcement**

Never lose track of *why* decisions were made. Enforce that every code change is backed by documented reasoning. Make your codebase self-documenting and your team more aligned.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Shell](https://img.shields.io/badge/Shell-Bash-blue.svg)](https://www.gnu.org/software/bash/)
[![Platform](https://img.shields.io/badge/Platform-Linux%20%7C%20macOS%20%7C%20WSL-lightgrey.svg)](https://github.com/on-the-ground/decision-driven-development)

## ⚡ Quick Start (1 minute setup)

### Install globally with one command:

```bash
curl -fsSL https://raw.githubusercontent.com/on-the-ground/decision-driven-development/main/install.sh | bash
```

### Start using in your project:

```bash
cd your-project
ddd bootstrap              # Setup DDD system
ddd init src/auth          # Create decision tracking for auth module
ddd decision src/auth "jwt-implementation"  # Document your first decision
```

That's it! Your codebase now has decision-driven development enabled. 🚀

## 🎬 See It In Action

```bash
# Initialize DDD in your project
$ ddd bootstrap
🚀 Bootstrapping Decision-Driven Project...
✅ Decision-driven project initialized!

# Create a decision for your authentication module
$ ddd decision src/auth "user-authentication-method"
📝 Opening decision file for editing...
✅ Created immutable decision: src/auth/.decision/20240827-1200-user-authentication-method.md

# Now when you commit code changes, DDD enforces decision coupling
$ git add src/auth/login.js
$ git commit -m "Implement JWT authentication"
🔍 Enforcing Decision-Driven Development policies...
✅ All decision-driven development policies passed
```

## 🔥 Why Decision-Driven Development?

### The Problem
- **Lost Context**: 6 months later, nobody remembers why this code was written this way
- **Technical Debt**: Changes are made without understanding original decisions  
- **Team Misalignment**: Different developers make contradictory architectural choices
- **Knowledge Silos**: When team members leave, their reasoning goes with them

### The Solution
DDD ensures **every code change is backed by documented reasoning**:

✅ **Decision Coupling**: Code changes must include decision documents  
✅ **Immutable History**: Decisions can never be modified, only extended  
✅ **Automatic Enforcement**: Git hooks prevent policy violations  
✅ **Searchable Decisions**: Find the reasoning behind any piece of code  
✅ **Progress Tracking**: See decision implementation status across modules

## 🛠️ Installation Options

### Option 1: One-Line Install (Recommended)
```bash
curl -fsSL https://raw.githubusercontent.com/on-the-ground/decision-driven-development/main/install.sh | bash
```

### Option 2: Manual Installation
```bash
git clone https://github.com/on-the-ground/decision-driven-development.git
cd decision-driven-development
./install.sh
```

### Option 3: Project-Local Installation
```bash
# Download to your project
curl -fsSL https://github.com/on-the-ground/decision-driven-development/archive/main.tar.gz | tar -xz
mv decision-driven-development-main ddd-system
./ddd-system.sh bootstrap
```

## 🎮 Usage

### Core Commands
```bash
ddd bootstrap                    # Initialize project with DDD
ddd init <directory>             # Setup .decision tracking for a module  
ddd decision <dir> <title>       # Create new decision document
ddd status                       # Show system health and stats
```

### Analysis & Search
```bash
ddd search "authentication"      # Search decisions for keywords
ddd timeline                     # Chronological decision history
ddd progress                     # Module-wise implementation progress
```

### Workflow Integration
```bash
ddd commit-msg                   # Generate commit message from decisions
ddd validate                     # Check system integrity
ddd github                       # Setup GitHub Actions workflow
```

## 📖 Complete Example

### 1. Setup Your Project
```bash
cd my-awesome-app
ddd bootstrap                    # Install git hooks and setup
```

### 2. Initialize Module Tracking
```bash
ddd init src/auth               # Track decisions for auth module
ddd init src/api                # Track decisions for API module
```

### 3. Create Your First Decision
```bash
ddd decision src/auth "password-hashing-algorithm"
```

This opens an editor with a template:
```markdown
# Password Hashing Algorithm

**TIMESTAMP**: 2024-08-27 12:00
**STATUS**: TODO
**MODULE**: src/auth

## Context
Our application needs secure password storage...

## Alternatives Considered
1. bcrypt: Industry standard, well-tested
2. scrypt: More memory-intensive, newer
3. Argon2: Winner of password hashing competition

## Decision
Use Argon2 for new implementations, migrate from bcrypt gradually.

## Implementation
**FILES**: 
- src/auth/password.js
- src/auth/migration.js

## Consequences
- Better security against rainbow table attacks
- Requires new dependency (argon2)
- Migration path needed for existing users
```

### 4. Implement Code Changes
```bash
# Edit your code files
vim src/auth/password.js

# Stage everything
git add src/auth/

# Commit (DDD automatically validates decision coupling)
git commit -m "feat(auth): implement Argon2 password hashing"
```

### 5. Track Progress
```bash
ddd progress
📊 Module Progress Report
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
src/auth: 1/3 done (33%), 1 in progress  
src/api: 0/1 done (0%), 0 in progress
```

## 🎯 Advanced Features

### GitHub Integration
```bash
ddd github                       # Creates .github/workflows/decision-policy.yml
```

Auto-validates decisions in pull requests and enforces coupling requirements.

### Custom Installation Paths
```bash
export DDD_INSTALL_DIR="$HOME/tools/ddd"
export DDD_BIN_DIR="$HOME/bin"
./install.sh
```

### Debug Mode
```bash
export DDD_LOG_LEVEL="DEBUG"
ddd status                       # Shows detailed logging
```

## 🔧 System Requirements

- **OS**: Linux, macOS, or Windows WSL
- **Dependencies**: Git, Bash 4.0+
- **Optional**: curl or wget (for installation)

## 📁 Project Structure

After installation, decisions are tracked in `.decision/` directories:

```
your-project/
├── src/
│   ├── auth/
│   │   ├── .decision/
│   │   │   ├── README.md
│   │   │   ├── 20240827-1200-password-hashing.md
│   │   │   └── 20240827-1330-session-management.md
│   │   ├── login.js
│   │   └── password.js
│   └── api/
│       ├── .decision/
│       │   └── 20240827-1400-rest-vs-graphql.md
│       └── routes.js
└── .git/hooks/                 # DDD enforcement hooks installed
```

## 🚫 What DDD Prevents

❌ **Decision-only commits** (decisions must accompany code)  
❌ **Modifying decision files** (immutable once created)  
❌ **Code without decisions** (every change needs reasoning)  
❌ **Ignoring .decision directories** (can't hide decisions)  
❌ **Symlinked decision files** (prevents tampering)

## ❓ Troubleshooting

### Common Issues

**"ddd command not found"**
```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

**"Permission denied"**
```bash
chmod +x ~/.local/bin/ddd
```

**"No decision directory found"**
```bash
ddd init src/your-module        # Create .decision directory first
```

### Get Help
```bash
ddd --help                      # Show all commands
ddd status                      # Check system health
ddd validate                    # Verify system integrity
```

## 📁 Decision File Format

Decision files follow a structured markdown template:

```markdown
# Decision Title

**TIMESTAMP**: 2024-08-27 12:00
**STATUS**: TODO|IN_PROGRESS|DONE  
**MODULE**: src/auth

## Context
Why is this decision needed? What problem are we solving?

## Alternatives Considered
1. Option A: Pros/Cons
2. Option B: Pros/Cons
3. **Option C (Selected)**: Pros/Cons

## Decision
What are we doing and why?

## Implementation
**FILES**: List files that will be changed
**ESTIMATED_EFFORT**: Time estimate
**DEPENDENCIES**: Prerequisites

## Consequences
What becomes easier or harder after this decision?
```

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md).

1. Fork the repository
2. Create your feature branch
3. Add tests for new functionality  
4. Run the test suite: `ddd test`
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🌟 Support

- ⭐ **Star this repo** if DDD helps your project!
- 🐛 **Report issues** on GitHub Issues
- 💡 **Request features** via GitHub Discussions
- 📧 **Contact us** for enterprise support

---

**Transform your development workflow today with Decision-Driven Development!** 🚀