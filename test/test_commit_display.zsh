#!/usr/bin/env zsh

# Test script for commit message display utility

# Get script directory and source the commit display utility
script_dir="${0:A:h}/.."
source "${script_dir}/utils/commit_display.zsh"

echo "🧪 Testing Commit Message Display Utility"
echo "==========================================="
echo ""

# Sample commit message based on your example
sample_commit_message='feat(pr-display): Enhance PR body with bold issue references

- Introduce `make_issue_refs_bold` function to format issue/PR references.
- Apply bold formatting to issue references within the PR body for improved readability.
- Add unit tests for the `make_issue_refs_bold` function.
- Fix issues #123 and resolve #456 for better UX.

🤖 Generated with [Gemini CLI](https://github.com/google-gemini/gemini-cli)'

echo "Testing display_commit_message function..."
echo "-------------------------------------------"
display_commit_message "$sample_commit_message"

echo ""
echo ""
echo "Testing display_commit_message_with_header function..."
echo "------------------------------------------------------"
display_commit_message_with_header "Regenerated commit message" "$sample_commit_message"

echo ""
echo ""
echo "✅ All commit display tests completed!"