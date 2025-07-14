# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This repository contains Zsh automation scripts that use the Gemini CLI to automate Git workflows and GitHub issue management. The scripts leverage AI to generate commit messages, pull request descriptions, and handle issue operations through natural language processing.

## Core Scripts

### auto_commit.zsh
Automated commit message generation using Gemini CLI with feedback loops:
- Analyzes staged changes and recent commit history
- Generates conventional commit messages 
- Interactive feedback mechanism for message refinement
- Optional push to remote after commit

Usage: `./auto_commit.zsh [optional_context]`

### auto_pr.zsh  
Pull request creation automation:
- Analyzes commit differences between current branch and main/master
- Generates PR titles and descriptions
- Extracts issue references from commit messages
- Integrates with GitHub CLI for PR creation

Usage: `./auto_pr.zsh [optional_context]`

### auto_issue.zsh
Natural language GitHub issue management:
- Two-stage processing: question conversion → intent parsing
- Supports create, edit, comment, view operations
- LLM-enhanced content generation for issue bodies and comments
- Repository context awareness (labels, milestones, collaborators)

Usage: `./auto_issue.zsh "natural language request"`

## Architecture

### Common Patterns
- All scripts use `gemini-2.5-flash` model via Gemini CLI
- Consistent attribution footer: `🤖 Generated with [Gemini CLI](https://github.com/google-gemini/gemini-cli)`
- Error handling with fallback to manual operation
- Interactive confirmation before execution

### Key Functions in auto_issue.zsh
- `convert_question_to_command()`: Converts conversational requests to direct commands
- `parse_intent()`: Extracts structured data (operation, issue number, content) from natural language
- `confirm_operation()`: Validates and confirms operations before execution
- `dispatch_operation()`: Routes to appropriate handler functions
- `create_issue_with_llm()`: LLM-controlled issue creation with repository context
- `edit_issue()` / `comment_issue()`: Issue modification operations

### Two-Stage Processing in auto_issue.zsh
1. **Question Detection & Conversion**: Handles polite/conversational requests
2. **Intent Parsing**: Extracts structured operation data from direct commands

## Dependencies

Required tools:
- Zsh shell
- Git
- Gemini CLI (`gemini` command)
- GitHub CLI (`gh` command)

## Common Commands

Since this is a shell script repository without build systems:

### Testing Scripts
```bash
# Test in a git repository with staged changes
./auto_commit.zsh "fix login bug"

# Test PR creation from feature branch  
./auto_pr.zsh "resolves #123"

# Test issue management
./auto_issue.zsh "create issue about dark mode"
./auto_issue.zsh "comment on issue 5 that this is resolved"
```

### Installation Pattern
Designed to be used as a git submodule:
```bash
git submodule add https://github.com/sebastianhuus/gemini-cli-scripts.git <path>
git submodule update --remote  # For updates
```

## Development Notes

### Adding New Operations to auto_issue.zsh
1. Update `parse_intent()` function with new operation types
2. Add validation in `confirm_operation()` function  
3. Create new operation handler function following existing patterns
4. Update `dispatch_operation()` with new case
5. Update help documentation

### Gemini Response Handling
- All scripts use `tail -n +2` to trim first line (handles auth-related output)
- Retry mechanism available in auto_commit.zsh via regeneration option
- Error checking for failed LLM calls with fallback messages

### Attribution Pattern
All generated content includes attribution footer for transparency and compliance with LLM usage policies.

## Zsh Scripting Tips
- If you are going to use ``` inside of zsh scripts, remember to escape it like \``` so that it doesnt accidentally open a quote block