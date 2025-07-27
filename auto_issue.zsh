#!/usr/bin/env zsh

# Get script directory early for configuration loading
script_dir="$(dirname "${0:A}")"

# Load configuration system
source "${script_dir}/config/config_loader.zsh"
load_gemini_config "$script_dir"

# Load context utility if available

# Function to get absolute path to utils directory
get_utils_path() {
    echo "${script_dir:A}/utils"
}

gemini_context=""
if [ -f "$(get_utils_path)/core/gemini_context.zsh" ]; then
    source "$(get_utils_path)/core/gemini_context.zsh"
    gemini_context=$(load_gemini_context "$script_dir")
fi

# Load shared gum helper functions
source "${script_dir}/gum/gum_helpers.zsh"

# Load shared command extraction utility
if [ -f "${script_dir}/utils/git/gh_command_extraction.zsh" ]; then
    source "${script_dir}/utils/git/gh_command_extraction.zsh"
else
    echo "Error: Required command extraction utility not found at ${script_dir}/utils/git/gh_command_extraction.zsh"
    exit 1
fi

# Load issue display utility
if [ -f "${script_dir}/utils/ui/issue_display.zsh" ]; then
    source "${script_dir}/utils/ui/issue_display.zsh"
else
    echo "Error: Required issue display utility not found at ${script_dir}/utils/ui/issue_display.zsh"
    exit 1
fi

# Load LLM regeneration handler utility
if [ -f "${script_dir}/utils/core/llm_regeneration_handler.zsh" ]; then
    source "${script_dir}/utils/core/llm_regeneration_handler.zsh"
else
    echo "Error: Required LLM regeneration handler utility not found at ${script_dir}/utils/core/llm_regeneration_handler.zsh"
    exit 1
fi

# GitHub Issue Management Assistant with Menu Interface
# 
# Usage:
#   ./auto_issue.zsh                                   # Interactive menu mode
#   ./auto_issue.zsh --help                            # Show this help
#
# Interactive menu features:
#   - Menu-driven interface for GitHub issue operations
#   - Supports create, edit, comment, and view operations
#   - Input validation and user-friendly prompts
#   - LLM-powered content generation
#
# Operations available:
#   - Create new issue with optional labels, assignees, and milestone
#   - Comment on existing issue with contextual content
#   - Edit existing issue (title, body, labels, etc.)
#   - View existing issue details
#
# Developer Expansion Guide:
# =========================
# 
# To add new operations (close, reopen, label management):
#
# 1. Add new option to show_operation_menu() function:
#    - Add menu option like "Close issue" or "Reopen issue"
#    - Add corresponding case in the menu handler
#
# 2. Create new handler function:
#    - Follow pattern of handle_*_issue_flow() functions
#    - Use gum for user input and validation
#    - Call execute_operation() with appropriate parameters
#
# 3. Create new operation function:
#    - Follow pattern of comment_issue() and edit_issue()
#    - Use LLM for content generation when appropriate
#    - Include confirmation step before execution
#
# 4. Update execute_operation() function:
#    - Add new case to route to your function
#
# 5. Update help documentation and menu options
#
# Architecture:
# - show_operation_menu(): Main menu interface using gum
# - handle_*_issue_flow(): Operation-specific input flows
# - execute_operation(): Routes to appropriate handler function
# - Individual operation functions: Handle specific GitHub operations
# - LLM integration: Uses Gemini CLI for content generation

# Initialize flags
dry_run=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            dry_run=true
            shift
            ;;
        -h|--help)
            echo "GitHub Issue Management Assistant with Menu Interface"
            echo ""
            echo "Usage:"
            echo "  $0 [--dry-run]                             # Interactive menu mode"
            echo "  $0 --help                                  # Show this help"
            echo ""
            echo "Options:"
            echo "  --dry-run        Show what would be executed without making changes"
            echo "  -h, --help       Show this help message"
            echo ""
            echo "Interactive menu features:"
            echo "  - Menu-driven interface for GitHub issue operations"
            echo "  - Supports create, edit, comment, view, close, and reopen operations"
            echo "  - Input validation and user-friendly prompts"
            echo "  - LLM-powered content generation"
            echo ""
            echo "Operations available:"
            echo "  - Create new issue with optional labels, assignees, and milestone"
            echo "  - Comment on existing issue with contextual content"
            echo "  - Edit existing issue (title, body, labels, etc.)"
            echo "  - View existing issue details"
            echo "  - Close existing issue with optional reason"
            echo "  - Reopen existing issue with optional reason"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information."
            exit 1
            ;;
    esac
