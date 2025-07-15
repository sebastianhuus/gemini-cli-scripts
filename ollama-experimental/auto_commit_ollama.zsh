#!/usr/bin/env zsh

# auto_commit_ollama.zsh - Local AI-Powered Git Commit Automation
# v0.1 - Uses Ollama with Gemma models instead of Gemini CLI
# Based on auto_commit.zsh but adapted for local AI workflows

# Default options
auto_stage=false
auto_pr=false
auto_branch=false
test_mode=false
debug_mode=false

# Usage function
usage() {
    echo "Usage: $0 [-s|--stage] [-b|--branch] [-pr|--pr] [-t|--test] [-d|--debug] [optional_context]"
    echo ""
    echo "Options:"
    echo "  -s, --stage    Automatically stage all changes before generating commit"
    echo "  -b, --branch   Automatically create new branch without confirmation"
    echo "  -pr, --pr      Automatically create pull request after successful commit"
    echo "  -t, --test     Run in test mode to validate Ollama setup"
    echo "  -d, --debug    Enable verbose debugging output"
    echo "  -h, --help     Show this help message"
    echo ""
    echo "Arguments:"
    echo "  optional_context    Additional context for commit message generation"
    echo ""
    echo "Requirements:"
    echo "  - Ollama service running (ollama serve)"
    echo "  - Required models: gemma3:1b, gemma3:4b, gemma3:12b-it-qat"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--stage)
            auto_stage=true
            shift
            ;;
        -b|--branch)
            auto_branch=true
            shift
            ;;
        -pr|--pr)
            auto_pr=true
            shift
            ;;
        -t|--test)
            test_mode=true
            shift
            ;;
        -d|--debug)
            debug_mode=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        -*)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
        *)
            # First non-option argument is the optional context
            break
            ;;
    esac
done

# Load configuration and utilities
script_dir="${0:A:h}"
source "${script_dir}/ollama_config.zsh"
source "${script_dir}/ollama_context.zsh"

# Debug logging function
debug_log() {
    if [[ "$debug_mode" == true ]]; then
        echo "$@"
    fi
}

# Test mode - validate setup and exit
if [[ "$test_mode" == true ]]; then
    echo "🧪 Testing Ollama setup..."
    
    if ! setup_ollama_environment; then
        exit 1
    fi
    
    echo "🧪 Testing model generation..."
    test_prompt="Generate a conventional commit message for adding a test feature."
    
    result=$(call_ollama_generate "commit" "$test_prompt")
    if [ $? -eq 0 ] && [ -n "$result" ]; then
        echo "✅ Test generation successful:"
        echo "$result"
        echo ""
        echo "🎉 Ollama setup is working correctly!"
    else
        echo "❌ Test generation failed"
        exit 1
    fi
    
    exit 0
fi

# Function to escape JSON strings using Python
escape_json() {
    local string="$1"
    
    # Use Python's json.dumps for proper JSON escaping
    python3 -c "
import json, sys
try:
    # json.dumps properly escapes all characters, then we remove the surrounding quotes
    escaped = json.dumps(sys.argv[1])
    print(escaped[1:-1])  # Remove surrounding quotes
except Exception as e:
    print('JSON escaping error', file=sys.stderr)
    sys.exit(1)
" "$string"
}

# Function to extract JSON response using Python
extract_json_response() {
    local json="$1"
    
    # Check if Python is available
    if ! command -v python3 > /dev/null 2>&1; then
        echo "❌ Python3 is required for JSON processing but not found"
        return 1
    fi
    
    # Use Python to extract and clean the response
    python3 -c "
import json, sys, re

try:
    data = json.loads(sys.stdin.read())
    response = data.get('response', '')
    
    # Clean up the response
    response = response.strip()
    
    # Remove markdown code blocks if present
    if response.startswith('\`\`\`'):
        lines = response.split('\n')
        # Remove first line (opening \`\`\`) and last line if it's closing \`\`\`
        if len(lines) > 1:
            if lines[-1].strip() == '\`\`\`':
                response = '\n'.join(lines[1:-1])
            else:
                response = '\n'.join(lines[1:])
        response = response.strip()
    
    # Remove any remaining backticks at start/end
    response = re.sub(r'^\`+', '', response)
    response = re.sub(r'\`+$', '', response)
    response = response.strip()
    
    if response:
        print(response)
    else:
        sys.exit(1)
        
except Exception as e:
    print(f'JSON parsing error: {e}', file=sys.stderr)
    sys.exit(1)
" <<< "$json"
}

