# Gemini CLI Orchestrator

Go/Bubble Tea interface for seamless integration with Gemini CLI automation scripts (`auto-commit`, `auto-pr`, `auto-issue`). Features natural script execution and conversation history preservation.

## Usage

```bash
go build -o gemini-orchestrator && ./gemini-orchestrator
```

## Script Integration

**Slash Commands:** `/commit fix bug`, `/pr resolves #123`, `/issue`  
**Zsh Mode:** Press `!` then run `auto-commit fix bug`, `auto-pr`, etc.

Scripts execute naturally with `tea.ExecProcess` - the orchestrator suspends during execution and automatically resumes with conversation history intact.

## Controls

- `?` - Help | `!` - Zsh mode | `/` - Slash commands
- `↑/↓` - Navigate | `Tab/Enter` - Select | `Backspace` - Exit mode
- `Ctrl+C` twice - Quit

## Dependencies

- Go 1.19+
- [Bubble Tea](https://github.com/charmbracelet/bubbletea) - TUI framework
- [Bubbles](https://github.com/charmbracelet/bubbles) - UI components
- [Lip Gloss](https://github.com/charmbracelet/lipgloss) - Styling

## Architecture

**Simplified Design:**
- Single process throughout session - no complex state persistence needed
- `tea.ExecProcess` handles script execution naturally
- Conversation history preserved in memory across script runs
- Clean exit handling with double Ctrl+C confirmation

**Elm Architecture Pattern:**
- **Model** - Application state (input, messages, suggestions, modes)
- **Update** - Event handling (key presses, commands, script execution)
- **View** - Responsive UI rendering with dynamic layout