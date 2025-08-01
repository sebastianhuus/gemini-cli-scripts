#!/usr/bin/env zsh

# Get script directory early for configuration loading
script_dir="$(dirname "${0:A}")"

# Load configuration system
source "${script_dir}/config/config_loader.zsh"
load_gemini_config "$script_dir"

# Load context utility if available
gemini_context=""
if [ -f "${script_dir}/utils/core/gemini_context.zsh" ]; then
    source "${script_dir}/utils/core/gemini_context.zsh"
    gemini_context=$(load_gemini_context "${script_dir}")
fi

# Load shared gum helper functions
if [ -f "${script_dir}/gum/gum_helpers.zsh" ]; then
    source "${script_dir}/gum/gum_helpers.zsh"
else
    echo "Error: Required gum helper functions not found at ${script_dir}/gum/gum_helpers.zsh"
    exit 1
fi

# Load shared git push helper functions
if [ -f "${script_dir}/utils/git/git_push_helpers.zsh" ]; then
    source "${script_dir}/utils/git/git_push_helpers.zsh"
else
    echo "Error: Required git push helper functions not found at ${script_dir}/utils/git/git_push_helpers.zsh"
    exit 1
fi

# Load PR content generator utility
if [ -f "${script_dir}/utils/generators/pr_content_generator.zsh" ]; then
    source "${script_dir}/utils/generators/pr_content_generator.zsh"
else
    echo "Error: Required PR content generator utility not found at ${script_dir}/utils/generators/pr_content_generator.zsh"
    exit 1
fi

# Load shared command extraction utility
if [ -f "${script_dir}/utils/git/gh_command_extraction.zsh" ]; then
    source "${script_dir}/utils/git/gh_command_extraction.zsh"
else
    echo "Error: Required command extraction utility not found at ${script_dir}/utils/git/gh_command_extraction.zsh"
    exit 1
fi

# Load PR display utility
if [ -f "${script_dir}/utils/ui/pr_display.zsh" ]; then
    source "${script_dir}/utils/ui/pr_display.zsh"
else
    echo "Error: Required PR display utility not found at ${script_dir}/utils/ui/pr_display.zsh"
    exit 1
fi


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


# Get script name for usage display
SCRIPT_NAME="$(basename "${0}")"

# Usage function
usage() {
    echo "Usage: $SCRIPT_NAME [--dry-run] [optional_context]"
    echo ""
    echo "Options:"
    echo "  --dry-run        Show what would be executed without making changes"
    echo "  -h, --help       Show this help message"
    echo ""
    echo "Arguments:"
    echo "  optional_context    Additional context for PR content generation"
}

# Initialize flags
dry_run=false
optional_prompt=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            dry_run=true
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
            # Assume it's the optional prompt
            optional_prompt="$1"
            shift
            ;;
    esac
done

# Load and display repository information using the reusable utility
source "${script_dir}/gum/env_display.zsh"
display_env_info

# Get current branch name
current_branch=$(git branch --show-current)

# Check if we're not on main/master
if [[ "$current_branch" == "main" || "$current_branch" == "master" ]]; then
    echo "Cannot create PR from main/master branch."
    exit 1
fi

# Check if PR already exists for this branch
if check_existing_pr "$current_branch"; then
    echo ""
    echo "Skipping PR creation since one already exists."
    exit 0
fi

# Check if main branch exists, otherwise use master
if git show-ref --verify --quiet refs/heads/main; then
    base_branch="main"
elif git show-ref --verify --quiet refs/heads/master; then
    base_branch="master"
else
    echo "Neither 'main' nor 'master' branch found."
    exit 1
fi

# Get commits that are in current branch but not in main/master
commits=$(git log $base_branch..$current_branch --oneline)

if [ -z "$commits" ]; then
    echo "No new commits found between $current_branch and $base_branch."
    exit 1
fi

# Display commits using the same pattern as auto_commit.zsh
colored_status "Found commits to include in PR:" "info"
git log $base_branch..$current_branch --no-merges --pretty=format:"     • %h %f" | sed 's/-/ /g'
echo ""

# Get detailed commit information for better context
commit_details=$(git log $base_branch..$current_branch --pretty=format:"%h - %s%n%b" --no-merges)