# Function to call Ollama with retry mechanism
call_ollama_generate() {
    local task="$1"
    local prompt="$2"
    local model=$(get_model_for_task "$task")
    local retry_count=0
    
    debug_log "🔍 DEBUG: Starting generation with model: $model"
    debug_log "🔍 DEBUG: Task type: $task"
    debug_log "🔍 DEBUG: Prompt length: $(echo "$prompt" | wc -c) characters"
    debug_log "🔍 DEBUG: First 200 chars of prompt: $(echo "$prompt" | head -c 200)..."
    debug_log ""
    
    # Escape the prompt for JSON
    local escaped_prompt=$(escape_json "$prompt")
    debug_log "🔍 DEBUG: Escaped prompt length: $(echo "$escaped_prompt" | wc -c) characters"
    
    while [ $retry_count -lt $RETRY_ATTEMPTS ]; do
        debug_log "🔍 DEBUG: Attempt $((retry_count + 1)) of $RETRY_ATTEMPTS"
        debug_log "🔍 DEBUG: Calling Ollama API at: $OLLAMA_API_GENERATE"
        
        # Use curl for more control over timeouts and error handling
        local curl_exit_code=0
        local response=$(curl -s -m "$TIMEOUT_SECONDS" -X POST "$OLLAMA_API_GENERATE" \
            -H "Content-Type: application/json" \
            -d "{
                \"model\": \"$model\",
                \"prompt\": \"$escaped_prompt\",
                \"stream\": false,
                \"options\": {
                    \"temperature\": $TEMPERATURE,
                    \"top_p\": $TOP_P
                }
            }" 2>&1)
        curl_exit_code=$?
        
        debug_log "🔍 DEBUG: curl exit code: $curl_exit_code"
        debug_log "🔍 DEBUG: Response length: $(echo "$response" | wc -c) characters"
        debug_log "🔍 DEBUG: First 300 chars of response: $(echo "$response" | head -c 300)..."
        debug_log ""
        
        if [ $curl_exit_code -eq 0 ] && [ -n "$response" ]; then
            # Check if response contains an error
            if echo "$response" | grep -q '"error"'; then
                echo "❌ Ollama API returned error:"
                echo "$response" | grep -o '"error":"[^"]*"' || echo "$response"
                echo ""
            else
                # Extract the response using Python JSON processing
                debug_log "🔍 DEBUG: Using Python for JSON parsing"
                local result=""
                result=$(extract_json_response "$response" 2>&1)
                local extraction_exit_code=$?
                
                debug_log "🔍 DEBUG: Python extraction exit code: $extraction_exit_code"
                debug_log "🔍 DEBUG: Python extraction result: '$result'"
                
                # Check if extraction was successful
                if [ $extraction_exit_code -eq 0 ] && [ -n "$result" ] && [ "$result" != "null" ]; then
                    debug_log "✅ DEBUG: Successfully extracted response with Python"
                    echo "$result"
                    return 0
                else
                    debug_log "❌ DEBUG: Python extraction failed"
                    if [[ "$result" == *"JSON parsing error"* ]]; then
                        debug_log "🔍 DEBUG: JSON parsing error: $result"
                    else
                        debug_log "🔍 DEBUG: Empty or null response"
                    fi
                    debug_log "🔍 DEBUG: Full raw response:"
                    debug_log "$response"
                    debug_log ""
                fi
            fi
        else
            debug_log "❌ DEBUG: curl failed or empty response"
            if [ $curl_exit_code -ne 0 ]; then
                debug_log "🔍 DEBUG: curl error code $curl_exit_code"
                case $curl_exit_code in
                    7) echo "  → Failed to connect to Ollama service" ;;
                    28) echo "  → Timeout after $TIMEOUT_SECONDS seconds" ;;
                    *) debug_log "  → curl error (see man curl for code $curl_exit_code)" ;;
                esac
            fi
            debug_log "🔍 DEBUG: Response content (if any): '$response'"
            debug_log ""
        fi
        
        retry_count=$((retry_count + 1))
        if [ $retry_count -lt $RETRY_ATTEMPTS ]; then
            echo "⚠️  Generation failed, retrying ($retry_count/$RETRY_ATTEMPTS)..."
            sleep 2
        fi
    done
    
    echo "❌ Failed to generate response after $RETRY_ATTEMPTS attempts"
    debug_log "🔍 DEBUG: All retry attempts exhausted"
    return 1
}

