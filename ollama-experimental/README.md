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

### Debug Mode
```bash
./auto_commit_ollama.zsh --debug
```

## Model Selection

- **gemma3:1b** - Branch names (fast, simple tasks)
- **gemma3:4b** - Commit messages (balanced speed/quality)
- **gemma3:12b-it-qat** - PR descriptions (higher quality)

## Performance Expectations

- **Speed**: 3-8 seconds (vs 1-3 seconds for cloud)
- **Quality**: 85-95% of cloud model quality
- **Memory**: ~3GB RAM for gemma3:4b
- **Offline**: Works without internet connection

## Key Findings from Prototype Testing

### Commit Message Quality Comparison

**Cloud vs Local Model Performance:**

#### Gemini 2.5 Flash (Cloud) - Excellent Context Analysis
```
refactor(ollama-experimental): improve JSON parsing and remove jq dependency
- Replaced custom JSON parsing with Python-based extraction for robustness.
- Removed `jq` as a dependency for JSON processing.
- Enhanced response cleaning, including markdown code block removal.
- Updated commit message generation rules within the script.
```

#### Gemma3 4b (Local) - Good Feature Overview
```
feat(ollama-experimental): add auto commit script for local AI workflows
- Introduces automated Git commit message generation using Ollama and Gemma.
- Extracts JSON responses from Ollama API interactions using Python.
- Implements auto-staging, branch creation, and interactive commit message refinement.
- Includes retry mechanisms and robust error handling for Ollama API interactions.
```

### Analysis

**Cloud Model Strengths:**
- ✅ **Precise change analysis** - Correctly identified this as a `refactor` of existing code
- ✅ **Technical accuracy** - Mentioned specific changes (jq removal, Python replacement)
- ✅ **Context awareness** - Understood this was improving existing functionality
- ✅ **Specific details** - Included "markdown code block removal"

**Local Model Strengths:**
- ✅ **Comprehensive feature description** - Excellent overview of script capabilities
- ✅ **User-focused content** - Describes what the script accomplishes
- ✅ **Good technical details** - Mentions Python, API interactions, retry mechanisms
- ✅ **Well-structured bullets** - Clear breakdown of functionality

**Local Model Areas for Improvement:**
- ❌ **Change vs feature confusion** - Used `feat` instead of `refactor`
- ❌ **Context interpretation** - Described overall script purpose rather than specific changes
- ❌ **Commit focus** - Analyzed "what does this code do" instead of "what changed"

### Recommendations for Local Model Optimization

1. **Prompt Enhancement**:
   - Emphasize analyzing specific changes made in this commit
   - Include examples distinguishing `feat` vs `refactor` vs `fix`
   - Add guidance on focusing on deltas rather than overall functionality

2. **Context Management**:
   - Provide better diff analysis instructions
   - Include examples of before/after scenarios
   - Emphasize reading the actual changes, not just file contents

3. **Model Selection**:
   - Use `gemma3:4b` for balanced performance (current default)
   - Consider `gemma3:12b-it-qat` for complex refactoring analysis
   - `gemma3:1b` sufficient for simple changes only

### Conclusion

Local models can produce **very good commit messages** (85-95% of cloud quality) but require:
- **More specific prompting** about analyzing changes vs describing features
- **Better examples** showing commit type distinctions
- **Enhanced context guidance** for change analysis

The prototype demonstrates that **local AI-powered development workflows are viable** with proper prompt engineering and model selection.

## Future Development Ideas

### Multi-Pass Processing Architecture

A promising approach for improving local model performance would be implementing a **two-pass system** that leverages different model strengths:

#### Pass 1: High-Level Analysis (Fast Model)
```bash
# Use gemma3:1b or gemma3:4b for quick analysis
ollama run gemma3:4b "Analyze this git diff and provide:
1. High-level summary of changes
2. Type of change (feat/fix/refactor/docs/etc)
3. Main areas affected
4. Key technical modifications"
```

#### Pass 2: Detailed Message Generation (Quality Model)
```bash
# Use gemma3:12b-it-qat with enriched context
ollama run gemma3:12b-it-qat "Generate a conventional commit message using:
- Summary: [Pass 1 output]
- Change type: [Pass 1 analysis]
- Technical details: [Pass 1 findings]
- Full diff context: [original diff]"
```

### Benefits of Multi-Pass Approach

1. **Improved Context Understanding**:
   - First pass provides structured analysis
   - Second pass works with pre-digested information
   - Reduces complexity for final generation

2. **Better Change Type Detection**:
   - Dedicated analysis step for feat vs refactor vs fix
   - Separate reasoning about scope and impact
   - More accurate conventional commit typing

3. **Enhanced Technical Accuracy**:
   - First pass identifies key technical changes
   - Second pass incorporates specific details
   - Combines broad understanding with precise descriptions

4. **Performance Optimization**:
   - Use faster models for analysis tasks
   - Reserve expensive models for final generation
   - Total time similar to single large model call

### Implementation Considerations

- **Cost vs Quality**: Two API calls vs one, but potentially better results
- **Error Handling**: Fallback strategies when first pass fails
- **Context Size**: Managing token limits across passes
- **Caching**: Store first pass results for regeneration requests

This multi-pass architecture could bridge the gap between local model capabilities and cloud model performance for complex code analysis tasks.

## Context Management

The script looks for an `OLLAMA.md` file in the current directory or git root to provide repository-specific context to the AI models. This helps generate more relevant commit messages.

## Troubleshooting

1. **Service not running**: Start with `ollama serve`
2. **Model not found**: Install with `ollama pull gemma3:4b`
3. **Timeout errors**: Increase `TIMEOUT_SECONDS` in config
4. **Memory issues**: Use smaller models like `gemma3:1b`
5. **JSON parsing errors**: Ensure Python3 is installed
6. **Escape character issues**: The script uses Python-based JSON processing to handle all special characters correctly