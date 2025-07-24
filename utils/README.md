# Utilities Architecture Documentation

This document provides technical documentation for developers and contributors who want to understand or modify the internal architecture of the Gemini CLI scripts.

## Architecture Overview

The Gemini CLI scripts are built on a sophisticated modular architecture that separates concerns into specialized utilities organized by functionality. This design enables:

- **Separation of concerns**: Each utility has a single, well-defined responsibility
- **Reusability**: Shared functions reduce code duplication across main scripts
- **Testability**: Individual utilities can be tested and validated independently
- **Maintainability**: Changes are isolated to specific functionality areas
- **Progressive enhancement**: Gum styling with graceful fallbacks for all environments

## Directory Structure

The utils folder is organized into functional categories:

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
├── git/                     # Git and GitHub integration utilities
│   ├── git_push_helpers.zsh
│   └── gh_command_extraction.zsh
└── README.md                # This documentation
```

## Core Utilities (`core/`)

### `gemini_clean.zsh`
**Purpose**: AI response cleaning and authentication line removal

**Features**:
- Removes authentication-related output that sometimes appears in Gemini responses
- Pattern-based detection of auth messages ("Loaded cached credentials.", etc.)
- Preserves original content when no cleaning is needed
- Handles edge cases like single-line auth-only responses

**Usage**: `gemini ... | ./utils/core/gemini_clean.zsh`

### `gemini_context.zsh`
**Purpose**: Repository context loading from GEMINI.md files

**Key Functions**:
- `load_gemini_context()` - Searches for and loads GEMINI.md content
- `has_gemini_context()` - Checks if context is available
- File size validation (2KB limit) to prevent token overuse
- Search hierarchy: current directory → git root

### `config_generator.zsh`
**Purpose**: Interactive configuration creation for Gemini CLI scripts

**Features**:
- Creates personalized .gemini-config files through guided prompts
- Integrates with the main configuration system
- Handles model selection and theme preferences

## Content Generators (`generators/`)

### `commit_message_generator.zsh`
**Purpose**: AI-powered commit message generation with interactive feedback loops

**Key Functions**:
- `build_commit_prompt()` - Constructs comprehensive prompts with context, feedback, and repository information
- `generate_commit_message()` - Main generation function with regeneration support
- Interactive feedback loop allowing users to refine generated messages
- Integration with configuration system for model selection
- Context embedding from repository state and GEMINI.md

**Dependencies**: 
- `../config/config_loader.zsh` - Configuration management
- `../gum/gum_helpers.zsh` - UI components
- `../ui/commit_display.zsh` - Message formatting

### `pr_content_generator.zsh`
**Purpose**: Specialized pull request content generation including GitHub command creation

**Key Functions**:
- `generate_pr_content()` - Creates complete `gh pr create` commands
- `generate_pr_update_content()` - Handles PR updates with new commits
- Uses shared `extract_gh_title()` / `extract_gh_body()` functions from git/gh_command_extraction.zsh
- Automatic issue reference detection and inclusion
- Context-aware content generation based on commit history

**Features**:
- Complete GitHub CLI command generation (not just content)
- Issue reference extraction from commit messages (`resolves #123`, `fixes #456`)
- Repository context integration for better AI understanding
- Regeneration with user feedback support

### `parse_intent.zsh`
**Purpose**: Enhanced natural language parsing for GitHub issue operations

**Key Functions**:
- `parse_intent()` - Extracts structured intent from natural language
- Advanced parameter extraction including labels, assignees, milestones
- Priority detection and tone preference analysis
- Confidence scoring for parsed intent

**Output Format**:
```
OPERATION: [create|edit|comment|view|close|reopen]
ISSUE_NUMBER: [number or NONE]
CONTENT: [extracted content]
CONFIDENCE: [high|medium|low]
REQUESTED_LABELS: [comma-separated labels or NONE]
REQUESTED_ASSIGNEES: [comma-separated usernames or NONE]
REQUESTED_MILESTONE: [milestone name or NONE]
PRIORITY_INDICATORS: [urgent|high|medium|low|NONE]
TONE_PREFERENCE: [formal|casual|technical|NONE]
SPECIAL_INSTRUCTIONS: [any specific formatting/content requests or NONE]
```

## User Interface (`ui/`)

### `commit_display.zsh`
**Purpose**: Sophisticated commit message formatting with gum styling

**Key Functions**:
- `display_commit_message()` - Enhanced commit message display
- Title and body parsing with appropriate formatting
- Issue reference enhancement using `text_formatting.zsh`
- Gum integration with styled borders and padding

### `issue_display.zsh`
**Purpose**: GitHub issue content display with enhanced formatting

**Key Functions**:
- `display_issue_content()` - Formats issue titles and bodies with borders
- Gum integration with professional styling
- Issue reference bolding integration

### `pr_display.zsh`
**Purpose**: Enhanced PR content display with professional formatting

**Key Functions**:
- `display_pr_content()` - Formats PR titles and bodies with borders
- `display_styled_content()` - Generic styled content display
- Terminal-aware width calculation (`COLUMNS - 6`)
- Issue reference bolding integration

### `text_formatting.zsh`
**Purpose**: Text enhancement utilities for markdown content

