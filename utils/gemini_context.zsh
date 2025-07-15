#!/usr/bin/env zsh

# Gemini Context Utility
# Provides repository-specific context from GEMINI.md file to enhance AI understanding

# Function to load and format GEMINI.md context
load_gemini_context() {
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
    
    # Return formatted context
    echo "$content"
}

# Function to check if context is available
has_gemini_context() {
    local context=$(load_gemini_context)
    [ -n "$context" ]
}