done

# Check if gh is installed first
if ! command -v gh &> /dev/null; then
    echo "GitHub CLI (gh) not found. This script requires 'gh' to create issues."
    echo "Please install it from https://cli.github.com/ and try again."
    exit 1
fi


# Load reusable environment display utility
source "${script_dir}/gum/env_display.zsh"

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

# Function to fetch and display issue details with consistent formatting
# Returns: 0 on success, 1 on failure
# Sets global variable: current_issue_content
fetch_and_display_issue() {
    local issue_number="$1"
    local context_message="${2:-Fetching issue details...}"
    local show_truncated="${3:-true}"
    
    if [ -z "$issue_number" ]; then
        colored_status "**Error:** Issue number is required" "error"
        return 1
    fi
    
    colored_status "$context_message" "info"
    
    # Fetch issue details
    current_issue_content=$(gh issue view "$issue_number" 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        colored_status "**Failed** to fetch issue #$issue_number. Please check the issue number and try again." "error"
        return 1
    fi
    
    # Display issue with consistent formatting
    echo "Current issue:"
    echo "=============="
    
    if [ "$show_truncated" = "true" ]; then
        echo "$current_issue_content" | head -10
        echo "..."
    else
        echo "$current_issue_content"
    fi
    echo ""
    
    return 0
}

# Function to validate issue exists and is accessible
validate_issue_exists() {
    local issue_number="$1"
    
    if [ -z "$issue_number" ]; then
        return 1
    fi
    
    # Check if issue exists by trying to fetch its details
    gh issue view "$issue_number" --json id >/dev/null 2>&1
    return $?
}

# Function to get issue number with validation
get_validated_issue_number() {
    local prompt="$1"
    local placeholder="$2"
    
    while true; do
        local issue_number=$(use_gum_input "--dry-run=$dry_run" "$prompt" "$placeholder")
        
        if [ -z "$issue_number" ]; then
            echo "Issue number is required." >&2
            continue
        fi
        
        # Validate issue number is numeric
        if ! [[ "$issue_number" =~ ^[0-9]+$ ]]; then
            echo "Issue number must be a positive integer." >&2
            continue
        fi
        
        # Validate issue exists
        echo "Validating issue #$issue_number exists..." >&2
        if validate_issue_exists "$issue_number"; then
            echo "$issue_number"
            return 0
        else
            echo "Issue #$issue_number not found or not accessible. Please check the issue number." >&2
            if ! use_gum_confirm "--dry-run=$dry_run" "Try again?"; then
                return 1
            fi
        fi
    done
}

# Callback functions for edit operations
_edit_generate_content() {
    local prompt="$1"
    local local_dry_run="${2:-$dry_run}"
    if [ "$local_dry_run" = true ]; then
        colored_status "🔍 DRY RUN: Would generate edit commands with Gemini" "info" >&2
        echo "gh issue edit 42 --title \"Updated Issue Title\" --body \"Updated issue body with more details\""
    else
        echo "$prompt" | gemini -m "$(get_gemini_model)" --prompt "$prompt" | "$(get_utils_path)/core/gemini_clean.zsh"
    fi
}

_edit_display_content() {
    local content="$1"
    local local_dry_run="${2:-$dry_run}"  # Accept but don't use dry run parameter
    echo "Generated edit commands:"
    echo "------------------------"
    echo "$content"
    echo "------------------------"
}

_edit_execute_content() {
    local content="$1"
    local local_dry_run="${2:-$dry_run}"
    echo "Executing edit commands..."
    echo "Running: $content"
    escaped_command=$(echo "$content" | sed 's/`/\\`/g')
    if dry_run_execute "--dry-run=$local_dry_run" "execute issue edit command" "$escaped_command"; then
        echo "✓ Command executed successfully"
        echo "Issue edit completed!"
        return 0
    else
        echo "✗ Command failed"
        return 1
    fi
}

_edit_validate_content() {
    local content="$1"
    local local_dry_run="${2:-$dry_run}"  # Accept but don't use dry run parameter
    if ! validate_quotes "$content"; then
        echo "Generated commands contained unclosed quotes. Please ensure all quotes are properly closed in the commands."
        return 1
    fi
    return 0
}

# Function to handle issue editing
edit_issue() {
    local issue_number="$1"
    local edit_prompt="$2"
    local local_dry_run="${3:-$dry_run}"
    
    if [ -z "$issue_number" ] || [ -z "$edit_prompt" ]; then
        echo "Usage: $0 edit <issue_number> <edit_prompt>"
        echo "Example: $0 edit 42 \"change the title to 'Bug: Login button not working'\""
        exit 1
    fi
    
    if ! fetch_and_display_issue "$issue_number" "Fetching current issue details..." "false"; then
        exit 1
    fi
    current_issue="$current_issue_content"
    
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
    
    # Use the generic regeneration handler
    handle_llm_regeneration_with_feedback \
        "$llm_prompt" \
        "_edit_generate_content" \
        "_edit_display_content" \
        "_edit_execute_content" \
        "edit commands" \
        "_edit_validate_content" \
        "$local_dry_run"
}


# Callback functions for comment operations
_comment_generate_content() {
    local prompt="$1"
    local local_dry_run="${2:-$dry_run}"
    if [ "$local_dry_run" = true ]; then
        colored_status "🔍 DRY RUN: Would generate comment content with Gemini" "info" >&2
        echo "This is a sample comment generated in dry-run mode. It would address the user's request with appropriate context and professional tone."
    else
        echo "$prompt" | gemini -m "$(get_gemini_model)" --prompt "$prompt" | "$(get_utils_path)/core/gemini_clean.zsh"
    fi
}

_comment_display_content() {
    local content="$1"
    local local_dry_run="${2:-$dry_run}"  # Accept but don't use dry run parameter
    echo "Generated comment:"
    echo "=================="
    echo "$content"
    echo "=================="
}

_comment_execute_content() {
    local content="$1"
    local local_dry_run="${2:-$dry_run}"
    # The issue_number is captured from the parent scope
    echo "Posting comment to issue #$_comment_issue_number..."
    if dry_run_execute "--dry-run=$local_dry_run" "post comment to issue #$_comment_issue_number" "gh issue comment \"$_comment_issue_number\" --body \"$content\""; then
        echo "Comment posted successfully!"
        return 0
    else
        echo "Failed to post comment."
        return 1
    fi
}

# Function to add comment to GitHub issue
comment_issue() {
    local issue_number="$1"
    local comment_prompt="$2"
    local tone_preference="$3"
    local special_instructions="$4"
    local local_dry_run="${5:-$dry_run}"
    
    if [ -z "$issue_number" ] || [ -z "$comment_prompt" ]; then
        echo "Usage: comment_issue <issue_number> <comment_prompt>"
        return 1
    fi
    
    if ! fetch_and_display_issue "$issue_number" "Fetching issue details for context..."; then
        return 1
    fi
    local current_issue="$current_issue_content"
    
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
    
    # Ask user if they want AI refinement or to post as-is
    echo "How would you like to proceed with your comment?"
    local refinement_choice=$(use_gum_choose "--dry-run=$local_dry_run" "Choose an option:" "Refine with AI" "Post as-is")
    
    case "$refinement_choice" in
        "Post as-is" )
            echo "Posting comment as-is to issue #$issue_number..."
            if dry_run_execute "--dry-run=$local_dry_run" "post comment to issue #$issue_number" "gh issue comment \"$issue_number\" --body \"$comment_prompt\""; then
                echo "Comment posted successfully!"
                return 0
            else
                echo "Failed to post comment."
                return 1
            fi
            ;;
        "Refine with AI" )
            echo "Generating comment with Gemini..."
            ;;
        * )
            echo "Comment cancelled."
            return 1
            ;;
    esac
    
    # Store issue number for callback function access
    _comment_issue_number="$issue_number"
    
    # Use the generic regeneration handler (no validation needed for comments)
    handle_llm_regeneration_with_feedback \
        "$llm_prompt" \
        "_comment_generate_content" \
        "_comment_display_content" \
        "_comment_execute_content" \
        "comment" \
        "" \
        "$local_dry_run"
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
    local local_dry_run="${10:-$dry_run}"
    
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
    if [ "$local_dry_run" = true ]; then
        colored_status "🔍 DRY RUN: Would generate issue creation command with Gemini" "info" >&2
        create_command='gh issue create --title "Bug: Sample issue for dry-run" --body "## Description
