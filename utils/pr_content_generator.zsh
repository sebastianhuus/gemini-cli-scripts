#!/usr/bin/env zsh

# PR Content Generator Utility
# Provides AI-powered pull request content generation using Gemini CLI

# Function to generate PR content using Gemini
generate_pr_content() {
    local optional_prompt="$1"
    local commit_details="$2"
    local gemini_context="$3"
    local script_dir="$4"
    local feedback_prompt="$5"
    
    local base_prompt="${optional_prompt} Based on the following git commit history, generate a complete gh pr create command. Ensure to include any relevant issue references (e.g., 'resolves #123', 'closes #456', 'fixes #789', 'connects to #101', 'relates to #202', 'contributes to #303') found in the commit messages.

Generate a complete gh pr create command that includes:
1. --title \"[concise, descriptive title]\"
2. --body \"[detailed description with bullet points of changes and issue references]\"
3. --assignee \"@me\" (to assign the PR to yourself)

Format the output as the complete gh pr create command, ready to execute.

Example format:
gh pr create --title \"Fix: Resolve login timeout issue\" --body \"## Summary\n- Fixed session timeout handling\n- Updated error messages\n\n## Changes\n- Modified auth.js timeout logic\n- Added better error handling\n\nCloses #123\n\n🤖 Generated with [Gemini CLI](https://github.com/google-gemini/gemini-cli)\" --assignee \"@me\"

For PR updates, focus on the NEW commits provided and generate content that builds upon or updates the existing PR. Structure the body with:
- ## Summary (brief overview of changes)  
- ## Changes (bullet points of specific modifications)
- Issue references if applicable

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

# Function to generate PR update content for existing PRs
generate_pr_update_content() {
    local pr_number="$1"
    local optional_prompt="$2"
    local new_commits="$3"
    local gemini_context="$4"
    local script_dir="$5"
    local feedback_prompt="$6"
    
    # Nuclear approach: Only ask for title and body, we'll build the command ourselves
    local base_prompt="${optional_prompt} You are updating an existing PR. Based on ALL the commits for this PR and the existing PR content, generate ONLY an updated title and body for the PR.

DO NOT include any gh pr edit command or PR numbers in your response.
DO NOT include any command structure.

Generate ONLY:
TITLE: [updated, descriptive title that builds on existing title]
BODY: [updated description that extends/refines the existing content]

Format your response exactly like this:
TITLE: Fix: Resolve login timeout and add validation
BODY: ## Summary
- Fixed session timeout handling
- Added input validation
- Updated error messages

## Recent Changes
- Modified auth.js timeout logic
- Added validation middleware
- Improved error handling

Closes #123

🤖 Generated with [Gemini CLI](https://github.com/google-gemini/gemini-cli)

Instructions:
- Review the existing PR title and body provided below
- Look at ALL commits for this PR to understand the full scope
- Generate an updated title that builds upon or refines the existing one
- Create an updated body that extends the existing content with any new information from recent commits
- Maintain consistency with the existing structure and tone
- Include any new issue references found in recent commits
- Output ONLY the TITLE: and BODY: lines as shown above

Always end the --body content with the attribution line:
🤖 Generated with [Gemini CLI](https://github.com/google-gemini/gemini-cli)"
    
    if [ -n "$gemini_context" ]; then
        base_prompt+="

Repository context from GEMINI.md:
$gemini_context"
    fi
    
    # Add existing PR content if available
    if [ -n "$existing_title" ] || [ -n "$existing_body" ]; then
        base_prompt+="

EXISTING PR CONTENT:
Title: $existing_title
Body: $existing_body"
    fi
    
    base_prompt+="

ALL COMMITS FOR THIS PR:
$all_pr_commits"
    
    # Combine base prompt with feedback if provided
    local full_prompt="$base_prompt"
    if [ -n "$feedback_prompt" ]; then
        full_prompt="$base_prompt\n\nAdditional feedback to consider: $feedback_prompt"
    fi
    
    # Generate only title and body from Gemini (no command structure)
    gemini -m gemini-2.5-flash --prompt "$full_prompt" | "${script_dir}/utils/gemini_clean.zsh"
}