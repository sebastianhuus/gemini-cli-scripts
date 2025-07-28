# Project Context for Gemini CLI Scripts

This repository contains a set of Zsh scripts that leverage the Gemini CLI to automate common Git and GitHub workflows. It also includes a Go-based TUI orchestrator for a more interactive experience.

## Key Information
- **Languages**: Zsh, Go
- **Key Technologies**: Gemini CLI, GitHub CLI (gh), Git, Bubble Tea (for TUI)
- **Primary Goal**: To streamline the development workflow by automating commit message generation, pull request creation, and issue management.
- **Attribution**: All generated content includes "🤖 Generated with Gemini CLI" footer.

## Project Structure

- **`/` (Root)**
  - `auto_commit.zsh`: Script for automated commit message generation.
  - `auto_pr.zsh`: Script for automated pull request creation.
  - `auto_issue.zsh`: Script for natural language GitHub issue management.
  - `install.zsh`: Installation script for the tools.
  - `README.md`: Main project documentation.
  - `GEMINI.md`: This file, providing context for the LLM.

- **`/.claude/`**: Configuration for the Claude AI (not directly used by the Gemini scripts).

- **`/config/`**: Contains the configuration files for the scripts.
  - `config_loader.zsh`: Loads the configuration from the `.gemini-config` files.
  - `default.gemini-config`: The default configuration for the scripts.

- **`/gum/`**: Helper scripts for the `gum` TUI.

- **`/orchestrator/`**: The Go-based TUI orchestrator.
  - `main.go`: The entry point for the orchestrator application.
  - `internal/`: Contains the internal logic for the orchestrator.
    - `commands/`: Command handlers for the TUI.
    - `models/`: Data models for the application.
    - `ui/`: TUI rendering and styling.
    - `utils/`: Utility functions.

- **`/test/`**: Test scripts for the Zsh utilities.

- **`/utils/`**: Shared utility scripts.
  - `core/`: Core utilities, including the `gemini_context.zsh` script for loading this file.
  - `generators/`: Scripts that generate content using the Gemini CLI (e.g., commit messages, PR descriptions).
  - `git/`: Git and GitHub related helper functions.
  - `ui/`: UI related helper functions, using `gum`.

## Core Scripts

- **`auto_commit.zsh`**:
  - Generates commit messages from staged changes.
  - Can automatically stage changes, create a new branch, push, and create a PR.
  - Uses `gum` for interactive prompts.

- **`auto_pr.zsh`**:
  - Creates a GitHub pull request with a title and description generated from the branch's commits.
  - Can automatically push the branch and create the PR.

- **`auto_issue.zsh`**:
  - A menu-driven tool for managing GitHub issues.
  - Supports creating, viewing, editing, and commenting on issues.
  - Uses natural language to generate issue content.

- **Orchestrator (`orchestrator/main.go`)**:
  - A Go application that provides a Bubble Tea-based TUI for running the scripts.
  - Offers a chat-like interface with slash commands and a "Zsh mode".

## Coding Conventions
- Use conventional commit messages (e.g., `feat:`, `fix:`, `docs:`).
- Branch names should be in kebab-case with a category prefix (e.g., `feat/new-feature`, `fix/bug-fix`).
- All generated content should be professional in tone.
- Scripts should handle errors gracefully.

## Dependencies
- **Git**
- **GitHub CLI (`gh`)**
- **Gemini CLI (`gemini`)**
- **Go** (for the orchestrator)
- **Gum** (for the TUI elements in the Zsh scripts)
