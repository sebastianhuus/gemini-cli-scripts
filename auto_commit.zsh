#!/usr/bin/env zsh

# Default options
auto_stage=false
auto_pr=false
auto_branch=false
auto_push=false
skip_env_info=false

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
        --skip-env-info)
            skip_env_info=true
            shift
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
    
    if command -v gum &> /dev/null; then
        local result
        if [ -n "$placeholder" ]; then
            result=$(gum input --placeholder="$placeholder" --header="$prompt")
        else
            result=$(gum input --header="$prompt")
        fi
        echo "# $prompt" | gum format >&2
        gum style --faint "> $result" >&2
        echo "$result"
    else
        # Fallback to traditional prompt
        echo "$prompt"
        read -r response
        echo "> $response"
        echo "$response"
    fi
}

# Function to display colored status messages
colored_status() {
    local message="$1"
    local type="$2"  # "success", "error", "info", "cancel"
    
    if command -v gum &> /dev/null; then
        case "$type" in
            "success")
                echo "$(gum style --foreground 2 "⏺") $message"
                ;;
            "error")
                echo "$(gum style --foreground 1 "⏺") $message"
                ;;
            "info"|"cancel")
                echo "$(gum style --foreground 4 "⏺") $message"
                ;;
            *)
                echo "⏺ $message"
                ;;
        esac
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


# Display environment information for user confirmation at start (unless skipped)
if [ "$skip_env_info" != true ]; then
    repo_url=$(git remote get-url origin 2>/dev/null)
    current_branch=$(git branch --show-current 2>/dev/null)

    # Extract repository name from URL
    repo_name=""
    if [ -n "$repo_url" ]; then
        if [[ "$repo_url" =~ github\.com[:/]([^/]+/[^/]+)(\.git)?$ ]]; then
            repo_name="${match[1]}"
        else
            repo_name="$repo_url"
        fi
    fi

    env_info_block="> **Current Working Environment:**"
    env_info_block+=$'\n> 🏗️  Repository: '"$repo_name"
    env_info_block+=$'\n> 🌿 Branch: '"$current_branch"

    # Display using gum format if available, otherwise fallback to echo
    if command -v gum &> /dev/null; then
        echo "$env_info_block" | gum format
        echo "> \\n" | gum format
    else
        echo "$env_info_block"
        echo ""
    fi
