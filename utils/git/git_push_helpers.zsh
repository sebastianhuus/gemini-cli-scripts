#!/usr/bin/env zsh

# Git Push Helper Functions
# Shared utilities for consistent git push behavior and display formatting
# across auto_commit.zsh and auto_pr.zsh

# Global variables to return results from functions
PUSH_OUTPUT=""
PUSH_EXIT_CODE=""
PUSH_COMMAND=""

# Function to display formatted push results
# Usage: display_push_result "$push_output" "$current_branch" "$fallback_command"
display_push_result() {
    local push_output="$1"
    local current_branch="$2"
    local fallback_command="$3"
    
    if [ -n "$push_output" ]; then
        # Extract branch info from push output (using -- to prevent shell interpretation of ->)
        local branch_info=$(echo "$push_output" | grep -E -- '->|\.\.\..*->' | head -n 1 | sed 's/^[[:space:]]*//')
        if [ -n "$branch_info" ]; then
            colored_status "Push successful:" "success"
            echo "  ⎿ $current_branch"
            echo "    $branch_info"
        else
            colored_status "Push completed:" "success"
            echo "  ⎿ $fallback_command"
        fi
    else
        colored_status "Push completed:" "success"
        echo "  ⎿ $current_branch"
    fi
}

# Function to intelligently select and execute git push command
# Usage: smart_git_push "$branch_name"
# Returns results in global variables: PUSH_OUTPUT, PUSH_EXIT_CODE, PUSH_COMMAND
smart_git_push() {
    local branch_name="$1"
    
    # Check if upstream branch is set
    if git rev-parse --abbrev-ref --symbolic-full-name @{u} >/dev/null 2>&1; then
        # Upstream is set, a simple push is enough
        PUSH_COMMAND="git push"
        PUSH_OUTPUT=$(git push 2>&1)
        PUSH_EXIT_CODE=$?
    else
        # Upstream is not set, so we need to publish the branch
        colored_status "No upstream branch found for '$branch_name'" "info"
        echo "  ⎿ Publishing to 'origin/$branch_name'..."
        PUSH_COMMAND="git push --set-upstream origin \"$branch_name\""
        PUSH_OUTPUT=$(git push --set-upstream origin "$branch_name" 2>&1)
        PUSH_EXIT_CODE=$?
    fi
}

# Function to execute git push with upstream setup (always sets upstream)
# Usage: force_upstream_push "$branch_name"
# Returns results in global variables: PUSH_OUTPUT, PUSH_EXIT_CODE, PUSH_COMMAND
force_upstream_push() {
    local branch_name="$1"
    
    PUSH_COMMAND="git push -u origin \"$branch_name\""
    PUSH_OUTPUT=$(git push -u origin "$branch_name" 2>&1)
    PUSH_EXIT_CODE=$?
}

# High-level function combining push execution and display
# Usage: execute_push_with_display "$branch_name" "$push_mode" "$on_failure"
# push_mode: "smart" (detect upstream) | "force-upstream" (always set upstream)
# on_failure: "continue" | "exit" | "break" | "return"
execute_push_with_display() {
    local branch_name="$1"
    local push_mode="${2:-smart}"
    local on_failure="${3:-continue}"
    
    # Execute the appropriate push command
    case "$push_mode" in
        "smart")
            smart_git_push "$branch_name"
            ;;
        "force-upstream")
            force_upstream_push "$branch_name"
            ;;
        *)
            echo "Error: Unknown push mode '$push_mode'. Use 'smart' or 'force-upstream'."
            return 1
            ;;
    esac
    
    # Handle the result
    if [ $PUSH_EXIT_CODE -eq 0 ]; then
        # Success: display clean output
        display_push_result "$PUSH_OUTPUT" "$branch_name" "$PUSH_COMMAND"
        return 0
    else
        # Failure: display error and handle according to on_failure setting
        colored_status "Failed to push changes." "error"
        if [ -n "$PUSH_OUTPUT" ]; then
            echo "Error details: $PUSH_OUTPUT"
        fi
        
        case "$on_failure" in
            "continue")
                return 1
                ;;
            "exit")
                exit 1
                ;;
            "break")
                # Note: This won't work directly in a function context
                # The calling script needs to check return code and break
                return 2
                ;;
            "return")
                return 1
                ;;
            *)
                return 1
                ;;
        esac
    fi
}

# Convenience function for simple push with display (most common case)
# Usage: simple_push_with_display "$branch_name"
simple_push_with_display() {
    local branch_name="$1"
    execute_push_with_display "$branch_name" "smart" "return"
}

# Convenience function for PR-style push with display (always set upstream)
# Usage: pr_push_with_display "$branch_name"
pr_push_with_display() {
    local branch_name="$1"
    execute_push_with_display "$branch_name" "force-upstream" "return"
}