This is a sample issue created in dry-run mode.

## Steps to Reproduce
1. Run the script with --dry-run flag
2. Select create issue option
3. Observe simulated behavior

## Expected Behavior
Commands should be simulated without actual execution

🤖 Generated with [Gemini CLI](https://github.com/google-gemini/gemini-cli)" --label "bug" --assignee "example-user"'
    else
        create_command=$(echo "$full_prompt" | gemini -m "$(get_gemini_model)" --prompt "$full_prompt" | "$(get_utils_path)/core/gemini_clean.zsh")
        
        if [ $? -ne 0 ] || [ -z "$create_command" ]; then
            echo "Failed to generate create command. Please try again."
            return 1
        fi
    fi
    
    # The LLM now includes attribution directly in the body, so no post-processing needed
    enhanced_command="$create_command"
    
    # Extract title and body from the generated command for enhanced display
    local issue_title=$(extract_gh_title "$enhanced_command")
    local issue_body=$(extract_gh_body "$enhanced_command")
    
    if [ -n "$issue_title" ] && [ -n "$issue_body" ]; then
        display_issue_content "$issue_title" "$issue_body"
    else
        # Fallback: show raw command when extraction fails
        echo "Generated create command:"
        if command -v gum &> /dev/null; then
            echo "$enhanced_command" | gum format -t "code" -l "zsh"
        else
            echo "------------------------"
            echo "$enhanced_command"
            echo "------------------------"
        fi
    fi
    echo ""
    response=$(use_gum_choose "--dry-run=$dry_run" "Execute this command?" "Yes" "Regenerate with feedback" "Quit")
    
    case "$response" in
        "Yes" )
            echo "Creating issue on GitHub..."
            # Escape backticks in the command to prevent shell interpretation
            escaped_command=$(echo "$enhanced_command" | sed 's/`/\\`/g')
            if ! validate_quotes "$escaped_command"; then
                echo "Command validation failed - unsafe quotes detected"
                return 1
            fi
            if dry_run_execute "--dry-run=$dry_run" "create GitHub issue" "$escaped_command"; then
                echo "Issue created successfully!"
                return 0
            else
                echo "Failed to create issue."
                return 1
            fi
            ;;
        "Regenerate with feedback" )
            feedback_input=$(use_gum_input "--dry-run=$local_dry_run" "Please provide feedback for improvement:" "Enter your feedback here")
            if [ -n "$feedback_input" ]; then
                create_issue_with_llm "$user_description" "$requested_labels" "$requested_assignees" "$requested_milestone" "$priority_indicators" "$tone_preference" "$special_instructions" "$feedback_input" "$create_command" "$dry_run"
            else
                create_issue_with_llm "$user_description" "$requested_labels" "$requested_assignees" "$requested_milestone" "$priority_indicators" "$tone_preference" "$special_instructions" "" "$create_command" "$dry_run"
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

