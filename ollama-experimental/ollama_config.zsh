#!/usr/bin/env zsh

# Ollama Configuration for Local AI-Powered Git Workflows
# Based on OLLAMA_EXPERIMENTAL.md guidelines

# Model Configuration
# Task-specific model selection for optimal performance
DEFAULT_MODEL="gemma3:4b"
COMMIT_MODEL="gemma3:4b"      # Balance of speed and quality for commit messages
BRANCH_MODEL="gemma3:1b"      # Simple task, speed preferred for branch names
PR_MODEL="gemma3:12b-it-qat"         # More complex, quality matters for PR descriptions  
ISSUE_MODEL="gemma3:12b-it-qat"      # Complex reasoning required for issue operations

# Ollama Service Configuration
OLLAMA_HOST="http://localhost:11434"
OLLAMA_API_GENERATE="$OLLAMA_HOST/api/generate"
OLLAMA_API_TAGS="$OLLAMA_HOST/api/tags"

# Context Management
MAX_CONTEXT_TOKENS=2000      # Token limit for Gemma models
MAX_DIFF_LINES=50           # Maximum lines of git diff to include
MAX_COMMIT_HISTORY=3        # Maximum recent commits to include for context

# Performance Configuration
RETRY_ATTEMPTS=3            # Number of retry attempts for failed generations
TIMEOUT_SECONDS=30          # Timeout for model generation
TEMPERATURE=0.7             # Model temperature for balanced creativity/consistency
TOP_P=0.9                   # Top-p sampling for response diversity

# Attribution Configuration
ATTRIBUTION_FOOTER="🤖 Generated locally with [Ollama](https://ollama.ai) using Gemma"

# Context File Configuration
CONTEXT_FILE_NAME="OLLAMA.md"  # Repository-specific context file name
MAX_CONTEXT_SIZE=2048          # Maximum context file size in bytes

# Validation Configuration
REQUIRED_MODELS=("gemma3:1b" "gemma3:4b" "gemma3:12b-it-qat")  # Models required for full functionality

# Function to validate Ollama service availability
check_ollama_service() {
    if ! curl -s "$OLLAMA_API_TAGS" > /dev/null 2>&1; then
        echo "❌ Ollama service is not running."
        echo "Please start it with: ollama serve"
        return 1
    fi
    return 0
}

# Function to check if a model is available
check_model_availability() {
    local model="$1"
    if ! ollama list | grep -q "^$model"; then
        echo "❌ Model '$model' not found."
        echo "Install with: ollama pull $model"
        return 1
    fi
    return 0
}

# Function to validate all required models
validate_models() {
    local missing_models=()
    
    for model in "${REQUIRED_MODELS[@]}"; do
        if ! check_model_availability "$model" 2>/dev/null; then
            missing_models+=("$model")
        fi
    done
    
    if [ ${#missing_models[@]} -gt 0 ]; then
        echo "❌ Missing required models:"
        for model in "${missing_models[@]}"; do
            echo "  - $model"
        done
        echo ""
        echo "Install missing models with:"
        for model in "${missing_models[@]}"; do
            echo "  ollama pull $model"
        done
        return 1
    fi
    return 0
}

# Function to get model for specific task
get_model_for_task() {
    local task="$1"
    case "$task" in
        "commit")
            echo "$COMMIT_MODEL"
            ;;
        "branch")
            echo "$BRANCH_MODEL"
            ;;
        "pr")
            echo "$PR_MODEL"
            ;;
        "issue")
            echo "$ISSUE_MODEL"
            ;;
        *)
            echo "$DEFAULT_MODEL"
            ;;
    esac
}

# Function to setup Ollama environment
setup_ollama_environment() {
    echo "🔧 Setting up Ollama environment..."
    
    # Check service availability
    if ! check_ollama_service; then
        return 1
    fi
    
    # Validate models
    if ! validate_models; then
        return 1
    fi
    
    echo "✅ Ollama environment ready"
    return 0
}