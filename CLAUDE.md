# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This repository contains Zsh automation scripts that use the Gemini CLI to automate Git workflows and GitHub issue management. The scripts leverage AI to generate commit messages, pull request descriptions, and handle issue operations through natural language processing. The scripts feature enhanced UI with Charmbracelet Gum for improved user experience and visual presentation.

## Core Scripts

### Main Automation Scripts

#### auto_commit.zsh
Automated commit message generation using Gemini CLI with feedback loops:
- Analyzes staged changes and recent commit history
- Generates conventional commit messages 
- Interactive feedback mechanism for message refinement
- Enhanced UI with gum for better user experience
- Colored status indicators and formatted quote blocks
- Environment context display for user verification
- Optional branch creation, pushing, and PR creation
- Smart text wrapping for terminal-aware display

**PATH-compatible usage:**
- `auto-commit [-s|--stage] [-b|--branch] [-pr|--pr] [-p|--push] [optional_context]`
- `./auto_commit.zsh [-s|--stage] [-b|--branch] [-pr|--pr] [-p|--push] [optional_context]` (local execution)

Options:
- `-s, --stage`: Automatically stage all changes before generating commit
- `-b, --branch`: Automatically create new branch without confirmation  
- `-pr, --pr`: Automatically create pull request after successful commit
- `-p, --push`: Automatically push changes after successful commit

#### auto_pr.zsh  
Pull request creation automation:
- Analyzes commit differences between current branch and main/master
- Generates PR titles and descriptions
- Extracts issue references from commit messages
- Integrates with GitHub CLI for PR creation

**PATH-compatible usage:**
- `auto-pr [optional_context]`
- `./auto_pr.zsh [optional_context]` (local execution)

#### auto_issue.zsh
Natural language GitHub issue management:
- Two-stage processing: question conversion → intent parsing
- Supports create, edit, comment, view operations
- LLM-enhanced content generation for issue bodies and comments
- Repository context awareness (labels, milestones, collaborators)
- Priority label support for visual issue urgency indication

**PATH-compatible usage:**
- `auto-issue "natural language request"`
- `./auto_issue.zsh "natural language request"` (local execution)

### Utility Scripts (utils/)

#### utils/path_resolver.zsh
**NEW**: PATH compatibility utility for symlink resolution:
- Provides `find_script_base()` function for locating repository structure
- Resolves symlinks to find actual script location and utils/ directory
- Enables scripts to work both as git submodules and PATH executables
- Automatically sourced by all main scripts for PATH compatibility

Usage: Automatically loaded by main scripts via `source "$(dirname "${0:A}")/utils/path_resolver.zsh"`

#### utils/gemini_clean.zsh
Utility script for cleaning Gemini CLI responses:
- Removes authentication-related lines that can appear at response start
- Prevents command execution failures when auth messages get included
- Used by all other scripts via pipe: `gemini ... | "${script_dir}/utils/gemini_clean.zsh"`

Usage: `gemini -m model --prompt "..." | ./utils/gemini_clean.zsh`

#### utils/gemini_context.zsh
Repository context utility for enhanced AI understanding:
- Loads and formats GEMINI.md file content for LLM context
- Provides functions: `load_gemini_context()` and `has_gemini_context()`
- Automatically sourced by main scripts when available
- File size validation (max 2KB) to prevent token overuse

Usage: Automatically loaded by main scripts when present

## Development Guidelines

### General Development Notes
- When making new utilities and files, be aware of pitfalls with pathing and ensure they are symlink compatible

## Architecture

### PATH Compatibility
The scripts now support both traditional git submodule usage and system-wide PATH installation:

**Directory Resolution Pattern:**
```zsh
# All main scripts use this pattern for PATH compatibility
source "$(dirname "${0:A}")/utils/path_resolver.zsh"
script_dir="$(find_script_base)"
```

**find_script_base() Function:**
- Uses `"${0:A}"` to resolve symlinks to actual script location
- Searches for `utils/` directory in script location and parent directory
- Falls back gracefully to script directory if structure not found
- Enables seamless operation from PATH or local execution

