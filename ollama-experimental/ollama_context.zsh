#!/usr/bin/env zsh

# Ollama Context Utility
# Provides repository-specific context from OLLAMA.md file to enhance AI understanding
# Based on gemini_context.zsh but adapted for Ollama workflows

# Function to load and format OLLAMA.md context
load_ollama_context() {
    local context_file=""
    local search_dir="$(pwd)"
    local git_root=""
    
    # Find git root directory
    git_root=$(git rev-parse --show-toplevel 2>/dev/null)
    
    # Search for OLLAMA.md in current directory first, then git root
    if [ -f "$search_dir/OLLAMA.md" ]; then
        context_file="$search_dir/OLLAMA.md"
    elif [ -n "$git_root" ] && [ -f "$git_root/OLLAMA.md" ]; then
        context_file="$git_root/OLLAMA.md"
    else
        # No OLLAMA.md found, return empty string
        return 0
    fi
    
    # Validate file exists and is readable
    if [ ! -r "$context_file" ]; then
        return 0
    fi
    
    # Check file size (limit to ~2KB to avoid token overuse for local models)
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
has_ollama_context() {
    local context=$(load_ollama_context)
    [ -n "$context" ]
}

# Function to truncate context to fit token limits
truncate_context() {
    local context="$1"
    local max_lines="${2:-20}"  # Default to 20 lines if not specified
    
    # Count lines in context
    local line_count=$(echo "$context" | wc -l)
    
    if [ "$line_count" -gt "$max_lines" ]; then
        # Truncate to max_lines and add indicator
        echo "$context" | head -n "$max_lines"
        echo "... (context truncated for token limit)"
    else
        echo "$context"
    fi
}

# Function to get prioritized context for local models
get_prioritized_context() {
    local context=$(load_ollama_context)
    
    if [ -n "$context" ]; then
        # For local models, prioritize essential information
        # Keep first 15 lines which should contain the most important context
        truncate_context "$context" 15
    fi
}