# Function to truncate diff for context limits
truncate_diff() {
    local diff="$1"
    local max_lines="$MAX_DIFF_LINES"
    
    # Count lines in diff
    local line_count=$(echo "$diff" | wc -l)
    
    if [ "$line_count" -gt "$max_lines" ]; then
        # Keep file headers and first few lines of each file
        echo "$diff" | head -n "$max_lines"
        echo "... (diff truncated for context limit)"
    else
        echo "$diff"
    fi
}

# Function to build optimized context for local models
build_context() {
    local staged_diff="$1"
    local recent_commits="$2"
    local user_context="$3"
    local repository_context="$4"
    local ollama_context="$5"
    
    local context=""
    
    # Prioritize context elements for token efficiency
    if [ -n "$user_context" ]; then
        context+="User context: $user_context\n\n"
    fi
    
    if [ -n "$repository_context" ]; then
        context+="Repository: $(echo "$repository_context" | head -n 2)\n\n"
    fi
    
    if [ -n "$ollama_context" ]; then
        context+="Project context: $(echo "$ollama_context" | head -n 10)\n\n"
    fi
    
    if [ -n "$recent_commits" ]; then
        context+="Recent commits:\n$(echo "$recent_commits" | head -n $MAX_COMMIT_HISTORY)\n\n"
    fi
    
    context+="Changes to commit:\n$(truncate_diff "$staged_diff")"
    
    echo "$context"
}

# Function to get repository context for LLM (same as original)
get_repository_context() {
    local repo_url=$(git remote get-url origin 2>/dev/null)
    local current_branch=$(git branch --show-current 2>/dev/null)
    local context=""
    
    if [ -n "$repo_url" ]; then
        local repo_name
        if [[ "$repo_url" =~ github\.com[:/]([^/]+/[^/]+)(\.git)?$ ]]; then
            repo_name="${match[1]}"
        else
            repo_name="$repo_url"
        fi
        context+="Repository: $repo_name"
    else
        context+="Repository: (unable to detect remote)"
    fi
    
    if [ -n "$current_branch" ]; then
        context+="
Current branch: $current_branch"
    fi
    
    echo "$context"
}

# Function to display repository information (same as original)
display_repository_info() {
    local repo_url=$(git remote get-url origin 2>/dev/null)
    local current_branch=$(git branch --show-current 2>/dev/null)
    
    if [ -n "$repo_url" ]; then
        local repo_name
        if [[ "$repo_url" =~ github\.com[:/]([^/]+/[^/]+)(\.git)?$ ]]; then
            repo_name="${match[1]}"
        else
            repo_name="$repo_url"
        fi
        echo "🏗️  Repository: $repo_name"
    else
        echo "🏗️  Repository: (unable to detect remote)"
    fi
    
    if [ -n "$current_branch" ]; then
        echo "🌿 Branch: $current_branch"
    fi
    
    echo ""
}

