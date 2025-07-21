# Gemini CLI Git Automation Scripts

This project provides a set of Zsh scripts designed to automate common Git workflows using the power of the Gemini AI.

## Why?

I ran out of Claude Code usage for the next few hours and figured I'd stop wasting tokens on getting it to commit its changes when Gemini CLI is free :) Both LLMs generate better commit messages and PRs much faster than what I could do. 
Telling Gemini to check files and commit changes on its own tends to be very slow compared to CC, so I figured it was faster to just pipe all the relevant info into Gemini and have it generate directly instead of wasting time (and tokens) on letting it find discover context by itself.

### Why is it hard coded to use 2.5 Flash?
I was enjoying Gemini CLI in my Claude Code downtime and was notified that I had hit my 2.5 Pro usage limits after ~5 messages - but how? 

> 🥁🥁🥁🥁🥁

All these commit messages and PRs I had made with Gemini had drained my usage quota!
So I opted for using Flash instead. It is still a very capable model with a good context window, so explaining code diffs should not be an issue for it even if it does not have project specific knowledge.

## Features

### `auto_commit.zsh`
- **Automated Commit Message Generation**: Generates concise and conventional Git commit messages based on staged changes and recent commit history using Gemini.
- **Interactive Feedback Loop**: Allows users to provide feedback to regenerate commit messages for improved accuracy.
- **Staging Assistant**: Prompts to stage all changes if no changes are currently staged.
- **Optional Push**: Offers to push changes to the remote repository after a successful commit.

### `auto_pr.zsh`
- **Automated Pull Request Creation**: Generates pull request titles and descriptions based on the commit history between the current branch and the base branch (main/master) using Gemini.
- **Issue Reference Inclusion**: Automatically includes relevant issue references (e.g., `resolves #123`, `fixes #456`) found in commit messages.
- **GitHub CLI Integration**: Integrates with the GitHub CLI (`gh`) to create pull requests directly from the command line.

### `auto_issue.zsh`
- **Natural Language GitHub Issue Management**: Processes conversational requests and converts them to GitHub operations using advanced NLP capabilities.
- **Two-Stage Processing**: First converts questions to commands, then parses intent to extract structured operation data.
- **Multi-Operation Support**: Handles create, edit, comment, view, and other issue operations through natural language.
- **LLM-Enhanced Content Generation**: Uses Gemini to generate professional issue titles, descriptions, and comments with repository context.
- **Interactive Confirmation**: Validates and confirms all operations before execution to prevent mistakes.
- **Smart Parameter Extraction**: Automatically extracts issue numbers, content, and operation types from natural language input.

### `gemini_context.zsh` & `GEMINI.md`
- **Repository Context System**: Automatically loads project-specific context from `GEMINI.md` to enhance AI understanding.
- **Context Discovery**: Searches for `GEMINI.md` in current directory and git root for flexible usage.
- **Token Optimization**: Limits context size to prevent token overuse while maintaining effectiveness.
- **Enhanced AI Responses**: Provides coding conventions, project structure, and architectural guidance to improve generated content.

### Optional parameters
All scripts allow you to pass an optional prompt to tell Gemini what to do. E.g "This commit resolves #55" will tell it to include that comment in its commit message.

## Natural Language Processing Features

The `auto_issue.zsh` script introduces advanced NLP capabilities that allow you to interact with GitHub issues using natural, conversational language. This represents a significant evolution from simple command-line tools to an intelligent assistant that understands context and intent.

### Two-Stage Processing Architecture

#### Stage 1: Question Detection & Conversion
The system first analyzes your input to determine if it's a conversational request (like "Can you help me create an issue?") and converts it to a direct command format. This allows for both polite, natural requests and direct instructions.

**Examples:**
- "Can you create an issue about the login bug?" → "create issue about login bug"
- "I need to add a comment to issue 5" → "comment on issue 5"

#### Stage 2: Intent Parsing
The converted command is then analyzed to extract:
- **Operation type**: create, edit, comment, view, etc.
- **Target**: issue number, title, or description
- **Content**: what to say or change
- **Context**: additional parameters and requirements

### Supported Natural Language Patterns

