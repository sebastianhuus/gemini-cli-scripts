#!/usr/bin/env zsh

# Text Formatting Utility
# 
# This utility provides shared text formatting functions for enhancing
# markdown content across different display utilities.

# Function to make issue/PR references bold in text
# Usage: make_issue_refs_bold "text with #123 references"
# Example: "Fixes #123 and closes #456" -> "Fixes **#123** and closes **#456**"
make_issue_refs_bold() {
    local text="$1"
    
    if [ -z "$text" ]; then
        echo ""
        return 0
    fi
    
    # Replace #number patterns with **#number** for markdown bold formatting using Python
    echo "$text" | python3 -c "
import re
import sys
text = sys.stdin.read().rstrip()
result = re.sub(r'#(\d+)\b', r'**#\1**', text)
print(result)
"
}