# Check Python3 dependency
if ! command -v python3 > /dev/null 2>&1; then
    echo "❌ Python3 is required for JSON processing but not found."
    echo "Please install Python3 and try again."
    exit 1
fi

# Initialize Ollama environment
if ! setup_ollama_environment; then
    echo "❌ Ollama environment setup failed. Please check the requirements above."
    exit 1
fi

# Load context utility
ollama_context=""
if has_ollama_context; then
    ollama_context=$(get_prioritized_context)
fi

# Branch creation logic (adapted for Ollama)
current_branch=$(git branch --show-current)
if [[ "$current_branch" == "main" || "$current_branch" == "master" ]]; then
    echo "⚠️  You're currently on the '$current_branch' branch."
    echo "It's recommended to create a feature branch for your changes."
    echo ""
    
    # Handle staging (same logic as original)
    staged_diff=""
    if ! git diff --cached --quiet; then
        staged_diff=$(git diff --cached)
        echo "✅ Found staged changes for branch name generation."
    elif ! git diff --quiet; then
        if [[ "$auto_stage" == true ]]; then
            echo "Auto-staging all changes..."
            git add -A
            if ! git diff --cached --quiet; then
                staged_diff=$(git diff --cached)
                echo "✅ Changes staged successfully."
            else
                echo "❌ No changes to stage."
                exit 1
            fi
        else
            echo "Found unstaged changes. Stage all changes? [Y/n]"
            read -r stage_response
            if [[ "$stage_response" =~ ^[Yy]$ || -z "$stage_response" ]]; then
                git add .
                if ! git diff --cached --quiet; then
                    staged_diff=$(git diff --cached)
                    echo "✅ Changes staged successfully."
                else
                    echo "❌ No changes to stage."
                    exit 1
                fi
            else
                echo "Cannot generate branch name without staged changes."
                echo "Either stage changes first or create branch manually."
                echo "❌ Auto-commit cancelled. Stage changes manually and try again."
                exit 0
            fi
        fi
    else
        echo "No changes found (staged or unstaged)."
        echo "Create empty branch anyway? [Y/n]"
        read -r empty_branch_response
        if [[ "$empty_branch_response" =~ ^[Yy]$ || -z "$empty_branch_response" ]]; then
            echo "Enter branch name:"
            read -r manual_branch_name
            if [ -n "$manual_branch_name" ]; then
                if git switch -c "$manual_branch_name"; then
                    echo "✅ Created and switched to branch '$manual_branch_name'"
                    echo ""
                    exit 0
                else
                    echo "❌ Failed to create branch. Exiting."
                    exit 1
                fi
            else
                echo "No branch name provided. Staying on '$current_branch'."
                echo "❌ Auto-commit cancelled. No branch name provided."
                exit 0
            fi
        else
            echo "Staying on '$current_branch' branch."
            echo "❌ Auto-commit cancelled. Create changes and try again."
            exit 0
        fi
    fi
    
    # Branch creation with Ollama
    echo ""
    
    if [[ "$auto_branch" == true ]]; then
        echo "Auto-creating new branch..."
        create_branch_response="y"
    else
        echo "Create a new branch? [Y/n]"
        read -r create_branch_response
    fi
    
    if [[ "$create_branch_response" =~ ^[Yy]$ || -z "$create_branch_response" ]]; then
        echo "Generating branch name based on staged changes..."
        
        # Simplified prompt for local models
        branch_name_prompt="Generate a git branch name for these changes. Use format: type/description (e.g., feat/user-login, fix/memory-leak, docs/api-guide).

Examples:
- feat/user-authentication
- fix/login-timeout
- docs/api-documentation
- refactor/database-queries

Output only the branch name:

$(truncate_diff "$staged_diff")"
        
        # Generate branch name with Ollama
        generated_branch_name=$(call_ollama_generate "branch" "$branch_name_prompt" | tr -d '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        
        if [ $? -ne 0 ] || [ -z "$generated_branch_name" ]; then
            echo "Failed to generate branch name. Enter manually:"
            read -r manual_branch_name
            generated_branch_name="$manual_branch_name"
        fi
        
        # Branch creation confirmation loop
        if [[ "$auto_branch" == true ]]; then
            echo ""
            echo "Generated branch name: $generated_branch_name"
            echo ""
            if git switch -c "$generated_branch_name"; then
                echo "✅ Created and switched to branch '$generated_branch_name'"
                echo ""
            else
                echo "❌ Failed to create branch. Exiting."
                exit 1
            fi
        else
            # Interactive confirmation loop
            while true; do
                echo ""
                echo "Generated branch name: $generated_branch_name"
                echo ""
                echo "Create branch '$generated_branch_name'? [y/e/r/q] (yes / edit / regenerate / quit)"
                read -r branch_response
                
                case "$branch_response" in
                    [Yy]* )
                        if git switch -c "$generated_branch_name"; then
                            echo "✅ Created and switched to branch '$generated_branch_name'"
                            echo ""
                        else
                            echo "❌ Failed to create branch. Exiting."
                            exit 1
                        fi
                        break
                        ;;
                    [Ee]* )
                        echo "Enter new branch name:"
                        read -r manual_branch_name
                        if [ -n "$manual_branch_name" ]; then
                            generated_branch_name="$manual_branch_name"
                        fi
                        ;;
                    [Rr]* )
                        echo "Regenerating branch name..."
                        generated_branch_name=$(call_ollama_generate "branch" "$branch_name_prompt" | tr -d '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                        if [ $? -ne 0 ] || [ -z "$generated_branch_name" ]; then
                            echo "Failed to regenerate branch name."
                        fi
                        ;;
                    [Qq]* )
                        echo "Branch creation cancelled. Staying on '$current_branch'."
                        exit 0
                        ;;
                    * )
                        echo "Invalid option. Please choose 'y', 'e', 'r', or 'q'."
                        ;;
                esac
            done
        fi
    else
        echo "Continuing on '$current_branch' branch."
        echo ""
    fi
fi

# Main commit message generation logic
if ! git diff --cached --quiet; then
    display_repository_info
    
    # Get context information
    staged_diff=$(git diff --cached)
    recent_commits=$(git log --oneline --no-merges -5)
    repository_context=$(get_repository_context)
    
    user_feedback=""
    last_commit_msg=""
    should_generate=true

    while true; do
        if [ "$should_generate" = true ]; then
            echo "Staged files to be analyzed:"
            git diff --name-only --cached
            echo ""
            echo "🤖 Generating commit message with Ollama..."
            
            # Build optimized context
            context=$(build_context "$staged_diff" "$recent_commits" "$1" "$repository_context" "$ollama_context")
            
            # Enhanced prompt for local models with better guidance
            commit_prompt="You are a Git commit message generator. Analyze the changes and create a conventional commit message.

## STRICT REQUIREMENTS:
1. Use ONLY these types: feat, fix, docs, style, refactor, test, chore
2. Format: type(scope): description
3. Use imperative mood (add, fix, update, not added, fixed, updated)
4. Max 50 characters for the title line
5. Be specific about what changed, not just filenames
6. For complex changes, add detailed bullet points after a blank line

## SCOPE GUIDELINES:
- Use scope when changes affect specific areas: feat(auth):, fix(parser):, docs(api):
- For experimental/sub-projects: feat(experimental):, docs(ollama):
- Omit scope only for broad changes across multiple areas

## FORMAT RULES:
- **Simple changes**: Single line only
- **Complex changes**: Title line + blank line + bullet points (-)
- **Multiple files/features**: Always use detailed format
- **New features**: Always use detailed format

## SIMPLE EXAMPLES:
- fix(auth): resolve token validation bug
- docs(api): update endpoint documentation
- style(ui): fix button alignment

