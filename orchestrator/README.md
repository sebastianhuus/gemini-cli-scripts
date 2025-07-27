# Gemini CLI Orchestrator

A terminal-based chat interface built with Go and Bubble Tea, designed to orchestrate the existing Gemini CLI automation scripts.

## Features

- **Chat input** with non-blinking cursor
- **Slash command autocomplete** (`/commit`, `/pr`, `/issue`, `/help`, `/clear`)
- **Interactive help system** (press `?` to view keyboard shortcuts)
- **Responsive layout** that adapts to terminal width
- **Message history** with quote-style formatting

## Usage

```bash
cd orchestrator
go run main.go
```

## Keyboard Shortcuts

- `?` - Show/hide help
- `/` - Show slash command autocomplete
- `↑/↓` - Navigate suggestions
- `Tab/Enter` - Complete selected command
- `Backspace` (on empty input) - Exit current mode
- `Ctrl+C/Esc` - Quit

## Dependencies

- Go 1.19+
- [Bubble Tea](https://github.com/charmbracelet/bubbletea) - TUI framework
- [Bubbles](https://github.com/charmbracelet/bubbles) - UI components
- [Lip Gloss](https://github.com/charmbracelet/lipgloss) - Styling

## Architecture

The app uses the Elm Architecture pattern:
- **Model** - Application state (input, messages, suggestions, help mode)
- **Update** - Event handling (key presses, window resizing)
- **View** - Rendering the UI with responsive layout