#!/usr/bin/env zsh

# Get script directory early for configuration loading
script_dir="$(dirname "${0:A}")"

# Load configuration system
source "${script_dir}/config/config_loader.zsh"
load_gemini_config "$script_dir"

# Set default options from configuration (can be overridden by command-line flags)
auto_stage=$(is_config_true "$CONFIG_AUTO_STAGE" && echo true || echo false)
auto_pr=$(is_config_true "$CONFIG_AUTO_PR" && echo true || echo false)
auto_branch=$(is_config_true "$CONFIG_AUTO_BRANCH" && echo true || echo false)
auto_push=$(is_config_true "$CONFIG_AUTO_PUSH" && echo true || echo false)
skip_env_info=$(is_config_true "$CONFIG_SKIP_ENV_INFO" && echo true || echo false)
no_branch=false

# Usage function
usage() {
    echo "Usage: $0 [-s|--stage] [-b|--branch] [--no-branch] [-pr|--pr] [-p|--push] [optional_context]"
    echo ""
    echo "Options:"
    echo "  -s, --stage      Automatically stage all changes before generating commit"
    echo "  -b, --branch     Automatically create new branch without confirmation"
    echo "  --no-branch      Skip branch creation and commit directly to current branch"
    echo "  -pr, --pr        Automatically create pull request after successful commit"
    echo "  -p, --push       Automatically push changes after successful commit"
    echo "  -h, --help       Show this help message"
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
        --no-branch)
            no_branch=true
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
            colored_status "Unknown option: $1" "error"
            usage
            exit 1
            ;;
        *)
            # First non-option argument is the optional context
            if [ -z "$optional_context" ]; then
                optional_context="$1"
            fi
            shift
            ;;
    esac
done

# Load shared gum helper functions early for validation
source "${script_dir}/gum/gum_helpers.zsh"

# Validate flag compatibility
if [[ "$no_branch" == true && "$auto_branch" == true ]]; then
    colored_status "Error: --no-branch and -b/--branch flags are incompatible" "error"
    echo "Use --no-branch to commit to current branch, or -b/--branch to auto-create new branch"
    exit 1
fi

# Load context utility if available  
gemini_context=""
if [ -f "${script_dir}/utils/core/gemini_context.zsh" ]; then
    source "${script_dir}/utils/core/gemini_context.zsh"
    gemini_context=$(load_gemini_context "${script_dir}")
fi

# Load commit message generator utility
source "${script_dir}/utils/generators/commit_message_generator.zsh"

# Load shared git push helper functions
source "${script_dir}/utils/git/git_push_helpers.zsh"

# Load PR display utility
source "${script_dir}/utils/ui/pr_display.zsh"

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


# Function to check for existing pull request and detect new commits
check_existing_pr() {
    local current_branch="$1"
    local pr_info=$(gh pr list --head "$current_branch" --json number,title,url 2>/dev/null)
    
    if [ -n "$pr_info" ] && [ "$pr_info" != "[]" ]; then
        # Extract PR details for informative display
        local pr_number=$(echo "$pr_info" | jq -r '.[0].number')
        local pr_title=$(echo "$pr_info" | jq -r '.[0].title')
        local pr_url=$(echo "$pr_info" | jq -r '.[0].url')
        
        colored_status "Pull request #${pr_number} already exists for branch '$current_branch'" "info"
        echo "  ⎿ Title: \"$pr_title\""
        echo "     View: gh pr view $pr_number --web"
        echo "     URL: $pr_url"
        
        # Check for new commits since PR creation by comparing with remote
        local remote_branch="origin/$current_branch"
        
        # Fetch latest to ensure we have current remote state
        git fetch origin "$current_branch" 2>/dev/null
        
        # Check if local is ahead of remote (has unpushed commits)
        local unpushed_commits=$(git rev-list ${remote_branch}..HEAD --count 2>/dev/null)
        
        if [ "$unpushed_commits" -gt 0 ]; then
            echo ""
            colored_status "Found $unpushed_commits new commit(s) to push:" "info"
            git log ${remote_branch}..HEAD --oneline --no-merges | sed 's/^/  • /'
            
            # Export PR number for use by calling function
            export EXISTING_PR_NUMBER="$pr_number"
            return 2  # PR exists with new commits
        else
            return 0  # PR exists, no new commits
        fi
    else
        return 1  # No PR exists
    fi
}