## DETAILED EXAMPLES:
- feat(ollama-experimental): add auto commit script for local AI workflows
  - Introduces automated Git commit message generation
  - Utilizes Ollama and Gemma models for local AI processing
  - Includes features for auto-staging and interactive refinement
  - Implements retry mechanisms and robust error handling

- refactor(parser): restructure JSON processing pipeline
  - Separates parsing logic from validation
  - Improves error handling and debugging
  - Adds support for streaming JSON processing

## BAD EXAMPLES (DON'T DO THIS):
- feat: add file (too vague)
- fix: bug fix (not specific)
- docs: update documentation (what documentation?)
- Added new feature (not imperative mood)

## ANALYSIS INSTRUCTIONS:
1. READ the actual file changes in the diff, not just filenames
2. FOCUS on the functionality/purpose of the changes
3. IDENTIFY the main area affected for scope
4. DESCRIBE what the change accomplishes for users/developers
5. For significant changes, explain the key features/improvements

Context:
$context

Commit message:"

            # Validate prompt length
            prompt_length=$(echo "$commit_prompt" | wc -c)
            debug_log "🔍 DEBUG: Full prompt length: $prompt_length characters"
            
            if [ $prompt_length -gt 8000 ]; then
                echo "⚠️  WARNING: Prompt is very long ($prompt_length chars), may exceed context limit"
                debug_log "🔍 DEBUG: Truncating context to fit within limits..."
                
                # Create a shorter context
                short_context="Repository: $(echo "$repository_context" | head -n 1)
Recent commits: $(echo "$recent_commits" | head -n 2)
User context: $1
Changes: $(echo "$staged_diff" | head -n 20)
... (truncated for token limits)"
                
                commit_prompt="Create a conventional commit message. Use type(scope): description format.

RULES:
1. Types: feat, fix, docs, style, refactor, test, chore
2. Use imperative mood (add, fix, update)
3. Max 50 chars for title, add bullet points for complex changes
4. Be specific about functionality, not just filenames

EXAMPLES:
Simple: fix(auth): resolve token validation bug
Complex: feat(ollama-experimental): add auto commit script
- Introduces automated Git commit message generation
- Utilizes Ollama and Gemma models for local AI processing

Context:
$short_context

Commit message:"
                
                debug_log "🔍 DEBUG: Shortened prompt length: $(echo "$commit_prompt" | wc -c) characters"
            fi
            
            # Add feedback if available
            if [ -n "$last_commit_msg" ]; then
                commit_prompt="$commit_prompt

## FEEDBACK INCORPORATION:
Previous attempt: $last_commit_msg

User feedback to incorporate:
$user_feedback

## IMPORTANT: 
- MUST address the specific feedback provided
- MUST improve the commit message based on user input
- MUST maintain conventional commit format
- MUST be more specific than the previous attempt

