#!/usr/bin/env zsh

# Load context utility if available
script_dir="${0:A:h}"

# Function to get absolute path to utils directory
get_utils_path() {
    echo "${script_dir:A}/utils"
}

gemini_context=""
if [ -f "$(get_utils_path)/gemini_context.zsh" ]; then
    source "$(get_utils_path)/gemini_context.zsh"
    gemini_context=$(load_gemini_context)
fi

# GitHub Issue Natural Language Assistant with LLM Enhancement
# 
# Usage:
#   ./auto_issue.zsh "natural language request"        # Natural language mode
#   ./auto_issue.zsh --help                            # Show this help
#
# Natural language mode features:
#   - Understands natural language requests for GitHub operations
#   - Supports create, edit, comment, and other issue operations
#   - Intent parsing with confirmation before execution
#   - Smart parameter extraction and validation
#
# Examples:
#   ./auto_issue.zsh "create issue about login bug"
#   ./auto_issue.zsh "add comment to issue 8 about fix deployed"
#   ./auto_issue.zsh "edit issue 13 title to say Bug: Login timeout"
#   ./auto_issue.zsh "comment on issue #5: this is resolved"
#
# Developer Expansion Guide:
# =========================
# 
# To add new operations (close, reopen, label management):
#
# 1. Update parse_intent() function:
#    - Add new operation to OPERATION list in prompt
#    - Add examples for the new operation
#
# 2. Update confirm_operation() function:
#    - Add new case for the operation
#    - Define validation rules and display format
#
# 3. Create new operation function:
#    - Follow pattern of comment_issue() and edit_issue()
#    - Use LLM for content generation when appropriate
#    - Include confirmation step before execution
#
# 4. Update dispatch_operation() function:
#    - Add new case to route to your function
#
# 5. Update help documentation and examples
#
# Architecture:
# - convert_question_to_command(): Converts questions/requests to direct commands
# - parse_intent(): Extracts operation type and parameters from natural language
# - confirm_operation(): Validates and confirms operation before execution
# - dispatch_operation(): Routes to appropriate handler function
# - Individual operation functions: Handle specific GitHub operations
# - LLM integration: Uses Gemini CLI for content generation and intent parsing
#
# Two-Stage Processing:
# 1. Question Detection & Conversion: Handles conversational requests
# 2. Intent Parsing: Extracts structured data from direct commands

# Check for help flag
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "GitHub Issue Natural Language Assistant with LLM Enhancement"
    echo ""
    echo "Usage:"
    echo "  $0 \"natural language request\"             # Natural language mode"
    echo "  $0 --help                                  # Show this help"
    echo ""
    echo "Natural language mode features:"
    echo "  - Understands natural language requests for GitHub operations"
    echo "  - Supports create, edit, comment, and other issue operations"
    echo "  - Intent parsing with confirmation before execution"
    echo "  - Smart parameter extraction and validation"
    echo ""
    echo "Examples:"
    echo "  $0 \"create issue about login bug\""
    echo "  $0 \"add comment to issue 8 about fix deployed\""
    echo "  $0 \"edit issue 13 title to say Bug: Login timeout\""
    echo "  $0 \"comment on issue #5: this is resolved\""
    exit 0
fi

# Check if gh is installed first
if ! command -v gh &> /dev/null; then
    echo "GitHub CLI (gh) not found. This script requires 'gh' to create issues."
    echo "Please install it from https://cli.github.com/ and try again."
    exit 1
fi

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
        echo "> $result" | gum format >&2
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
        echo "> $result" | gum format >&2
        echo "$result"
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
    
    if command -v gum &> /dev/null; then
        local result
        if [ -n "$placeholder" ]; then
            result=$(gum input --placeholder="$placeholder" --header="$prompt")
        else
            result=$(gum input --header="$prompt")
        fi
        echo "# $prompt" | gum format >&2
        echo "> $result" | gum format >&2
        echo "$result"
    else
        # Fallback to traditional prompt
        echo "$prompt"
        read -r response
        echo "> $response"
        echo "$response"
    fi
}

