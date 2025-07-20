# Configuration System Design

## File Format: `.gemini-config`

Simple key=value format for easy parsing in zsh:

```bash
# Model Configuration
GEMINI_MODEL=gemini-2.5-flash

# Auto-commit Default Behaviors
AUTO_STAGE=false
AUTO_PR=false
AUTO_BRANCH=false
AUTO_PUSH=false
SKIP_ENV_INFO=false

# Auto-PR Default Behaviors
AUTO_PUSH_AFTER_PR=false

# Branch Naming Configuration
BRANCH_PREFIX_FEAT=feat/
BRANCH_PREFIX_FIX=fix/
BRANCH_PREFIX_DOCS=docs/
BRANCH_PREFIX_REFACTOR=refactor/
BRANCH_NAMING_STYLE=kebab-case
```

## Location Strategy (Priority Order)

1. `$PWD/.gemini-config` (repo-specific)
2. `$HOME/.config/gemini-cli/.gemini-config` (user global)  
3. `$script_dir/config/default.gemini-config` (system defaults)

## Implementation Plan

1. Create `config/config_loader.zsh` utility
2. Load config in each script before setting defaults
3. Override with command-line flags (flags take precedence)
4. Maintain backwards compatibility