# Function to update existing pull request with new commits
update_existing_pr() {
    local current_branch="$1"
    local optional_context="$2"
    local pr_number="$EXISTING_PR_NUMBER"
    
    echo ""
    local update_choice=$(use_gum_choose "Update existing PR #${pr_number} with new commits?" "Yes" "View PR" "Skip")
    
    case "$update_choice" in
        "Yes" )
            colored_status "Generating updated PR content..." "info"
            
            # Get ALL commits for this PR (from main/master to current branch)
            local base_branch="main"
            if ! git show-ref --verify --quiet refs/heads/main; then
                base_branch="master"
            fi
            local all_pr_commits=$(git log ${base_branch}..HEAD --pretty=format:"%h - %s%n%b" --no-merges)
            
            # Get existing PR content using Python for robust JSON parsing
            local existing_title=""
            local existing_body=""
            local pr_content=$(gh pr view "$pr_number" --json title,body 2>/dev/null | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    title = data.get('title', '').replace('\n', '\\n')
    body = data.get('body', '').replace('\n', '\\n')
    print(f'TITLE:{title}')
    print(f'BODY:{body}')
except Exception:
    print('TITLE:')
    print('BODY:')
" 2>/dev/null)
            
            if [ -n "$pr_content" ]; then
                existing_title=$(echo "$pr_content" | grep '^TITLE:' | sed 's/^TITLE://' | sed 's/\\n/\n/g')
                existing_body=$(echo "$pr_content" | grep '^BODY:' | sed 's/^BODY://' | sed 's/\\n/\n/g')
            fi
            
            # Get repository context
            local repository_context=$(get_repository_context)
            
            # Load PR content generator if available
            if [ -f "${script_dir}/utils/generators/pr_content_generator.zsh" ]; then
                source "${script_dir}/utils/generators/pr_content_generator.zsh"
                
                # Generate updated PR content using all commits and existing content
                local updated_content=$(generate_pr_update_content "$pr_number" "$optional_context" "$all_pr_commits" "$gemini_context" "$script_dir" "" "$existing_title" "$existing_body")
                
                if [ $? -eq 0 ] && [ -n "$updated_content" ]; then
                    # Parse TITLE: and BODY: from LLM response
                    local new_title=$(echo "$updated_content" | grep "^TITLE:" | sed 's/^TITLE: *//' | head -n 1)
                    local new_body=$(echo "$updated_content" | sed -n '/^BODY: */,$p' | sed '1s/^BODY: *//' | sed '$d' 2>/dev/null || echo "$updated_content" | sed -n '/^BODY: */,$p' | sed '1s/^BODY: *//')
                    
                    # Build the gh pr edit command ourselves with the correct PR number
                    local pr_edit_command="gh pr edit $pr_number --title \"$new_title\" --body \"$new_body\""
                    
                    # Interactive loop for PR update confirmation
                    while true; do
                        
                        # Display the updated PR content using utility function
                        display_pr_content "$new_title" "$new_body"
                        
                        local confirm_choice=$(use_gum_choose "Update PR with this content?" "Yes" "Regenerate with feedback" "Skip")
                        
                        case "$confirm_choice" in
                            "Yes" )
                                # Push new commits first
                                colored_status "Pushing new commits..." "info"
                                if simple_push_with_display "$current_branch"; then
                                    # Execute the generated PR edit command
                                    if command -v gh &> /dev/null; then
                                        # Execute the command (similar to auto_pr.zsh pattern)
                                        escaped_command=$(echo "$pr_edit_command" | sed 's/`/\\`/g')
                                        eval "$escaped_command"
                                        
                                        if [ $? -eq 0 ]; then
                                            colored_status "PR #${pr_number} updated successfully!" "success"
                                            echo "  ⎿ View updated PR: gh pr view $pr_number --web"
                                            return 0
                                        else
                                            colored_status "Failed to update PR #${pr_number}" "error"
                                            return 1
                                        fi
                                    else
                                        colored_status "GitHub CLI (gh) not found" "error"
                                        return 1
                                    fi
                                else
                                    colored_status "Failed to push new commits" "error"
                                    return 1
                                fi
                                ;;
                            "Regenerate with feedback" )
                                local feedback=$(use_gum_input "What specific feedback would you like to incorporate?" "Enter feedback or leave empty")
                                colored_status "Regenerating PR content..." "info"
                                updated_content=$(generate_pr_update_content "$pr_number" "$optional_context" "$all_pr_commits" "$gemini_context" "$script_dir" "$feedback" "$existing_title" "$existing_body")
                                if [ $? -ne 0 ] || [ -z "$updated_content" ]; then
                                    colored_status "Failed to regenerate PR content" "error"
                                fi
                                ;;
                            "Skip"|* )
                                colored_status "PR update cancelled" "cancel"
                                return 0
                                ;;
                        esac
                    done
                else
                    colored_status "Failed to generate updated PR content" "error"
                    return 1
                fi
            else
                colored_status "PR content generator not found" "error"
                return 1
            fi
            ;;
        "View PR" )
            gh pr view "$pr_number" --web
            return 0
            ;;
        "Skip"|* )
            colored_status "PR update skipped" "cancel"
            return 0
            ;;
    esac
}