# Function to close GitHub issue
close_issue() {
    local issue_number="$1"
    local close_reason="$2"
    local local_dry_run="${3:-$dry_run}"
    
    if [ -z "$issue_number" ]; then
        echo "Usage: close_issue <issue_number> [close_reason]"
        return 1
    fi
    
    if ! fetch_and_display_issue "$issue_number"; then
        return 1
    fi
    local current_issue="$current_issue_content"
    
    # Show confirmation with optional reason
    if [ -n "$close_reason" ]; then
        echo "Closing issue #$issue_number with reason: $close_reason"
    else
        echo "Closing issue #$issue_number"
    fi
    
    if use_gum_confirm "--dry-run=$local_dry_run" "Are you sure you want to close this issue?"; then
        if [ -n "$close_reason" ]; then
            # Add a comment with the close reason, then close
            if dry_run_execute "--dry-run=$local_dry_run" "add closing comment to issue #$issue_number" "gh issue comment \"$issue_number\" --body \"Closing: $close_reason\""; then
                dry_run_execute "--dry-run=$local_dry_run" "close issue #$issue_number" "gh issue close \"$issue_number\""
            else
                return 1
            fi
        else
            dry_run_execute "--dry-run=$local_dry_run" "close issue #$issue_number" "gh issue close \"$issue_number\""
        fi
        
        if [ $? -eq 0 ]; then
            echo "Issue #$issue_number closed successfully!"
            return 0
        else
            echo "Failed to close issue #$issue_number."
            return 1
        fi
    else
        echo "Close operation cancelled."
        return 1
    fi
}

