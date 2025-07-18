#!/usr/bin/env zsh

# Default options
auto_stage=false
auto_pr=false
auto_branch=false
auto_push=false

# Usage function
usage() {
    echo "Usage: $0 [-s|--stage] [-b|--branch] [-pr|--pr] [-p|--push] [optional_context]"
    echo ""
    echo "Options:"
    echo "  -s, --stage    Automatically stage all changes before generating commit"
    echo "  -b, --branch   Automatically create new branch without confirmation"
    echo "  -pr, --pr      Automatically create pull request after successful commit"
    echo "  -p, --push     Automatically push changes after successful commit"
    echo "  -h, --help     Show this help message"
    echo ""
    echo "Arguments:"
    echo "  optional_context    Additional context for commit message generation"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--stage)
            auto_stage=true
            shift
            ;;
        -b|--branch)
            auto_branch=true
            shift
            ;;
        -pr|--pr)
            auto_pr=true
            shift
            ;;
        -p|--push)
            auto_push=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        -*)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
        *)
            # First non-option argument is the optional context
            break
            ;;
    esac
done

# Load context utility if available
script_dir="${0:A:h}"
gemini_context=""
if [ -f "${script_dir}/utils/gemini_context.zsh" ]; then
    source "${script_dir}/utils/gemini_context.zsh"
    gemini_context=$(load_gemini_context)
fi

# Function to get repository context for LLM
get_repository_context() {
    local repo_url=$(git remote get-url origin 2>/dev/null)
    local current_branch=$(git branch --show-current 2>/dev/null)
    local context=""
    
    if [ -n "$repo_url" ]; then
        # Extract repository name from different URL formats
        local repo_name
        if [[ "$repo_url" =~ github\.com[:/]([^/]+/[^/]+)(\.git)?$ ]]; then
            repo_name="${match[1]}"
        else
            # Fallback: use the URL as is
            repo_name="$repo_url"
        fi
        
        context+="Repository: $repo_name"
    else
        context+="Repository: (unable to detect remote)"
    fi
    
    if [ -n "$current_branch" ]; then
        context+="
Current branch: $current_branch"
    fi
    
    echo "$context"
}

# Function to check if gum is available and provide fallback
use_gum_confirm() {
    local prompt="$1"
    local default_yes="${2:-true}"
    
    if command -v gum &> /dev/null; then
        if [ "$default_yes" = true ]; then
            gum confirm "$prompt"
        else
            gum confirm "$prompt" --default=false
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
        gum choose --header="$prompt" "${options[@]}"
    else
        # Fallback to traditional prompt
        echo "$prompt"
        local i=1
        for option in "${options[@]}"; do
            echo "$i) $option"
            ((i++))
        done
        read -r choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#options[@]} ]; then
            echo "${options[$((choice-1))]}"
        else
            echo "${options[0]}" # Default to first option
        fi
    fi
}

use_gum_input() {
    local prompt="$1"
    local placeholder="${2:-}"
    
    if command -v gum &> /dev/null; then
        if [ -n "$placeholder" ]; then
            gum input --placeholder="$placeholder" --header="$prompt"
        else
            gum input --header="$prompt"
        fi
    else
        # Fallback to traditional prompt
        echo "$prompt"
        read -r response
        echo "$response"
    fi
}

