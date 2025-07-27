package main

import (
	"fmt"
	"log"
	"os"
	"strings"

	"github.com/charmbracelet/bubbles/cursor"
	"github.com/charmbracelet/bubbles/textinput"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

var (
	focusedStyle = lipgloss.NewStyle().Foreground(lipgloss.Color("205"))
	blurredStyle = lipgloss.NewStyle().Foreground(lipgloss.Color("240"))
	titleStyle   = lipgloss.NewStyle().
			Background(lipgloss.Color("62")).
			Foreground(lipgloss.Color("230")).
			Padding(0, 1).
			MarginBottom(1)
	suggestionStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#CBC8C6")).
			Padding(0, 1)
	selectedSuggestionStyle = lipgloss.NewStyle().
				Foreground(lipgloss.Color("#4E5EDE")).
				Padding(0, 1)
	inputBoxStyle = lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).
			BorderForeground(lipgloss.Color("#CBC8C6")).
			Padding(0, 1)
	helpTextStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#CBC8C6")).
			MarginTop(1)
	messageStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#CBC8C6"))
)

var slashCommands = []string{
	"/commit",
	"/pr",
	"/issue",
	"/help",
	"/clear",
}

var shortcuts = []string{
	"! for bash mode",
	"/ for commands",
	"@ for file paths",
	"# to memorize",
	"double tap esc to clear input",
	"shift + tab to auto-accept edits",
	"ctrl + r for verbose output",
	"shift + e for newline",
	"ctrl + _ to undo",
	"ctrl + z to suspend",
}

func distributeShortcuts(shortcuts []string, terminalWidth int) []string {
	if len(shortcuts) == 0 {
		return []string{}
	}

	// Try 3 columns first
	formatted := tryDistribution(shortcuts, 3, terminalWidth)
	if formatted != nil {
		return formatted
	}

	// Fallback to 2 columns if 3 doesn't fit
	formatted = tryDistribution(shortcuts, 2, terminalWidth)
	if formatted != nil {
		return formatted
	}

	// Fallback to 1 column if 2 doesn't fit
	return tryDistribution(shortcuts, 1, terminalWidth)
}

func tryDistribution(shortcuts []string, numCols int, terminalWidth int) []string {
	if len(shortcuts) == 0 {
		return []string{}
	}

	// Calculate rows needed
	numRows := (len(shortcuts) + numCols - 1) / numCols // ceiling division

	// Create 2D grid
	grid := make([][]string, numRows)
	for i := range grid {
		grid[i] = make([]string, numCols)
	}

	// Fill grid column by column for even distribution
	for i, shortcut := range shortcuts {
		col := i / numRows
		row := i % numRows
		if col < numCols && row < numRows {
			grid[row][col] = shortcut
		}
	}

	// Find max width for each column
	maxWidths := make([]int, numCols)
	for _, row := range grid {
		for i, cell := range row {
			if len(cell) > maxWidths[i] {
				maxWidths[i] = len(cell)
			}
		}
	}

	// Calculate total width needed (including 8 spaces between columns)
	totalWidth := 0
	for i, width := range maxWidths {
		totalWidth += width
		if i < len(maxWidths)-1 && maxWidths[i+1] > 0 {
			totalWidth += 8 // spacing between columns
		}
	}

	// Check if it fits (leave some margin for padding)
	if totalWidth > terminalWidth-10 {
		return nil // Doesn't fit
	}

	// Format each row with proper spacing
	var formatted []string
	for _, row := range grid {
		var line string
		for i, cell := range row {
			if i == 0 {
				line = cell
			} else if cell != "" {
				// Add 8 spaces after the previous column's max width
				padding := maxWidths[i-1] - len(row[i-1]) + 8
				line += strings.Repeat(" ", padding) + cell
			}
		}
		// Only add non-empty lines
		if strings.TrimSpace(line) != "" {
			formatted = append(formatted, line)
		}
	}

	return formatted
}

type model struct {
	textInput          textinput.Model
	messages           []string
	suggestions        []string
	selectedSuggestion int
	showSuggestions    bool
	showHelp           bool
	width              int
	height             int
}

func initialModel() model {
	ti := textinput.New()
	ti.Placeholder = "Type your message..."
	ti.Focus()
	ti.CharLimit = 200
	ti.Width = 50
	ti.Cursor.SetMode(cursor.CursorStatic)

	return model{
		textInput:          ti,
		messages:           []string{},
		suggestions:        []string{},
		selectedSuggestion: 0,
		showSuggestions:    false,
		showHelp:           false,
		width:              80,
		height:             24,
	}
}

func (m model) Init() tea.Cmd {
	return nil
}

