#!/usr/bin/env zsh

# Issue Display Utility
# 
# This utility provides functions for displaying GitHub issue content with enhanced formatting
# using Charmbracelet Gum when available, with graceful fallbacks.

# Source shared text formatting utility
source "${0:A:h}/text_formatting.zsh"

# Function to display issue content with formatted title and body
# Usage: display_issue_content "title" "body"
display_issue_content() {
    local title="$1"
    local body="$2"
    
    if [ -z "$title" ] || [ -z "$body" ]; then
        echo "Error: display_issue_content requires both title and body parameters"
        return 1
    fi
    
    # Display the issue content with gum formatting or fallback
    if command -v gum &> /dev/null; then
        local enhanced_body=$(make_issue_refs_bold "$body")
        local issue_content=""
        issue_content+="# $title"$'\n'$'\n'
        issue_content+="$enhanced_body"

        gum style --border=normal --padding="1 2" --width=$((COLUMNS - 6)) "$(gum format "$issue_content")"
    else
        echo ""
        echo "Issue content:"
        echo "Title: $title"
        echo ""
        echo "Body:"
        echo "$body"
    fi
}

