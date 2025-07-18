#!/usr/bin/env zsh

# Load context utility if available
script_dir="${0:A:h}"
gemini_context=""
if [ -f "${script_dir}/utils/gemini_context.zsh" ]; then
    source "${script_dir}/utils/gemini_context.zsh"
    gemini_context=$(load_gemini_context)
fi

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
        local result
        result=$(gum choose --header="$prompt" "${options[@]}")
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

# Display repository information
display_repository_info

# Get optional prompt argument
optional_prompt="$1"

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

echo "Found commits to include in PR:"
echo "$commits"
echo ""

# Get detailed commit information for better context
commit_details=$(git log $base_branch..$current_branch --pretty=format:"%h - %s%n%b" --no-merges)


# Function to generate PR content using Gemini
generate_pr_content() {
    local feedback_prompt="$1"
    
    local base_prompt="${optional_prompt} Based on the following git commit history, generate a complete gh pr create command. Ensure to include any relevant issue references (e.g., 'resolves #123', 'closes #456', 'fixes #789', 'connects to #101', 'relates to #202', 'contributes to #303') found in the commit messages.

Generate a complete gh pr create command that includes:
1. --title \"[concise, descriptive title]\"
2. --body \"[detailed description with bullet points of changes and issue references]\"
3. --assignee \"@me\" (to assign the PR to yourself)

Format the output as the complete gh pr create command, ready to execute.

Example format:
gh pr create --title \"Fix: Resolve login timeout issue\" --body \"- Fixed session timeout handling...\n\n🤖 Generated with [Gemini CLI](https://github.com/google-gemini/gemini-cli)\" --assignee \"@me\"

Always end the --body content with the attribution line:
🤖 Generated with [Gemini CLI](https://github.com/google-gemini/gemini-cli)"
    
    if [ -n "$gemini_context" ]; then
        base_prompt+="

Repository context from GEMINI.md:
$gemini_context"
    fi
    
    base_prompt+="

Commit history:
$commit_details"
    
    # Combine base prompt with feedback if provided
    local full_prompt="$base_prompt"
    if [ -n "$feedback_prompt" ]; then
        full_prompt="$base_prompt\n\nAdditional feedback to consider: $feedback_prompt"
    fi
    
    # Generate raw PR content from Gemini
    echo "$commit_details" | gemini -m gemini-2.5-flash --prompt "$full_prompt" | "${script_dir}/utils/gemini_clean.zsh"
}

# Generate initial PR content
pr_content_raw=$(generate_pr_content)


if [ $? -eq 0 ] && [ -n "$pr_content_raw" ]; then
    # Interactive loop for PR content confirmation and regeneration
    while true; do
        # The LLM now generates a complete gh pr create command
        pr_create_command="$pr_content_raw"

        echo "Generated PR create command:"
        echo "$pr_create_command"
        echo ""
        response=$(use_gum_choose "Create PR with this command?" "Yes" "Regenerate with feedback" "Quit")
        
        case "$response" in
            "Yes" )
                # Push current branch to remote
                echo "Pushing current branch to remote..."
                git push -u origin "$current_branch"
                
                # Create PR using the generated command
                if command -v gh &> /dev/null; then
                    # Add the base and head parameters to the generated command
                    enhanced_command="$pr_create_command --base \"$base_branch\" --head \"$current_branch\""
                    echo "Executing: $enhanced_command"
                    
                    # Execute the command (similar to auto_issue.zsh pattern)
                    escaped_command=$(echo "$enhanced_command" | sed 's/`/\\`/g')
                    eval "$escaped_command"
                    
                    if [ $? -eq 0 ]; then
                        echo "Pull request created successfully!"
                    else
                        echo "Failed to create pull request."
                        break
                    fi
                    
                    # Prompt to switch to main and pull latest changes
                    echo ""
                    if use_gum_confirm "Do you want to switch to $base_branch and pull latest changes?"; then
                        echo "Switching to $base_branch and pulling latest changes..."
                        if git switch "$base_branch" && git pull; then
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
                pr_content_raw=$(generate_pr_content "$feedback")
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