#!/usr/bin/env zsh

# PR Display Utility
# 
# This utility provides functions for displaying PR content with enhanced formatting
# using Charmbracelet Gum when available, with graceful fallbacks.

# Source shared text formatting utility
source "${0:A:h}/text_formatting.zsh"

# Function to display PR content with formatted title and body
# Usage: display_pr_content "title" "body"
display_pr_content() {
    local title="$1"
    local body="$2"
    
    if [ -z "$title" ] || [ -z "$body" ]; then
        echo "Error: display_pr_content requires both title and body parameters"
        return 1
    fi
    
    # Display the updated PR content with gum formatting or fallback
    if command -v gum &> /dev/null; then
        local enhanced_body=$(make_issue_refs_bold "$body")
        local pr_content=""
        pr_content+="# $title"$'\n'$'\n'
        pr_content+="$enhanced_body"

        gum style --border=normal --padding="1 2" --width=$((COLUMNS - 6)) "$(gum format "$pr_content")"
    else
        echo ""
        echo "Updated PR content:"
        echo "Title: $title"
        echo ""
        echo "Body:"
        echo "$body"
    fi
}


