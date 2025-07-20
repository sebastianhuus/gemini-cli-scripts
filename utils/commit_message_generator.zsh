#!/usr/bin/env zsh

# Commit Message Generator Utility
# Provides AI-powered commit message generation with interactive feedback loops

# Get the script directory to source dependencies
local util_script_dir="${0:A:h}"
local gum_helpers_path="${util_script_dir}/../gum/gum_helpers.zsh"
local commit_display_helpers_path="${util_script_dir}/display/commit_display.zsh"

source "$commit_display_helpers_path"

# Source gum helper functions for consistent UI
if [ -f "$gum_helpers_path" ]; then
    source "$gum_helpers_path"
else
    # Fallback: try relative to parent directory (when called from auto_commit.zsh)
    local parent_gum_path="${util_script_dir}/../gum/gum_helpers.zsh"
    if [ -f "$parent_gum_path" ]; then
        source "$parent_gum_path"
    fi
fi

# Function to build the commit prompt with all necessary context
build_commit_prompt() {
    local staged_diff="$1"
    local recent_commits="$2"
    local repository_context="$3"
    local gemini_context="$4"
    local optional_context="$5"
    local last_commit_msg="$6"
    local user_feedback="$7"
    
    local base_prompt="Based on the following git diff and recent commit history, generate a concise, conventional commit message (e.g., 'feat:', 'fix:', 'docs:', etc.)."
    
    local feedback_prompt=""
    if [ -n "$last_commit_msg" ]; then
        feedback_prompt="\n\nThe previous attempt was:\n---\n$last_commit_msg\n---\n\nPlease incorporate the following cumulative feedback to improve the message:\n$user_feedback"
    fi

    local full_prompt="$base_prompt$feedback_prompt"
    
    if [ -n "$repository_context" ]; then
        full_prompt+="\n\nRepository context:\n$repository_context"
    fi
    
    if [ -n "$gemini_context" ]; then
        full_prompt+="\n\nRepository context from GEMINI.md:\n$gemini_context"
    fi
    
    full_prompt+="\n\nRecent commits for context:\n$recent_commits\n\nCurrent staged changes:\n$staged_diff\n\n"
    if [ -n "$optional_context" ]; then
        full_prompt+="Additional context from user: $optional_context\n\n"
    fi
    full_prompt+="Focus on what changed and why, considering the recent development context. IMPORTANT: Start with the commit title on the first line immediately - do NOT wrap the commit message in code blocks (\`\`\` marks). Use a bullet list under the title with dashes (-) for bullet points:"

    echo "$full_prompt"
}

# Function to call Gemini CLI and generate commit message
call_gemini_for_commit() {
    local staged_diff="$1"
    local full_prompt="$2"
    local script_dir="$3"
    
    # Generate the raw commit message from Gemini
    local gemini_raw_msg=$(echo "$staged_diff" | gemini -m gemini-2.5-flash --prompt "$full_prompt" | "${script_dir}/utils/gemini_clean.zsh")
    
    # Check for generation failure
    if [ $? -ne 0 ] || [ -z "$gemini_raw_msg" ]; then
        return 1
    fi
    
    echo "$gemini_raw_msg"
}

# Function to display staged files information
display_staged_files() {
    local staged_files=$(git diff --name-only --cached)
    local staged_files_block="> **Staged files to be shown to Gemini:**"
    while IFS= read -r file; do
        staged_files_block+=$'\n> '"$file"
    done <<< "$staged_files"
    
    # Display using gum format if available, otherwise fallback to echo
    if command -v gum &> /dev/null; then
        echo "$staged_files_block" | gum format
        echo "> \n" | gum format
    else
        echo "$staged_files_block"
    fi
}

# Main function to generate commit message with interactive feedback loop
generate_commit_message() {
    local staged_diff="$1"
    local recent_commits="$2"
    local repository_context="$3"
    local gemini_context="$4"
    local optional_context="$5"
    local script_dir="$6"
    
    local user_feedback=""
    local last_commit_msg=""
    local should_generate=true
    local final_commit_msg=""

    while true; do
        if [ "$should_generate" = true ]; then
            # Display staged files
            display_staged_files
            
            # Build the prompt
            local full_prompt=$(build_commit_prompt "$staged_diff" "$recent_commits" "$repository_context" "$gemini_context" "$optional_context" "$last_commit_msg" "$user_feedback")
            
            # Generate the raw commit message from Gemini
            local gemini_raw_msg=$(call_gemini_for_commit "$staged_diff" "$full_prompt" "$script_dir")
            
            # Check for generation failure before proceeding
            if [ $? -ne 0 ] || [ -z "$gemini_raw_msg" ]; then
                echo "Failed to generate commit message. Please commit manually."
                return 1
            fi

            # Store the raw message for the next iteration's feedback loop (without attribution)
            last_commit_msg=$gemini_raw_msg

            # Create the final commit message with attribution for display and commit
            final_commit_msg="$gemini_raw_msg"
            final_commit_msg+=$'\n\n🤖 Generated with [Gemini CLI](https://github.com/google-gemini/gemini-cli)'
            
            should_generate=false
        fi

        # Display the commit message
        display_commit_message "$final_commit_msg"
        
        local response=$(use_gum_choose "Accept and commit?" "Yes" "Append text" "Regenerate" "Quit")

        case "$response" in
            "Yes" )
                # Store the final commit message in a variable for the caller to access
                GENERATED_COMMIT_MESSAGE="$final_commit_msg"
                return 0
                ;;
            "Append text" )
                local append_text=$(use_gum_input "Enter text to append:" "Additional details here")
                if [ -n "$append_text" ]; then
                    # Append to the raw message (before attribution)
                    last_commit_msg="$last_commit_msg"$'\n\n'"$append_text"
                    # Recreate final message with attribution
                    final_commit_msg="$last_commit_msg"
                    final_commit_msg+=$'\n\n🤖 Generated with [Gemini CLI](https://github.com/google-gemini/gemini-cli)'
                    echo "Text appended successfully."
                else
                    echo "No text entered, keeping original message."
                fi
                continue
                ;;
            "Regenerate" )
                local feedback_input=$(use_gum_input "Please provide feedback for improvement:" "Enter your feedback here")
                if [ -n "$feedback_input" ]; then
                    user_feedback+="- $feedback_input\n"
                fi
                echo "Regenerating commit message..."
                should_generate=true
                continue
                ;;
            "Quit" )
                return 2  # Special return code for quit
                ;;
            "Cancelled"|* )
                return 2  # Special return code for cancelled
                ;;
        esac
    done
}