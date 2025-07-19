# Gum Usage Guide - Claude's Learning Summary

This document captures practical knowledge about using [Charmbracelet Gum](https://github.com/charmbracelet/gum) gained through hands-on implementation in zsh scripts.

## Core Gum Commands

### Interactive Prompts

```bash
# Confirmation prompts
gum confirm "Do you want to continue?"

# Multiple choice selection
gum choose --header="Select option:" "Option 1" "Option 2" "Option 3"

# Text input with placeholder
gum input --header="Enter name:" --placeholder="Your name here"
```

### Text Formatting & Display

```bash
# Format markdown text
echo "**Bold text**" | gum format

# Style text with effects
gum style --faint "Subtle text"
gum style --foreground 2 "Colored text"
```

## Critical Discovery: Color Syntax

**❌ WRONG** (doesn't work):
```bash
gum style --foreground="green" "text"    # Color names don't work!
gum style --foreground="red" "text"      # This fails silently
gum style --foreground="blue" "text"     # Shows as black/default
```

**✅ CORRECT**:
```bash
gum style --foreground 2 "text"          # ANSI color numbers (1-255)
gum style --foreground "#00FF00" "text"  # Or hex codes
gum style --foreground 1 "text"          # Red
gum style --foreground 5 "text"          # Magenta
```

### Common ANSI Color Numbers
- **1** = Red (errors, failures)
- **2** = Green (success, completion) 
- **5** = Magenta (info, cancellation)
- **3** = Yellow (warnings)
- **4** = Blue
- **6** = Cyan

## Practical Integration Patterns

### 1. Graceful Fallbacks
Always check if gum is available and provide fallbacks:

```bash
use_gum_confirm() {
    local prompt="$1"
    
    if command -v gum &> /dev/null; then
        if gum confirm "$prompt"; then
            return 0
        else
            return 1
        fi
    else
        echo "$prompt [Y/n]"
        read -r response
        case "$response" in
            [Yy]* | "" ) return 0 ;;
            * ) return 1 ;;
        esac
    fi
}
```

### 2. Combining gum format with styled elements

```bash
# Embed styled elements in markdown formatting
echo "**$(gum style --foreground 2 "⏺") Success message**" | gum format

# For quote blocks with colored elements
echo "> **$(gum style --foreground 1 "⏺") Error occurred**" | gum format
```

### 3. Cancel/Escape Detection

```bash
use_gum_choose() {
    local prompt="$1"
    shift
    local options=("$@")
    
    if command -v gum &> /dev/null; then
        local result
        result=$(gum choose --header="$prompt" "${options[@]}")
        if [ -z "$result" ]; then
            echo "Cancelled"  # User pressed escape
        else
            echo "$result"
        fi
    else
        # Traditional fallback
        echo "$prompt"
        # ... handle traditional input
    fi
}
```

### 4. Quote Block Creation

```bash
# Build markdown quote blocks dynamically
create_info_block() {
    local title="$1"
    local content="$2"
    
    local block="> **$title**"
    block+=$'\n>'  # Empty line for spacing
    
    while IFS= read -r line; do
        block+=$'\n> '"$line"
    done <<< "$content"
    
    if command -v gum &> /dev/null; then
        echo "$block" | gum format
    else
        echo "$block"
    fi
}
```

## Reusable Functions

### Colored Status Messages

```bash
colored_status() {
    local message="$1"
    local type="$2"  # "success", "error", "info", "cancel"
    
    if command -v gum &> /dev/null; then
        case "$type" in
            "success")
                echo "$(gum style --foreground 2 "⏺") $message"
                ;;
            "error")
                echo "$(gum style --foreground 1 "⏺") $message"
                ;;
            "info"|"cancel")
                echo "$(gum style --foreground 5 "⏺") $message"
                ;;
            *)
                echo "⏺ $message"
                ;;
        esac
    else
        echo "⏺ $message"
    fi
}
```

### Repository Context Block

```bash
create_repo_context_block() {
    local repo_url=$(git remote get-url origin 2>/dev/null)
    local current_branch=$(git branch --show-current 2>/dev/null)
    
    # Extract repository name from URL
    local repo_name=""
    if [ -n "$repo_url" ]; then
        if [[ "$repo_url" =~ github\.com[:/]([^/]+/[^/]+)(\.git)?$ ]]; then
            repo_name="${match[1]}"
        else
            repo_name="$repo_url"
        fi
    fi
    
    local block="> 🏗️  Repository: $repo_name"
    block+=$'\n> 🌿 Branch: '"$current_branch"
    
    if command -v gum &> /dev/null; then
        echo "$block" | gum format
    else
        echo "$block"
    fi
}
```

## Best Practices

### 1. User Feedback Consistency
- Always show what the user selected: `gum style --faint "> $result"`
- Provide clear headers for prompts
- Use consistent emoji/symbols for visual hierarchy

### 2. Error Handling
- Check gum availability before using advanced features
- Handle empty results (user cancellation)
- Provide meaningful fallbacks for non-gum environments

### 3. Visual Hierarchy
- Use colors meaningfully (red=error, green=success, blue=info)
- Combine formatting (bold + color) for emphasis
- Add spacing with empty quote lines (`> \n`)

## Advanced Techniques

### 1. Dynamic Content in Quote Blocks

```bash
# Add repository context to information blocks
create_file_list_block() {
    local files="$1"
    local title="$2"
    
    local block="> 🏗️ Repository: $repo_name"
    block+=$'\n> 🌿 Branch: '"$current_branch"
    block+=$'\n>'  # Empty line for spacing
    block+=$'\n> **'"$title"':**'
    
    while IFS= read -r file; do
        block+=$'\n> '"$file"
    done <<< "$files"
    
    if command -v gum &> /dev/null; then
        echo "$block" | gum format
        echo "> \n" | gum format  # Extra spacing
    else
        echo "$block"
        echo ""
    fi
}
```

### 2. Progressive Enhancement Pattern

```bash
# Works without gum, enhanced with gum
display_message() {
    local message="$1"
    local style="$2"  # "bold", "faint", "success", "error"
    
    if command -v gum &> /dev/null; then
        case "$style" in
            "bold")
                echo "**$message**" | gum format
                ;;
            "faint")
                gum style --faint "$message"
                ;;
            "success")
                echo "$(gum style --foreground 2 "✓") $message"
                ;;
            "error")
                echo "$(gum style --foreground 1 "✗") $message"
                ;;
            *)
                echo "$message"
                ;;
        esac
    else
        # Plain text fallbacks
        case "$style" in
            "success") echo "✓ $message" ;;
            "error") echo "✗ $message" ;;
            *) echo "$message" ;;
        esac
    fi
}
```

## Common Gotchas

1. **Color names don't work** - always use ANSI numbers (1-255) or hex codes
2. **Empty results mean cancellation** - always check `[ -z "$result" ]`
3. **Quoting matters** - be careful with quotes in dynamic content
4. **gum format expects markdown** - structure content accordingly
5. **Fallbacks are essential** - not everyone has gum installed
6. **Performance** - batch gum calls when possible
7. **Context switching** - `gum format` outputs to stdout, `gum style --faint` to stderr

## Integration Tips

- **Batch gum calls** when possible for better performance
- **Consistent visual language** - same colors for same meanings across scripts
- **Progressive enhancement** - scripts work without gum, better with it
- **Test both paths** - always test with and without gum during development
- **User feedback** - show selections and confirmations clearly
- **Graceful degradation** - meaningful fallbacks for all interactive elements

## Testing Gum Features

```bash
# Quick test if gum styling works
test_gum_colors() {
    if command -v gum &> /dev/null; then
        echo "Testing gum colors:"
        echo "$(gum style --foreground 1 "Red text (error)")"
        echo "$(gum style --foreground 2 "Green text (success)")"
        echo "$(gum style --foreground 5 "Magenta text (info)")"
        echo "**Bold text**" | gum format
    else
        echo "Gum not available"
    fi
}
```

---

*This guide reflects practical experience implementing gum in production zsh scripts. Focus is on patterns that work reliably across different environments and use cases.*