# Function to reopen GitHub issue
reopen_issue() {
    local issue_number="$1"
    local reopen_reason="$2"
    local local_dry_run="${3:-$dry_run}"
    
    if [ -z "$issue_number" ]; then
        echo "Usage: reopen_issue <issue_number> [reopen_reason]"
        return 1
    fi
    
    if ! fetch_and_display_issue "$issue_number"; then
        return 1
    fi
    local current_issue="$current_issue_content"
    
    # Show confirmation with optional reason
    if [ -n "$reopen_reason" ]; then
        echo "Reopening issue #$issue_number with reason: $reopen_reason"
    else
        echo "Reopening issue #$issue_number"
    fi
    
    if use_gum_confirm "--dry-run=$local_dry_run" "Are you sure you want to reopen this issue?"; then
        if [ -n "$reopen_reason" ]; then
            # Reopen first, then add a comment with the reason
            if dry_run_execute "--dry-run=$local_dry_run" "reopen issue #$issue_number" "gh issue reopen \"$issue_number\""; then
                dry_run_execute "--dry-run=$local_dry_run" "add reopening comment to issue #$issue_number" "gh issue comment \"$issue_number\" --body \"Reopening: $reopen_reason\""
            else
                return 1
            fi
        else
            dry_run_execute "--dry-run=$local_dry_run" "reopen issue #$issue_number" "gh issue reopen \"$issue_number\""
        fi
        
        if [ $? -eq 0 ]; then
            echo "Issue #$issue_number reopened successfully!"
            return 0
        else
            echo "Failed to reopen issue #$issue_number."
            return 1
        fi
    else
        echo "Reopen operation cancelled."
        return 1
    fi
}

# Function to execute operations with simplified parameters
execute_operation() {
    local operation="$1"
    local issue_number="$2"
    local content="$3"
    local requested_labels="$4"
    local requested_assignees="$5"
    local requested_milestone="$6"
    
    case "$operation" in
        "comment")
            comment_issue "$issue_number" "$content" "" "" "$dry_run"
            ;;
        "edit")
            edit_issue "$issue_number" "$content" "$dry_run"
            ;;
        "create")
            create_issue_with_llm "$content" "$requested_labels" "$requested_assignees" "$requested_milestone" "" "" "" "" "" "$dry_run"
            ;;
        "view")
            echo "Viewing issue #$issue_number:"
            dry_run_execute "--dry-run=$dry_run" "view issue #$issue_number" "gh issue view \"$issue_number\""
            ;;
        "close")
            close_issue "$issue_number" "$content" "$dry_run"
            ;;
        "reopen")
            reopen_issue "$issue_number" "$content" "$dry_run"
            ;;
        *)
            echo "Unsupported operation: $operation"
            return 1
            ;;
    esac
}


# Function to show operation menu and handle user selection
show_operation_menu() {
    # Display repository information
    display_env_info
    
    local operation=$(use_gum_choose "--dry-run=$dry_run" "What would you like to do?" \
        "Create new issue" \
        "Comment on existing issue" \
        "Edit existing issue" \
        "View existing issue" \
        "Close existing issue" \
        "Reopen existing issue" \
        "Quit")
    
    case "$operation" in
        "Create new issue")
            colored_status "Selected: Create new issue" "info"
            handle_create_issue_flow
            ;;
        "Comment on existing issue")
            colored_status "Selected: Comment on existing issue" "info"
            handle_comment_issue_flow
            ;;
        "Edit existing issue")
            colored_status "Selected: Edit existing issue" "info"
            handle_edit_issue_flow
            ;;
        "View existing issue")
            colored_status "Selected: View existing issue" "info"
            handle_view_issue_flow
            ;;
        "Close existing issue")
            colored_status "Selected: Close existing issue" "info"
            handle_close_issue_flow
            ;;
        "Reopen existing issue")
            colored_status "Selected: Reopen existing issue" "info"
            handle_reopen_issue_flow
            ;;
        "Quit"|"")
            echo "Goodbye!"
            return 0
            ;;
        *)
            echo "Invalid selection."
            return 1
            ;;
    esac
}

