# Ollama Experimental Implementation Guide

## Overview & Context

This document provides comprehensive guidelines for implementing local Ollama versions of the Gemini CLI scripts using Gemma models. The goal is to run AI-powered Git workflows locally without consuming cloud API tokens.

### Motivation
- **Cost Savings**: Eliminate token costs for frequent Git operations
- **Privacy**: Keep code and commit messages entirely local
- **Offline Capability**: Work without internet connectivity
- **Experimentation**: Test local AI capabilities for development workflows

### Trade-offs
- **Context Window**: Limited to ~2000 tokens (vs. larger cloud models)
- **Model Intelligence**: Lower capability compared to Gemini 2.5 Flash
- **Memory Requirements**: 2-4GB RAM per model instance
- **Processing Speed**: Potentially slower than cloud API calls

## Model Selection Strategy

### Available Gemma Models

#### Gemma 1b (gemma:1b)
- **Memory**: ~2GB RAM
- **Speed**: Fastest generation
- **Use Cases**: Simple commit messages, basic branch naming
- **Limitations**: May struggle with complex context analysis

#### Gemma 4b (gemma:4b)  
- **Memory**: ~3GB RAM
- **Speed**: Good balance
- **Use Cases**: Standard commit messages, PR descriptions
- **Limitations**: Limited reasoning for complex issues

#### Gemma 12b (gemma:12b)
- **Memory**: ~4GB RAM
- **Speed**: Moderate
- **Use Cases**: Complex PR descriptions, issue analysis
- **Limitations**: Higher memory requirements

#### Gemma 27b (gemma:27b)
- **Memory**: ~6GB RAM
- **Speed**: Slowest but highest quality
- **Use Cases**: Complex issue creation, detailed analysis
- **Limitations**: Significant memory requirements

### Model Selection Recommendations

```bash
# Task-based model selection
COMMIT_MESSAGE_MODEL="gemma:4b"      # Balance of speed and quality
BRANCH_NAME_MODEL="gemma:1b"         # Simple task, speed preferred
PR_DESCRIPTION_MODEL="gemma:12b"     # More complex, quality matters
ISSUE_OPERATIONS_MODEL="gemma:12b"   # Complex reasoning required
```

## Ollama Command Integration

### Basic Command Structure
Replace existing Gemini CLI calls:
```bash
# Current cloud implementation
gemini -m gemini-2.5-flash --prompt "$full_prompt"

# Ollama local implementation
ollama run gemma:4b "$full_prompt"
```

### API Endpoint Usage
For more control, use the REST API:
```bash
# Generate with API
curl -X POST http://localhost:11434/api/generate \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gemma:4b",
    "prompt": "'"$full_prompt"'",
    "stream": false,
    "options": {
      "temperature": 0.7,
      "top_p": 0.9
    }
  }'
```

### Error Handling Strategies
```bash
# Check if Ollama is running
if ! curl -s http://localhost:11434/api/tags > /dev/null; then
    echo "Ollama is not running. Please start it with: ollama serve"
    exit 1
fi

# Verify model availability
if ! ollama list | grep -q "gemma:4b"; then
    echo "Model gemma:4b not found. Install with: ollama pull gemma:4b"
    exit 1
fi

# Retry mechanism
retry_count=0
max_retries=3
while [ $retry_count -lt $max_retries ]; do
    if result=$(ollama run gemma:4b "$prompt"); then
        break
    fi
    retry_count=$((retry_count + 1))
    sleep 2
done
```

## Context Window Management

### 2000-Token Limit Strategies

#### 1. Input Truncation
```bash
# Truncate git diff to essential parts
truncate_diff() {
    local diff="$1"
    local max_lines=50
    
    # Keep file headers and first few lines of each file
    echo "$diff" | head -n $max_lines
    
    # Add indicator if truncated
    if [ $(echo "$diff" | wc -l) -gt $max_lines ]; then
        echo "... (diff truncated for context limit)"
    fi
}
```

#### 2. Context Prioritization
```bash
# Prioritize most important context elements
build_context() {
    local staged_diff="$1"
    local recent_commits="$2"
    local user_context="$3"
    
    # Essential context only
    context="Repository context: $(get_repository_context | head -n 3)"
    context+="\nRecent commits: $(echo "$recent_commits" | head -n 3)"
    context+="\nUser context: $user_context"
    context+="\nStaged changes: $(truncate_diff "$staged_diff")"
    
    echo "$context"
}
```