# Function to display repository information
display_repository_info() {
    local repo_url=$(git remote get-url origin 2>/dev/null)
    local current_branch=$(git branch --show-current 2>/dev/null)
    
    if [ -n "$repo_url" ]; then
        # Extract repository name from different URL formats
        local repo_name
        if [[ "$repo_url" =~ github\.com[:/]([^/]+/[^/]+)(\.git)?$ ]]; then
            repo_name="${match[1]}"
        else
            # Fallback: use the URL as is
            repo_name="$repo_url"
        fi
        
        echo "🏗️  Repository: $repo_name"
    else
        echo "🏗️  Repository: (unable to detect remote)"
    fi
    
    if [ -n "$current_branch" ]; then
        echo "🌿 Branch: $current_branch"
    fi
    
    echo ""
}

# Function to validate that quotes are properly closed in a string
validate_quotes() {
    local input="$1"
    
    # Only validate double quotes at the shell command level
    # Single quotes inside double-quoted strings (like contractions) are safe
    local double_quote_count=$(echo "$input" | grep -o '"' | wc -l)
    
    # Check if double quote count is odd (unclosed quotes)
    if [ $((double_quote_count % 2)) -ne 0 ]; then
        echo "Error: Unclosed double quotes detected in: $input"
        return 1
    fi
    
    return 0
}

# Function to handle issue editing
edit_issue() {
    local issue_number="$1"
    local edit_prompt="$2"
    
    if [ -z "$issue_number" ] || [ -z "$edit_prompt" ]; then
        echo "Usage: $0 edit <issue_number> <edit_prompt>"
        echo "Example: $0 edit 42 \"change the title to 'Bug: Login button not working'\""
        exit 1
    fi
    
    echo "Fetching current issue details..."
    
    # Get current issue details as readable text
    current_issue=$(gh issue view "$issue_number")
    
    if [ $? -ne 0 ]; then
        echo "Failed to fetch issue #$issue_number. Please check the issue number and try again."
        exit 1
    fi
    
    echo "Current issue:"
    echo "=========================="
    echo "$current_issue"
    echo "=========================="
    echo ""
    
    # Create prompt for LLM
    llm_prompt="You are helping to edit a GitHub issue. Based on the user's request, generate the appropriate gh issue edit command(s) to modify the issue.

Current issue:
$current_issue

User's edit request: $edit_prompt"
    
    if [ -n "$gemini_context" ]; then
        llm_prompt+="

Repository context from GEMINI.md:
$gemini_context"
    fi
    
    llm_prompt+="

Please provide the exact gh issue edit command(s) needed to apply these changes. Only output the command(s), one per line, without any additional text or explanation. Use the issue number $issue_number in your commands.

IMPORTANT: Output the gh commands as plain text without bash code blocks or backticks around the commands.

Examples of valid commands:
- gh issue edit $issue_number --title \"New Title\"
- gh issue edit $issue_number --body \"New body content\"
- gh issue edit $issue_number --add-label \"bug,enhancement\"
- gh issue edit $issue_number --remove-label \"wontfix\"
- gh issue edit $issue_number --add-assignee \"username\"
- gh issue edit $issue_number --remove-assignee \"username\"

For body edits, if the user wants to append or prepend text, combine it with the existing body content."
    
    echo "Generating edit commands with Gemini..."
    
    # Initialize variables for regeneration loop
    local user_feedback=""
    local should_generate=true
    
    # Regeneration loop
    while true; do
        if [ "$should_generate" = true ]; then
            # Rebuild prompt with feedback if provided
            local final_prompt="$llm_prompt"
            if [ -n "$user_feedback" ]; then
                final_prompt+="

User feedback for improvement:
$user_feedback

Please incorporate this feedback to improve the edit commands."
            fi
            
            # Generate edit commands from Gemini
            edit_commands=$(echo "$final_prompt" | gemini -m gemini-2.5-flash --prompt "$final_prompt" | "$(get_utils_path)/gemini_clean.zsh")
            
            if [ $? -ne 0 ] || [ -z "$edit_commands" ]; then
                echo "Failed to generate edit commands. Please try again."
                exit 1
            fi
            
            should_generate=false
        fi
        
        # Validate quotes in the entire command block before presenting to user
        if ! validate_quotes "$edit_commands"; then
            echo "⚠️  Validation failed: Generated commands contain unclosed quotes."
            echo "Please regenerate the commands to fix this issue."
            echo ""
            
            validation_choice=$(use_gum_choose "What would you like to do?" "Regenerate commands" "Quit")
            
            case "$validation_choice" in
                "Regenerate commands" )
                    echo "Regenerating edit commands..."
                    user_feedback+="- Generated commands contained unclosed quotes. Please ensure all quotes are properly closed in the commands.\n"
                    should_generate=true
                    continue
                    ;;
                "Quit" )
                    echo "Edit cancelled."
                    return 1
                    ;;
                * )
                    echo "Edit cancelled."
                    return 1
                    ;;
            esac
        fi

        echo "Generated edit commands:"
        echo "------------------------"
        echo "$edit_commands"
        echo "------------------------"
        echo ""
        response=$(use_gum_choose "Execute these commands?" "Yes" "Regenerate" "Quit")
        
        case "$response" in
            "Yes" )
                echo "Executing edit commands..."
                # Execute the entire command block, escaping backticks like in create_issue_with_llm
                echo "Running: $edit_commands"
                escaped_command=$(echo "$edit_commands" | sed 's/`/\\`/g')
                eval "$escaped_command"
                if [ $? -eq 0 ]; then
                    echo "✓ Command executed successfully"
                else
                    echo "✗ Command failed"
                fi
                echo "Issue edit completed!"
                return 0
                ;;
            "Regenerate" )
                feedback_input=$(use_gum_input "Please provide feedback for improvement:" "Enter your feedback here")
                if [ -n "$feedback_input" ]; then
                    user_feedback+="- $feedback_input\n"
                fi
                echo "Regenerating edit commands..."
                should_generate=true
                continue
                ;;
            "Quit" )
                echo "Edit cancelled."
                return 1
                ;;
            * )
                echo "Edit cancelled."
                return 1
                ;;
        esac
    done
}

