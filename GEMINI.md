# Project Context for Gemini CLI Scripts

This repository contains Zsh automation scripts for Git workflows and GitHub issue management.

## Key Information
- **Language**: Zsh scripting
- **Target**: Git repositories with GitHub integration
- **Architecture**: Standalone scripts that can call each other
- **Attribution**: All generated content includes "🤖 Generated with Gemini CLI" footer

## Coding Conventions
- Use conventional commit messages (feat:, fix:, docs:, etc.)
- Follow kebab-case for branch names with category prefixes
- Professional tone for all generated content
- Graceful error handling with fallbacks

## Project Structure
- `auto_commit.zsh`: Automated commit message generation
- `auto_pr.zsh`: Pull request creation automation  
- `auto_issue.zsh`: Natural language GitHub issue management
- `gemini_context.zsh`: Context utility (this file's purpose)

## Dependencies
- Git, GitHub CLI (gh), Gemini CLI
- Designed for git submodule usage