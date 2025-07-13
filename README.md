# Gemini CLI Git Automation Scripts

This project provides a set of Zsh scripts designed to automate common Git workflows using the power of the Gemini AI.

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

## Usage

To use these scripts, ensure you have the `gemini` command-line tool installed and configured, as well as the GitHub CLI (`gh`) for `auto_pr.zsh`.

### `auto_commit.zsh`
```bash
./auto_commit.zsh [optional_additional_context]
```
Run this script in your Git repository when you have staged changes. It will propose a commit message and guide you through the commit process.

### `auto_pr.zsh`
```bash
./auto_pr.zsh [optional_additional_context]
```
Run this script on a feature branch to generate and create a pull request. It will analyze your commit history and suggest a PR title and description.

## Requirements
- Zsh shell
- Git
- Gemini command-line tool (configured with access to Gemini models)
- GitHub CLI (`gh`) (for `auto_pr.zsh` functionality)

## How to Use

To run the scripts, simply drag the `.zsh` file into your terminal window (e.g., in VS Code or iTerm2) and press Enter. This will execute the script directly.

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