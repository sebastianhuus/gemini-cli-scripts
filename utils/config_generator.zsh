#!/usr/bin/env zsh

# Interactive Configuration Generator for Gemini CLI Scripts
# Creates a personalized .gemini-config file through guided prompts

set -e

# Get script directory
SCRIPT_DIR="${0:A:h:h}"
UTILS_DIR="${0:A:h}"

# Load gum helpers for interactive prompts
if [ -f "${SCRIPT_DIR}/gum/gum_helpers.zsh" ]; then
    source "${SCRIPT_DIR}/gum/gum_helpers.zsh"
else
    echo "Error: Required gum helper functions not found"
    exit 1
fi

# Colors for output
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_header() {
    echo -e "\n${BLUE}$1${NC}"
    echo -e "${BLUE}$(echo "$1" | sed 's/./=/g')${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Function to get user choice for boolean settings
get_boolean_choice() {
    local prompt="$1"
    local default="$2"
    local description="$3"
    
    if [ -n "$description" ]; then
        echo "$description"
        echo ""
    fi
    
    local options=("true" "false")
    if [ "$default" = "true" ]; then
        options=("true (recommended)" "false")
    elif [ "$default" = "false" ]; then
        options=("true" "false (recommended)")
    fi
    
    local choice=$(use_gum_choose "$prompt" "${options[@]}")
    
    # Extract just true/false from the choice
    echo "$choice" | grep -o "^[^[:space:]]*"
}

# Function to get user input with validation
get_input_with_default() {
    local prompt="$1"
    local default="$2"
    local description="$3"
    
    if [ -n "$description" ]; then
        echo "$description"
        echo ""
    fi
    
    local result=$(use_gum_input "$prompt" "$default")
    
    # Return default if empty
    if [ -z "$result" ]; then
        echo "$default"
    else
        echo "$result"
    fi
}

# Function to get model selection
get_model_choice() {
    echo "Select the Gemini model to use for all AI operations:"
    echo "• gemini-2.5-flash: Fast and efficient (recommended for most users)"
    echo "• gemini-2.5-pro: More capable for complex tasks, but may have usage limits"
    echo ""
    
    local models=("gemini-2.5-flash (recommended)" "gemini-1.5-pro" "gemini-1.5-flash" "Other (enter manually)")
    local choice=$(use_gum_choose "Choose your preferred Gemini model:" "${models[@]}")
    
    case "$choice" in
        "gemini-2.5-flash"*)
            echo "gemini-2.5-flash"
            ;;
        "gemini-1.5-pro")
            echo "gemini-1.5-pro"
            ;;
        "gemini-1.5-flash")
            echo "gemini-1.5-flash"
            ;;
        "Other"*)
            local custom_model=$(use_gum_input "Enter model name:" "gemini-2.5-flash")
            echo "${custom_model:-gemini-2.5-flash}"
            ;;
        *)
            echo "gemini-2.5-flash"
            ;;
    esac
}

# Function to get workflow preset
get_workflow_preset() {
    echo "Choose a workflow preset that matches your development style:"
    echo ""
    echo "• Conservative: Manual confirmations for all actions (safest)"
    echo "• Balanced: Auto-stage changes, manual PR/push decisions"  
    echo "• Fast: Minimize prompts, auto-stage and auto-branch"
    echo "• Custom: Configure each setting individually"
    echo ""
    
    local presets=("Conservative (safest)" "Balanced (recommended)" "Fast development" "Custom configuration")
    local choice=$(use_gum_choose "Select workflow preset:" "${presets[@]}")
    
    case "$choice" in
        "Conservative"*)
            WORKFLOW_PRESET_CHOICE="conservative"
            ;;
        "Balanced"*)
            WORKFLOW_PRESET_CHOICE="balanced"
            ;;
        "Fast"*)
            WORKFLOW_PRESET_CHOICE="fast"
            ;;
        "Custom"*)
            WORKFLOW_PRESET_CHOICE="custom"
            ;;
        *)
            WORKFLOW_PRESET_CHOICE="balanced"
            ;;
    esac
}