# Generate initial PR content
pr_content_raw=$(generate_pr_content "$optional_prompt" "$commit_details" "$gemini_context" "$script_dir")


if [ $? -eq 0 ] && [ -n "$pr_content_raw" ]; then
    # Interactive loop for PR content confirmation and regeneration
    while true; do
        # The LLM now generates a complete gh pr create command
        pr_create_command="$pr_content_raw"

        # Extract title and body from the generated command
        local pr_title=$(extract_gh_title "$pr_create_command")
        local pr_body=$(extract_gh_body "$pr_create_command")

        echo ""
        if command -v gum &> /dev/null;then
            echo "**Generated PR content:**" | gum format
        else
            echo "Generated PR content:"
        fi
        
        # Display the extracted PR content using the PR display utility
        if [ -n "$pr_title" ] && [ -n "$pr_body" ]; then
            display_pr_content "$pr_title" "$pr_body"
        else
            # Fallback: show raw command when extraction fails
            echo "Generated PR create command:"
            if command -v gum &> /dev/null; then
                echo "$pr_create_command" | gum format -t "code" -l "zsh"
            else
                echo "$pr_create_command"
            fi
        fi

        response=$(use_gum_choose "--dry-run=$dry_run" "Create PR with this command?" "Yes" "Regenerate with feedback" "Quit")
        
        case "$response" in
            "Yes" )
                # Push current branch to remote
                colored_status "Pushing current branch to remote..." "info"
                
                # Use shared push function (force upstream for PR creation)
                if ! dry_run_execute "--dry-run=$dry_run" "push branch to remote" "pr_push_with_display \"$current_branch\""; then
                    # Push failed, break out of loop to prevent PR creation
                    break
                fi
                
                # Create PR using the generated command
                if command -v gh &> /dev/null; then
                    # Add the base and head parameters to the generated command
                    enhanced_command="$pr_create_command --base \"$base_branch\" --head \"$current_branch\""
                    
                    # Always show the command for transparency
                    colored_status "🔍 Executing PR command:" "info" 
                    echo "$enhanced_command" | gum format -t "code" -l "zsh"
                    
                    # Execute the command with dry-run protection
                    escaped_command=$(echo "$enhanced_command" | sed 's/`/\\`/g')
                    if dry_run_execute "--dry-run=$dry_run" "create pull request" "$escaped_command"; then
                        echo "Pull request created successfully!"
                    else
                        echo "Failed to create pull request."
                        break
                    fi
                    
                    # Prompt to switch to main and pull latest changes
                    if use_gum_confirm "--dry-run=$dry_run" "Do you want to switch to $base_branch and pull latest changes?" true; then
                        echo "Switching to $base_branch and pulling latest changes..."
                        if dry_run_execute "--dry-run=$dry_run" "switch branches and pull" "git switch \"$base_branch\" && git pull"; then
                            echo "Successfully updated $base_branch branch!"
                        else
                            echo "Error: Failed to switch to $base_branch or pull latest changes."
                        fi
                    else
                        echo "Skipping branch switch and pull."
                    fi
                else
                    echo "GitHub CLI (gh) not found. Please install it or create the PR manually."
                    echo "Generated command: $pr_create_command"
                    echo "Base: $base_branch"
                    echo "Head: $current_branch"
                fi
                break
                ;;
            "Regenerate with feedback" )
                feedback=$(use_gum_input "What specific feedback would you like to incorporate?" "Enter feedback or leave empty")
                echo "Regenerating PR content..."
                pr_content_raw=$(generate_pr_content "$optional_prompt" "$commit_details" "$gemini_context" "$script_dir" "$feedback")
                if [ $? -ne 0 ] || [ -z "$pr_content_raw" ]; then
                    echo "Failed to regenerate PR content. Please try again."
                fi
                ;;
            "Quit" )
                echo "PR creation cancelled. You can create it manually with:"
                echo "$pr_create_command --base \"$base_branch\" --head \"$current_branch\""
                exit 0
                ;;
            * )
                echo "PR creation cancelled."
                exit 0
                ;;
        esac
    done
else
    echo "Failed to generate PR content. Please create PR manually."
    exit 1
fi