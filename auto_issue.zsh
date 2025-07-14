#!/usr/bin/env zsh

# GitHub Issue Auto-Creation Tool with LLM Enhancement
# 
# Usage:
#   ./auto_issue.zsh [description]              # New LLM-controlled mode (default)
#   ./auto_issue.zsh legacy [description]       # Legacy mode (structured text parsing)
#   ./auto_issue.zsh edit <issue_number> <edit_prompt>  # Edit existing issue
#   ./auto_issue.zsh --help                     # Show this help
#
# New LLM-controlled mode features:
#   - LLM generates complete `gh issue create` command
#   - Supports assignees, labels, milestones, and project boards
#   - Smart parameter selection based on issue content
#   - Command preview and confirmation before execution
#
# Examples:
#   ./auto_issue.zsh "Bug: Login button not working"
#   ./auto_issue.zsh legacy "Feature request for dark mode"
#   ./auto_issue.zsh edit 42 "add bug label and assign to john"

# Check for help flag
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "GitHub Issue Auto-Creation Tool with LLM Enhancement"
    echo ""
    echo "Usage:"
    echo "  $0 [description]                        # New LLM-controlled mode (default)"
    echo "  $0 legacy [description]                 # Legacy mode (structured text parsing)"
    echo "  $0 edit <issue_number> <edit_prompt>    # Edit existing issue"
    echo "  $0 --help                               # Show this help"
    echo ""
    echo "New LLM-controlled mode features:"
    echo "  - LLM generates complete 'gh issue create' command"
    echo "  - Supports assignees, labels, milestones, and project boards"
    echo "  - Smart parameter selection based on issue content"
    echo "  - Command preview and confirmation before execution"
    echo ""
    echo "Examples:"
    echo "  $0 \"Bug: Login button not working\""
    echo "  $0 legacy \"Feature request for dark mode\""
    echo "  $0 edit 42 \"add bug label and assign to john\""
    exit 0
fi

# Check if gh is installed first
if ! command -v gh &> /dev/null; then
    echo "GitHub CLI (gh) not found. This script requires 'gh' to create issues."
    echo "Please install it from https://cli.github.com/ and try again."
    exit 1
fi

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

User's edit request: $edit_prompt

Please provide the exact gh issue edit command(s) needed to apply these changes. Only output the command(s), one per line, without any additional text or explanation. Use the issue number $issue_number in your commands.

Examples of valid commands:
- gh issue edit $issue_number --title \"New Title\"
- gh issue edit $issue_number --body \"New body content\"
- gh issue edit $issue_number --add-label \"bug,enhancement\"
- gh issue edit $issue_number --remove-label \"wontfix\"
- gh issue edit $issue_number --add-assignee \"username\"
- gh issue edit $issue_number --remove-assignee \"username\"

For body edits, if the user wants to append or prepend text, combine it with the existing body content."
    
    echo "Generating edit commands with Gemini..."
    
    # Generate edit commands from Gemini
    edit_commands=$(echo "$llm_prompt" | gemini -m gemini-2.5-flash --prompt "$llm_prompt" | tail -n +2)
    
    if [ $? -ne 0 ] || [ -z "$edit_commands" ]; then
        echo "Failed to generate edit commands. Please try again."
        exit 1
    fi
    
    echo "Generated edit commands:"
    echo "------------------------"
    echo "$edit_commands"
    echo "------------------------"
    echo ""
    echo "Execute these commands? [y/N]"
    read -r response
    
    case "$response" in
        [Yy]* )
            echo "Executing edit commands..."
            # Execute each command
            echo "$edit_commands" | while IFS= read -r cmd; do
                if [ -n "$cmd" ]; then
                    echo "Running: $cmd"
                    eval "$cmd"
                    if [ $? -eq 0 ]; then
                        echo "✓ Command executed successfully"
                    else
                        echo "✗ Command failed"
                    fi
                fi
            done
            echo "Issue edit completed!"
            ;;
        * )
            echo "Edit cancelled."
            ;;
    esac
}

# Check for edit subcommand
if [ "$1" = "edit" ]; then
    edit_issue "$2" "$3"
    exit 0
fi

# Check for legacy mode flag
if [ "$1" = "legacy" ]; then
    use_legacy_mode=true
    shift  # Remove the 'legacy' argument
else
    use_legacy_mode=false
fi

