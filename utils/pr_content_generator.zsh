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