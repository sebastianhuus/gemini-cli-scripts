#!/usr/bin/env zsh

# Test script for PR content extraction from gh pr create commands

# Get script directory
script_dir="${0:A:h}/.."

# Source the text formatting utility first (required by pr_display.zsh)
source "${script_dir}/utils/text_formatting.zsh"

# Source the PR display utility to get the extraction function
source "${script_dir}/utils/display/pr_display.zsh"

echo "Testing PR content extraction from gh pr create commands..."
echo ""

# Test Case 1: Simple title and body
test_command1='gh pr create --title "Fix login bug" --body "This PR resolves the authentication issue by updating the login validation logic."'

echo "Test 1: Simple title and body"
echo "Command: $test_command1"
title1=$(extract_pr_title "$test_command1")
body1=$(extract_pr_body "$test_command1")
echo "Extracted title: '$title1'"
echo "Extracted body: '$body1'"
echo ""

# Test Case 2: Multi-line body with issue references
test_command2='gh pr create --title "Update documentation" --body "This PR updates the documentation to include new features.\n\n## Changes:\n- Added installation guide\n- Updated API documentation\n- Fixed typos\n\nFixes #123 and resolves #456."'

echo "Test 2: Multi-line body with issue references"
echo "Command: $test_command2"
title2=$(extract_pr_title "$test_command2")
body2=$(extract_pr_body "$test_command2")
echo "Extracted title: '$title2'"
echo "Extracted body:"
echo "$body2"
echo ""

# Test Case 3: Single quotes
test_command3="gh pr create --title 'Add dark mode feature' --body 'Implements dark mode toggle functionality for better user experience.'"

echo "Test 3: Single quotes"
echo "Command: $test_command3"
title3=$(extract_pr_title "$test_command3")
body3=$(extract_pr_body "$test_command3")
echo "Extracted title: '$title3'"
echo "Extracted body: '$body3'"
echo ""

# Test Case 4: Complex body with code blocks
test_command4='gh pr create --title "Refactor user service" --body "This PR refactors the user service to improve performance.\n\n\`\`\`typescript\ninterface User {\n  id: string;\n  name: string;\n}\n\`\`\`\n\nThe changes include:\n- Better error handling\n- Improved type safety\n- Performance optimizations"'

echo "Test 4: Complex body with code blocks"
echo "Command: $test_command4"
title4=$(extract_pr_title "$test_command4")
body4=$(extract_pr_body "$test_command4")
echo "Extracted title: '$title4'"
echo "Extracted body:"
echo "$body4"
echo ""

echo "All tests completed!"