# Function to determine if we should push automatically or ask for confirmation
should_auto_push() {
    local context_message="${1:-Do you want to push the changes now?}"
    
    if [[ "$auto_push" == true ]]; then
        return 0  # Yes, push automatically (no message, no interaction)
    else
        if use_gum_confirm "$context_message"; then
            return 0  # Yes, user confirmed
        else
            return 1  # No, user declined
        fi
    fi
}

# Function to check for unpushed commits
check_unpushed_commits() {
    local current_branch=$(git branch --show-current)
    
    # Check if upstream branch is set
    if ! git rev-parse --abbrev-ref --symbolic-full-name @{u} >/dev/null 2>&1; then
        # No upstream branch set
        return 1
    fi
    
    # Count unpushed commits
    local unpushed_count=$(git rev-list @{u}..HEAD --count 2>/dev/null)
    
    if [ $? -ne 0 ] || [ -z "$unpushed_count" ]; then
        # Error getting unpushed commits (possibly no remote)
        return 1
    fi
    
    if [ "$unpushed_count" -gt 0 ]; then
        # Display unpushed commits info
        colored_status "Found $unpushed_count unpushed commit(s) on branch '$current_branch'." "info"
        
        # Show recent unpushed commits (first line only)
        echo "Recent unpushed commits:"
        git log @{u}..HEAD --no-merges -5 --pretty=format:"  • %h %f" | sed 's/-/ /g'
        echo ""
        
        return 0  # Has unpushed commits
    else
        return 1  # No unpushed commits
    fi
}


# Display environment information for user confirmation at start (unless skipped)
if [ "$skip_env_info" != true ]; then
    # Use the reusable environment display utility
    source "${script_dir}/gum/env_display.zsh"
    display_env_info
fi

