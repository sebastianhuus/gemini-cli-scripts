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
    local base_prompt="${optional_prompt} Based on the following git commit history, generate a pull request title and description. Ensure to include any relevant issue references (e.g., 'resolves #123', 'closes #456', 'fixes #789', 'connects to #101', 'relates to #202', 'contributes to #303') found in the commit messages. Format as:

TITLE: [concise, descriptive title]

DESCRIPTION:
[detailed description with bullet points of changes]
[Optional: List of issue references, e.g., 'Resolves #123', 'Contributes to #456']

Commit history:
$commit_details"
    
    # Combine base prompt with feedback if provided
    local full_prompt="$base_prompt"
    if [ -n "$feedback_prompt" ]; then
        full_prompt="$base_prompt\n\nAdditional feedback to consider: $feedback_prompt"
    fi
    
    # Generate raw PR content from Gemini
    echo "$commit_details" | gemini -m gemini-2.5-flash --prompt "$full_prompt" | tail -n +2
}

# Generate initial PR content
pr_content_raw=$(generate_pr_content)


if [ $? -eq 0 ] && [ -n "$pr_content_raw" ]; then
    # Interactive loop for PR content confirmation and regeneration
    while true; do
        # Create the final PR content with attribution for display
        pr_content="$pr_content_raw"
        pr_content+=$'\n\n🤖 Generated with [Gemini CLI](https://github.com/google-gemini/gemini-cli)'

        echo "Generated PR content:"
        echo "$pr_content"
        echo ""
        echo "Create PR with this content? [y/r/q] (yes / regenerate with feedback / quit)"
        read -r response
        
        case "$response" in
            [Yy]* )
                # Extract title and description
                pr_title=$(echo "$pr_content" | grep "^TITLE:" | sed 's/^TITLE: //')
                pr_description=$(echo "$pr_content" | sed '1,/^DESCRIPTION:/d')

                # Push current branch to remote
                echo "Pushing current branch to remote..."
                git push -u origin "$current_branch"
                
                # Create PR using GitHub CLI (requires gh CLI to be installed)
                if command -v gh &> /dev/null; then
                    gh pr create --title "$pr_title" --body "$pr_description" --base "$base_branch" --head "$current_branch"
                    echo "Pull request created successfully!"
                    
                    # Prompt to switch to main and pull latest changes
                    echo ""
                    echo "Do you want to switch to $base_branch and pull latest changes? [y/N]"
                    read -r switch_response
                    
                    if [[ "$switch_response" =~ ^[Yy]$ ]]; then
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
                    echo "GitHub CLI (gh) not found. Please install it or create the PR manually:"
                    echo "Title: $pr_title"
                    echo "Description: $pr_description"
                    echo "Base: $base_branch"
                    echo "Head: $current_branch"
                fi
                break
                ;;
            [Rr]* )
                echo "What specific feedback would you like to incorporate? (or press Enter to regenerate without feedback)"
                read -r feedback
                echo "Regenerating PR content..."
                pr_content_raw=$(generate_pr_content "$feedback")
                if [ $? -ne 0 ] || [ -z "$pr_content_raw" ]; then
                    echo "Failed to regenerate PR content. Please try again."
                fi
                ;;
            [Qq]* )
                echo "PR creation cancelled. You can create it manually with:"
                echo "Title: $(echo "$pr_content" | grep "^TITLE:" | sed 's/^TITLE: //')"
                echo "Description: $(echo "$pr_content" | sed '1,/^DESCRIPTION:/d')"
                exit 0
                ;;
            * )
                echo "Invalid option. Please choose 'y', 'r', or 'q'."
                ;;
        esac
    done
else
    echo "Failed to generate PR content. Please create PR manually."
    exit 1
fi