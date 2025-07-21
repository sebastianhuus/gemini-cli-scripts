# Utilities Architecture Documentation

This document provides technical documentation for developers and contributors who want to understand or modify the internal architecture of the Gemini CLI scripts.

## Architecture Overview

The Gemini CLI scripts are built on a sophisticated modular architecture that separates concerns into specialized utilities. This design enables:

- **Separation of concerns**: Each utility has a single, well-defined responsibility
- **Reusability**: Shared functions reduce code duplication across main scripts
- **Testability**: Individual utilities can be tested and validated independently
- **Maintainability**: Changes are isolated to specific functionality areas
- **Progressive enhancement**: Gum styling with graceful fallbacks for all environments

## Core Utilities

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
- `display/commit_display.zsh` - Message formatting

### `pr_content_generator.zsh`
**Purpose**: Specialized pull request content generation including GitHub command creation

**Key Functions**:
- `generate_pr_content()` - Creates complete `gh pr create` commands
- `generate_pr_update_content()` - Handles PR updates with new commits
- `extract_pr_title()` / `extract_pr_body()` - Parses generated commands
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

### Supporting Infrastructure

#### `path_resolver.zsh`
**Purpose**: PATH compatibility and symlink resolution for system-wide installation

**Key Functions**:
- `find_script_base()` - Locates repository structure from any execution context
- Resolves symlinks to find actual script locations
- Enables scripts to work both as git submodules and PATH executables

**Resolution Logic**:
1. Use `${0:A}` to resolve symlinks to actual script location
2. Search for `utils/` directory in script location and parent directory
3. Fall back gracefully to script directory if structure not found

#### `gemini_clean.zsh`
**Purpose**: AI response cleaning and authentication line removal

**Features**:
- Removes authentication-related output that sometimes appears in Gemini responses
- Pattern-based detection of auth messages ("Loaded cached credentials.", etc.)
- Preserves original content when no cleaning is needed
- Handles edge cases like single-line auth-only responses

#### `gemini_context.zsh`
**Purpose**: Repository context loading from GEMINI.md files

**Key Functions**:
- `load_gemini_context()` - Searches for and loads GEMINI.md content
- `has_gemini_context()` - Checks if context is available
- File size validation (2KB limit) to prevent token overuse
- Search hierarchy: current directory → git root

## Display System

### `display/commit_display.zsh`
**Purpose**: Sophisticated commit message formatting with gum styling

**Key Functions**:
- `display_commit_message()` - Enhanced commit message display
- Title and body parsing with appropriate formatting
- Issue reference enhancement using `text_formatting.zsh`
- Gum integration with styled borders and padding

### `display/pr_display.zsh`
**Purpose**: Enhanced PR content display with professional formatting

**Key Functions**:
- `display_pr_content()` - Formats PR titles and bodies with borders
- `display_styled_content()` - Generic styled content display
- Terminal-aware width calculation (`COLUMNS - 6`)
- Issue reference bolding integration

### `../gum/gum_helpers.zsh`
**Purpose**: Reusable gum UI functions with graceful fallbacks

**Key Functions**:
- `use_gum_confirm()` - Confirmation prompts with fallback to read
- `use_gum_choose()` - Multiple choice selection with traditional alternatives
- `use_gum_input()` - Text input with placeholder support
- `colored_status()` - Consistent status messaging with color codes

**Design Patterns**:
```bash
# Always check gum availability
if command -v gum &> /dev/null; then
    # Enhanced gum experience
    result=$(gum choose "Select option:" "A" "B" "C")
else
    # Traditional fallback
    echo "Select option: [1] A [2] B [3] C"
    read -r choice
fi
```

### `../gum/env_display.zsh`
**Purpose**: Repository context display with branch warnings

**Key Functions**:
- `display_env_info()` - Shows repository and branch information
- GitHub URL parsing for clean repository names
- Main/master branch warnings for safety
- Formatted quote blocks with repository emoji

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

## Development Guidelines

### Adding New Utilities

1. **Create in appropriate directory**:
   - Core logic utilities: `utils/`
   - Display utilities: `utils/display/`
   - UI helpers: `gum/` (might want to merge this into `utils/` later)

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

### Integration Examples

#### Main Script Integration
```bash
# In auto_commit.zsh
source "${script_dir}/utils/commit_message_generator.zsh"

# Use the utility
generate_commit_message "$staged_diff" "$recent_commits" "$repository_context" "$gemini_context" "$1" "$script_dir"
```

#### Utility Chaining
```bash
# In commit_message_generator.zsh
source "${util_script_dir}/display/commit_display.zsh"

# Chain utilities
display_commit_message "$generated_message"
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