**Key Functions**:
- `make_issue_refs_bold()` - Converts `#123` to `**#123**` in markdown text
- Python-based regex processing for reliable text transformation
- Handles edge cases and empty input gracefully

**Usage Example**:
```bash
# "Fixes #123 and closes #456" -> "Fixes **#123** and closes **#456**"
enhanced_text=$(make_issue_refs_bold "$original_text")
```

### `gum_theme.zsh`
**Purpose**: Consistent styling across all gum commands

**Features**:
- Centralized theme configuration for all gum components
- Format theme settings for markdown rendering
- Consistent color schemes and styling patterns

## Git Integration (`git/`)

### `git_push_helpers.zsh`
**Purpose**: Smart git push functionality with upstream detection and formatted output

**Key Functions**:
- `smart_git_push()` - Intelligently selects appropriate push command
- `simple_push_with_display()` - Push with formatted result display
- `pr_push_with_display()` - Push specifically for PR creation
- `display_push_result()` - Consistent push result formatting

**Features**:
- Automatic upstream branch detection and handling
- Fallback to `git push -u origin <branch>` when no upstream exists
- Comprehensive error handling and user feedback
- Global variable system for returning detailed results

### `gh_command_extraction.zsh`
**Purpose**: GitHub CLI command parsing and extraction utilities

**Key Functions**:
- `extract_gh_title()` - Extracts title from GitHub CLI commands
- `extract_gh_body()` - Extracts body content from GitHub CLI commands
- Handles both `gh pr create` and `gh issue create` commands
- Robust parsing of quoted and unquoted parameters

**Usage**:
```bash
# Extract title from: gh pr create --title 'My Title' --body 'My Body'
title=$(extract_gh_title "gh pr create --title 'My Title' --body 'My Body'")
```

## Design Patterns & Conventions

### Error Handling Standards
- Return meaningful exit codes (0=success, 1=error, 2=user cancellation)
- Use global variables for complex return data when needed
- Provide clear error messages with suggested actions

### Gum Integration Pattern
```bash
# 1. Check availability
if command -v gum &> /dev/null; then
    # 2. Enhanced experience
    enhanced_function()
else
    # 3. Graceful fallback
    fallback_function()
fi
```

### Utility Sourcing Pattern
```bash
# Relative path resolution from utility location
local util_script_dir="${0:A:h}"
source "${util_script_dir}/../other_utility.zsh"
```

### Context Building Pattern
```bash
# Build comprehensive prompts with all available context
build_prompt() {
    local base_prompt="$1"
    local context="$2"
    
    if [ -n "$context" ]; then
        base_prompt+="\\n\\nContext:\\n$context"
    fi
    
    echo "$base_prompt"
}
```

## Configuration Integration

All utilities integrate with the configuration system through consistent patterns:

```bash
# Standard configuration loading pattern
if [ -z "$CONFIG_GEMINI_MODEL" ]; then
    source "${script_dir}/config/config_loader.zsh"
    load_gemini_config
fi

# Using configuration values
model=$(get_gemini_model)
```

## Development Guidelines

### Adding New Utilities

1. **Choose appropriate directory**:
   - Core system utilities: `core/`
   - Content generation: `generators/`
   - UI and display: `ui/`
   - Git/GitHub integration: `git/`

2. **Follow naming conventions**:
   - Descriptive names with `_` separators
   - `.zsh` extension for all utilities

3. **Include standard headers**:
   ```bash
   #!/usr/bin/env zsh
   
   # Utility Name
   # Purpose description
   ```

4. **Implement configuration loading**:
   ```bash
   if [ -z "$CONFIG_GEMINI_MODEL" ]; then
       source "${script_dir}/config/config_loader.zsh"
       load_gemini_config
   fi
   ```

5. **Add gum integration with fallbacks**:
   - Always check `command -v gum &> /dev/null`
   - Provide meaningful alternatives

### Testing New Utilities

1. **Individual testing**: Test utilities independently when possible
2. **Integration testing**: Verify they work correctly with main scripts
3. **Fallback testing**: Test without gum installed
4. **Configuration testing**: Test with different config values

### Function Documentation

Use consistent documentation format:
```bash
# Function description
# Usage: function_name "param1" "param2"
# Returns: exit_code (0=success, 1=error)
# Sets: GLOBAL_VARIABLE if applicable
function_name() {
    # Implementation
}
```

## Contributing

When contributing to the utility architecture:

1. **Maintain separation of concerns** - each utility should have a single responsibility
2. **Follow existing patterns** - use established conventions for consistency
3. **Add comprehensive error handling** - utilities should fail gracefully
4. **Include fallback support** - don't assume gum is available
5. **Update this documentation** - keep architecture docs current
6. **Test thoroughly** - verify both enhanced and fallback experiences

## Future Improvements

Potential areas for enhancement:

1. **Utility testing framework** - Automated testing for individual utilities
2. **Performance optimization** - Reduce utility loading overhead
3. **Enhanced error reporting** - More detailed error context
4. **Plugin system** - Allow custom utilities to extend functionality
5. **Caching layer** - Cache expensive operations like git context

---

This architecture enables the sophisticated user experience provided by the main scripts while maintaining clean, maintainable, and testable code.