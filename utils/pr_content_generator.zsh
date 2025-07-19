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
    
    local base_prompt="${optional_prompt} Based on the following NEW git commits that will be added to existing PR #${pr_number}, generate a complete gh pr edit command to update the PR.

Generate a complete gh pr edit command that includes:
1. The PR number: ${pr_number}
2. --title \"[updated, descriptive title]\"
3. --body \"[updated description focusing on new changes with bullet points]\"

Format the output as the complete gh pr edit command, ready to execute.

Example format:
gh pr edit ${pr_number} --title \"Fix: Resolve login timeout and add validation\" --body \"## Summary\n- Fixed session timeout handling\n- Added input validation\n- Updated error messages\n\n## Recent Changes\n- Modified auth.js timeout logic\n- Added validation middleware\n- Improved error handling\n\nCloses #123\n\n🤖 Generated with [Gemini CLI](https://github.com/google-gemini/gemini-cli)\"

Focus on the NEW commits provided and generate content that builds upon the existing PR. Structure the body with:
- ## Summary (brief overview of all changes including new ones)
- ## Recent Changes (bullet points of the new commits being added)  
- Issue references if applicable

Always end the --body content with the attribution line:
🤖 Generated with [Gemini CLI](https://github.com/google-gemini/gemini-cli)"
    
    if [ -n "$gemini_context" ]; then
        base_prompt+="

Repository context from GEMINI.md:
$gemini_context"
    fi
    
    base_prompt+="

New commits being added to PR:
$new_commits"
    
    # Combine base prompt with feedback if provided
    local full_prompt="$base_prompt"
    if [ -n "$feedback_prompt" ]; then
        full_prompt="$base_prompt\n\nAdditional feedback to consider: $feedback_prompt"
    fi
    
    # Generate PR update content from Gemini
    gemini -m gemini-2.5-flash --prompt "$full_prompt" | "${script_dir}/utils/gemini_clean.zsh"
}