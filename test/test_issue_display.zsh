#!/usr/bin/env zsh

# Test script for Issue display utility
# Tests all display functions with sample data

# Get script directory and source utilities
script_dir="${0:A:h}/.."
source "${script_dir}/utils/ui/text_formatting.zsh"
source "${script_dir}/utils/ui/issue_display.zsh"

echo "🧪 Testing Issue Display Utility"
echo "================================="
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
    "Issue #42 and PR #789 references"
)

for test_case in "${test_cases[@]}"; do
    result=$(make_issue_refs_bold "$test_case")
    echo "Input:  $test_case"
    echo "Output: $result"
    echo ""
done

echo "✅ make_issue_refs_bold tests completed!"
echo ""

# Sample issue data for testing
echo "Testing issue display functions..."
echo "=================================="
echo ""

sample_title="Bug: Login button not working on mobile devices"

sample_body='## Steps to Reproduce

1. Open the application on a mobile device (tested on iPhone 12, Android Pixel 5)
2. Navigate to the login page
3. Enter valid credentials
4. Tap the "Login" button

## Expected Behavior

User should be successfully logged in and redirected to the dashboard.

## Actual Behavior

The login button does not respond to touch events. No visual feedback is provided when the button is tapped.

## Environment Information

- **Device**: iPhone 12 (iOS 16.1), Android Pixel 5 (Android 13)
- **Browser**: Safari 16.1, Chrome Mobile 107
- **App Version**: 2.1.4

## Additional Context

This issue started appearing after the recent UI update in version 2.1.0. Desktop browsers work fine - the issue is specific to mobile devices.

Related to #156 and possibly connected to #89.

🤖 Generated with [Gemini CLI](https://github.com/google-gemini/gemini-cli)'

echo "1. Testing display_issue_content function..."
echo ""
display_issue_content "$sample_title" "$sample_body"

echo ""
echo "✅ display_issue_content test completed!"
echo ""

# Test with gum disabled to show fallback behavior
if command -v gum &> /dev/null; then
    echo "🔧 Testing fallback mode (simulating gum not available)..."
    echo ""
    
    # Temporarily rename gum to test fallback
    PATH_BACKUP="$PATH"
    export PATH=""
    
    echo "Fallback: display_issue_content"
    display_issue_content "$sample_title" "$sample_body"
    echo ""
    
    # Restore PATH
    export PATH="$PATH_BACKUP"
    
    echo "✅ Fallback tests completed!"
else
    echo "ℹ️  Gum not available - only fallback mode was tested"
fi

echo ""
echo "🧪 All issue display tests completed successfully!"