#!/usr/bin/env zsh

# GitHub Command Extraction Utility
# 
# This utility provides shared functions for extracting title and body parameters
# from GitHub CLI commands (gh pr create, gh issue create, etc.)

# Function to extract title from gh create commands
# Usage: extract_gh_title "gh pr create --title 'My Title' --body 'My Body'"
# Usage: extract_gh_title "gh issue create --title 'My Title' --body 'My Body'"
extract_gh_title() {
    local gh_command="$1"
    
    echo "$gh_command" | python3 -c "
import re
import sys

command = sys.stdin.read().strip()

# Find --title with quoted content (non-greedy to stop at first closing quote)
title_match = re.search(r'--title\s+\"(.*?)\"', command, re.DOTALL)
if not title_match:
    title_match = re.search(r'--title\s+\'(.*?)\'', command, re.DOTALL)

title = title_match.group(1) if title_match else ''
print(title)
"
}

# Function to extract body from gh create commands
# Usage: extract_gh_body "gh pr create --title 'My Title' --body 'My Body'"
# Usage: extract_gh_body "gh issue create --title 'My Title' --body 'My Body'"
extract_gh_body() {
    local gh_command="$1"
    
    echo "$gh_command" | python3 -c "
import re
import sys

command = sys.stdin.read().strip()

# Find --body with quoted content (non-greedy to stop at first closing quote) 
body_match = re.search(r'--body\s+\"(.*?)\"', command, re.DOTALL)
if not body_match:
    body_match = re.search(r'--body\s+\'(.*?)\'', command, re.DOTALL)

body = body_match.group(1) if body_match else ''
print(body)
"
}