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

🤖 Generated with [Gemini CLI](https://github.com/google-gemini/gemini-cli)