#### 3. Multi-pass Processing
```bash
# For complex tasks, break into smaller steps
generate_pr_description() {
    local commits="$1"
    
    # Step 1: Generate summary
    summary=$(ollama run gemma:4b "Summarize these commits in one sentence: $commits")
    
    # Step 2: Generate detailed description using summary
    description=$(ollama run gemma:4b "Create PR description for: $summary")
    
    echo "$description"
}
```

## Adaptation Strategies for Local Models

### 1. Simplified Prompts
```bash
# Cloud model (complex prompt)
cloud_prompt="Based on the following git diff and recent commit history, generate a concise, conventional commit message considering the development context and repository patterns..."

# Local model (simplified prompt)
local_prompt="Generate a conventional commit message for these changes:
$staged_diff

Format: type(scope): description
Examples:
- feat: add user authentication
- fix: resolve login timeout issue
- docs: update API documentation"
```

### 2. Explicit Instructions
```bash
# More explicit formatting requirements
local_prompt="Generate a commit message. Requirements:
1. Start with type: feat, fix, docs, style, refactor, test, or chore
2. Add colon and space after type
3. Write clear description (max 50 characters)
4. No code blocks or backticks
5. Output only the commit message

Changes:
$staged_diff

Commit message:"
```

### 3. Example-driven Prompts
```bash
# Include more examples for consistency
local_prompt="Generate a conventional commit message.

Examples:
- feat: add dark mode toggle
- fix: resolve memory leak in parser
- docs: update installation guide
- refactor: simplify authentication logic

Your turn - analyze these changes and generate a similar message:
$staged_diff

Message:"
```

## Testing & Evaluation Framework

### Output Comparison Tool
```bash
# Compare local vs cloud outputs
compare_outputs() {
    local prompt="$1"
    local cloud_output=$(gemini -m gemini-2.5-flash --prompt "$prompt")
    local local_output=$(ollama run gemma:4b "$prompt")
    
    echo "=== CLOUD OUTPUT ==="
    echo "$cloud_output"
    echo "=== LOCAL OUTPUT ==="
    echo "$local_output"
    echo "=== COMPARISON ==="
    
    # Use Gemini as evaluator
    evaluation_prompt="Compare these two outputs and rate the local version (1-10):
    
    Task: $prompt
    
    Cloud version: $cloud_output
    Local version: $local_output
    
    Rate the local version on:
    1. Accuracy (follows format)
    2. Relevance (addresses the task)
    3. Quality (professional tone)
    
    Provide a score (1-10) and brief explanation."
    
    gemini -m gemini-2.5-flash --prompt "$evaluation_prompt"
}
```

### Quality Metrics
- **Format Compliance**: Follows conventional commit format
- **Relevance**: Accurately describes the changes
- **Clarity**: Easy to understand
- **Consistency**: Similar output quality across runs

### Performance Benchmarking
```bash
# Measure generation speed and memory usage
benchmark_model() {
    local model="$1"
    local prompt="$2"
    
    echo "Benchmarking $model..."
    
    # Time the generation
    start_time=$(date +%s.%N)
    output=$(ollama run "$model" "$prompt")
    end_time=$(date +%s.%N)
    
    duration=$(echo "$end_time - $start_time" | bc)
    
    echo "Model: $model"
    echo "Duration: ${duration}s"
    echo "Output length: $(echo "$output" | wc -c) characters"
    echo "Memory usage: $(ps aux | grep ollama | awk '{print $6}' | head -1) KB"
}
```

## Implementation Guidelines

### Directory Structure
```
ollama-experimental/
├── auto_commit_ollama.zsh
├── auto_pr_ollama.zsh
├── auto_issue_ollama.zsh
├── ollama_context.zsh
├── ollama_config.zsh
├── benchmarks/
│   ├── compare_outputs.zsh
│   └── benchmark_models.zsh
└── tests/
    ├── test_commit_messages.zsh
    ├── test_pr_descriptions.zsh
    └── test_issue_operations.zsh
```

### Configuration Management
```bash
# ollama_config.zsh
DEFAULT_MODEL="gemma:4b"
COMMIT_MODEL="gemma:1b"
PR_MODEL="gemma:12b"
ISSUE_MODEL="gemma:12b"
BRANCH_MODEL="gemma:1b"

OLLAMA_HOST="http://localhost:11434"
MAX_CONTEXT_TOKENS=2000
RETRY_ATTEMPTS=3
TIMEOUT_SECONDS=30
```

### Attribution Updates
```bash
# Update attribution for local generation
attribution_footer="🤖 Generated locally with [Ollama](https://ollama.ai) using Gemma"
```