fi

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
        colored_status "Found staged changes for branch name generation." "success"
    elif ! git diff --quiet; then
        # Have unstaged changes, auto-stage if flag is set or ask user
        if [[ "$auto_stage" == true ]]; then
            echo ""
            if command -v gum &> /dev/null; then
                echo "**⏺ Auto-staging all changes...**" | gum format
            else
                echo "⏺ Auto-staging all changes..."
            fi
            git add -A
            if ! git diff --cached --quiet; then
                staged_diff=$(git diff --cached)
                colored_status "Changes staged successfully." "success"
            else
                colored_status "No changes to stage." "error"
                exit 1
            fi
        else
            if use_gum_confirm "Found unstaged changes. Stage all changes?"; then
                git add .
                if ! git diff --cached --quiet; then
                    staged_diff=$(git diff --cached)
                    colored_status "Changes staged successfully." "success"
                else
                    colored_status "No changes to stage." "error"
                    exit 1
                fi
            else
                echo "Cannot generate branch name without staged changes."
                echo "Either stage changes first or create branch manually."
                colored_status "Auto-commit cancelled. Stage changes manually and try again." "cancel"
                exit 0
            fi
        fi
    else
        echo "No changes found (staged or unstaged)."
        if use_gum_confirm "Create empty branch anyway?"; then
            manual_branch_name=$(use_gum_input "Enter branch name:" "feature/branch-name")
            if [ -n "$manual_branch_name" ]; then
                if git switch -c "$manual_branch_name"; then
                    echo "⏺ Created and switched to branch '$manual_branch_name'"
                    echo ""
                    exit 0
                else
                    echo "⏺ Failed to create branch. Exiting."
                    exit 1
                fi
            else
                echo "No branch name provided. Staying on '$current_branch'."
                colored_status "Auto-commit cancelled. No branch name provided." "cancel"
                exit 0
            fi
        else
            echo "Staying on '$current_branch' branch."
            colored_status "Auto-commit cancelled. Create changes and try again." "cancel"
            exit 0
        fi
    fi
    
    # Now ask about branch creation or auto-create if -b flag is used
    echo ""
    
    if [[ "$auto_branch" == true ]]; then
        echo "Auto-creating new branch..."
        create_branch=true
    else
        if use_gum_confirm "Create a new branch?"; then
            create_branch=true
        else
            create_branch=false
        fi
    fi
    
    if [[ "$create_branch" == true ]]; then
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
                echo "⏺ Created and switched to branch '$generated_branch_name'"
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
                            echo "⏺ Created and switched to branch '$generated_branch_name'"
                            echo ""
                        else
                            echo "⏺ Failed to create branch. Exiting."
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
                        colored_status "Branch creation cancelled. Staying on '$current_branch'." "cancel"
                        exit 0
                        ;;
                    "Cancelled"|* )
                        colored_status "Branch creation cancelled. Staying on '$current_branch'." "cancel"
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
            # Create the staged files list with markdown formatting
            staged_files=$(git diff --name-only --cached)
            staged_files_block="> **Staged files to be shown to Gemini:**"
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

        # Display generated commit message in quote block format
        commit_msg_header="> **Generated commit message:**"
        commit_msg_content=$(wrap_quote_block_text "$final_commit_msg")
        commit_msg_block="$commit_msg_header"$'\n'"$commit_msg_content"
        
        # Display using gum format if available, otherwise fallback to echo
        if command -v gum &> /dev/null; then
            echo "$commit_msg_block" | gum format
            echo "> \\n" | gum format
        else
            echo "Generated commit message:"
            echo "$final_commit_msg"
            echo ""
        fi
        
        response=$(use_gum_choose "Accept and commit?" "Yes" "Append text" "Regenerate" "Quit")

        case "$response" in
            "Yes" )
                # Capture git commit output
                commit_output=$(git commit -m "$final_commit_msg" 2>&1)
                commit_exit_code=$?
                
                if [ $commit_exit_code -eq 0 ]; then
                    # Display minimalistic commit summary
                    current_branch=$(git branch --show-current)
                    commit_title=$(echo "$final_commit_msg" | head -n 1)
                    
                    # Extract commit hash from git output
                    commit_hash=$(echo "$commit_output" | grep -oE '\[[a-f0-9]{7,}\]' | tr -d '[]' | head -n 1)
                    
                    # Extract file statistics from git output
                    file_stats=$(echo "$commit_output" | grep -E "file.*changed" | head -n 1)
                    
                    echo "git commit ..."
                    echo "[$current_branch $commit_hash]"
                    echo "$commit_title"
                    if [ -n "$file_stats" ]; then
                        echo "$file_stats"
                    fi
                else
                    colored_status "Failed to commit changes." "error"
                    break
                fi

                echo ""
                if [[ "$auto_push" == true ]]; then
                    echo "⏺ Auto-pushing changes..."
                    should_push=true
                else
                    if use_gum_confirm "Do you want to push the changes now?"; then
                        should_push=true
                    else
                        should_push=false
                    fi
                fi

                if [[ "$should_push" == true ]]; then
                    current_branch=$(git branch --show-current)
                    # Check if upstream branch is set
                    local push_output
                    local push_exit_code
                    local push_command
                    if git rev-parse --abbrev-ref --symbolic-full-name @{u} >/dev/null 2>&1; then
                        # Upstream is set, a simple push is enough
                        push_command="git push"
                        push_output=$(git push 2>&1)
                        push_exit_code=$?
                    else
                        # Upstream is not set, so we need to publish the branch
                        echo "No upstream branch found for '$current_branch'. Publishing to 'origin/$current_branch'..."
                        push_command="git push --set-upstream origin \"$current_branch\""
                        push_output=$(git push --set-upstream origin "$current_branch" 2>&1)
                        push_exit_code=$?
                    fi

                    # Display push output in quote block format
                    if [ -n "$push_output" ]; then
                        push_output_header="> **$push_command**"
                        push_output_content=$(wrap_quote_block_text "$push_output")
                        push_output_block="$push_output_header"$'\n>'"$'\n'"$push_output_content""
                        
                        # Display using gum format if available, otherwise fallback to echo
                        if command -v gum &> /dev/null; then
                            echo "$push_output_block" | gum format
                            echo "> \\n" | gum format
                        else
                            echo "$push_output_block"
                        fi
                    fi

                    if [ $push_exit_code -eq 0 ]; then
                        # Display success message in bold using gum format
                        if command -v gum &> /dev/null; then
                            echo "**$(gum style --foreground 2 "⏺") Changes pushed successfully!**" | gum format
                        else
                            colored_status "Changes pushed successfully!" "success"
                        fi
                        
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
                        colored_status "Failed to push changes." "error"
                    fi
                else
                    colored_status "Push cancelled. You can push manually later with 'git push'." "cancel"
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
                colored_status "Commit cancelled. You can commit manually with:" "cancel"
                echo "git commit -m \"$final_commit_msg\""
                break
                ;;
            "Cancelled"|* )
                colored_status "Commit cancelled." "cancel"
                break
                ;;
        esac
    done
else
    if [[ "$auto_stage" == true ]]; then
        echo "No staged changes found."
        echo ""
        if command -v gum &> /dev/null; then
            echo "**⏺ Auto-staging all changes...**" | gum format
        else
            echo "⏺ Auto-staging all changes..."
        fi
        git add -A
        if ! git diff --cached --quiet; then
            colored_status "All changes staged successfully." "success"
            # Re-run the script to proceed with commit message generation
            exec "$0" "$@" --skip-env-info
        else
            echo "⏺ No changes to stage."
            exit 1
        fi
    else
        echo "No staged changes found."
        if use_gum_confirm "Do you want to stage all changes?"; then
            git add .
            if command -v gum &> /dev/null; then
                echo "**$(gum style --foreground 2 "⏺") All changes staged.**" | gum format
            else
                colored_status "All changes staged." "success"
            fi
            echo ""
            # Re-run the script to proceed with commit message generation
            exec "$0" "$@" --skip-env-info
        else
            colored_status "No changes staged. Commit cancelled." "cancel"
            exit 0
        fi
    fi
fi