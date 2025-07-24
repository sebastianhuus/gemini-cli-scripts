#!/usr/bin/env zsh

# Configuration Loading Utility for Gemini CLI Scripts
# Loads configuration from multiple sources with priority order:
# 1. Repository-specific: $PWD/.gemini-config
# 2. User global: $HOME/.config/gemini-cli/.gemini-config  
# 3. System defaults: $script_dir/config/default.gemini-config

# Script directory will be passed as parameter to load_gemini_config()
# No longer using ${0:A} since this file is sourced, not executed directly
SCRIPT_DIR=""

# Default configuration values
DEFAULT_GEMINI_MODEL="gemini-2.5-flash"
DEFAULT_AUTO_STAGE="false"
DEFAULT_AUTO_PR="false"
DEFAULT_AUTO_BRANCH="false"
DEFAULT_AUTO_PUSH="false"
DEFAULT_SKIP_ENV_INFO="false"
DEFAULT_AUTO_PUSH_AFTER_PR="false"
DEFAULT_BRANCH_PREFIX_FEAT="feat/"
DEFAULT_BRANCH_PREFIX_FIX="fix/"
DEFAULT_BRANCH_PREFIX_DOCS="docs/"
DEFAULT_BRANCH_PREFIX_REFACTOR="refactor/"
DEFAULT_BRANCH_NAMING_STYLE="kebab-case"

# Function to load configuration value with fallback
# Usage: config_value=$(get_config_value "KEY_NAME" "default_value")
get_config_value() {
    local key="$1"
    local default_value="$2"
    local value=""
    
    # Check if the variable is already set (from previous config loading)
    eval "value=\$CONFIG_$key"
    
    if [ -n "$value" ]; then
        echo "$value"
    else
        echo "$default_value"
    fi
}

# Function to load a single config file
# Usage: load_config_file "/path/to/config"
load_config_file() {
    local config_file="$1"
    
    if [ -f "$config_file" ]; then
        # Source the config file, but prefix all variables with CONFIG_
        while IFS='=' read -r key value; do
            # Skip empty lines and comments
            [[ "$key" =~ ^[[:space:]]*$ ]] && continue
            [[ "$key" =~ ^[[:space:]]*# ]] && continue
            
            # Remove leading/trailing whitespace
            key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            
            # Set the configuration variable
            if [ -n "$key" ] && [ -n "$value" ]; then
                eval "CONFIG_$key=\"$value\""
            fi
        done < "$config_file"
        return 0
    fi
    return 1
}

# Main function to load configuration from all sources
# Usage: load_gemini_config [script_directory]
load_gemini_config() {
    local script_dir_param="$1"
    
    # Set SCRIPT_DIR from parameter if provided
    if [ -n "$script_dir_param" ]; then
        SCRIPT_DIR="$script_dir_param"
    fi
    # Load in reverse priority order (later sources override earlier ones)
    
    # 3. System defaults (lowest priority)
    load_config_file "$SCRIPT_DIR/config/default.gemini-config"
    
    # 2. User global config
    if [ -n "$HOME" ]; then
        mkdir -p "$HOME/.config/gemini-cli" 2>/dev/null
        load_config_file "$HOME/.config/gemini-cli/.gemini-config"
    fi
    
    # 1. Repository-specific config (highest priority)
    load_config_file "$PWD/.gemini-config"
    
    # Load gum theme configuration
    if [ -f "$SCRIPT_DIR/utils/ui/gum_theme.zsh" ]; then
        source "$SCRIPT_DIR/utils/ui/gum_theme.zsh"
    fi
    
    # Set defaults for any missing values
    CONFIG_GEMINI_MODEL=$(get_config_value "GEMINI_MODEL" "$DEFAULT_GEMINI_MODEL")
    CONFIG_AUTO_STAGE=$(get_config_value "AUTO_STAGE" "$DEFAULT_AUTO_STAGE")
    CONFIG_AUTO_PR=$(get_config_value "AUTO_PR" "$DEFAULT_AUTO_PR")
    CONFIG_AUTO_BRANCH=$(get_config_value "AUTO_BRANCH" "$DEFAULT_AUTO_BRANCH")
    CONFIG_AUTO_PUSH=$(get_config_value "AUTO_PUSH" "$DEFAULT_AUTO_PUSH")
    CONFIG_SKIP_ENV_INFO=$(get_config_value "SKIP_ENV_INFO" "$DEFAULT_SKIP_ENV_INFO")
    CONFIG_AUTO_PUSH_AFTER_PR=$(get_config_value "AUTO_PUSH_AFTER_PR" "$DEFAULT_AUTO_PUSH_AFTER_PR")
    CONFIG_BRANCH_PREFIX_FEAT=$(get_config_value "BRANCH_PREFIX_FEAT" "$DEFAULT_BRANCH_PREFIX_FEAT")
    CONFIG_BRANCH_PREFIX_FIX=$(get_config_value "BRANCH_PREFIX_FIX" "$DEFAULT_BRANCH_PREFIX_FIX")
    CONFIG_BRANCH_PREFIX_DOCS=$(get_config_value "BRANCH_PREFIX_DOCS" "$DEFAULT_BRANCH_PREFIX_DOCS")
    CONFIG_BRANCH_PREFIX_REFACTOR=$(get_config_value "BRANCH_PREFIX_REFACTOR" "$DEFAULT_BRANCH_PREFIX_REFACTOR")
    CONFIG_BRANCH_NAMING_STYLE=$(get_config_value "BRANCH_NAMING_STYLE" "$DEFAULT_BRANCH_NAMING_STYLE")
}

# Helper function to convert config boolean to shell boolean
# Usage: if is_config_true "$CONFIG_AUTO_STAGE"; then
is_config_true() {
    local value="$1"
    [[ "$value" == "true" || "$value" == "1" || "$value" == "yes" ]]
}

# Function to get the configured Gemini model
get_gemini_model() {
    echo "$CONFIG_GEMINI_MODEL"
}

# Function to get branch prefix for a given type
# Usage: prefix=$(get_branch_prefix "feat")
get_branch_prefix() {
    local branch_type="$1"
    case "$branch_type" in
        feat|feature)
            echo "$CONFIG_BRANCH_PREFIX_FEAT"
            ;;
        fix|bugfix)
            echo "$CONFIG_BRANCH_PREFIX_FIX"
            ;;
        docs|documentation)
            echo "$CONFIG_BRANCH_PREFIX_DOCS"
            ;;
        refactor)
            echo "$CONFIG_BRANCH_PREFIX_REFACTOR"
            ;;
        *)
            echo "${branch_type}/"
            ;;
    esac
}

# Export configuration functions for use in other scripts
# Note: The CONFIG_* variables will be available after calling load_gemini_config()