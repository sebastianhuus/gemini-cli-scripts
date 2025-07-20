#!/usr/bin/env zsh

# Test script for PR display utility
# Tests the display_pr_content function with sample data

# Get script directory and source utilities
script_dir="${0:A:h}/.."
source "${script_dir}/utils/text_formatting.zsh"
source "${script_dir}/utils/pr_display.zsh"

echo "🧪 Testing PR Display Utility"
echo "============================="
echo ""

# Test the make_issue_refs_bold function
echo "Testing make_issue_refs_bold function..."
echo "----------------------------------------"

test_cases=(
    "Closes #92"
    "Refs #106" 
    "Fixes #123 and resolves #456"
    "No issue references here"
    "Multiple #1 #22 #333 #4444 references"
    "Mixed content with #99 in the middle"
)

for test_case in "${test_cases[@]}"; do
    result=$(make_issue_refs_bold "$test_case")
    echo "Input:  $test_case"
    echo "Output: $result"
    echo ""
done

echo "✅ make_issue_refs_bold tests completed!"
echo ""
echo "Testing full PR display..."
echo "=========================="
echo ""

# Sample data from user
sample_title="feat(auto-commit): Enhance PR update, fix PR number generation, and improve display rendering"

sample_body='## Summary

- Implemented automatic PR update for existing branches, streamlining continuous development workflows.
- Significantly improved the robustness and accuracy of PR number generation and handling within `gh pr edit` commands, addressing persistent issues.
- Enhanced PR content generation by providing the LLM with full context, leading to more comprehensive and relevant titles and bodies.
- Introduced markdown rendering and display width adjustments for PR body content, improving readability in the terminal.
- Refactored PR content parsing for increased robustness and streamlined update logic.

## Recent Changes

- Automatic PR Update: Enhanced `auto_commit.zsh` to detect unpushed commits on branches with open PRs and provide an interactive flow to update them.
- PR Number Fixes:
  - Introduced `PR_NUMBER_PLACEHOLDER` and `sed` replacement to ensure correct PR numbers.
  - Corrected prompt instructions for LLM to use placeholders effectively.
  - Built `gh pr edit` command internally from LLM output, ensuring accuracy.
  - Added validation and auto-correction for PR numbers in LLM-generated commands.
- Improved PR Content Generation:
  - Passed all PR commits and existing PR content to the LLM for more context-aware updates.
  - Delegated full `gh pr edit` command generation to the LLM for flexibility.
- Display Enhancements:
  - Implemented markdown rendering for PR bodies using `gum format`.
  - Correctly nested `gum format` within `gum style` for consistent rendering.
  - Added `--width` parameter to `gum style` to adjust PR body display width, preventing overflow.
- Code Refinements:
  - Replaced `jq` with a Python script for more robust PR content parsing.
  - Streamlined PR update logic by merging conditional flows.
  - Replaced `echo` with `colored_status` for consistent and readable output.

Closes #92
Refs #106'

echo "Testing display_pr_content function..."
echo ""

# Test the function
display_pr_content "$sample_title" "$sample_body"

echo ""
echo "✅ Test completed!"
echo ""

# Test with gum disabled to show fallback behavior
if command -v gum &> /dev/null; then
    echo "🔧 Testing fallback mode (simulating gum not available)..."
    echo ""
    
    # Temporarily rename gum to test fallback
    PATH_BACKUP="$PATH"
    export PATH=""
    
    display_pr_content "$sample_title" "$sample_body"
    
    # Restore PATH
    export PATH="$PATH_BACKUP"
    
    echo ""
    echo "✅ Fallback test completed!"
else
    echo "ℹ️  Gum not available - only fallback mode was tested"
fi

echo ""
echo "🧪 All tests completed successfully!"