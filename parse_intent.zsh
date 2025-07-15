#!/usr/bin/env zsh

# GitHub Issue Intent Parser
# Extracts structured intent from natural language requests
#
# Usage:
#   ./parse_intent.zsh "user input" [gemini_context]
#   echo "user input" | ./parse_intent.zsh [gemini_context]
#
# Output format:
#   OPERATION: [create|edit|comment|view|close|reopen]
#   ISSUE_NUMBER: [number or NONE]
#   CONTENT: [extracted content]
#   CONFIDENCE: [high|medium|low]

# Get script directory for utility access
script_dir="${0:A:h}"

# Function to parse natural language intent without JSON dependencies
parse_intent() {
    local input="$1"
    local gemini_context="$2"
    
    # Create prompt for LLM to parse intent
    local parser_prompt="Analyze this GitHub issue request and determine the operation, issue number, and content.

User input: $input"
    
    if [ -n "$gemini_context" ]; then
        parser_prompt+="

Repository context from GEMINI.md:
$gemini_context"
    fi
    
    parser_prompt+="

Respond with ONLY these lines in this exact format:
OPERATION: [create|edit|comment|view|close|reopen]
ISSUE_NUMBER: [number or NONE]
CONTENT: [extracted content]
CONFIDENCE: [high|medium|low]

IMPORTANT: Output as plain text only, no code blocks or markdown formatting.

Examples:
Input: \"add comment to issue 8 about login fix\"
OPERATION: comment
ISSUE_NUMBER: 8
CONTENT: login fix
CONFIDENCE: high

Input: \"create issue about dark mode\"
OPERATION: create
ISSUE_NUMBER: NONE
CONTENT: dark mode
CONFIDENCE: high

Input: \"edit issue 13 title to say Bug: Login timeout\"
OPERATION: edit
ISSUE_NUMBER: 13
CONTENT: title to say Bug: Login timeout
CONFIDENCE: high

Be precise and only extract what's clearly stated."
    
    # Generate intent parsing from Gemini
    local intent_output=$(echo "$parser_prompt" | gemini -m gemini-2.5-flash --prompt "$parser_prompt" | "${script_dir}/utils/gemini_clean.zsh")
    
    if [ $? -ne 0 ] || [ -z "$intent_output" ]; then
        echo "OPERATION: unknown"
        echo "ISSUE_NUMBER: NONE"
        echo "CONTENT: $input"
        echo "CONFIDENCE: low"
        return 1
    fi
    
    echo "$intent_output"
}

# Function to extract specific fields from intent output
extract_field() {
    local field="$1"
    local intent_output="$2"
    echo "$intent_output" | grep "^$field:" | sed "s/^$field: //"
}

# Main execution
main() {
    local input="$1"
    local gemini_context="$2"
    
    # If no input provided as argument, read from stdin
    if [ -z "$input" ]; then
        input=$(cat)
    fi
    
    if [ -z "$input" ]; then
        echo "Error: No input provided" >&2
        echo "Usage: $0 \"user input\" [gemini_context]" >&2
        echo "   or: echo \"user input\" | $0 [gemini_context]" >&2
        exit 1
    fi
    
    # Parse intent and output results
    parse_intent "$input" "$gemini_context"
}

# Only run main if script is executed directly (not sourced)
if [ "${BASH_SOURCE[0]}" = "${0}" ] || [ "${0:t}" = "parse_intent.zsh" ]; then
    main "$@"
fi