# Function to check for existing pull request
check_existing_pr() {
    local current_branch="$1"
    local pr_info=$(gh pr list --head "$current_branch" --json number,title,url 2>/dev/null)
    
    if [ -n "$pr_info" ] && [ "$pr_info" != "[]" ]; then
        # Extract PR details for informative display
        local pr_number=$(echo "$pr_info" | jq -r '.[0].number')
        local pr_title=$(echo "$pr_info" | jq -r '.[0].title')
        local pr_url=$(echo "$pr_info" | jq -r '.[0].url')
        
        echo "ℹ️  Pull request #${pr_number} already exists for branch '$current_branch'"
        echo "   Title: \"$pr_title\""
        echo "   View: gh pr view $pr_number --web"
        echo "   URL: $pr_url"
        return 0  # PR exists
    else
        return 1  # No PR exists
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
        # Have unstaged changes, auto-stage if flag is set or ask user
        if [[ "$auto_stage" == true ]]; then
            echo "Auto-staging all changes..."
            git add -A
            if ! git diff --cached --quiet; then
                staged_diff=$(git diff --cached)
                echo "✅ Changes staged successfully."
            else
                echo "❌ No changes to stage."
                exit 1
            fi
        else
            if use_gum_confirm "Found unstaged changes. Stage all changes?"; then
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
                echo "❌ Auto-commit cancelled. Stage changes manually and try again."
                exit 0
            fi
        fi
    else
        echo "No changes found (staged or unstaged)."
        if use_gum_confirm "Create empty branch anyway?"; then
            manual_branch_name=$(use_gum_input "Enter branch name:" "feature/branch-name")
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
                echo "❌ Auto-commit cancelled. No branch name provided."
                exit 0
            fi
        else
            echo "Staying on '$current_branch' branch."
            echo "❌ Auto-commit cancelled. Create changes and try again."
            exit 0
        fi
    fi
    
    # Now ask about branch creation or auto-create if -b flag is used
    echo ""
    
    if [[ "$auto_branch" == true ]]; then
        echo "Auto-creating new branch..."
        create_branch_response=true
    else
        create_branch_response=$(use_gum_confirm "Create a new branch?")
    fi
    
    if [[ "$create_branch_response" == true ]]; then
        # Generate branch name based on staged changes
        echo "Generating branch name based on staged changes..."
        
        # Get repository context for LLM
        repository_context=$(get_repository_context)
        
        # Create full prompt with embedded diff (like commit message generation)
        branch_name_prompt="Based on the following git diff, generate a concise git branch name following conventional naming patterns (e.g., 'feat/user-login', 'fix/memory-leak', 'docs/api-guide'). Use kebab-case and include a category prefix. Output ONLY the branch name, no explanations or code blocks:"
        
        if [ -n "$repository_context" ]; then
            branch_name_prompt+="

Repository context:
$repository_context"
        fi
        
        if [ -n "$gemini_context" ]; then
            branch_name_prompt+="

Repository context from GEMINI.md:
$gemini_context"
        fi
        
        branch_name_prompt+="

Current staged changes:
$staged_diff"
        
        # Generate branch name with Gemini (using prompt embedding, not pipe)
        generated_branch_name=$(gemini -m gemini-2.5-flash --prompt "$branch_name_prompt" | "${script_dir}/utils/gemini_clean.zsh" | tr -d '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        
        if [ $? -ne 0 ] || [ -z "$generated_branch_name" ]; then
            echo "Failed to generate branch name. Enter manually:"
            read -r manual_branch_name
            generated_branch_name="$manual_branch_name"
        fi
        
        # Branch name confirmation loop (or auto-create if -b flag is used)
        if [[ "$auto_branch" == true ]]; then
            # Auto-create branch without confirmation
            echo ""
            echo "Generated branch name: $generated_branch_name"
            echo ""
            if git switch -c "$generated_branch_name"; then
                echo "✅ Created and switched to branch '$generated_branch_name'"
                echo ""
            else
                echo "❌ Failed to create branch. Exiting."
                exit 1
            fi
        else
            # Interactive confirmation loop
            while true; do
                echo ""
                echo "Generated branch name: $generated_branch_name"
                echo ""
                
                branch_response=$(use_gum_choose "Create branch '$generated_branch_name'?" "Yes" "Edit" "Regenerate" "Quit")
                
                case "$branch_response" in
                    "Yes" )
                        if git switch -c "$generated_branch_name"; then
                            echo "✅ Created and switched to branch '$generated_branch_name'"
                            echo ""
                        else
                            echo "❌ Failed to create branch. Exiting."
                            exit 1
                        fi
                        break
                        ;;
                    "Edit" )
                        manual_branch_name=$(use_gum_input "Enter new branch name:" "$generated_branch_name")
                        if [ -n "$manual_branch_name" ]; then
                            generated_branch_name="$manual_branch_name"
                        fi
                        ;;
                    "Regenerate" )
                        echo "Regenerating branch name..."
                        # Rebuild prompt for regeneration
                        branch_name_prompt="Based on the following git diff, generate a concise git branch name following conventional naming patterns (e.g., 'feat/user-login', 'fix/memory-leak', 'docs/api-guide'). Use kebab-case and include a category prefix. Output ONLY the branch name, no explanations or code blocks:"
                        
                        if [ -n "$repository_context" ]; then
                            branch_name_prompt+="

Repository context:
$repository_context"
                        fi
                        
                        if [ -n "$gemini_context" ]; then
                            branch_name_prompt+="

Repository context from GEMINI.md:
$gemini_context"
                        fi
                        
                        branch_name_prompt+="

