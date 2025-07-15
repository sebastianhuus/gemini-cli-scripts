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

## Usage

To use these scripts, ensure you have the necessary tools installed and configured.

### Requirements
- Zsh shell
- Git
- Gemini command-line tool (configured with access to Gemini models)
- GitHub CLI (`gh`) (for `auto_pr.zsh` and `auto_issue.zsh` functionality)

### Installation
I recommend installing this repository as a git submodule in your own project. 

`git submodule add https://github.com/sebastianhuus/gemini-cli-scripts.git <path_to_your_scripts>`

This lets you keep these out of your main repo code and reuse it elsewhere.

To pull updates from this repo, run

`git submodule update --remote`

#### Files in this repository:
- `auto_commit.zsh` - Automated commit message generation
- `auto_pr.zsh` - Pull request creation automation
- `auto_issue.zsh` - Natural language GitHub issue management
- `gemini_context.zsh` - Context utility for loading project context
- `GEMINI.md` - Example project context file
- `CLAUDE.md` - Instructions for Claude Code integration

### Running the Scripts

To run the scripts, simply drag the `.zsh` file into your terminal window (e.g., in VS Code or iTerm2) and press Enter. This will execute the script directly. They use git and Github CLI under the hood, so commands will be called on your repository based on your terminal's current working directory. 

#### `auto_commit.zsh`
```bash
./auto_commit.zsh [optional_additional_context]
```
Run this script in your Git repository when you have staged changes. It will propose a commit message and guide you through the commit process.

#### `auto_pr.zsh`
```bash
./auto_pr.zsh [optional_additional_context]
```
Run this script on a feature branch to generate and create a pull request. It will analyze your commit history and suggest a PR title and description.

#### `auto_issue.zsh`
```bash
./auto_issue.zsh "natural language request"
./auto_issue.zsh --help
```
Run this script anywhere in your Git repository to manage GitHub issues through natural language. It supports creating, editing, commenting on, and viewing issues using conversational commands.

**Natural Language Examples:**
```bash
./auto_issue.zsh "create issue about dark mode implementation"
./auto_issue.zsh "comment on issue 15 that the bug is fixed"
./auto_issue.zsh "edit issue 8 title to include severity level"
./auto_issue.zsh "I need to report a performance issue with the API"
```

### Context System (`GEMINI.md`)

The scripts automatically load project-specific context from a `GEMINI.md` file to enhance AI understanding. This system:

- **Automatically discovers** `GEMINI.md` in your current directory or git root
- **Provides context** about your project structure, conventions, and preferences
- **Improves AI responses** by giving Gemini relevant background information
- **Optimizes tokens** by limiting context size while maintaining effectiveness

To use the context system, create a `GEMINI.md` file in your repository root with:
- Project overview and architecture
- Coding conventions and standards
- Common patterns and practices
- Any specific guidance for AI-generated content

The context is automatically loaded by `auto_issue.zsh` and can be leveraged by other scripts as needed.

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

### Known Issue: Gemini Response Trimming

Occasionally, the Gemini model might include an extraneous line (e.g., related to authentication methods) at the beginning of its response. To mitigate this, our scripts trim the first line of every Gemini output. In cases where Gemini *does not* include this extra line, the trimming might result in an empty or truncated message.

**Workaround**: If you encounter an empty or incomplete message, simply choose the 'regenerate with feedback' option (`r`) and Gemini will typically provide a complete response on the next attempt. You can also explicitly ask Gemini to add a new line at the start of its response if this issue persists.

🤖 Generated with [Gemini CLI](https://github.com/google-gemini/gemini-cli)