# Function to configure individual settings
configure_individual_settings() {
    print_header "Individual Setting Configuration"
    
    CONFIG_AUTO_STAGE=$(get_boolean_choice \
        "Auto-stage all changes before commit generation?" \
        "true" \
        "When enabled, automatically runs 'git add -A' when no changes are staged.\nRecommended: true (saves time)")
    
    CONFIG_AUTO_BRANCH=$(get_boolean_choice \
        "Auto-create new branches without confirmation?" \
        "false" \
        "When enabled, creates branches automatically based on AI-generated names.\nRecommended: false (safety)")
    
    CONFIG_AUTO_PR=$(get_boolean_choice \
        "Auto-create pull requests after successful commits?" \
        "false" \
        "When enabled, automatically creates PRs after pushing commits.\nRecommended: false (gives you control)")
    
    CONFIG_AUTO_PUSH=$(get_boolean_choice \
        "Auto-push changes after successful commits?" \
        "false" \
        "When enabled, automatically pushes commits to remote.\nRecommended: false (safety)")
    
    CONFIG_SKIP_ENV_INFO=$(get_boolean_choice \
        "Skip environment info display at script start?" \
        "false" \
        "When enabled, skips showing repository and branch info.\nRecommended: false (helpful context)")
    
    CONFIG_AUTO_PUSH_AFTER_PR=$(get_boolean_choice \
        "Auto-push changes after creating pull requests?" \
        "false" \
        "When enabled, automatically pushes after PR creation.\nRecommended: false (usually not needed)")
}

# Function to configure branch naming
configure_branch_naming() {
    print_header "Branch Naming Configuration"
    
    echo "Configure branch prefixes for different types of changes:"
    echo ""
    
    CONFIG_BRANCH_PREFIX_FEAT=$(get_input_with_default \
        "Prefix for feature branches:" \
        "feat/" \
        "Used for new features and enhancements.")
    
    CONFIG_BRANCH_PREFIX_FIX=$(get_input_with_default \
        "Prefix for bug fix branches:" \
        "fix/" \
        "Used for bug fixes and patches.")
    
    CONFIG_BRANCH_PREFIX_DOCS=$(get_input_with_default \
        "Prefix for documentation branches:" \
        "docs/" \
        "Used for documentation updates.")
    
    CONFIG_BRANCH_PREFIX_REFACTOR=$(get_input_with_default \
        "Prefix for refactoring branches:" \
        "refactor/" \
        "Used for code refactoring and cleanup.")
    
    local naming_styles=("kebab-case (recommended)" "snake_case" "camelCase")
    local style_choice=$(use_gum_choose "Branch naming style:" "${naming_styles[@]}")
    
    case "$style_choice" in
        "kebab-case"*)
            CONFIG_BRANCH_NAMING_STYLE="kebab-case"
            ;;
        "snake_case")
            CONFIG_BRANCH_NAMING_STYLE="snake_case"
            ;;
        "camelCase")
            CONFIG_BRANCH_NAMING_STYLE="camelCase"
            ;;
        *)
            CONFIG_BRANCH_NAMING_STYLE="kebab-case"
            ;;
    esac
}

# Function to choose config location
choose_config_location() {
    echo "Where would you like to save the configuration?"
    echo ""
    echo "• Repository-specific: .gemini-config in current directory"
    echo "  (Only affects this project)"
    echo "• User-wide: ~/.config/gemini-cli/.gemini-config"
    echo "  (Affects all projects for your user)"
    echo ""
    
    local locations=("Repository-specific (recommended)" "User-wide")
    local choice=$(use_gum_choose "Choose configuration location:" "${locations[@]}")
    
    case "$choice" in
        "Repository-specific"*)
            echo "repo"
            ;;
        "User-wide")
            echo "user"
            ;;
        *)
            echo "repo"
            ;;
    esac
}

# Function to write config file
write_config_file() {
    local location="$1"
    local config_path=""
    
    if [ "$location" = "repo" ]; then
        config_path="$PWD/.gemini-config"
    else
        mkdir -p "$HOME/.config/gemini-cli"
        config_path="$HOME/.config/gemini-cli/.gemini-config"
    fi
    
    # Check if file exists
    if [ -f "$config_path" ]; then
        if ! use_gum_confirm "Configuration file already exists. Overwrite?"; then
            print_info "Configuration cancelled."
            return 1
        fi
    fi
    
    # Write the config file
    cat > "$config_path" << EOF
# Gemini CLI Configuration
# Generated on $(date)

# ============================================================================
# Model Configuration
# ============================================================================
GEMINI_MODEL=$CONFIG_GEMINI_MODEL

# ============================================================================
# Auto-Commit Default Behaviors
# ============================================================================
AUTO_STAGE=$CONFIG_AUTO_STAGE
AUTO_PR=$CONFIG_AUTO_PR
AUTO_BRANCH=$CONFIG_AUTO_BRANCH
AUTO_PUSH=$CONFIG_AUTO_PUSH
SKIP_ENV_INFO=$CONFIG_SKIP_ENV_INFO

# ============================================================================
# Auto-PR Default Behaviors
# ============================================================================
AUTO_PUSH_AFTER_PR=$CONFIG_AUTO_PUSH_AFTER_PR

# ============================================================================
# Branch Naming Configuration
# ============================================================================
BRANCH_PREFIX_FEAT=$CONFIG_BRANCH_PREFIX_FEAT
BRANCH_PREFIX_FIX=$CONFIG_BRANCH_PREFIX_FIX
BRANCH_PREFIX_DOCS=$CONFIG_BRANCH_PREFIX_DOCS
BRANCH_PREFIX_REFACTOR=$CONFIG_BRANCH_PREFIX_REFACTOR
BRANCH_NAMING_STYLE=$CONFIG_BRANCH_NAMING_STYLE
EOF
    
    print_success "Configuration saved to: $config_path"
    echo ""
    echo "You can edit this file manually at any time to adjust settings."
    
    return 0
}