#### Issue Creation
```bash
./auto_issue.zsh "create issue about dark mode toggle"
./auto_issue.zsh "I need to report a bug with user authentication"
./auto_issue.zsh "create new issue: API rate limiting problems"
```

#### Issue Management
```bash
./auto_issue.zsh "comment on issue 5 that the fix is deployed"
./auto_issue.zsh "edit issue 13 title to say Bug: Login timeout"
./auto_issue.zsh "add comment to issue #8: this has been resolved"
```

#### Content Generation
When creating issues or comments, the system:
- Analyzes your brief description
- Generates professional, detailed content
- Includes relevant technical context
- Follows repository conventions from `GEMINI.md`
- Maintains consistent formatting and tone

### Interactive Workflow
1. **Input Processing**: Your natural language request is analyzed
2. **Intent Confirmation**: The system shows what it understood and asks for confirmation
3. **Content Generation**: If needed, Gemini generates professional content
4. **Final Confirmation**: You review and approve before execution
5. **Execution**: The GitHub CLI command is executed

This approach ensures accuracy while maintaining the convenience of natural language interaction.

## Configuration System

The Gemini CLI scripts include a sophisticated configuration system that allows you to customize default behaviors, avoid repetitive command-line flags, and maintain consistent settings across projects and team members.

### Why Use Configuration?

**Convenience**: Set your preferred workflows once instead of passing the same flags repeatedly:
```bash
# Without config - repetitive flags
auto-commit -s -b -p "fix login bug"
auto-commit -s -b -p "add dark mode"

# With config - clean commands  
auto-commit "fix login bug"
auto-commit "add dark mode"
```

**Team Consistency**: Share repository-specific configurations to standardize workflows across your team.

**Personal Optimization**: Configure global defaults that match your development style.

### Configuration Priority System

The configuration system uses a 3-tier priority hierarchy:

1. **Repository-specific** (highest priority): `.gemini-config` in project root
2. **User global**: `~/.config/gemini-cli/.gemini-config`  
3. **System defaults** (lowest priority): `config/default.gemini-config`

Settings in higher-priority files override those in lower-priority files.

### Quick Setup: Interactive Config Generator

Generate a personalized configuration using the interactive tool:

```bash
# Run the configuration generator
./utils/config_generator.zsh

# Or if installed via PATH
cd /path/to/gemini-cli-scripts && ./utils/config_generator.zsh
```

The generator guides you through:

**Workflow Presets:**
- **Conservative**: Manual confirmations for all actions (safest)
- **Balanced**: Auto-stage changes, manual PR/push decisions (recommended)
- **Fast**: Minimize prompts, auto-stage and auto-branch
- **Custom**: Configure each setting individually

**Model Selection:**
- `gemini-2.5-flash`: Fast and efficient (recommended)
- `gemini-2.5-pro`: More capable but may have usage limits
- Custom model names

**Configuration Location:**
- Repository-specific (recommended for project-specific workflows)
- User-wide (affects all your projects)

### Available Configuration Settings

#### Model Configuration
```bash
GEMINI_MODEL=gemini-2.5-flash  # AI model for all operations
```

#### Auto-Commit Behaviors
```bash
AUTO_STAGE=false              # Auto-stage changes before commit generation
AUTO_BRANCH=false             # Auto-create branches without confirmation  
AUTO_PR=false                 # Auto-create PRs after successful commits
AUTO_PUSH=false               # Auto-push changes after commits
SKIP_ENV_INFO=false           # Skip repository info display
```

#### Auto-PR Behaviors
```bash
AUTO_PUSH_AFTER_PR=false      # Auto-push after creating PRs
```

#### Branch Naming (Future Feature)
```bash
BRANCH_PREFIX_FEAT=feat/      # Prefix for feature branches
BRANCH_PREFIX_FIX=fix/        # Prefix for bug fix branches  
BRANCH_PREFIX_DOCS=docs/      # Prefix for documentation branches
BRANCH_PREFIX_REFACTOR=refactor/  # Prefix for refactoring branches
BRANCH_NAMING_STYLE=kebab-case    # Branch naming convention
```

*Note: Branch naming configuration is prepared for future implementation but not yet active in the current version.*

### Manual Configuration

#### Repository-Specific Configuration
Create `.gemini-config` in your project root:

```bash
# Example: Fast development workflow
GEMINI_MODEL=gemini-2.5-flash
AUTO_STAGE=true
AUTO_BRANCH=true
AUTO_PUSH=true
AUTO_PR=false
```

#### User Global Configuration
Create `~/.config/gemini-cli/.gemini-config`:

```bash
# Example: Conservative personal defaults
GEMINI_MODEL=gemini-2.5-flash
AUTO_STAGE=false
AUTO_BRANCH=false
AUTO_PUSH=false
AUTO_PR=false
SKIP_ENV_INFO=false
```

### Configuration Examples

**Team Development Workflow** (`.gemini-config` in project root):
```bash
# Consistent team settings
GEMINI_MODEL=gemini-2.5-flash
AUTO_STAGE=true              # Always stage changes
AUTO_BRANCH=false            # Manual branch creation for safety
AUTO_PR=false                # Manual PR creation for review
AUTO_PUSH=false              # Manual push for control
```

**Fast Personal Development** (`~/.config/gemini-cli/.gemini-config`):
```bash
# Optimized for speed
GEMINI_MODEL=gemini-2.5-flash
AUTO_STAGE=true
AUTO_BRANCH=true
AUTO_PUSH=true
AUTO_PR=false                # Still want PR control
SKIP_ENV_INFO=true           # Skip info display
```

**Conservative Workflow**:
```bash
# Maximum safety and control
GEMINI_MODEL=gemini-2.5-flash
AUTO_STAGE=false             # Manual staging
AUTO_BRANCH=false            # Manual branch creation
AUTO_PR=false                # Manual PR creation
AUTO_PUSH=false              # Manual push
```

### Overriding Configuration

Command-line flags always override configuration settings:

```bash
# Even with AUTO_STAGE=false in config, this will auto-stage
auto-commit -s "emergency fix"

# Configuration is ignored when explicit flags are provided
auto-commit -s -b -pr -p "feature complete"
```

## Technical Documentation

For developers and contributors interested in the internal architecture, utility functions, and development guidelines, see the comprehensive technical documentation in [utils/README.md](utils/README.md).

## Usage