# Check if we're on main/master branch and handle staging/branch creation
current_branch=$(git branch --show-current)
if [[ "$current_branch" == "main" || "$current_branch" == "master" ]] && [[ "$no_branch" != true ]]; then
    # First, handle staging if needed
    staged_diff=""
    if ! git diff --cached --quiet; then
        # Already have staged changes
        staged_diff=$(git diff --cached)
        colored_status "Found staged changes for branch name generation." "success"
    elif [ -n "$(git status --porcelain)" ]; then
        # Have unstaged changes, auto-stage if flag is set or ask user
        if [[ "$auto_stage" == true ]]; then
            echo ""
            colored_status "Auto-staging all changes..." "info"
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
                git add -A
                if ! git diff --cached --quiet; then
                    staged_diff=$(git diff --cached)
                    colored_status "Changes staged successfully." "success"
                else
                    colored_status "No changes to stage." "error"
                    exit 1
                fi
            else
                colored_status "Cannot generate branch name without staged changes." "info"
                colored_status "Either stage changes first or create branch manually." "info"
                colored_status "Auto-commit cancelled. Stage changes manually and try again." "cancel"
                exit 0
            fi
        fi
    else
        colored_status "No changes found (staged or unstaged)." "info"
        if use_gum_confirm "Create empty branch anyway?"; then
            manual_branch_name=$(use_gum_input "Enter branch name:" "feature/branch-name")
            if [ -n "$manual_branch_name" ]; then
                if git switch -c "$manual_branch_name"; then
                    colored_status "Created and switched to branch '$manual_branch_name'" "info"
                    echo ""
                    exit 0
                else
                    colored_status "Failed to create branch. Exiting." "error"
                    exit 1
                fi
            else
                colored_status "No branch name provided. Staying on '$current_branch'." "info"
                colored_status "Auto-commit cancelled. No branch name provided." "cancel"
                exit 0
            fi
        else
            colored_status "Staying on '$current_branch' branch." "info"
            colored_status "Auto-commit cancelled. Create changes and try again." "cancel"
            exit 0
        fi
    fi
    
    # Now ask about branch creation or auto-create if -b flag is used
    echo ""
    
    if [[ "$auto_branch" == true ]]; then
        colored_status "Auto-creating new branch..." "info"
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
        colored_status "Generating branch name based on staged changes..." "info"
        
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
        generated_branch_name=$(gemini -m "$(get_gemini_model)" --prompt "$branch_name_prompt" | "${script_dir}/utils/core/gemini_clean.zsh" | tr -d '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        
        if [ $? -ne 0 ] || [ -z "$generated_branch_name" ]; then
            colored_status "Failed to generate branch name. Enter manually:" "info"
            read -r manual_branch_name
            generated_branch_name="$manual_branch_name"
        fi
        
        # Branch name confirmation loop (or auto-create if -b flag is used)
        if [[ "$auto_branch" == true ]]; then
            # Auto-create branch without confirmation
            echo ""
            colored_status "Generated branch name: $generated_branch_name" "info"
            if git switch -c "$generated_branch_name"; then
                colored_status "Created and switched to branch '$generated_branch_name'" "info"
                echo ""
            else
                colored_status "Failed to create branch. Exiting." "error"
                exit 1
            fi
        else
            # Interactive confirmation loop
            while true; do
                echo ""
                colored_status "Generated branch name: $generated_branch_name" "info"
                echo ""
                
                branch_response=$(use_gum_choose "Create branch '$generated_branch_name'?" "Yes" "Edit" "Regenerate" "Quit")
                
                case "$branch_response" in
                    "Yes" )
                        if git switch -c "$generated_branch_name"; then
                            colored_status "Created and switched to branch '$generated_branch_name'" "info"
                            echo ""
                        else
                            colored_status "Failed to create branch. Exiting." "error"
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
                        colored_status "Regenerating branch name..." "info"
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
                        
                        generated_branch_name=$(gemini -m "$(get_gemini_model)" --prompt "$branch_name_prompt" | "${script_dir}/utils/core/gemini_clean.zsh" | tr -d '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                        if [ $? -ne 0 ] || [ -z "$generated_branch_name" ]; then
                            colored_status "Failed to regenerate branch name." "error"
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
        colored_status "Continuing on '$current_branch' branch." "info"
        echo ""
    fi
elif [[ "$current_branch" == "main" || "$current_branch" == "master" ]] && [[ "$no_branch" == true ]]; then
    # Handle --no-branch on main/master: just handle staging, skip branch creation
    colored_status "Using --no-branch flag: will commit directly to '$current_branch' branch." "info"
    
    # Handle staging if needed (same logic as branch creation case)
    if ! git diff --cached --quiet; then
        # Already have staged changes
        colored_status "Found staged changes for commit generation." "success"
    elif [ -n "$(git status --porcelain)" ]; then
        # Have unstaged changes, auto-stage if flag is set or ask user
        if [[ "$auto_stage" == true ]]; then
            echo ""
            colored_status "Auto-staging all changes..." "info"
            git add -A
            if ! git diff --cached --quiet; then
                colored_status "Changes staged successfully." "success"
            else
                colored_status "No changes to stage." "error"
                exit 1
            fi
        else
            if use_gum_confirm "Found unstaged changes. Stage all changes?"; then
                git add -A
                if ! git diff --cached --quiet; then
                    colored_status "Changes staged successfully." "success"
                else
                    colored_status "No changes to stage." "error"
                    exit 1
                fi
            else
                colored_status "Cannot generate commit without staged changes." "info"
                colored_status "Auto-commit cancelled. Stage changes manually and try again." "cancel"
                exit 0
            fi
        fi
    else
        colored_status "No changes found (staged or unstaged)." "info"
        colored_status "Auto-commit cancelled. No changes to commit." "cancel"
        exit 0
    fi
    
    # Add confirmation for safety when committing to main/master directly
    if [[ "$auto_stage" != true && "$auto_push" != true ]]; then
        echo ""
        if ! use_gum_confirm "Commit directly to '$current_branch' branch?"; then
            # Unstage changes if user cancels
            if git reset HEAD >/dev/null 2>&1; then
                colored_status "Commit cancelled. All staged changes have been unstaged." "cancel"
            else
                colored_status "Commit cancelled. Warning: Failed to unstage changes." "error"
            fi
            exit 0
        fi
    fi
    echo ""
fi

# Check if there are staged changes
if ! git diff --cached --quiet; then
    
    # Get the diff for context
    staged_diff=$(git diff --cached)
    
    # Get recent commit history for context
    recent_commits=$(git log --oneline --no-merges -5)
    
    # Get repository context for LLM
    repository_context=$(get_repository_context)
    
    # Generate commit message using the utility function
    generate_commit_message "$staged_diff" "$recent_commits" "$repository_context" "$gemini_context" "$1" "$script_dir"
    commit_generator_exit_code=$?
    
    case $commit_generator_exit_code in
        0)
            # Commit message generated successfully, get it from the global variable
            final_commit_msg="$GENERATED_COMMIT_MESSAGE"
            
            # Capture git commit output
            commit_output=$(git commit -m "$final_commit_msg" 2>&1)
            commit_exit_code=$?
            
            if [ $commit_exit_code -eq 0 ]; then
                # Display minimalistic commit summary
                current_branch=$(git branch --show-current)
                commit_title=$(echo "$final_commit_msg" | head -n 1)
                
                # Extract commit hash from git output
                commit_hash=$(echo "$commit_output" | grep -oE '\[[A-Fa-f0-9]{7,}\]' | tr -d '[]' | head -n 1)
                if [ -z "$commit_hash" ]; then
                    # Fallback: extract any 7+ character hex string
                    commit_hash=$(echo "$commit_output" | grep -oE '[A-Fa-f0-9]{7,}' | head -n 1)
                fi
                
                # Extract file statistics from git output
                file_stats=$(echo "$commit_output" | grep -E "file.*changed" | head -n 1)
                
                colored_status "Commit successful:" "success"
                echo "  ⎿ [$current_branch $commit_hash] $file_stats"
                echo "     $commit_title"
            else
                colored_status "Failed to commit changes." "error"
                exit 1
            fi

            echo ""
            echo "=== DEBUG AUTO-PUSH ==="
            echo "auto_push value: '$auto_push'"
            echo "auto_push length: ${#auto_push}"
            echo "auto_push chars: $(echo -n "$auto_push" | od -c)"
            if [[ "$auto_push" == "true" ]]; then
                echo "Conditional test: TRUE"
            else
                echo "Conditional test: FALSE"
            fi
            echo "======================="
            
            if [[ "$auto_push" == true ]]; then
                colored_status "Auto-pushing changes..." "info"
                should_push=true
                echo "DEBUG: Took auto-push branch"
            else
                echo "DEBUG: Took manual confirmation branch"
                if should_auto_push "Do you want to push the changes now?"; then
                    should_push=true
                else
                    should_push=false
                fi
            fi

            if [[ "$should_push" == true ]]; then
                current_branch=$(git branch --show-current)
                
                # Use shared smart push function
                if simple_push_with_display "$current_branch"; then
                    # Display success message
                    colored_status "Changes pushed successfully!" "success"
                    
                    # Check for auto_pr.zsh and handle PR creation
                    script_dir="${0:A:h}"
                    if [ -f "${script_dir}/auto_pr.zsh" ]; then
                        # Get current branch for PR check
                        current_branch=$(git branch --show-current)
                        
                        # Only suggest PR creation if not on main/master
                        if [[ "$current_branch" != "main" && "$current_branch" != "master" ]]; then
                            # Check if PR already exists for this branch
                            check_existing_pr "$current_branch"
                            pr_check_result=$?
                            
                            case $pr_check_result in
                                0|2)
                                    # PR exists - offer to update since we just pushed new commits
                                    if [[ "$auto_pr" == true ]]; then
                                        echo ""
                                        colored_status "Updating existing pull request automatically..." "info"
                                        update_existing_pr "$current_branch" "$1"
                                    else
                                        update_existing_pr "$current_branch" "$1"
                                    fi
                                    ;;
                                1)
                                    # No existing PR, proceed with creation
                                    if [[ "$auto_pr" == true ]]; then
                                        echo ""
                                        colored_status "Creating pull request automatically..." "info"
                                        "${script_dir}/auto_pr.zsh" "$1"
                                    else
                                        echo ""
                                        pr_choice=$(use_gum_choose "Create a pull request?" "Yes" "Yes with comment" "No")
                                        case "$pr_choice" in
                                            "Yes" )
                                                "${script_dir}/auto_pr.zsh" "$1"
                                                ;;
                                            "Yes with comment" )
                                                pr_comment=$(use_gum_input "Enter additional context for PR generation:" "Additional context or requirements")
                                                # Combine original context with new comment
                                                combined_context="$1"
                                                if [ -n "$pr_comment" ]; then
                                                    if [ -n "$combined_context" ]; then
                                                        combined_context="$combined_context. $pr_comment"
                                                    else
                                                        combined_context="$pr_comment"
                                                    fi
                                                fi
                                                "${script_dir}/auto_pr.zsh" "$combined_context"
                                                ;;
                                            "No"|* )
                                                # Do nothing - no PR creation
                                                ;;
                                        esac
                                    fi
                                    ;;
                            esac
                        fi
                    fi
                else
                    colored_status "Failed to push changes." "error"
                fi
            else
                colored_status "Push cancelled. You can push manually later with 'git push'." "cancel"
            fi
            ;;
        1)
            # Generation failed
            colored_status "Failed to generate commit message. Please commit manually." "error"
            exit 1
            ;;
        2)
            # User cancelled or quit
            # Unstage all staged changes before exiting
            if git reset HEAD >/dev/null 2>&1; then
                colored_status "Commit cancelled. All staged changes have been unstaged." "cancel"
            else
                colored_status "Commit cancelled. Warning: Failed to unstage changes." "error"
            fi
            colored_status "You can manually stage and commit later if needed." "info"
            exit 0
            ;;
        *)
            # Unknown exit code
            colored_status "Unexpected error in commit generation." "error"
            exit 1
            ;;
    esac
