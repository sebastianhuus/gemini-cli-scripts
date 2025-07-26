#!/usr/bin/env zsh

# Test script for enhanced gum utilities with dry-run support

script_dir="$(dirname "${0:A}")"
source "${script_dir}/gum/gum_helpers.zsh"

echo "=== Testing Enhanced Gum Utilities with Dry-Run Support ==="
echo ""

echo "1. Testing use_gum_choose - Normal mode:"
result=$(use_gum_choose "Choose option" "Option A" "Option B" "Option C" false)
echo "Result: $result"
echo ""

echo "2. Testing use_gum_choose - Dry-run mode:"
result=$(use_gum_choose "Choose option" "Option A" "Option B" "Option C" true)
echo "Result: $result"
echo ""

echo "3. Testing use_gum_confirm - Normal mode:"
if use_gum_confirm "Confirm action?" true false; then
    echo "Result: Confirmed"
else
    echo "Result: Denied"
fi
echo ""

echo "4. Testing use_gum_confirm - Dry-run mode:"
if use_gum_confirm "Confirm action?" true true; then
    echo "Result: Confirmed"
else
    echo "Result: Denied"
fi
echo ""

echo "5. Testing dry_run_execute - Normal mode:"
dry_run_execute "echo test command" "echo 'Command executed successfully'" false
echo ""

echo "6. Testing dry_run_execute - Dry-run mode:"
dry_run_execute "echo test command" "echo 'Command executed successfully'" true
echo ""

echo "=== All tests completed ==="