Current staged changes:
$staged_diff"
                        
                        generated_branch_name=$(gemini -m gemini-2.5-flash --prompt "$branch_name_prompt" | "${script_dir}/utils/gemini_clean.zsh" | tr -d '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                        if [ $? -ne 0 ] || [ -z "$generated_branch_name" ]; then
                            echo "Failed to regenerate branch name."
                        fi
                        ;;
                    "Quit" )
                        echo "Branch creation cancelled. Staying on '$current_branch'."
                        exit 0
                        ;;
                    * )
                        echo "Branch creation cancelled. Staying on '$current_branch'."
                        exit 0
                        ;;
                esac
            done
        fi
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
    
    # Get repository context for LLM
    repository_context=$(get_repository_context)
    
    user_feedback=""
    last_commit_msg=""
    should_generate=true

    while true; do
        # Create a more focused prompt for the commit message with recent history context
        base_prompt="Based on the following git diff and recent commit history, generate a concise, conventional commit message (e.g., 'feat:', 'fix:', 'docs:', etc.)."
        
        feedback_prompt=""
        if [ -n "$last_commit_msg" ]; then
            feedback_prompt="\n\nThe previous attempt was:\n---\n$last_commit_msg\n---\n\nPlease incorporate the following cumulative feedback to improve the message:\n$user_feedback"
        fi

        optional_prompt="$1"

        full_prompt="$base_prompt$feedback_prompt"
        
        if [ -n "$repository_context" ]; then
            full_prompt+="\n\nRepository context:\n$repository_context"
        fi
        
        if [ -n "$gemini_context" ]; then
            full_prompt+="\n\nRepository context from GEMINI.md:\n$gemini_context"
        fi
        
        full_prompt+="\n\nRecent commits for context:\n$recent_commits\n\nCurrent staged changes:\n$staged_diff\n\n"
        if [ -n "$optional_prompt" ]; then
            full_prompt+="Additional context from user: $optional_prompt\n\n"
        fi
        full_prompt+="Focus on what changed and why, considering the recent development context. IMPORTANT: Start with the commit title on the first line immediately - do NOT wrap the commit message in code blocks (\``` marks). Use a bullet list under the title with dashes (-) for bullet points:"

        if [ "$should_generate" = true ]; then
            echo "Staged files to be shown to Gemini:"
            git diff --name-only --cached

            # Generate the raw commit message from Gemini
            gemini_raw_msg=$(echo "$staged_diff" | gemini -m gemini-2.5-flash --prompt "$full_prompt" | "${script_dir}/utils/gemini_clean.zsh")
            
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
            
            should_generate=false
        fi

        echo "Generated commit message:\n$final_commit_msg"
        echo ""
        
        response=$(use_gum_choose "Accept and commit?" "Yes" "Append text" "Regenerate" "Quit")

        case "$response" in
            "Yes" )
                git commit -m "$final_commit_msg"
                echo "Changes committed successfully!"

                echo ""
                if [[ "$auto_push" == true ]]; then
                    echo "Auto-pushing changes..."
                    push_response=true
                else
                    push_response=$(use_gum_confirm "Do you want to push the changes now?")
                fi

                if [[ "$push_response" == true ]]; then
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
                        
                        # Check for auto_pr.zsh and handle PR creation
                        script_dir="${0:A:h}"
                        if [ -f "${script_dir}/auto_pr.zsh" ]; then
                            # Get current branch for PR check
                            current_branch=$(git branch --show-current)
                            
                            # Only suggest PR creation if not on main/master
                            if [[ "$current_branch" != "main" && "$current_branch" != "master" ]]; then
                                # Check if PR already exists for this branch
                                if check_existing_pr "$current_branch"; then
                                    echo ""
                                else
                                    # No existing PR, proceed with creation
                                    if [[ "$auto_pr" == true ]]; then
                                        echo ""
                                        echo "Creating pull request automatically..."
                                        "${script_dir}/auto_pr.zsh" "$1"
                                    else
                                        echo ""
                                        if use_gum_confirm "Create a pull request?"; then
                                            "${script_dir}/auto_pr.zsh" "$1"
                                        fi
                                    fi
                                fi
                            fi
                        fi
                    else
                        echo "Failed to push changes."
                    fi
                else
                    echo "Push cancelled. You can push manually later with 'git push'."
                fi
                break
                ;;
            "Append text" )
                append_text=$(use_gum_input "Enter text to append:" "Additional details here")
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
                feedback_input=$(use_gum_input "Please provide feedback for improvement:" "Enter your feedback here")
                if [ -n "$feedback_input" ]; then
                    user_feedback+="- $feedback_input\n"
                fi
                echo "Regenerating commit message..."
                should_generate=true
                continue
                ;;
            "Quit" )
                echo "Commit cancelled. You can commit manually with:"
                echo "git commit -m \"$final_commit_msg\""
                break
                ;;
            * )
                echo "Commit cancelled."
                break
                ;;
        esac
    done
else
    if [[ "$auto_stage" == true ]]; then
        echo "No staged changes found. Auto-staging all changes..."
        git add -A
        if ! git diff --cached --quiet; then
            echo "✅ All changes staged successfully."
            # Re-run the script to proceed with commit message generation
            exec "$0" "$@"
        else
            echo "❌ No changes to stage."
            exit 1
        fi
    else
        echo "No staged changes found."
        if use_gum_confirm "Do you want to stage all changes?"; then
            git add .
            echo "All changes staged."
            # Re-run the script to proceed with commit message generation
            exec "$0" "$@"
        else
            echo "No changes staged. Commit cancelled."
            exit 0
        fi
    fi
fi