# Function to parse natural language intent using enhanced parser
parse_intent_wrapper() {
    local input="$1"
    
    # Source the enhanced parse intent functions
    source "$(get_utils_path)/parse_intent.zsh"
    
    # Use the enhanced parse intent function
    local intent_output=$(parse_intent "$input" "$gemini_context")
    
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

# Function to extract specific fields from intent output with enhanced NONE handling
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

# Function to confirm operation before execution
confirm_operation() {
    local operation="$1"
    local issue_number="$2"
    local content="$3"
    local confidence="$4"
    local requested_labels="$5"
    local requested_assignees="$6"
    local requested_milestone="$7"
    local priority_indicators="$8"
    local tone_preference="$9"
    local special_instructions="${10}"
    
    echo "Intent Analysis:"
    echo "================"
    
    case "$operation" in
        "comment")
            if [ "$issue_number" = "NONE" ]; then
                echo "❌ Cannot comment - no issue number specified"
                return 1
            fi
            echo "✓ COMMENT on issue #$issue_number"
            echo "Content: $content"
            ;;
        "edit")
            if [ "$issue_number" = "NONE" ]; then
                echo "❌ Cannot edit - no issue number specified"
                return 1
            fi
            echo "✓ EDIT issue #$issue_number"
            echo "Changes: $content"
            ;;
        "create")
            echo "✓ CREATE new issue"
            echo "Description: $content"
            ;;
        "view")
            if [ "$issue_number" = "NONE" ]; then
                echo "❌ Cannot view - no issue number specified"
                return 1
            fi
            echo "✓ VIEW issue #$issue_number"
            ;;
        *)
            echo "❌ Unknown operation: $operation"
            return 1
            ;;
    esac
    
    # Display extracted parameters if present
    if [ -n "$requested_labels" ]; then
        echo "Requested Labels: $requested_labels"
    fi
    if [ -n "$requested_assignees" ]; then
        echo "Requested Assignees: $requested_assignees"
    fi
    if [ -n "$requested_milestone" ]; then
        echo "Requested Milestone: $requested_milestone"
    fi
    if [ -n "$priority_indicators" ]; then
        echo "Priority: $priority_indicators"
    fi
    if [ -n "$tone_preference" ]; then
        echo "Tone Preference: $tone_preference"
    fi
    if [ -n "$special_instructions" ]; then
        echo "Special Instructions: $special_instructions"
    fi
    
    echo ""
    echo "Confidence: $confidence"
    echo ""
    
    if [ "$confidence" = "low" ]; then
        echo "⚠️  Low confidence in intent parsing. Please verify the operation above is correct."
        echo ""
    fi
    
    if use_gum_confirm "Proceed with this operation?"; then
        return 0
    else
        return 1
    fi
}

