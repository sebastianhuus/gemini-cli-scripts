#!/usr/bin/env zsh

# GitHub Issue Intent Parser - Enhanced Version
# Extracts structured intent from natural language requests with enhanced parameter extraction
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
#   REQUESTED_LABELS: [comma-separated labels or NONE]
#   REQUESTED_ASSIGNEES: [comma-separated usernames or NONE]
#   REQUESTED_MILESTONE: [milestone name or NONE]
#   PRIORITY_INDICATORS: [urgent|high|medium|low|NONE]
#   TONE_PREFERENCE: [formal|casual|technical|NONE]
#   SPECIAL_INSTRUCTIONS: [any specific formatting/content requests or NONE]

# Get script directory for utility access
local_script_dir="${0:A:h}"

# Function to get absolute path to utils directory
get_utils_path() {
    echo "${local_script_dir:A}"
}

# Enhanced intent parsing function
parse_intent() {
    local input="$1"
    local gemini_context="$2"
    
    # Enhanced prompt that captures more parameters
    local parser_prompt="Analyze this GitHub issue request and extract ALL parameters and intent.

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
CONTENT: [main topic/description]
CONFIDENCE: [high|medium|low]
REQUESTED_LABELS: [comma-separated labels or NONE]
REQUESTED_ASSIGNEES: [comma-separated usernames or NONE]
REQUESTED_MILESTONE: [milestone name or NONE]
PRIORITY_INDICATORS: [urgent|high|medium|low|NONE]
TONE_PREFERENCE: [formal|casual|technical|NONE]
SPECIAL_INSTRUCTIONS: [any specific formatting/content requests or NONE]

IMPORTANT: 
- Extract ALL mentioned parameters, even if implied
- For labels: look for keywords like 'bug', 'feature', 'urgent', 'security', 'mobile'
- For assignees: look for names, usernames, or team references
- For priority: look for words like 'urgent', 'critical', 'high priority', 'asap'
- For tone: detect if user wants formal, casual, or technical language
- Output as plain text only, no code blocks or markdown formatting

Examples:

Input: \"create urgent bug report about login timeout, tag as security and mobile, assign to sarah\"
OPERATION: create
ISSUE_NUMBER: NONE
CONTENT: login timeout
CONFIDENCE: high
REQUESTED_LABELS: urgent,bug,security,mobile
REQUESTED_ASSIGNEES: sarah
REQUESTED_MILESTONE: NONE
PRIORITY_INDICATORS: urgent
TONE_PREFERENCE: NONE
SPECIAL_INSTRUCTIONS: NONE

Input: \"add comment to issue 8 about login fix with formal tone\"
OPERATION: comment
ISSUE_NUMBER: 8
CONTENT: login fix
CONFIDENCE: high
REQUESTED_LABELS: NONE
REQUESTED_ASSIGNEES: NONE
REQUESTED_MILESTONE: NONE
PRIORITY_INDICATORS: NONE
TONE_PREFERENCE: formal
SPECIAL_INSTRUCTIONS: NONE

Input: \"create feature request for dark mode with high priority label and assign to ui-team for v2.1 milestone\"
OPERATION: create
ISSUE_NUMBER: NONE
CONTENT: dark mode
CONFIDENCE: high
REQUESTED_LABELS: feature,high-priority
REQUESTED_ASSIGNEES: ui-team
REQUESTED_MILESTONE: v2.1
PRIORITY_INDICATORS: high
TONE_PREFERENCE: NONE
SPECIAL_INSTRUCTIONS: NONE

Input: \"edit issue 13 title to say Bug: Login timeout and add steps to reproduce\"
OPERATION: edit
ISSUE_NUMBER: 13
CONTENT: title to say Bug: Login timeout
CONFIDENCE: high
REQUESTED_LABELS: NONE
REQUESTED_ASSIGNEES: NONE
REQUESTED_MILESTONE: NONE
PRIORITY_INDICATORS: NONE
TONE_PREFERENCE: NONE
SPECIAL_INSTRUCTIONS: add steps to reproduce

Input: \"comment on issue 5 that this is resolved, use technical language\"
OPERATION: comment
ISSUE_NUMBER: 5
CONTENT: this is resolved
CONFIDENCE: high
REQUESTED_LABELS: NONE
REQUESTED_ASSIGNEES: NONE
REQUESTED_MILESTONE: NONE
PRIORITY_INDICATORS: NONE
TONE_PREFERENCE: technical
SPECIAL_INSTRUCTIONS: NONE

Be precise and extract everything mentioned, including implied parameters from context."
    
    # Generate enhanced intent parsing from Gemini
    local intent_output=$(echo "$parser_prompt" | gemini -m gemini-2.5-flash --prompt "$parser_prompt" | "$(get_utils_path)/gemini_clean.zsh")
    
    if [ $? -ne 0 ] || [ -z "$intent_output" ]; then
        echo "OPERATION: unknown"
        echo "ISSUE_NUMBER: NONE"
        echo "CONTENT: $input"
        echo "CONFIDENCE: low"
        echo "REQUESTED_LABELS: NONE"
        echo "REQUESTED_ASSIGNEES: NONE"
        echo "REQUESTED_MILESTONE: NONE"
        echo "PRIORITY_INDICATORS: NONE"
        echo "TONE_PREFERENCE: NONE"
        echo "SPECIAL_INSTRUCTIONS: NONE"
        return 1
    fi
    
    echo "$intent_output"
}

# Enhanced field extraction to handle new fields
extract_field() {
    local field="$1"
    local intent_output="$2"
    local value=$(echo "$intent_output" | grep "^$field:" | sed "s/^$field: //")
    
    # Return empty string if NONE, otherwise return the value
    if [ "$value" = "NONE" ]; then
        echo ""
    else
        echo "$value"
    fi
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
# DISABLED: This script is only meant to be sourced, never executed directly
# if [[ "${ZSH_EVAL_CONTEXT}" = toplevel ]] || [[ "${(%):-%N}" = "${0}" ]]; then
#     main "$@"
# fi