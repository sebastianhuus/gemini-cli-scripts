#!/usr/bin/env zsh

# LLM Regeneration Handler Utility
# 
# Generic handler for LLM content generation with user feedback loops.
# Eliminates duplicated regeneration loop patterns across different operations.
#
# Usage:
#   handle_llm_regeneration_with_feedback "$base_prompt" "$generate_func" "$display_func" "$execute_func" "$content_type" "$validate_func" "$dry_run_flag"
#
# Parameters:
#   $1: base_prompt - The initial LLM prompt
#   $2: generate_func - Function name to call for content generation  
#   $3: display_func - Function name to call for content display
#   $4: execute_func - Function name to call for content execution
#   $5: content_type - Description for user messages (e.g., "edit commands", "comment")
#   $6: validate_func - Optional function name for content validation (can be empty)
#   $7: dry_run_flag - Boolean flag for dry run mode (true/false)
#
# Returns:
#   0 on successful execution, 1 on cancellation or error
#
# Example callback functions:
#   generate_func: Takes prompt as $1, returns generated content via stdout
#   display_func: Takes content as $1, displays it to user
#   execute_func: Takes content as $1, executes it and returns success/failure
#   validate_func: Takes content as $1, returns 0 if valid, 1 if invalid

handle_llm_regeneration_with_feedback() {
    local base_prompt="$1"
    local generate_func="$2"
    local display_func="$3" 
    local execute_func="$4"
    local content_type="$5"
    local validate_func="$6"
    local dry_run_flag="$7"
    
    # Validate required parameters
    if [ -z "$base_prompt" ] || [ -z "$generate_func" ] || [ -z "$display_func" ] || [ -z "$execute_func" ] || [ -z "$content_type" ]; then
        echo "Error: Missing required parameters for LLM regeneration handler"
        return 1
    fi
    
    local user_feedback=""
    local should_generate=true
    local generated_content=""
    
    while true; do
        if [ "$should_generate" = true ]; then
            # Build final prompt with feedback
            local final_prompt="$base_prompt"
            if [ -n "$user_feedback" ]; then
                final_prompt+="

User feedback for improvement:
$user_feedback

Please incorporate this feedback to improve the $content_type."
            fi
            
            # Generate content using callback
            generated_content=$($generate_func "$final_prompt" "$dry_run_flag")
            
            if [ $? -ne 0 ] || [ -z "$generated_content" ]; then
                echo "Failed to generate $content_type. Please try again."
                return 1
            fi
            
            should_generate=false
        fi
        
        # Optional validation
        if [ -n "$validate_func" ]; then
            if ! $validate_func "$generated_content" "$dry_run_flag"; then
                echo "⚠️  Validation failed for generated $content_type."
                echo "Please regenerate to fix this issue."
                echo ""
                
                validation_choice=$(use_gum_choose "--dry-run=$dry_run_flag" "What would you like to do?" "Regenerate $content_type" "Quit")
                
                case "$validation_choice" in
                    "Regenerate $content_type" )
                        echo "Regenerating $content_type..."
                        user_feedback+="- Generated $content_type failed validation. Please fix the issues.\\n"
                        should_generate=true
                        continue
                        ;;
                    "Quit" )
                        echo "Operation cancelled."
                        return 1
                        ;;
                    * )
                        echo "Operation cancelled."
                        return 1
                        ;;
                esac
            fi
        fi
        
        # Display content using callback
        $display_func "$generated_content" "$dry_run_flag"
        echo ""
        
        response=$(use_gum_choose "--dry-run=$dry_run_flag" "Execute this $content_type?" "Yes" "Regenerate" "Quit")
        
        case "$response" in
            "Yes" )
                $execute_func "$generated_content" "$dry_run_flag"
                return $?
                ;;
            "Regenerate" )
                feedback_input=$(use_gum_input "--dry-run=$dry_run_flag" "Please provide feedback for improvement:" "Enter your feedback here")
                if [ -n "$feedback_input" ]; then
                    user_feedback+="- $feedback_input\\n"
                fi
                echo "Regenerating $content_type..."
                should_generate=true
                continue
                ;;
            "Quit" )
                echo "Operation cancelled."
                return 1
                ;;
            * )
                echo "Operation cancelled."
                return 1
                ;;
        esac
    done
}