else
    if [[ "$auto_stage" == true ]]; then
        colored_status "No staged changes found." "info"
        colored_status "Auto-staging all changes..." "info"
        git add -A
        if ! git diff --cached --quiet; then
            colored_status "All changes staged successfully." "success"
            # Re-run the script to proceed with commit message generation
            exec "$0" "$@" --skip-env-info
        else
            colored_status "No changes to stage." "error"
            
            # Check for unpushed commits before exiting
            if check_unpushed_commits; then
                if [[ "$auto_push" == true ]]; then
                    colored_status "Auto-pushing unpushed commits..." "info"
                    should_push_unpushed=true
                else
                    if should_auto_push "Do you want to push these unpushed commits now?"; then
                        should_push_unpushed=true
                    else
                        should_push_unpushed=false
                    fi
                fi
                
                if [[ "$should_push_unpushed" == true ]]; then
                    current_branch=$(git branch --show-current)
                    
                    # Use shared smart push function with exit on failure
                    if simple_push_with_display "$current_branch"; then
                        # Display success message
                        colored_status "Changes pushed successfully!" "success"
                        exit 0
                    else
                        colored_status "Failed to push changes." "error"
                        exit 1
                    fi
                else
                    colored_status "Push cancelled. You can push manually later with 'git push'." "cancel"
                    exit 0
                fi
            fi
            
            exit 1
        fi
    else
        colored_status "No staged changes found." "info"
        
        # First check if there are any unstaged changes
        if [ -n "$(git status --porcelain)" ]; then
            # Has unstaged changes - offer to stage them
            if use_gum_confirm "Do you want to stage all changes?"; then
                git add -A
                colored_status "All changes staged." "success"
                # Re-run the script to proceed with commit message generation
                exec "$0" "$@" --skip-env-info
            else
                colored_status "No changes staged. Commit cancelled." "cancel"
                
                # Check for unpushed commits before exiting
                if check_unpushed_commits; then
                    if [[ "$auto_push" == true ]]; then
                        colored_status "Auto-pushing unpushed commits..." "info"
                        should_push_unpushed=true
                    else
                        if should_auto_push "Do you want to push these unpushed commits now?"; then
                            should_push_unpushed=true
                        else
                            should_push_unpushed=false
                        fi
                    fi
                    
                    if [[ "$should_push_unpushed" == true ]]; then
                        current_branch=$(git branch --show-current)
                        
                        # Use shared smart push function
                        if simple_push_with_display "$current_branch"; then
                            # Display success message
                            colored_status "Changes pushed successfully!" "success"
                        else
                            colored_status "Failed to push changes." "error"
                        fi
                    else
                        colored_status "Push cancelled. You can push manually later with 'git push'." "cancel"
                    fi
                fi
                
                exit 0
            fi
        else
            # No unstaged changes either - go directly to unpushed commits check
            colored_status "No unstaged changes found either." "info"
            
            # Check for unpushed commits before exiting
            if check_unpushed_commits; then
                if [[ "$auto_push" == true ]]; then
                    colored_status "Auto-pushing unpushed commits..." "info"
                    should_push_unpushed=true
                else
                    if should_auto_push "Do you want to push these unpushed commits now?"; then
                        should_push_unpushed=true
                    else
                        should_push_unpushed=false
                    fi
                fi
                
                if [[ "$should_push_unpushed" == true ]]; then
                    current_branch=$(git branch --show-current)
                    
                    # Use shared smart push function
                    if simple_push_with_display "$current_branch"; then
                        # Display success message
                        colored_status "Changes pushed successfully!" "success"
                    else
                        colored_status "Failed to push changes." "error"
                    fi
                else
                    colored_status "Push cancelled. You can push manually later with 'git push'." "cancel"
                fi
            fi
            
            exit 0
        fi
    fi
fi