# Function to display configuration summary
display_config_summary() {
    print_header "Configuration Summary"
    
    echo "Model: Select the Gemini model to use for all AI operations:"
    echo "• gemini-2.5-flash: Fast and efficient (recommended for most users)"
    echo "• gemini-2.5-pro: More capable for complex tasks, but may have usage limits"
    echo ""
    echo "$CONFIG_GEMINI_MODEL"
    echo ""
    echo "Auto-behaviors:"
    echo "  Auto-stage changes: $CONFIG_AUTO_STAGE"
    echo "  Auto-create branches: $CONFIG_AUTO_BRANCH"
    echo "  Auto-create PRs: $CONFIG_AUTO_PR"
    echo "  Auto-push changes: $CONFIG_AUTO_PUSH"
    echo "  Skip environment info: $CONFIG_SKIP_ENV_INFO"
    echo "  Auto-push after PR: $CONFIG_AUTO_PUSH_AFTER_PR"
    echo ""
    echo "Branch naming:"
    echo "  Feature prefix: Used for new features and enhancements."
    echo ""
    echo "$CONFIG_BRANCH_PREFIX_FEAT"
    echo "  Fix prefix: Used for bug fixes and patches."
    echo ""
    echo "$CONFIG_BRANCH_PREFIX_FIX"
    echo "  Docs prefix: Used for documentation updates."
    echo ""
    echo "$CONFIG_BRANCH_PREFIX_DOCS"
    echo "  Refactor prefix: Used for code refactoring and cleanup."
    echo ""
    echo "$CONFIG_BRANCH_PREFIX_REFACTOR"
    echo "  Naming style: $CONFIG_BRANCH_NAMING_STYLE"
    echo ""
}

# Main function
main() {
    echo -e "${BLUE}Gemini CLI Configuration Generator${NC}"
    echo -e "${BLUE}====================================${NC}"
    echo ""
    echo "This tool will help you create a personalized configuration file"
    echo "for the Gemini CLI automation scripts."
    echo ""
    
    # Step 1: Model selection
    print_header "Model Configuration"
    CONFIG_GEMINI_MODEL=$(get_model_choice)
    
    # Step 2: Workflow preset
    print_header "Workflow Configuration"
    get_workflow_preset
    
    # Apply preset settings in main scope
    case "$WORKFLOW_PRESET_CHOICE" in
        "conservative")
            CONFIG_AUTO_STAGE="false"
            CONFIG_AUTO_PR="false"  
            CONFIG_AUTO_BRANCH="false"
            CONFIG_AUTO_PUSH="false"
            CONFIG_SKIP_ENV_INFO="false"
            CONFIG_AUTO_PUSH_AFTER_PR="false"
            ;;
        "balanced")
            CONFIG_AUTO_STAGE="true"
            CONFIG_AUTO_PR="false"
            CONFIG_AUTO_BRANCH="false"
            CONFIG_AUTO_PUSH="false"
            CONFIG_SKIP_ENV_INFO="false"
            CONFIG_AUTO_PUSH_AFTER_PR="false"
            ;;
        "fast")
            CONFIG_AUTO_STAGE="true"
            CONFIG_AUTO_PR="false"
            CONFIG_AUTO_BRANCH="true"
            CONFIG_AUTO_PUSH="true"
            CONFIG_SKIP_ENV_INFO="false"
            CONFIG_AUTO_PUSH_AFTER_PR="false"
            ;;
        "custom")
            # Configure each setting individually
            configure_individual_settings
            ;;
    esac
    
    # Step 4: Branch naming
    configure_branch_naming
    
    # Step 5: Show summary and confirm
    display_config_summary
    
    if ! use_gum_confirm "Save this configuration?"; then
        print_info "Configuration cancelled."
        exit 0
    fi
    
    # Step 6: Choose location and save
    local location=$(choose_config_location)
    
    if write_config_file "$location"; then
        print_success "Configuration generator completed successfully!"
        echo ""
        echo "You can now use the Gemini CLI scripts with your personalized settings."
        echo "Run any script (auto_commit.zsh, auto_pr.zsh, auto_issue.zsh) to see them in action."
    else
        exit 1
    fi
}

# Run main function
main "$@"