# Function to handle create issue flow
handle_create_issue_flow() {
    colored_status "Creating a new issue..." "info"
    
    local description=$(use_gum_write "--dry-run=$dry_run" "Describe the issue you want to create:" "Enter a detailed description of the issue, including any relevant context, steps to reproduce, expected behavior, etc.")
    
    if [ -z "$description" ]; then
        echo "Issue description is required."
        return 1
    fi
    
    # Ask if user wants to add optional parameters
    if use_gum_confirm "--dry-run=$dry_run" "Would you like to specify labels, assignees, or milestone?"; then
        local labels=$(use_gum_input "--dry-run=$dry_run" "Labels (comma-separated, leave empty for none):" "bug,enhancement")
        local assignees=$(use_gum_input "--dry-run=$dry_run" "Assignees (comma-separated, leave empty for none):" "username")
        local milestone=$(use_gum_input "--dry-run=$dry_run" "Milestone (leave empty for none):" "v1.0")
        
        execute_operation "create" "" "$description" "$labels" "$assignees" "$milestone"
    else
        execute_operation "create" "" "$description" "" "" ""
    fi
}

# Function to handle comment issue flow
handle_comment_issue_flow() {
    colored_status "Adding a comment to an issue..." "info"
    
    local issue_number=$(get_validated_issue_number "Issue number:" "Enter issue number (e.g., 42)")
    
    if [ -z "$issue_number" ]; then
        echo "Operation cancelled."
        return 1
    fi
    
    local comment=$(use_gum_write "--dry-run=$dry_run" "Comment content:" "Enter your comment. You can include markdown formatting, code blocks, references to other issues, etc.")
    
    if [ -z "$comment" ]; then
        echo "Comment content is required."
        return 1
    fi
    
    execute_operation "comment" "$issue_number" "$comment" "" "" ""
}

# Function to handle edit issue flow
handle_edit_issue_flow() {
    colored_status "Editing an existing issue..." "info"
    
    local issue_number=$(get_validated_issue_number "Issue number:" "Enter issue number (e.g., 42)")
    
    if [ -z "$issue_number" ]; then
        echo "Operation cancelled."
        return 1
    fi
    
    local edit_instruction=$(use_gum_input "--dry-run=$dry_run" "What would you like to edit?" "change title to 'Bug: Login timeout'")
    
    if [ -z "$edit_instruction" ]; then
        echo "Edit instruction is required."
        return 1
    fi
    
    execute_operation "edit" "$issue_number" "$edit_instruction" "" "" ""
}

# Function to handle view issue flow
handle_view_issue_flow() {
    colored_status "Viewing an existing issue..." "info"
    
    local issue_number=$(get_validated_issue_number "Issue number:" "Enter issue number (e.g., 42)")
    
    if [ -z "$issue_number" ]; then
        echo "Operation cancelled."
        return 1
    fi
    
    execute_operation "view" "$issue_number" "" "" "" ""
}

# Function to handle close issue flow
handle_close_issue_flow() {
    colored_status "Closing an existing issue..." "info"
    
    local issue_number=$(get_validated_issue_number "Issue number:" "Enter issue number (e.g., 42)")
    
    if [ -z "$issue_number" ]; then
        echo "Operation cancelled."
        return 1
    fi
    
    # Optional close reason
    local close_reason=$(use_gum_input "--dry-run=$dry_run" "Close reason (optional):" "Fixed, duplicate, etc.")
    
    execute_operation "close" "$issue_number" "$close_reason" "" "" ""
}

# Function to handle reopen issue flow
handle_reopen_issue_flow() {
    colored_status "Reopening an existing issue..." "info"
    
    local issue_number=$(get_validated_issue_number "Issue number:" "Enter issue number (e.g., 42)")
    
    if [ -z "$issue_number" ]; then
        echo "Operation cancelled."
        return 1
    fi
    
    # Optional reopen reason
    local reopen_reason=$(use_gum_input "--dry-run=$dry_run" "Reopen reason (optional):" "Need to revisit, etc.")
    
    execute_operation "reopen" "$issue_number" "$reopen_reason" "" "" ""
}

# Menu-driven interface - no command line arguments needed

# Main entry point - menu-driven mode
show_operation_menu