# Function to add comment to GitHub issue
comment_issue() {
    local issue_number="$1"
    local comment_prompt="$2"
    local tone_preference="$3"
    local special_instructions="$4"
    
    if [ -z "$issue_number" ] || [ -z "$comment_prompt" ]; then
        echo "Usage: comment_issue <issue_number> <comment_prompt>"
        return 1
    fi
    
    echo "Fetching issue details for context..."
    
    # Get current issue details for context
    local current_issue=$(gh issue view "$issue_number" 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        echo "Failed to fetch issue #$issue_number. Please check the issue number and try again."
        return 1
    fi
    
    echo "Current issue:"
    echo "=============="
    echo "$current_issue" | head -10
    echo "..."
    echo ""
    
    # Create prompt for LLM to generate comment
    local llm_prompt="Generate a professional GitHub issue comment based on the user's request.

Current issue context:
$current_issue

User's comment request: $comment_prompt"
    
    if [ -n "$gemini_context" ]; then
        llm_prompt+="

Repository context from GEMINI.md:
$gemini_context"
    fi
    
    llm_prompt+="

Please provide a well-structured comment that addresses the user's request. The comment should be:
- Clear and concise
- Relevant to the issue context
- Properly formatted with markdown if needed"

    # Add tone preference if specified
    if [ -n "$tone_preference" ]; then
        case "$tone_preference" in
            "formal")
                llm_prompt+="
- Use formal, professional language"
                ;;
            "casual")
                llm_prompt+="
- Use casual, friendly language"
                ;;
            "technical")
                llm_prompt+="
- Use technical, precise language with specific details"
                ;;
        esac
    else
        llm_prompt+="
- Professional in tone"
    fi
    
    # Add special instructions if specified
    if [ -n "$special_instructions" ]; then
        llm_prompt+="
- Special instructions: $special_instructions"
    fi
    
    llm_prompt+="

Only output the comment content, without any additional text or explanation."
    
    echo "Generating comment with Gemini..."
    
    # Initialize variables for regeneration loop
    local user_feedback=""
    local should_generate=true
    
    # Regeneration loop
    while true; do
        if [ "$should_generate" = true ]; then
            # Rebuild prompt with feedback if provided
            local final_prompt="$llm_prompt"
            if [ -n "$user_feedback" ]; then
                final_prompt+="

User feedback for improvement:
$user_feedback