func (m *model) updateSuggestions() {
	input := m.textInput.Value()

	if strings.HasPrefix(input, "/") {
		m.showHelp = false
		oldSuggestions := m.suggestions
		m.suggestions = []string{}
		for _, cmd := range slashCommands {
			if strings.HasPrefix(cmd, input) {
				m.suggestions = append(m.suggestions, cmd)
			}
		}
		m.showSuggestions = len(m.suggestions) > 0

		// Only reset selection if suggestions changed or if we had no suggestions before
		if len(oldSuggestions) == 0 || !slicesEqual(oldSuggestions, m.suggestions) {
			m.selectedSuggestion = 0
		} else if m.selectedSuggestion >= len(m.suggestions) {
			// Clamp selection if it's out of bounds
			m.selectedSuggestion = len(m.suggestions) - 1
		}
	} else {
		m.showSuggestions = false
		m.suggestions = []string{}
	}
}

func slicesEqual(a, b []string) bool {
	if len(a) != len(b) {
		return false
	}
	for i := range a {
		if a[i] != b[i] {
			return false
		}
	}
	return true
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	var cmd tea.Cmd

	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
		m.textInput.Width = msg.Width - 6 // Account for border and padding
		return m, nil
	case tea.KeyMsg:
		switch msg.Type {
		case tea.KeyCtrlC, tea.KeyEsc:
			return m, tea.Quit
		case tea.KeyRunes:
			// Intercept ? character when input is empty
			if len(msg.Runes) == 1 && string(msg.Runes[0]) == "?" && m.textInput.Value() == "" {
				m.showHelp = !m.showHelp
				m.showSuggestions = false
				m.suggestions = []string{}
				return m, nil
			}
		case tea.KeyEnter:
			if m.showSuggestions && len(m.suggestions) > 0 {
				// Auto-complete with selected suggestion + space
				completed := m.suggestions[m.selectedSuggestion] + " "
				m.textInput.SetValue(completed)
				m.textInput.SetCursor(len(completed))
				m.showSuggestions = false
			} else if m.textInput.Value() != "" {
				m.messages = append(m.messages, m.textInput.Value())
				m.textInput.SetValue("")
				m.showSuggestions = false
				m.showHelp = false
			}
		case tea.KeyUp:
			if m.showSuggestions && len(m.suggestions) > 0 {
				if m.selectedSuggestion > 0 {
					m.selectedSuggestion--
				}
				return m, nil
			}
		case tea.KeyDown:
			if m.showSuggestions && len(m.suggestions) > 0 {
				if m.selectedSuggestion < len(m.suggestions)-1 {
					m.selectedSuggestion++
				}
				return m, nil
			}
		case tea.KeyTab:
			if m.showSuggestions && len(m.suggestions) > 0 {
				// Tab to complete + space
				completed := m.suggestions[m.selectedSuggestion] + " "
				m.textInput.SetValue(completed)
				m.textInput.SetCursor(len(completed))
				m.showSuggestions = false
				return m, nil
			}
		}
	}

	m.textInput, cmd = m.textInput.Update(msg)
	m.updateSuggestions()
	return m, cmd
}

func (m model) View() string {
	var view string

	// Title
	view += titleStyle.Render("Gemini CLI Orchestrator")
	view += "\n\n"

	// Messages history
	if len(m.messages) > 0 {
		for _, msg := range m.messages {
			view += messageStyle.Render(fmt.Sprintf("> %s", msg)) + "\n"
		}
		view += "\n"
	}

	// Input with full-width border
	inputBox := inputBoxStyle.Width(m.width - 2) // Full width minus small margin
	view += inputBox.Render(m.textInput.View())

	// Suggestions dropdown
	if m.showSuggestions && len(m.suggestions) > 0 {
		view += "\n"
		for i, suggestion := range m.suggestions {
			if i == m.selectedSuggestion {
				view += selectedSuggestionStyle.Render(suggestion) + "\n"
			} else {
				view += suggestionStyle.Render(suggestion) + "\n"
			}
		}
	}

	// Help shortcuts
	if m.showHelp {
		view += "\n"
		formattedShortcuts := distributeShortcuts(shortcuts, m.width)
		for _, shortcut := range formattedShortcuts {
			view += suggestionStyle.Render(shortcut) + "\n"
		}
	}

	if m.showSuggestions {
		view += "\n"
		view += blurredStyle.Render("↑/↓ to navigate • Tab/Enter to complete")
	} else {
		view += helpTextStyle.Render("? for shortcuts")
	}

	view += "\n"
	view += "\n"

	return view
}

func main() {
	p := tea.NewProgram(initialModel())
	if _, err := p.Run(); err != nil {
		log.Fatal(err)
		os.Exit(1)
	}
}
