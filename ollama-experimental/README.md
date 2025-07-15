# Ollama Experimental Implementation

This directory contains experimental versions of the Gemini CLI scripts that use Ollama with local Gemma models instead of cloud APIs.

## Files

- `auto_commit_ollama.zsh` - Local AI-powered commit message generation
- `ollama_config.zsh` - Configuration and model management
- `ollama_context.zsh` - Context loading utilities
- `OLLAMA.md` - Sample repository context file

## Prerequisites

1. Install Ollama:
   ```bash
   curl -fsSL https://ollama.ai/install.sh | sh
   ```

2. Start Ollama service:
   ```bash
   ollama serve
   ```

3. Install required models:
   ```bash
   ollama pull gemma3:1b
   ollama pull gemma3:4b
   ollama pull gemma3:12b-it-qat
   ```

## Usage

### Test Setup
```bash
./auto_commit_ollama.zsh --test
```

### Basic Usage
```bash
./auto_commit_ollama.zsh
```

### With Options
```bash
./auto_commit_ollama.zsh --stage --branch "fix login issue"
```

## Model Selection

- **gemma3:1b** - Branch names (fast, simple tasks)
- **gemma3:4b** - Commit messages (balanced speed/quality)
- **gemma3:12b-it-qat** - PR descriptions (higher quality)

## Context Management

The script looks for an `OLLAMA.md` file in the current directory or git root to provide repository-specific context to the AI models. This helps generate more relevant commit messages.

## Performance Expectations

- **Speed**: 3-8 seconds (vs 1-3 seconds for cloud)
- **Quality**: 85-95% of cloud model quality
- **Memory**: ~3GB RAM for gemma3:4b
- **Offline**: Works without internet connection

## Troubleshooting

1. **Service not running**: Start with `ollama serve`
2. **Model not found**: Install with `ollama pull gemma3:4b`
3. **Timeout errors**: Increase `TIMEOUT_SECONDS` in config
4. **Memory issues**: Use smaller models like `gemma3:1b`