### Requirements
- Zsh shell
- Git
- [Gemini CLI](https://github.com/google-gemini/gemini-cli) (configured with API access)
- [GitHub CLI](https://cli.github.com/) (`gh`) (for PR and issue functionality)
- [Charmbracelet Gum](https://github.com/charmbracelet/gum) (optional, for enhanced UI)

### Installation

#### Option 1: System-wide Installation (Recommended)
Install scripts to your PATH for use from anywhere:

```bash
# Clone the repository
git clone https://github.com/sebastianhuus/gemini-cli-scripts.git
cd gemini-cli-scripts

# Run the installer
chmod +x install.zsh
./install.zsh
```

This creates symlinks in `/usr/local/bin`, allowing you to use the scripts from any directory:

```bash
# Use from anywhere on your system
cd ~/any/project
auto-commit "fix login bug"
auto-pr "resolves #123"
auto-issue "create issue about dark mode"
```

#### Option 2: Git Submodule (For Project-specific Use)
Add as a submodule to individual projects:

```bash
git submodule add https://github.com/sebastianhuus/gemini-cli-scripts.git scripts
cd scripts
chmod +x *.zsh

# Use with relative paths
./auto_commit.zsh "fix login bug"
```

Update submodules: `git submodule update --remote`

### Basic Usage

#### `auto-commit` - Smart Commit Message Generation
```bash
# Basic usage
auto-commit

# With context
auto-commit "fixes issue #123"

# Options
auto-commit -s          # Auto-stage all changes
auto-commit -b          # Auto-create new branch
auto-commit -pr         # Auto-create PR after commit
auto-commit -p          # Auto-push after commit
auto-commit -s -b -pr   # Combine multiple options
```

#### `auto-pr` - Pull Request Creation
```bash
# Generate PR from current branch
auto-pr

# With additional context
auto-pr "resolves #123 and improves performance"
```

#### `auto-issue` - Natural Language Issue Management
```bash
# Create issues
auto-issue "create issue about dark mode implementation"
auto-issue "I need to report a bug with user authentication"

# Comment on issues  
auto-issue "comment on issue 15 that the bug is fixed"
auto-issue "add comment to issue #8: this has been resolved"

# Edit issues
auto-issue "edit issue 13 title to say Bug: Login timeout"

# View help
auto-issue --help
```

### Advanced Features

#### Command Options
All scripts support various flags for automation:

**`auto-commit` options:**
- `-s, --stage` - Automatically stage all changes
- `-b, --branch` - Auto-create new branch without confirmation  
- `-pr, --pr` - Auto-create pull request after commit
- `-p, --push` - Auto-push changes after commit

**Combine for full automation:**
```bash
auto-commit -s -b -pr -p "implement user dashboard"
```

#### Context System (`GEMINI.md`)
Scripts automatically load project-specific context to enhance AI understanding:

- **Auto-discovery** - Finds `GEMINI.md` in current directory or git root
- **Enhanced responses** - Provides project structure and conventions  
- **Token optimization** - Limits context size for efficiency

Create a `GEMINI.md` file in your repository with:
- Project overview and architecture
- Coding conventions and standards  
- Common patterns and practices

### Example Usage: `auto_commit.zsh`

```
sebastian.huus@Mac gemini-cli-scripts % '/Users/sebastian.huus/Documents/Github/gemini-cli-scripts/auto_commit.zsh'
Staged files to be shown to Gemini:
README.md
Generated commit message:
docs: Add 'How to Use' section to README

- Introduce a new section for detailed usage instructions.
- Include a placeholder for future content on setup, configuration, and workflows.

 Generated with [Gemini CLI](https://github.com/google-gemini/gemini-cli)

Accept and commit? [y/r/q] (yes / regenerate with feedback / quit)

>y

[main 60caa4e] docs: Add 'How to Use' section to README
 1 file changed, 4 insertions(+)
Changes committed successfully!

Do you want to push the changes now? [y/N]

>y

Enumerating objects: 5, done.
Counting objects: 100% (5/5), done.
Delta compression using up to 12 threads
Compressing objects: 100% (3/3), done.
Writing objects: 100% (3/3), 672 bytes | 672.00 KiB/s, done.
Total 3 (delta 1), reused 0 (delta 0), pack-reused 0 (from 0)
remote: Resolving deltas: 100% (1/1), completed with 1 local object.
To https://github.com/sebastianhuus/gemini-cli-scripts.git
   1dccbc5..60caa4e  main -> main
Changes pushed successfully!
```

### Example Usage: `auto_pr.zsh`

```
sebastian.huus@Mac gemini-cli-scripts % '/Users/sebastian.huus/Documents/Github/gemini-cli-scripts/auto_pr.zsh'
Found commits to include in PR:
bda4e61 docs: Detail auto_commit.zsh usage in README

Generated PR content:
TITLE: docs: Detail auto_commit.zsh usage in README

DESCRIPTION:
- Provide a detailed example of `auto_commit.zsh` usage.
- Include a full terminal session output to illustrate script interaction.
- Clarify how to run Zsh scripts by dragging them into the terminal.

Do you want to create the PR with this content? [y/N]
y
Pushing current branch to remote...
Enumerating objects: 5, done.
Counting objects: 100% (5/5), done.
Delta compression using up to 12 threads
Compressing objects: 100% (3/3), done.
Writing objects: 100% (3/3), 1.29 KiB | 1.29 MiB/s, done.
Total 3 (delta 1), reused 0 (delta 0), pack-reused 0 (from 0)
remote: Resolving deltas: 100% (1/1), completed with 1 local object.
remote: 
remote: Create a pull request for 'demonstrate-auto-pr' on GitHub by visiting:
remote:      https://github.com/sebastianhuus/gemini-cli-scripts/pull/new/demonstrate-auto-pr
remote: 
To https://github.com/sebastianhuus/gemini-cli-scripts.git
 * [new branch]      demonstrate-auto-pr -> demonstrate-auto-pr
branch 'demonstrate-auto-pr' set up to track 'origin/demonstrate-auto-pr'.

Creating pull request for demonstrate-auto-pr into main in sebastianhuus/gemini-cli-scripts

https://github.com/sebastianhuus/gemini-cli-scripts/pull/1
Pull request created successfully!
```

🤖 Generated with [Gemini CLI](https://github.com/google-gemini/gemini-cli)