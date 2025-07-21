#!/usr/bin/env zsh

# Gemini Context Utility
# Provides repository-specific context from GEMINI.md file to enhance AI understanding

# Function to load and format GEMINI.md context
# Usage: load_gemini_context [script_dir]
load_gemini_context() {
    local script_dir="$1"
    
    # Source gum helpers if available
    if [ -n "$script_dir" ] && [ -f "$script_dir/gum/gum_helpers.zsh" ]; then
        source "$script_dir/gum/gum_helpers.zsh"
    elif [ -n "$script_dir" ] && [ -f "$script_dir/../gum/gum_helpers.zsh" ]; then
        source "$script_dir/../gum/gum_helpers.zsh"
    fi
    
    local context_file=""
    local search_dir="$(pwd)"
    local git_root=""
    
    # Find git root directory
    git_root=$(git rev-parse --show-toplevel 2>/dev/null)
    
    # Search for GEMINI.md in current directory first, then git root
    if [ -f "$search_dir/GEMINI.md" ]; then
        context_file="$search_dir/GEMINI.md"
    elif [ -n "$git_root" ] && [ -f "$git_root/GEMINI.md" ]; then
        context_file="$git_root/GEMINI.md"
    else
        # No GEMINI.md found, return empty string
        return 0
    fi
    
    # Validate file exists and is readable
    if [ ! -r "$context_file" ]; then
        return 0
    fi
    
    # Check file size (limit to ~2KB to avoid token overuse)
    local file_size=$(wc -c < "$context_file" 2>/dev/null)
    if [ -z "$file_size" ] || [ "$file_size" -gt 2048 ]; then
        return 0
    fi
    
    # Read and validate content
    local content=$(cat "$context_file" 2>/dev/null)
    if [ -z "$content" ]; then
        return 0
    fi

    # Show status when context is loaded
    if command -v colored_status &> /dev/null; then
        colored_status "Using GEMINI.md context from $(basename "$context_file")" "info" >&2
    else
        echo "⏺ Using GEMINI.md context from $context_file" >&2
    fi

    # Return formatted context
    echo "$content"
}

# Function to check if context is available
# Usage: has_gemini_context [script_dir]
has_gemini_context() {
    local script_dir="$1"
    local context=$(load_gemini_context "$script_dir")
    [ -n "$context" ]
}