#!/usr/bin/env zsh

# Environment display utility using gum formatting
# Displays repository and branch information in a formatted quote block

# Function to display environment information for user confirmation
display_env_info() {
    local repo_url=$(git remote get-url origin 2>/dev/null)
    local current_branch=$(git branch --show-current 2>/dev/null)

    # Extract repository name from URL
    local repo_name=""
    if [ -n "$repo_url" ]; then
        if [[ "$repo_url" =~ github\.com[:/]([^/]+/[^/]+)(\.git)?$ ]]; then
            repo_name="${match[1]}"
        else
            repo_name="$repo_url"
        fi
    fi

    local env_info_block="> **Current Working Environment:**"
    env_info_block+=$'\n> 🏗️  Repository: '"$repo_name"
    env_info_block+=$'\n> 🌿 Branch: '"$current_branch"

    # Display using gum format if available, otherwise fallback to echo
    if command -v gum &> /dev/null; then
        echo "$env_info_block" | gum format
        echo "> \\n" | gum format
    else
        echo "$env_info_block"
        echo ""
    fi
}