New commit message:"
            fi
            
            # Generate commit message with Ollama
            echo "📝 Calling Ollama to generate commit message..."
            raw_msg=$(call_ollama_generate "commit" "$commit_prompt")
            generation_exit_code=$?
            
            debug_log "🔍 DEBUG: Generation exit code: $generation_exit_code"
            debug_log "🔍 DEBUG: Raw message length: $(echo "$raw_msg" | wc -c) characters"
            debug_log "🔍 DEBUG: Raw message content: '$raw_msg'"
            debug_log ""
            
            if [ $generation_exit_code -ne 0 ] || [ -z "$raw_msg" ]; then
                echo "❌ Failed to generate commit message."
                echo ""
                echo "🔧 Troubleshooting steps:"
                echo "1. Check if Ollama service is running: ollama serve"
                echo "2. Verify model is available: ollama list | grep gemma3"
                echo "3. Test model manually: ollama run gemma3:4b 'hello'"
                echo "4. Check Ollama logs for errors"
                echo ""
                echo "You can commit manually with:"
                echo "git commit -m 'your commit message'"
                echo ""
                echo "Or try again with a simpler context by reducing the diff size."
                exit 1
            fi
            
            # Clean up the response
            last_commit_msg=$(echo "$raw_msg" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            
            # Create final message with attribution
            final_commit_msg="$last_commit_msg"
            final_commit_msg+=$'\n\n'"$ATTRIBUTION_FOOTER"
            
            should_generate=false
        fi

        echo "Generated commit message:"
        echo "$final_commit_msg"
        echo ""
        echo "Accept and commit? [Y/a/r/q] (yes / append / regenerate / quit)"
        read -r response

        case "$response" in
            [Yy]* | "" )
                git commit -m "$final_commit_msg"
                echo "Changes committed successfully!"

                echo ""
                echo "Do you want to push the changes now? [Y/n]"
                read -r push_response

                if [[ "$push_response" =~ ^[Yy]$ || -z "$push_response" ]]; then
                    current_branch=$(git branch --show-current)
                    if git rev-parse --abbrev-ref --symbolic-full-name @{u} >/dev/null 2>&1; then
                        git push
                    else
                        echo "No upstream branch found for '$current_branch'. Publishing to 'origin/$current_branch'..."
                        git push --set-upstream origin "$current_branch"
                    fi

                    if [ $? -eq 0 ]; then
                        echo "Changes pushed successfully!"
                        
                        # PR creation logic (same as original)
                        if [ -f "${script_dir}/auto_pr.zsh" ]; then
                            if [[ "$auto_pr" == true ]]; then
                                echo ""
                                echo "Creating pull request automatically..."
                                "${script_dir}/auto_pr.zsh" "$1"
                            else
                                echo ""
                                echo "Create a pull request? [Y/n]"
                                read -r pr_response
                                if [[ "$pr_response" =~ ^[Yy]$ || -z "$pr_response" ]]; then
                                    "${script_dir}/auto_pr.zsh" "$1"
                                fi
                            fi
                        fi
                    else
                        echo "Failed to push changes."
                    fi
                else
                    echo "Push cancelled. You can push manually later with 'git push'."
                fi
                break
                ;;
            [Aa]* )
                echo "Enter text to append:"
                read -r append_text
                if [ -n "$append_text" ]; then
                    last_commit_msg="$last_commit_msg"$'\n\n'"$append_text"
                    final_commit_msg="$last_commit_msg"
                    final_commit_msg+=$'\n\n'"$ATTRIBUTION_FOOTER"
                    echo "Text appended successfully."
                else
                    echo "No text entered, keeping original message."
                fi
                continue
                ;;
            [Rr]* )
                echo "Please provide feedback:"
                read -r feedback_input
                if [ -n "$feedback_input" ]; then
                    user_feedback+="- $feedback_input\n"
                fi
                echo "Regenerating commit message..."
                should_generate=true
                continue
                ;;
            [Qq]* )
                echo "Commit cancelled. You can commit manually with:"
                echo "git commit -m \"$final_commit_msg\""
                break
                ;;
            * )
                echo "Invalid option. Please choose 'y', 'a', 'r', or 'q'."
                ;;
        esac
    done
else
    # No staged changes logic (same as original)
    if [[ "$auto_stage" == true ]]; then
        echo "No staged changes found. Auto-staging all changes..."
        git add -A
        if ! git diff --cached --quiet; then
            echo "✅ All changes staged successfully."
            exec "$0" "$@"
        else
            echo "❌ No changes to stage."
            exit 1
        fi
    else
        echo "No staged changes found."
        echo "Do you want to stage all changes? [Y/n]"
        read -r stage_response

        if [[ "$stage_response" =~ ^[Yy]$ || -z "$stage_response" ]]; then
            git add .
            echo "All changes staged."
            exec "$0" "$@"
        else
            echo "No changes staged. Commit cancelled."
            exit 0
        fi
    fi
fi