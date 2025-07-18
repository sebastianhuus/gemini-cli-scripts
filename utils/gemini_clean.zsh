#!/usr/bin/env zsh

# Gemini CLI Response Cleaner
# 
# Utility to clean Gemini CLI responses by removing authentication-related 
# output lines that sometimes appear at the beginning of responses.
#
# Usage:
#   gemini -m model --prompt "..." | ./gemini_clean.zsh
#   echo "response with auth line" | ./gemini_clean.zsh
#
# Problem it solves:
# Sometimes Gemini CLI outputs "Loaded cached credentials." as the first line,
# which can break command execution when the response is meant to be a command.

# Read input from stdin
input=$(cat)

# Check if input is empty
if [ -z "$input" ]; then
    # Return empty if no input
    exit 0
fi

# Split input into lines
lines=("${(@f)input}")

# Check if first line contains authentication-related output
first_line="${lines[1]}"

# Remove first line if it matches known authentication patterns
if [[ "$first_line" =~ ^(Loaded cached credentials\.|Authentication.*|Cached.*|Loading.*credentials) ]]; then
    # Remove the first line and output the rest
    if [ ${#lines[@]} -gt 1 ]; then
        # Join remaining lines with newlines
        printf '%s\n' "${lines[@]:1}"
    fi
    # If only one line and it was auth-related, output nothing
else
    # No auth line detected, output everything unchanged
    echo "$input"
fi