# Function to handle LLM-controlled issue creation
create_issue_with_llm() {
    local user_description="$1"
    local user_feedback="$2"
    local last_command="$3"
    
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
$collaborators_context

User's description: $user_description"

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
    create_command=$(echo "$full_prompt" | gemini -m gemini-2.5-flash --prompt "$full_prompt" | tail -n +2)
    
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
    echo "Execute this command? [y/r/q] (yes / regenerate with feedback / quit)"
    read -r response
    
    case "$response" in
        [Yy]* )
            echo "Creating issue on GitHub..."
            # Escape backticks in the command to prevent shell interpretation
            escaped_command=$(echo "$enhanced_command" | sed 's/`/\\`/g')
            eval "$escaped_command"
            if [ $? -eq 0 ]; then
                echo "Issue created successfully!"
                return 0
            else
                echo "Failed to create issue."
                return 1
            fi
            ;;
        [Rr]* )
            echo "Please provide feedback:"
            read -r feedback_input
            if [ -n "$feedback_input" ]; then
                create_issue_with_llm "$user_description" "$feedback_input" "$create_command"
            else
                create_issue_with_llm "$user_description" "" "$create_command"
            fi
            ;;
        [Qq]* )
            echo "Issue creation cancelled."
            return 1
            ;;
        * )
            echo "Invalid option. Please choose 'y', 'r', or 'q'."
            create_issue_with_llm "$user_description" "$user_feedback" "$create_command"
            ;;
    esac
}

# Original functionality - Get optional prompt argument
initial_description="$1"

# Prompt for a description if not provided
if [ -z "$initial_description" ]; then
    echo "Please describe the issue you want to create (press Ctrl+D when done):"
    # Read multiple lines of input
    user_description=$(</dev/stdin)
else
    user_description="$initial_description"
fi

if [ -z "$user_description" ]; then
    echo "No description provided. Exiting."
    exit 1
fi

# Choose between new LLM-controlled mode and legacy mode
if [ "$use_legacy_mode" = true ]; then
    # Legacy mode - original functionality
    user_feedback=""
    last_issue_content=""

    while true; do
        # Create a prompt for generating the GitHub issue
        base_prompt="Based on the following description, generate a GitHub issue with a 'TITLE:' and a 'BODY:'. The body should be well-structured. If it's a bug, include sections like 'Steps to Reproduce', 'Expected Behavior', and 'Actual Behavior'. If it's a feature request, describe the feature clearly."

        feedback_prompt=""
        if [ -n "$last_issue_content" ]; then
            feedback_prompt="

The previous attempt was:
---
$last_issue_content
---

Please incorporate the following cumulative feedback to improve the issue:
$user_feedback"
        fi

        full_prompt="$base_prompt$feedback_prompt

Initial Description:
$user_description

"
        full_prompt+="Format the output strictly as:
TITLE: [Your Title]
BODY:
[Your Body Here]"

        echo "Generating GitHub issue content with Gemini..."

        # Generate the raw issue content from Gemini
        # Using tail -n +2 to trim potential initial auth lines from Gemini CLI
        gemini_raw_content=$(echo "$full_prompt" | gemini -m gemini-2.5-flash --prompt "$full_prompt" | tail -n +2)

        # Check for generation failure
        if [ $? -ne 0 ] || [ -z "$gemini_raw_content" ]; then
            echo "Failed to generate issue content. Please try again."
            echo "Retry? [y/N]"
            read -r retry_response
            if [[ "$retry_response" =~ ^[Yy]$ ]]; then
                continue
            else
                exit 1
            fi
        fi

        # Store the raw content for the feedback loop
        last_issue_content=$gemini_raw_content

        # Create the display content with attribution
        display_content="$gemini_raw_content"
        display_content+=$'

🤖 Generated with [Gemini CLI](https://github.com/google-gemini/gemini-cli)'

        echo "Generated GitHub Issue:
------------------------
$display_content
------------------------"
        echo ""
        echo "Create this issue? [y/r/q] (yes / regenerate with feedback / quit)"
        read -r response

        case "$response" in
            [Yy]* )
                # Extract title and body from the raw content (without attribution)
                issue_title=$(echo "$gemini_raw_content" | grep "^TITLE:" | sed 's/^TITLE: //')
                issue_body_raw=$(echo "$gemini_raw_content" | sed -n '/^BODY:/,$p' | sed '1d')

                # Add attribution to the final body
                issue_body="$issue_body_raw"$'

🤖 Generated with [Gemini CLI](https://github.com/google-gemini/gemini-cli)'

                echo "Creating issue on GitHub..."
                # Create issue using gh cli
                gh issue create --title "$issue_title" --body "$issue_body"
                
                if [ $? -eq 0 ]; then
                    echo "Issue created successfully!"
                else
                    echo "Failed to create issue."
                fi
                break
                ;;
            [Rr]* )
                echo "Please provide feedback:"
                read -r feedback_input
                if [ -n "$feedback_input" ]; then
                    user_feedback+="- $feedback_input
"
                fi
                echo "Regenerating issue content..."
                continue
                ;;
            [Qq]* )
                echo "Issue creation cancelled."
                break
                ;;
            * )
                echo "Invalid option. Please choose 'y', 'r', or 'q'."
                ;;
        esac
    done
else
    # New LLM-controlled mode (default)
    create_issue_with_llm "$user_description"
fi