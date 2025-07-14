#!/usr/bin/env zsh

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

# Generate PR title and description using Gemini

# Define the Gemini prompt
gemini_prompt="${optional_prompt} Based on the following git commit history, generate a pull request title and description. Ensure to include any relevant issue references (e.g., 'resolves #123', 'closes #456', 'fixes #789', 'connects to #101', 'relates to #202', 'contributes to #303') found in the commit messages. Format as:

TITLE: [concise, descriptive title]

DESCRIPTION:
[detailed description with bullet points of changes]
[Optional: List of issue references, e.g., 'Resolves #123', 'Contributes to #456']

Commit history:
$commit_details"

# Generate raw PR content from Gemini
pr_content_raw=$(echo "$commit_details" | gemini -m gemini-2.5-flash --prompt "$gemini_prompt" | tail -n +2)


if [ $? -eq 0 ] && [ -n "$pr_content_raw" ]; then
    # Create the final PR content with attribution for display, just like in auto_commit.zsh
    pr_content="$pr_content_raw"
    pr_content+=$'\n\n🤖 Generated with [Gemini CLI](https://github.com/google-gemini/gemini-cli)'

    echo "Generated PR content:"
    echo "$pr_content"
    echo ""
    echo "Do you want to create the PR with this content? [y/N]"
    read -r response
    
    if [[ "$response" =~ ^[Yy]$ ]]; then
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
        else
            echo "GitHub CLI (gh) not found. Please install it or create the PR manually:"
            echo "Title: $pr_title"
            echo "Description: $pr_description"
            echo "Base: $base_branch"
            echo "Head: $current_branch"
        fi
    else
        echo "PR creation cancelled. You can create it manually with:"
        echo "Title: $(echo "$pr_content" | grep "^TITLE:" | sed 's/^TITLE: //')"
        echo "Description: $(echo "$pr_content" | sed '1,/^DESCRIPTION:/d')"
    fi
else
    echo "Failed to generate PR content. Please create PR manually."
    exit 1
fi