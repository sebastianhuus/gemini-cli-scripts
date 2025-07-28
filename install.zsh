#!/usr/bin/env zsh

# Installation script for gemini-cli-scripts
# Creates symlinks in /usr/local/bin for PATH usage

set -e  # Exit on any error

# Get the absolute path to this script's directory
SCRIPT_DIR="${${0:A}:h}"

# Target installation directory
INSTALL_DIR="/usr/local/bin"

# Scripts to install (without .zsh extension for cleaner commands)
declare -A SCRIPTS=(
    ["auto_commit.zsh"]="auto-commit"
    ["auto_pr.zsh"]="auto-pr"
    ["auto_issue.zsh"]="auto-issue"
)

# Build orchestrator if Go project exists
if [[ -d "$SCRIPT_DIR/orchestrator" ]] && [[ -f "$SCRIPT_DIR/orchestrator/go.mod" ]]; then
    echo "🔨 Building orchestrator..."
    if (cd "$SCRIPT_DIR/orchestrator" && go build -o gemini-orchestrator .); then
        echo "   ✅ Orchestrator built successfully"
        SCRIPTS[orchestrator/gemini-orchestrator]="gemini-orchestrator"
    else
        echo "   ⚠️  Failed to build orchestrator, skipping"
    fi
fi

echo "🔧 Installing gemini-cli-scripts to PATH..."
echo "   Source: $SCRIPT_DIR"
echo "   Target: $INSTALL_DIR"
echo ""

# Create /usr/local/bin if it doesn't exist
if [[ ! -d "$INSTALL_DIR" ]]; then
    echo "📁 Creating $INSTALL_DIR directory..."
    if sudo mkdir -p "$INSTALL_DIR"; then
        echo "   ✅ Directory created successfully"
    else
        echo "   ❌ Failed to create directory"
        exit 1
    fi
else
    echo "📁 Directory $INSTALL_DIR already exists"
fi

echo ""

# Install each script
for script_file command_name in ${(kv)SCRIPTS}; do
    SOURCE_PATH="$SCRIPT_DIR/$script_file"
    TARGET_PATH="$INSTALL_DIR/$command_name"
    
    # Check if source script exists
    if [[ ! -f "$SOURCE_PATH" ]]; then
        echo "⚠️  Skipping $script_file (not found)"
        continue
    fi
    
    # Check if symlink already points to the correct source
    if [[ -L "$TARGET_PATH" ]]; then
        existing_target=$(readlink "$TARGET_PATH")
        if [[ "$existing_target" == "$SOURCE_PATH" ]]; then
            echo "✅ $command_name already points to correct source, skipping"
            continue
        else
            echo "🗑️  Removing existing $command_name (points to different source)..."
            sudo rm -f "$TARGET_PATH"
        fi
    elif [[ -f "$TARGET_PATH" ]]; then
        echo "🗑️  Removing existing $command_name (not a symlink)..."
        sudo rm -f "$TARGET_PATH"
    fi
    
    # Create new symlink
    echo "🔗 Creating symlink: $command_name -> $script_file"
    if sudo ln -s "$SOURCE_PATH" "$TARGET_PATH"; then
        echo "   ✅ $command_name installed successfully"
    else
        echo "   ❌ Failed to install $command_name"
        exit 1
    fi
done

echo ""
echo "🎉 Installation complete!"
echo ""
echo "You can now use these commands from anywhere:"
echo "   auto-commit \"your commit message\""
echo "   auto-pr \"resolves #123\""
echo "   auto-issue \"create issue about dark mode\""
if [[ -n "${SCRIPTS[orchestrator/gemini-orchestrator]}" ]]; then
    echo "   gemini-orchestrator"
fi
echo ""
echo "💡 Tip: These are symlinks, so they'll automatically get updates when you git pull this repository."