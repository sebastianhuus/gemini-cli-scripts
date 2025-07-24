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

The utils folder is organized into functional subdirectories:

```
utils/
├── core/                     # Core system and AI utilities
│   ├── gemini_clean.zsh     # AI response cleaning
│   ├── gemini_context.zsh   # Repository context loading
│   └── config_generator.zsh # Interactive configuration
├── generators/              # Content generation utilities
│   ├── commit_message_generator.zsh
│   ├── pr_content_generator.zsh
│   └── parse_intent.zsh     # Natural language parsing
├── ui/                      # User interface and display utilities
│   ├── commit_display.zsh   # Commit message formatting
│   ├── issue_display.zsh    # Issue content display
│   ├── pr_display.zsh       # PR content display
│   ├── text_formatting.zsh  # Text enhancement utilities
│   └── gum_theme.zsh        # Gum styling configuration
└── git/                     # Git and GitHub integration utilities
    ├── git_push_helpers.zsh
    └── gh_command_extraction.zsh
```

#### Core Utilities (utils/core/)

**utils/core/gemini_clean.zsh**
Utility script for cleaning Gemini CLI responses:
- Removes authentication-related lines that can appear at response start
- Prevents command execution failures when auth messages get included
- Used by all other scripts via pipe: `gemini ... | "${script_dir}/utils/core/gemini_clean.zsh"`

Usage: `gemini -m model --prompt "..." | ./utils/core/gemini_clean.zsh`

**utils/core/gemini_context.zsh**
Repository context utility for enhanced AI understanding:
- Loads and formats GEMINI.md file content for LLM context
- Provides functions: `load_gemini_context()` and `has_gemini_context()`
- Automatically sourced by main scripts when available
- File size validation (max 2KB) to prevent token overuse

Usage: Automatically loaded by main scripts when present

**utils/core/config_generator.zsh**
Interactive configuration creation for Gemini CLI scripts:
- Creates personalized .gemini-config files through guided prompts
- Integrates with the main configuration system
- Handles model selection and theme preferences

#### Content Generators (utils/generators/)

**utils/generators/commit_message_generator.zsh**
AI-powered commit message generation with interactive feedback loops:
- Analyzes staged changes and recent commit history with repository context
- Uses smart path detection for both PATH and test execution contexts
- Interactive feedback mechanism for message refinement
- Integration with configuration system and gum UI components

**utils/generators/pr_content_generator.zsh**
Specialized pull request content generation:
- Creates complete `gh pr create` commands with titles and descriptions
- Automatic issue reference detection and inclusion
- Context-aware content generation based on commit history
- Regeneration with user feedback support

**utils/generators/parse_intent.zsh**
Enhanced natural language parsing for GitHub issue operations:
- Extracts structured intent from conversational language
- Advanced parameter extraction (labels, assignees, milestones)
- Priority detection and tone preference analysis
- Confidence scoring for parsed intent

#### UI Utilities (utils/ui/)

**utils/ui/commit_display.zsh, issue_display.zsh, pr_display.zsh**
Sophisticated content formatting with gum styling:
- Enhanced display with borders, padding, and styled text
- Issue reference enhancement and terminal-aware formatting
- Graceful fallbacks when gum is not available

**utils/ui/text_formatting.zsh**
Text enhancement utilities for markdown content:
- Converts issue references `#123` to bold `**#123**` format
- Python-based regex processing for reliable transformations

**utils/ui/gum_theme.zsh**
Consistent styling configuration across all gum commands

#### Git Integration (utils/git/)

**utils/git/git_push_helpers.zsh**
Smart git push functionality with upstream detection:
- Automatic upstream branch detection and handling
- Formatted result display and comprehensive error handling
- Global variable system for returning detailed results

**utils/git/gh_command_extraction.zsh**
GitHub CLI command parsing and extraction utilities:
- Extracts title and body parameters from `gh pr create` and `gh issue create` commands
- Robust parsing of quoted and unquoted parameters

## Development Guidelines

### General Development Notes
- When making new utilities and files, be aware of pitfalls with pathing and ensure they are symlink compatible
- Use the organized subdirectory structure in utils/ for new utilities: core/, generators/, ui/, git/
- Follow established patterns for configuration loading and gum integration with fallbacks

### Path Resolution Best Practices

Based on the utils refactor and PATH compatibility work:

1. **Utility Path Resolution**: Utilities should implement smart path detection:
   ```zsh
   # Try production path first (passed by main scripts)
   if [ -n "$script_dir" ] && [ -f "${script_dir}/utils/core/gemini_clean.zsh" ]; then
       gemini_clean_path="${script_dir}/utils/core/gemini_clean.zsh"
   else
       # Fallback to utility-relative path (for test context)
       gemini_clean_path="${util_script_dir}/../core/gemini_clean.zsh"
   fi
   ```

2. **Main Script Integration**: Main scripts should pass `$script_dir` to utilities for consistent PATH resolution

3. **Cross-Utility References**: Within subdirectories, use relative paths from utility location:
   ```zsh
   # From ui/ directory utilities
   source "${0:A:h}/text_formatting.zsh"  # Same directory
   
   # From generators/ directory utilities  
   source "${util_script_dir}/../core/gemini_clean.zsh"  # Cross-directory
   ```

4. **Testing Compatibility**: Ensure utilities work from both:
   - Production context (via PATH installation with symlinks)
   - Test context (direct execution from repository)

### Utility Development Guidelines

1. **Choose Appropriate Directory**:
   - `core/`: System utilities, configuration, AI response processing
   - `generators/`: Content generation utilities (commits, PRs, intent parsing)
   - `ui/`: Display formatting, gum integration, text enhancement
   - `git/`: Git and GitHub CLI integration utilities

2. **Follow Established Patterns**:
   - Load configuration with standard pattern
   - Implement gum integration with graceful fallbacks
   - Use consistent error handling and exit codes
   - Include proper function documentation

## Architecture

### PATH Compatibility
The scripts now support both traditional git submodule usage and system-wide PATH installation:

**Directory Resolution Pattern:**
```zsh
# All main scripts use this pattern for PATH compatibility
script_dir="$(dirname "${0:A}")"
```

**Symlink Resolution:**
- Uses `"${0:A}"` to resolve symlinks to actual script location
- Main scripts pass `$script_dir` to utilities for consistent path resolution
- Utilities implement smart path detection for dual context support:
  - Production/PATH usage: Uses passed `$script_dir` parameter
  - Test context: Falls back to utility-relative paths
- Enables seamless operation from PATH installation or direct execution

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