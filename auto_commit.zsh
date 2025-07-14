#!/usr/bin/env zsh

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

# Check if we're on main/master branch and handle staging/branch creation
current_branch=$(git branch --show-current)
if [[ "$current_branch" == "main" || "$current_branch" == "master" ]]; then
    echo "⚠️  You're currently on the '$current_branch' branch."
    echo "It's recommended to create a feature branch for your changes."
    echo ""
    
    # First, handle staging if needed
    staged_diff=""
    if ! git diff --cached --quiet; then
        # Already have staged changes
        staged_diff=$(git diff --cached)
        echo "✅ Found staged changes for branch name generation."
    elif ! git diff --quiet; then
        # Have unstaged changes, ask to stage them
        echo "Found unstaged changes. Stage all changes? [y/N]"
        read -r stage_response
        if [[ "$stage_response" =~ ^[Yy]$ ]]; then
            git add .
            if ! git diff --cached --quiet; then
                staged_diff=$(git diff --cached)
                echo "✅ Changes staged successfully."
            else
                echo "❌ No changes to stage."
                exit 1
            fi
        else
            echo "Cannot generate branch name without staged changes."
            echo "Either stage changes first or create branch manually."
            exit 0
        fi
    else
        echo "No changes found (staged or unstaged)."
        echo "Create empty branch anyway? [y/N]"
        read -r empty_branch_response
        if [[ "$empty_branch_response" =~ ^[Yy]$ ]]; then
            echo "Enter branch name:"
            read -r manual_branch_name
            if [ -n "$manual_branch_name" ]; then
                if git switch -c "$manual_branch_name"; then
                    echo "✅ Created and switched to branch '$manual_branch_name'"
                    echo ""
                    exit 0
                else
                    echo "❌ Failed to create branch. Exiting."
                    exit 1
                fi
            else
                echo "No branch name provided. Staying on '$current_branch'."
                exit 0
            fi
        else
            echo "Staying on '$current_branch' branch."
            exit 0
        fi
    fi
    
    # Now ask about branch creation
    echo ""
    echo "Create a new branch? [y/N]"
    read -r create_branch_response
    
    if [[ "$create_branch_response" =~ ^[Yy]$ ]]; then
        # Generate branch name based on staged changes
        echo "Generating branch name based on staged changes..."
        
        # Create full prompt with embedded diff (like commit message generation)
        branch_name_prompt="Based on the following git diff, generate a concise git branch name following conventional naming patterns (e.g., 'feat/user-login', 'fix/memory-leak', 'docs/api-guide'). Use kebab-case and include a category prefix. Output ONLY the branch name, no explanations or code blocks:

Current staged changes:
$staged_diff"
        
        # Generate branch name with Gemini (using prompt embedding, not pipe)
        generated_branch_name=$(gemini -m gemini-2.5-flash --prompt "$branch_name_prompt" | tail -n +2 | tr -d '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        
        if [ $? -ne 0 ] || [ -z "$generated_branch_name" ]; then
            echo "Failed to generate branch name. Enter manually:"
            read -r manual_branch_name
            generated_branch_name="$manual_branch_name"
        fi
        
        # Branch name confirmation loop
        while true; do
            echo ""
            echo "Generated branch name: $generated_branch_name"
            echo ""
            echo "Create branch '$generated_branch_name'? [y/e/r/q] (yes / edit / regenerate / quit)"
            read -r branch_response
            
            case "$branch_response" in
                [Yy]* )
                    if git switch -c "$generated_branch_name"; then
                        echo "✅ Created and switched to branch '$generated_branch_name'"
                        echo ""
                    else
                        echo "❌ Failed to create branch. Exiting."
                        exit 1
                    fi
                    break
                    ;;
                [Ee]* )
                    echo "Enter new branch name:"
                    read -r manual_branch_name
                    if [ -n "$manual_branch_name" ]; then
                        generated_branch_name="$manual_branch_name"
                    fi
                    ;;
                [Rr]* )
                    echo "Regenerating branch name..."
                    generated_branch_name=$(gemini -m gemini-2.5-flash --prompt "$branch_name_prompt" | tail -n +2 | tr -d '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                    if [ $? -ne 0 ] || [ -z "$generated_branch_name" ]; then
                        echo "Failed to regenerate branch name."
                    fi
                    ;;
                [Qq]* )
                    echo "Branch creation cancelled. Staying on '$current_branch'."
                    exit 0
                    ;;
                * )
                    echo "Invalid option. Please choose 'y', 'e', 'r', or 'q'."
                    ;;
            esac
        done
    else
        echo "Continuing on '$current_branch' branch."
        echo ""
    fi
fi

# Check if there are staged changes
if ! git diff --cached --quiet; then
    # Display repository information
    display_repository_info
    
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
        full_prompt+="Focus on what changed and why, considering the recent development context. IMPORTANT: Start with the commit title on the first line immediately - do NOT wrap the commit message in code blocks (\``` marks). Use a bullet list under the title with dashes (-) for bullet points:"

        echo "Staged files to be shown to Gemini:"
        git diff --name-only --cached

        # Generate the raw commit message from Gemini
        gemini_raw_msg=$(echo "$staged_diff" | gemini -m gemini-2.5-flash --prompt "$full_prompt" | tail -n +2)
        
        # Check for generation failure before proceeding
        if [ $? -ne 0 ] || [ -z "$gemini_raw_msg" ]; then
            echo "Failed to generate commit message. Please commit manually."
            exit 1
        fi

        # Store the raw message for the next iteration's feedback loop (without attribution)
        last_commit_msg=$gemini_raw_msg

        # Create the final commit message with attribution for display and commit
        final_commit_msg="$gemini_raw_msg"
        final_commit_msg+=$'\n\n🤖 Generated with [Gemini CLI](https://github.com/google-gemini/gemini-cli)'

        echo "Generated commit message:\n$final_commit_msg"
        echo ""
        echo "Accept and commit? [y/r/q] (yes / regenerate with feedback / quit)"
        read -r response

        case "$response" in
            [Yy]* )
                git commit -m "$final_commit_msg"
                echo "Changes committed successfully!"

                echo ""
                echo "Do you want to push the changes now? [y/N]"
                read -r push_response

                if [[ "$push_response" =~ ^[Yy]$ ]]; then
                    current_branch=$(git branch --show-current)
                    # Check if upstream branch is set
                    if git rev-parse --abbrev-ref --symbolic-full-name @{u} >/dev/null 2>&1; then
                        # Upstream is set, a simple push is enough
                        git push
                    else
                        # Upstream is not set, so we need to publish the branch
                        echo "No upstream branch found for '$current_branch'. Publishing to 'origin/$current_branch'..."
                        git push --set-upstream origin "$current_branch"
                    fi

                    if [ $? -eq 0 ]; then
                        echo "Changes pushed successfully!"
                    else
                        echo "Failed to push changes."
                    fi
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
                echo "git commit -m \"$final_commit_msg\""
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