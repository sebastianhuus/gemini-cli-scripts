#!/usr/bin/env zsh

# Test script for commit message generator
# This allows testing the commit generation logic without running the full auto_commit script

# Get script directory
script_dir="${0:A:h}"

# Source the commit message generator
source "${script_dir}/../utils/commit_message_generator.zsh"

# Test data - simulate what auto_commit would pass
echo "🧪 Testing Commit Message Generator"
echo "=================================="
echo ""

# Create test data
test_staged_diff="diff --git a/test.txt b/test.txt
new file mode 100644
index 0000000..30d74d2
--- /dev/null
+++ b/test.txt
@@ -0,0 +1 @@
+test file for staging"

test_recent_commits="abc1234 feat: add new feature
def5678 fix: resolve memory leak
ghi9012 docs: update README"

test_repository_context="Repository: sebastianhuus/gemini-cli-scripts
Current branch: feat/commit-message-generator"

test_gemini_context="This repository contains Zsh automation scripts that use the Gemini CLI to automate Git workflows."

test_optional_context="Testing the commit message generator utility"

echo "📋 Test Input Data:"
echo "• Staged diff: test.txt (new file)"
echo "• Recent commits: 3 commits in history"
echo "• Repository: sebastianhuus/gemini-cli-scripts"
echo "• Branch: feat/commit-message-generator"
echo "• Optional context: Testing the commit message generator utility"
echo ""

echo "🚀 Starting commit message generation..."
echo ""

# Call the function with test data
generate_commit_message \
    "$test_staged_diff" \
    "$test_recent_commits" \
    "$test_repository_context" \
    "$test_gemini_context" \
    "$test_optional_context" \
    "$script_dir"

exit_code=$?

echo ""
echo "📊 Test Results:"
echo "• Exit code: $exit_code"

case $exit_code in
    0)
        echo "• Status: ✅ SUCCESS - Commit message generated"
        echo "• Generated message length: ${#GENERATED_COMMIT_MESSAGE} characters"
        echo ""
        echo "📝 Final commit message that would be used:"
        echo "----------------------------------------"
        echo "$GENERATED_COMMIT_MESSAGE"
        echo "----------------------------------------"
        ;;
    1)
        echo "• Status: ❌ FAILED - Generation error"
        ;;
    2)
        echo "• Status: 🚫 CANCELLED - User cancelled/quit"
        ;;
    *)
        echo "• Status: ❓ UNKNOWN - Unexpected exit code: $exit_code"
        ;;
esac

echo ""
echo "🧪 Test completed!"