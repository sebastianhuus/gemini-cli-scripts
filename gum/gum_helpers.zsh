#!/usr/bin/env zsh

# Shared Gum Helper Functions
# Provides consistent gum UI functions with graceful fallbacks

# Function to check if gum is available and provide fallback
use_gum_confirm() {
    local prompt="$1"
    local default_yes="${2:-true}"
    
    if command -v gum &> /dev/null; then
        local result
        if [ "$default_yes" = true ]; then
            if gum confirm "$prompt"; then
                result="Yes"
            else
                result="No"
            fi
        else
            if gum confirm "$prompt" --default=false; then
                result="Yes"
            else
                result="No"
            fi
        fi
        echo "# $prompt" | gum format >&2
        gum style --faint "> $result" >&2
        # Return the original exit code
        if [ "$result" = "Yes" ]; then
            return 0
        else
            return 1
        fi
    else
        # Fallback to traditional prompt
        echo "$prompt [Y/n]"
        read -r response
        case "$response" in
            [Yy]* | "" ) return 0 ;;
            * ) return 1 ;;
        esac
    fi
}

use_gum_choose() {
    local prompt="$1"
    shift
    local options=("$@")
    
    if command -v gum &> /dev/null; then
        local result
        result=$(gum choose --header="$prompt" "${options[@]}")
        echo "# $prompt" | gum format >&2
        if [ -z "$result" ]; then
            gum style --faint "> Cancelled" >&2
            echo "Cancelled"
        else
            gum style --faint "> $result" >&2
            echo "$result"
        fi
    else
        # Fallback to traditional prompt
        echo "$prompt"
        local i=1
        for option in "${options[@]}"; do
            echo "$i) $option"
            ((i++))
        done
        read -r choice
        local result
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#options[@]} ]; then
            result="${options[$((choice-1))]}"
        else
            result="${options[0]}" # Default to first option
        fi
        echo "> $result"
        echo "$result"
    fi
}

use_gum_input() {
    local prompt="$1"
    local placeholder="${2:-}"
    local default_value="${3:-}"
    
    if command -v gum &> /dev/null; then
        local result
        if [ -n "$placeholder" ]; then
            result=$(gum input --placeholder="$placeholder" --header="$prompt")
        else
            result=$(gum input --header="$prompt")
        fi
        
        # If no input provided and we have a default, use the default
        if [ -z "$result" ] && [ -n "$default_value" ]; then
            result="$default_value"
        fi
        
        echo "# $prompt" | gum format >&2
        gum style --faint "> $result" >&2
        echo "$result"
    else
        # Fallback to traditional prompt
        if [ -n "$default_value" ]; then
            echo "$prompt (default: $default_value)"
        else
            echo "$prompt"
        fi
        read -r response
        
        # Use default if empty response
        if [ -z "$response" ] && [ -n "$default_value" ]; then
            response="$default_value"
        fi
        
        echo "> $response"
        echo "$response"
    fi
}

# Function to display colored status messages with optional markdown support
colored_status() {
    local message=""
    local type=""
    local use_markdown=true
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --no-markdown)
                use_markdown=false
                shift
                ;;
            *)
                if [[ -z "$message" ]]; then
                    message="$1"
                elif [[ -z "$type" ]]; then
                    type="$1"
                fi
                shift
                ;;
        esac
    done
    
    # Default type if not specified
    if [[ -z "$type" ]]; then
        type="info"
    fi
    
    if command -v gum &> /dev/null; then
        local status_indicator=""
        case "$type" in
            "success")
                status_indicator="$(gum style --foreground "#22c55e" "⏺")"
                ;;
            "error")
                status_indicator="$(gum style --foreground "#ef4444" "⏺")"
                ;;
            "info"|"cancel")
                status_indicator="$(gum style --foreground "#a855f7" "⏺")"
                ;;
            *)
                status_indicator="⏺"
                ;;
        esac
        
        if [[ "$use_markdown" == true ]] && [[ "$message" == *"**"* || "$message" == *"__"* || "$message" == *"\`"* || "$message" == *"["* || "$message" == *"#"* ]]; then
            # Only use gum format if message contains markdown syntax
            printf "%s %s" "$status_indicator" "$(echo "$message" | gum format | tr -d '\n')"
        else
            # For plain text, add indent to align with formatted content
            echo "  $status_indicator $message"
        fi
    else
        echo "⏺ $message"
    fi
}

# Function to wrap text for quote blocks respecting terminal width
wrap_quote_block_text() {
    local text="$1"
    local max_width="${COLUMNS:-80}"  # Use COLUMNS env var or default to 80
    
    # Reserve space for "> " prefix (2 chars) and some margin (4 chars for safety)
    local usable_width=$((max_width - 6))
    
    # Ensure minimum usable width
    if [ $usable_width -lt 20 ]; then
        usable_width=20
    fi
    
    local result=""
    while IFS= read -r line; do
        if [ ${#line} -le $usable_width ]; then
            # Line fits, add it as-is
            if [ -n "$result" ]; then
                result+=$'\n> '"$line"
            else
                result="> $line"
            fi
        else
            # Line too long, need to wrap
            local remaining="$line"
            while [ ${#remaining} -gt $usable_width ]; do
                # Find last space within usable width
                local chunk="${remaining:0:$usable_width}"
                local break_pos=$usable_width
                
                # Try to break at word boundary
                for ((i = usable_width - 1; i >= $((usable_width * 3 / 4)); i--)); do
                    if [[ "${remaining:$i:1}" == " " ]]; then
                        break_pos=$i
                        break
                    fi
                done
                
                chunk="${remaining:0:$break_pos}"
                # Remove trailing space if we broke at word boundary
                chunk="${chunk% }"
                
                if [ -n "$result" ]; then
                    result+=$'\n> '"$chunk"
                else
                    result="> $chunk"
                fi
                
                # Remove processed chunk and any leading space
                remaining="${remaining:$break_pos}"
                remaining="${remaining# }"
            done
            
            # Add remaining text if any
            if [ -n "$remaining" ]; then
                result+=$'\n> '"$remaining"
            fi
        fi
    done <<< "$text"
    
    echo "$result"
}