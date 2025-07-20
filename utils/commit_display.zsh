#!/usr/bin/env zsh

# Commit Message Display Utility
# 
# This utility provides functions for displaying commit messages with enhanced formatting
# using Charmbracelet Gum when available, with graceful fallbacks.

# Source shared text formatting utility
source "${script_dir}/utils/text_formatting.zsh"

# Function to display commit message with enhanced formatting
# Usage: display_commit_message "full_commit_message"
display_commit_message() {
    local commit_message="$1"
    
    if [ -z "$commit_message" ]; then
        echo "Error: display_commit_message requires a commit message parameter"
        return 1
    fi
    
    # Parse the commit message to extract title and body
    local title=$(echo "$commit_message" | head -n 1)
    local body=$(echo "$commit_message" | tail -n +3)  # Skip title and empty line
    
    # Enhance the body with bold issue references
    local enhanced_body=$(make_issue_refs_bold "$body")
    
    # Display with gum formatting or fallback
    if command -v gum &> /dev/null; then
        local formatted_content=""
        formatted_content+="# $title"$'\n'$'\n'
        formatted_content+="$enhanced_body"
        
        echo ""
        echo "**Generated commit message:**" | gum format
        gum style --border=normal --padding="1 2" --width=$((COLUMNS - 6)) "$(gum format "$formatted_content")"
    else
        echo ""
        echo "Generated commit message:"
        echo "$title"
        echo ""
        echo "$enhanced_body"
    fi
}

# Function to display commit message with custom header
# Usage: display_commit_message_with_header "header_text" "full_commit_message"
display_commit_message_with_header() {
    local header="$1"
    local commit_message="$2"
    
    if [ -z "$header" ] || [ -z "$commit_message" ]; then
        echo "Error: display_commit_message_with_header requires header and commit message parameters"
        return 1
    fi
    
    # Parse the commit message to extract title and body
    local title=$(echo "$commit_message" | head -n 1)
    local body=$(echo "$commit_message" | tail -n +3)  # Skip title and empty line
    
    # Enhance the body with bold issue references
    local enhanced_body=$(make_issue_refs_bold "$body")
    
    # Display with gum formatting or fallback
    if command -v gum &> /dev/null; then
        local formatted_content=""
        formatted_content+="# $title"$'\n'$'\n'
        formatted_content+="$enhanced_body"
        
        echo ""
        echo "**$header:**" | gum format
        gum style --border=normal --padding="1 2" --width=$((COLUMNS - 6)) "$(gum format "$formatted_content")"
    else
        echo ""
        echo "$header:"
        echo "$title"
        echo ""
        echo "$enhanced_body"
    fi
}