### Error Handling Improvements
```bash
# Enhanced error handling for local models
handle_ollama_error() {
    local exit_code=$1
    local model=$2
    
    case $exit_code in
        1)
            echo "Model $model not found. Install with: ollama pull $model"
            ;;
        2)
            echo "Ollama service not running. Start with: ollama serve"
            ;;
        3)
            echo "Generation timeout. Try with smaller model or reduce context."
            ;;
        *)
            echo "Unknown error with model $model. Check Ollama logs."
            ;;
    esac
}
```

## Installation & Setup

### Prerequisites
```bash
# Install Ollama
curl -fsSL https://ollama.ai/install.sh | sh

# Start Ollama service
ollama serve

# Pull required models
ollama pull gemma:1b
ollama pull gemma:4b
ollama pull gemma:12b
ollama pull gemma:27b
```

### Configuration
```bash
# Set environment variables
export OLLAMA_HOST="http://localhost:11434"
export OLLAMA_DEFAULT_MODEL="gemma:4b"
export OLLAMA_MAX_CONTEXT=2000
```

### Testing Installation
```bash
# Verify setup
./ollama-experimental/tests/test_setup.zsh

# Run basic functionality test
./ollama-experimental/auto_commit_ollama.zsh --test
```

## Performance Expectations

### Speed Comparisons
- **Cloud (Gemini 2.5 Flash)**: 1-3 seconds
- **Local (Gemma 1b)**: 2-5 seconds
- **Local (Gemma 4b)**: 3-8 seconds
- **Local (Gemma 12b)**: 5-15 seconds
- **Local (Gemma 27b)**: 10-30 seconds

### Memory Usage
- **Base Ollama**: ~500MB
- **+ Gemma 1b**: ~2GB total
- **+ Gemma 4b**: ~3GB total
- **+ Gemma 12b**: ~4GB total
- **+ Gemma 27b**: ~6GB total

### Quality Expectations by Model

#### Gemma 1b (2GB RAM, Fastest)
- **Commit Messages**: 80-90% of cloud quality
- **Branch Names**: 85-95% of cloud quality
- **Limitations**: Simple tasks only, may struggle with complex context

#### Gemma 4b (3GB RAM, Balanced)
- **Commit Messages**: 85-95% of cloud quality
- **Branch Names**: 90-95% of cloud quality
- **PR Descriptions**: 75-85% of cloud quality
- **Limitations**: Limited reasoning for complex issue operations

#### Gemma 12b (4GB RAM, Higher Quality)
- **Commit Messages**: 90-95% of cloud quality
- **Branch Names**: 95% of cloud quality
- **PR Descriptions**: 80-90% of cloud quality
- **Issue Operations**: 75-85% of cloud quality
- **Limitations**: Higher memory requirements, slower generation

#### Gemma 27b (6GB RAM, Best Quality)
- **Commit Messages**: 90-95% of cloud quality
- **Branch Names**: 95% of cloud quality
- **PR Descriptions**: 85-95% of cloud quality
- **Issue Operations**: 80-90% of cloud quality
- **Limitations**: Highest memory usage, slowest generation

#### Task Complexity Impact
- **Simple Tasks** (branch names, basic commits): Local models perform very well
- **Medium Tasks** (detailed commits, PR descriptions): Noticeable but acceptable quality gap
- **Complex Tasks** (issue analysis, multi-step operations): Significant quality difference, consider cloud fallback

## Migration Guide

### From Cloud to Local
1. Install Ollama and required models
2. Copy scripts to `ollama-experimental/`
3. Update model calls from `gemini` to `ollama`
4. Adjust prompts for local model capabilities
5. Test with existing repositories
6. Gradually migrate workflows

### Hybrid Approach
- Use local models for simple tasks (commits, branches)
- Fall back to cloud for complex operations (detailed issues)
- Implement automatic fallback on local model failures

## Future Enhancements

### Planned Features
- **Model Auto-selection**: Based on task complexity
- **Context Compression**: Intelligent truncation strategies
- **Fine-tuning**: Custom models for specific repositories
- **Caching**: Store common patterns for faster generation
- **Batch Processing**: Multiple operations in single session

### Integration Possibilities
- **MLX Support**: For Apple Silicon optimization
- **Custom Models**: Repository-specific fine-tuned models
- **Distributed Processing**: Multiple models for different tasks
- **Quality Feedback**: Learn from user corrections

This experimental implementation provides a foundation for exploring local AI-powered Git workflows while maintaining the core functionality of the original cloud-based scripts.