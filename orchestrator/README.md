# Gemini CLI Orchestrator

Go/Bubble Tea interface for seamless integration with Gemini CLI automation scripts (`auto-commit`, `auto-pr`, `auto-issue`). Features state persistence and clean TUI separation.

## Usage

```bash
go build -o gemini-orchestrator && ./gemini-orchestrator
```

## Script Integration

**Slash Commands:** `/commit fix bug`, `/pr resolves #123`, `/issue`  
**Zsh Mode:** Press `!` then run `auto-commit fix bug`, `auto-pr`, etc.

Both methods maintain conversation history across script executions.

## Controls

- `?` - Help | `!` - Zsh mode | `/` - Slash commands
- `↑/↓` - Navigate | `Tab/Enter` - Select | `Backspace` - Exit mode
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