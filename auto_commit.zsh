#!/usr/bin/env zsh

# Check if there are staged changes
if ! git diff --cached --quiet; then
    # Get the diff for context
    staged_diff=$(git diff --cached)
    
    # Get recent commit history for context
    recent_commits=$(git log --oneline --no-merges -5)
    
    user_feedback=""
    last_commit_msg=""

    while true; do
        # Create a more focused prompt for the commit message with recent history context
        base_prompt="Based on the following git diff and recent commit history, generate a concise, conventional commit message (e.g., 'feat:', 'fix:', 'docs:', etc.)."
        
        feedback_prompt=""
        if [ -n "$last_commit_msg" ]; then
            feedback_prompt="\n\nThe previous attempt was:\n---\n$last_commit_msg\n---\n\nPlease incorporate the following cumulative feedback to improve the message:\n$user_feedback"
        fi

        optional_prompt="$1"

        full_prompt="$base_prompt$feedback_prompt\n\nRecent commits for context:\n$recent_commits\n\nCurrent staged changes:\n$staged_diff\n\n"
        if [ -n "$optional_prompt" ]; then
            full_prompt+="Additional context from user: $optional_prompt\n\n"
        fi
        full_prompt+="Focus on what changed and why, considering the recent development context. Use a bullet list under the title, and do NOT use markdown code blocks. Use dashes (-) for bullet points:"

        echo "Staged files to be shown to Gemini:"
        git diff --name-only --cached

        commit_msg=$(echo "$staged_diff" | gemini -m gemini-2.5-flash --prompt "$full_prompt" | tail -n +2)
        commit_msg+="

🤖 Generated with [Gemini CLI](https://github.com/google-gemini/gemini-cli)"

        if [ $? -ne 0 ] || [ -z "$commit_msg" ]; then
            echo "Failed to generate commit message. Please commit manually."
            exit 1
        fi
        last_commit_msg=$commit_msg

        echo "Generated commit message:\n$commit_msg"
        echo ""
        echo "Accept and commit? [y/r/q] (yes / regenerate with feedback / quit)"
        read -r response

        case "$response" in
            [Yy]* )

                git commit -m "$commit_msg"
                echo "Changes committed successfully!"

                echo ""
                echo "Do you want to push the changes now? [y/N]"
                read -r push_response

                if [[ "$push_response" =~ ^[Yy]$ ]]; then
                    git push
                    echo "Changes pushed successfully!"
                else
                    echo "Push cancelled. You can push manually later with 'git push'."
                fi
                break
                ;;
            [Rr]* )
                echo "Please provide feedback:"
                read -r feedback_input
                if [ -n "$feedback_input" ]; then
                    user_feedback+="- $feedback_input\n"
                fi
                echo "Regenerating commit message..."
                continue
                ;;
            [Qq]* )
                echo "Commit cancelled. You can commit manually with:"
                echo "git commit -m \"$commit_msg\""
                break
                ;;
            * )
                echo "Invalid option. Please choose 'y', 'r', or 'q'."
                ;;
        esac
    done
else
    echo "No staged changes found."
    echo "Do you want to stage all changes? [y/N]"
    read -r stage_response

    if [[ "$stage_response" =~ ^[Yy]$ ]]; then
        git add .
        echo "All changes staged."
        # Re-run the script to proceed with commit message generation
        exec "$0" "$@"
    else
        echo "No changes staged. Commit cancelled."
    fi
fi