**Installation Methods:**
1. **System-wide**: `./install.zsh` creates symlinks in `/usr/local/bin`
2. **Git submodule**: Traditional project-specific installation
3. **Manual**: Copy scripts while preserving directory structure

### Common Patterns
- All scripts use `gemini-2.5-flash` model via Gemini CLI
- Consistent attribution footer: `🤖 Generated with [Gemini CLI](https://github.com/google-gemini/gemini-cli)`
- Error handling with fallback to manual operation
- Interactive confirmation before execution
- PATH-aware utility sourcing for cross-platform compatibility

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
- Charmbracelet Gum (`gum` command) - For enhanced UI and interactive prompts

## UI Features

### Gum Integration
The scripts use Charmbracelet Gum for enhanced user experience:
- **Interactive prompts**: Confirm dialogs, multiple choice selections, text input
- **Formatted output**: Quote blocks, colored status indicators, styled text
- **Graceful fallbacks**: Scripts work without gum, enhanced when available
- **Color-coded status messages**: 
  - 🟢 Green ⏺ for success (staged successfully, pushed successfully)
  - 🔴 Red ⏺ for errors (failed to commit, failed to push)
  - 🟣 Magenta ⏺ for info/cancellation (commit cancelled, push cancelled)

### Smart Terminal Features
- **Environment context display**: Shows repository and branch at script start
- **Terminal-aware text wrapping**: Quote blocks respect `$COLUMNS` for proper formatting
- **Responsive UI**: Adapts to terminal width to prevent broken quote block markers

## Common Commands

Since this is a shell script repository without build systems:

### Testing Scripts
```bash
# Test with PATH installation (recommended)
auto-commit "fix login bug"
auto-pr "resolves #123"
auto-issue "create issue about dark mode"
auto-issue "comment on issue 5 that this is resolved"

# Test with local execution (git submodule)
./auto_commit.zsh "fix login bug"
./auto_pr.zsh "resolves #123"
./auto_issue.zsh "create issue about dark mode"
./auto_issue.zsh "comment on issue 5 that this is resolved"
```

### Development Testing Tools

#### test/test_commit_generator.zsh
Standalone test script for the commit message generator utility:
```bash
# Test commit message generation without affecting git repository
./test/test_commit_generator.zsh
```

Features:
- Tests the `generate_commit_message()` function in isolation
- Uses simulated staged diff and repository context
- Validates the full interactive flow (display, user choices, return mechanism)
- Shows both user experience and technical results
- Useful for debugging commit generation issues without staging real files

### Installation Patterns

#### System-wide Installation (Recommended)
```bash
git clone https://github.com/sebastianhuus/gemini-cli-scripts.git
cd gemini-cli-scripts
chmod +x install.zsh
./install.zsh
```

This creates symlinks in `/usr/local/bin` for system-wide access.

#### Git Submodule Installation
```bash
git submodule add https://github.com/sebastianhuus/gemini-cli-scripts.git <path>
git submodule update --remote  # For updates
```

Traditional project-specific installation.

## Development Notes

### Adding New Operations to auto_issue.zsh
1. Update `parse_intent()` function with new operation types
2. Add validation in `confirm_operation()` function  
3. Create new operation handler function following existing patterns
4. Update `dispatch_operation()` with new case
5. Update help documentation

### Gum UI Patterns
- Use `colored_status()` function for consistent status messaging with color codes
- Use `wrap_quote_block_text()` for terminal-aware text wrapping in quote blocks
- Always provide fallbacks when gum is not available
- Follow the color scheme: green for success, red for errors, blue for info/cancel

### Gemini Response Handling
- All scripts use `utils/gemini_clean.zsh` utility to clean auth-related output from responses
- Handles "Loaded cached credentials." and similar auth messages that sometimes appear
- Retry mechanism available in auto_commit.zsh via regeneration option
- Error checking for failed LLM calls with fallback messages
- Repository context loading via `utils/gemini_context.zsh` for enhanced AI understanding

### Attribution Pattern
All generated content includes attribution footer for transparency and compliance with LLM usage policies.

## Zsh Scripting Tips
- If you are going to use ``` inside of zsh scripts, remember to escape it like \``` so that it doesnt accidentally open a quote block