Please incorporate this feedback to improve the comment."
            fi
            
            # Generate comment content from Gemini
            local comment_content=$(echo "$final_prompt" | gemini -m gemini-2.5-flash --prompt "$final_prompt" | "$(get_utils_path)/gemini_clean.zsh")
            
            if [ $? -ne 0 ] || [ -z "$comment_content" ]; then
                echo "Failed to generate comment. Please try again."
                return 1
            fi
            
            should_generate=false
        fi
        
        # Use the comment content directly (attribution already included by prompt)
        local final_comment="$comment_content"
        
        echo "Generated comment:"
        echo "=================="
        echo "$final_comment"
        echo "=================="
        echo ""
        response=$(use_gum_choose "Post this comment?" "Yes" "Regenerate" "Quit")
        
        case "$response" in
            "Yes" )
                echo "Posting comment to issue #$issue_number..."
                gh issue comment "$issue_number" --body "$final_comment"
                if [ $? -eq 0 ]; then
                    echo "Comment posted successfully!"
                    return 0
                else
                    echo "Failed to post comment."
                    return 1
                fi
                ;;
            "Regenerate" )
                feedback_input=$(use_gum_input "Please provide feedback for improvement:" "Enter your feedback here")
                if [ -n "$feedback_input" ]; then
                    user_feedback+="- $feedback_input\n"
                fi
                echo "Regenerating comment..."
                should_generate=true
                continue
                ;;
            "Quit" )
                echo "Comment cancelled."
                return 1
                ;;
            * )
                echo "Comment cancelled."
                return 1
                ;;
        esac
    done
}

