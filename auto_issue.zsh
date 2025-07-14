#!/usr/bin/env zsh

# Check if gh is installed first
if ! command -v gh &> /dev/null; then
    echo "GitHub CLI (gh) not found. This script requires 'gh' to create issues."
    echo "Please install it from https://cli.github.com/ and try again."
    exit 1
fi

# Get optional prompt argument
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