# Function to handle LLM-controlled issue creation
create_issue_with_llm() {
    local user_description="$1"
    local requested_labels="$2"
    local requested_assignees="$3"
    local requested_milestone="$4"
    local priority_indicators="$5"
    local tone_preference="$6"
    local special_instructions="$7"
    local user_feedback="$8"
    local last_command="$9"
    
    # Fetch repository context to help LLM make better parameter choices
    echo "Fetching repository context..."
    
    # Get available labels
    available_labels=$(gh label list --limit 100 2>/dev/null | awk '{print $1}' | head -20)
    labels_context=""
    if [ -n "$available_labels" ]; then
        labels_context="Available labels in this repository: $(echo "$available_labels" | tr '\n' ', ' | sed 's/, $//')"
    fi
    
    # Get available milestones
    available_milestones=$(gh api repos/:owner/:repo/milestones --jq '.[].title' 2>/dev/null | head -10)
    milestones_context=""
    if [ -n "$available_milestones" ]; then
        milestones_context="Available milestones: $(echo "$available_milestones" | tr '\n' ', ' | sed 's/, $//')"
    fi
    
    # Get repository collaborators (for assignees)
    available_collaborators=$(gh api repos/:owner/:repo/collaborators --jq '.[].login' 2>/dev/null | head -10)
    collaborators_context=""
    if [ -n "$available_collaborators" ]; then
        collaborators_context="Available collaborators for assignment: $(echo "$available_collaborators" | tr '\n' ', ' | sed 's/, $//')"
    fi
    
    # Create prompt for LLM to generate gh issue create command
    base_prompt="You are helping to create a GitHub issue. Based ONLY on the user's description provided below, generate the appropriate gh issue create command with relevant parameters.

IMPORTANT: Only use information from the user's description. Do not make assumptions about project structure, file locations, or other project details not explicitly mentioned by the user.

Repository Context (use this to select appropriate labels, milestones, and assignees):
$labels_context
$milestones_context
$collaborators_context"
    
    if [ -n "$gemini_context" ]; then
        base_prompt+="

Additional repository context from GEMINI.md:
$gemini_context"
    fi
    
    base_prompt+="

User's description: $user_description"
    
    # Add extracted parameters to the prompt
    if [ -n "$requested_labels" ] || [ -n "$requested_assignees" ] || [ -n "$requested_milestone" ] || [ -n "$priority_indicators" ] || [ -n "$tone_preference" ] || [ -n "$special_instructions" ]; then
        base_prompt+="

User's requested parameters from natural language:
- Requested labels: $requested_labels
- Requested assignees: $requested_assignees  
- Requested milestone: $requested_milestone
- Priority indicators: $priority_indicators
- Tone preference: $tone_preference
- Special instructions: $special_instructions

IMPORTANT: Use these extracted parameters as guidance but validate them against the repository context above. Map requested labels to available labels when possible (e.g., 'urgent' might map to 'priority:high', 'critical' to 'priority:critical'). Only use assignees that exist in the collaborators list. If a requested parameter doesn't exist, suggest the closest available alternative or omit it."
    fi

    feedback_prompt=""
    if [ -n "$last_command" ]; then
        feedback_prompt="

The previous command was:
---
$last_command
---

Please incorporate the following feedback to improve the command:
$user_feedback"
    fi

    full_prompt="$base_prompt$feedback_prompt

Please provide the exact gh issue create command needed. Only output the command, without any additional text or explanation.

IMPORTANT: Output the gh command directly as plain text without wrapping it in bash code blocks (\```bash). Do NOT use backticks around the entire command. However, DO use proper markdown formatting inside the --body parameter content (headers, bullets, etc.).

For the --body parameter, create a comprehensive, well-structured issue body that includes:

**For Feature Requests:**
- Brief summary/overview
- ## Motivation section explaining why this feature is needed
- ## Proposed Solution section with implementation approach
- ## Acceptance Criteria with specific, testable requirements
- ## Additional Context with examples, references, or considerations

**For Bug Reports:**
- Brief summary of the issue
- ## Steps to Reproduce with numbered steps
- ## Expected Behavior section
- ## Actual Behavior section
- ## Environment Information if relevant
- ## Additional Context with screenshots, logs, or related issues

**For General Issues:**
- Clear problem statement
- ## Background/Context section
- ## Proposed Approach section
- ## Success Criteria section
- ## Implementation Notes if applicable

Make the body detailed, professional, and actionable. Use proper markdown formatting with headers, bullet points, and code blocks where appropriate.

CRITICAL: Do not assume or specify file paths, directory structures, or implementation details not mentioned in the user's description. Keep implementation details generic unless explicitly provided.

IMPORTANT: Always end the --body content with this attribution line: 

🤖 Generated with [Gemini CLI](https://github.com/google-gemini/gemini-cli)

Available parameters you can use:
- --title \"Issue Title\" (required)
- --body \"Issue body content\" (required)
- --assignee \"username\" (can be used multiple times - only use usernames from the collaborators list above)
- --label \"label1,label2\" (comma-separated labels - only use labels from the available labels list above)
- --milestone \"milestone_name\" (only use milestones from the available milestones list above)
- --project \"project_name\"

Examples of valid commands:
- gh issue create --title \"Bug: Login button not working\" --body \"Steps to reproduce...\" --label \"bug,high-priority\" --assignee \"username\"
- gh issue create --title \"Feature: Add dark mode\" --body \"Feature description...\" --label \"enhancement\" --milestone \"v2.0\"

IMPORTANT: Only use labels, milestones, and assignees that exist in the repository context provided above. If no suitable options exist in the repository context, omit those parameters rather than guessing.

Make sure to include appropriate labels and assignees based on the issue type and content. Always include both --title and --body parameters with a comprehensive, well-structured body."

    echo "Generating issue creation command with Gemini..."
    
    # Generate create command from Gemini
    create_command=$(echo "$full_prompt" | gemini -m gemini-2.5-flash --prompt "$full_prompt" | "$(get_utils_path)/gemini_clean.zsh")
    
    if [ $? -ne 0 ] || [ -z "$create_command" ]; then
        echo "Failed to generate create command. Please try again."
        return 1
    fi
    
    # The LLM now includes attribution directly in the body, so no post-processing needed
    enhanced_command="$create_command"
    
    echo "Generated create command:"
    echo "------------------------"
    echo "$enhanced_command"
    echo "------------------------"
    echo ""
    response=$(use_gum_choose "Execute this command?" "Yes" "Regenerate with feedback" "Quit")
    
    case "$response" in
        "Yes" )
            echo "Creating issue on GitHub..."
            # Escape backticks in the command to prevent shell interpretation
            escaped_command=$(echo "$enhanced_command" | sed 's/`/\\`/g')
            if ! validate_quotes "$escaped_command"; then
                echo "Command validation failed - unsafe quotes detected"
                return 1
            fi
            eval "$escaped_command"
            if [ $? -eq 0 ]; then
                echo "Issue created successfully!"
                return 0
            else
                echo "Failed to create issue."
                return 1
            fi
            ;;
        "Regenerate with feedback" )
            feedback_input=$(use_gum_input "Please provide feedback for improvement:" "Enter your feedback here")
            if [ -n "$feedback_input" ]; then
                create_issue_with_llm "$user_description" "$requested_labels" "$requested_assignees" "$requested_milestone" "$priority_indicators" "$tone_preference" "$special_instructions" "$feedback_input" "$create_command"
            else
                create_issue_with_llm "$user_description" "$requested_labels" "$requested_assignees" "$requested_milestone" "$priority_indicators" "$tone_preference" "$special_instructions" "" "$create_command"
            fi
            ;;
        "Quit" )
            echo "Issue creation cancelled."
            return 1
            ;;
        * )
            echo "Issue creation cancelled."
            return 1
            ;;
    esac
}

# Function to dispatch operations based on parsed intent
dispatch_operation() {
    local operation="$1"
    local issue_number="$2"
    local content="$3"
    local requested_labels="$4"
    local requested_assignees="$5"
    local requested_milestone="$6"
    local priority_indicators="$7"
    local tone_preference="$8"
    local special_instructions="$9"
    
    case "$operation" in
        "comment")
            comment_issue "$issue_number" "$content" "$tone_preference" "$special_instructions"
            ;;
        "edit")
            edit_issue "$issue_number" "$content" "$requested_labels" "$requested_assignees" "$requested_milestone" "$priority_indicators" "$special_instructions"
            ;;
        "create")
            create_issue_with_llm "$content" "$requested_labels" "$requested_assignees" "$requested_milestone" "$priority_indicators" "$tone_preference" "$special_instructions"
            ;;
        "view")
            echo "Viewing issue #$issue_number:"
            gh issue view "$issue_number"
            ;;
        *)
            echo "Unsupported operation: $operation"
            return 1
            ;;
    esac
}

# Function to convert questions to direct commands
convert_question_to_command() {
    local input="$1"
    
    # LLM prompt for question detection and conversion
    local converter_prompt="Analyze this input and determine if it's a question/polite request or already a direct command.

User input: $input

DETECTION RULES:
1. QUESTION/POLITE REQUEST (convert to direct command):
   - Contains question words: \"can you\", \"would you\", \"could you\", \"help me\", \"please\"
   - Contains polite phrases: \"would you mind\", \"if you could\", \"I need you to\"
   - Starts with question words: \"how do I\", \"what should I\", \"why is\"

2. DIRECT COMMAND (return unchanged):
   - Starts with action verbs: \"add\", \"edit\", \"create\", \"comment\", \"view\", \"close\", \"reopen\"
   - Contains imperative instructions without polite qualifiers
   - Already in command format

Examples of CONVERSION (questions → commands):
Input: \"can you generate a clear description of issue 16 based on the title\"
Output: \"edit issue 16 body to generate a clear description based on the title\"

Input: \"help me add a comment to issue 8 about the fix\"
Output: \"add comment to issue 8 about the fix\"

Input: \"please create an issue about dark mode\"
Output: \"create issue about dark mode\"

Input: \"would you mind commenting on issue 12 that this is resolved\"
Output: \"comment on issue 12 that this is resolved\"

Examples of NO CHANGE (already direct commands):
Input: \"edit issue 5 title to say Bug: Login timeout\"
Output: \"edit issue 5 title to say Bug: Login timeout\"

Input: \"add -p --push flag for automatic push when commit message confirmed\"
Output: \"add -p --push flag for automatic push when commit message confirmed\"

Input: \"create issue about login timeout\"
Output: \"create issue about login timeout\"

Input: \"comment on issue 15 about deployment status\"
Output: \"comment on issue 15 about deployment status\"

CRITICAL: If input starts with action verbs (add, edit, create, comment, view, close, reopen) and does NOT contain polite/question phrases, return it EXACTLY as provided. Do NOT add \"create\" or modify direct commands.

Only output the converted/unchanged command, no additional text.

IMPORTANT: Output as plain text only, no code blocks or formatting."
    
    # Get converted command from Gemini
    local converted_command=$(echo "$converter_prompt" | gemini -m gemini-2.5-flash --prompt "$converter_prompt" | "$(get_utils_path)/gemini_clean.zsh")
    
    if [ $? -ne 0 ] || [ -z "$converted_command" ]; then
        # If conversion fails, return original input
        echo "$input"
    else
        echo "$converted_command"
    fi
}

# Function to handle natural language input
handle_natural_language() {
    local input="$1"
    
    if [ -z "$input" ]; then
        echo "Please provide a natural language request."
        echo "Example: ./auto_issue.zsh \"add comment to issue 8 about login fix\""
        return 1
    fi
    
    # Display repository information
    display_repository_info
    
    echo "Processing natural language request..."
    
    # Stage 1: Convert questions to commands
    local processed_input=$(convert_question_to_command "$input")
    
    # Show conversion if it changed
    if [ "$processed_input" != "$input" ]; then
        echo "Converted request: $processed_input"
        echo ""
    fi
    
    echo "Parsing natural language request..."
    
    # Stage 2: Parse the processed command
    local intent_output=$(parse_intent_wrapper "$processed_input")
    
    if [ $? -ne 0 ]; then
        echo "Failed to parse intent. Please try rephrasing your request."
        return 1
    fi
    
    # Extract fields from intent output
    local operation=$(extract_field "OPERATION" "$intent_output")
    local issue_number=$(extract_field "ISSUE_NUMBER" "$intent_output")
    local content=$(extract_field "CONTENT" "$intent_output")
    local confidence=$(extract_field "CONFIDENCE" "$intent_output")
    
    # Extract new enhanced parameters
    local requested_labels=$(extract_field "REQUESTED_LABELS" "$intent_output")
    local requested_assignees=$(extract_field "REQUESTED_ASSIGNEES" "$intent_output")
    local requested_milestone=$(extract_field "REQUESTED_MILESTONE" "$intent_output")
    local priority_indicators=$(extract_field "PRIORITY_INDICATORS" "$intent_output")
    local tone_preference=$(extract_field "TONE_PREFERENCE" "$intent_output")
    local special_instructions=$(extract_field "SPECIAL_INSTRUCTIONS" "$intent_output")
    
    # Confirm operation with user
    if confirm_operation "$operation" "$issue_number" "$content" "$confidence" "$requested_labels" "$requested_assignees" "$requested_milestone" "$priority_indicators" "$tone_preference" "$special_instructions"; then
        echo "Executing operation..."
        dispatch_operation "$operation" "$issue_number" "$content" "$requested_labels" "$requested_assignees" "$requested_milestone" "$priority_indicators" "$tone_preference" "$special_instructions"
    else
        echo "Operation cancelled."
        return 1
    fi
}

# No explicit subcommands - everything through natural language

# Main entry point - natural language mode
# Get all arguments as the natural language input
natural_language_input="$*"

# If no arguments provided, prompt for input
if [ -z "$natural_language_input" ]; then
    echo "Please provide a natural language request:"
    echo "Examples:"
    echo "  \"create issue about login bug\""
    echo "  \"add comment to issue 8 about fix deployed\""
    echo "  \"edit issue 13 title to say Bug: Login timeout\""
    echo ""
    echo "Enter your request:"
    read -r natural_language_input
fi

# Handle natural language input
handle_natural_language "$natural_language_input"