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
			Background(lipgloss.Color("236")).
			Foreground(lipgloss.Color("250")).
			Padding(0, 1)
	selectedSuggestionStyle = lipgloss.NewStyle().
				Background(lipgloss.Color("205")).
				Foreground(lipgloss.Color("230")).
				Padding(0, 1)
	inputBoxStyle = lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).
			BorderForeground(lipgloss.Color("#CBC8C6")).
			Padding(0, 1)
)

var slashCommands = []string{
	"/commit",
	"/pr",
	"/issue",
	"/help",
	"/clear",
}

type model struct {
	textInput          textinput.Model
	messages           []string
	suggestions        []string
	selectedSuggestion int
	showSuggestions    bool
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
		view += "Messages:\n"
		for _, msg := range m.messages {
			view += fmt.Sprintf("• %s\n", msg)
		}
		view += "\n"
	}

	// Input with full-width border
	view += "Enter message:\n"
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

	view += "\n\n"
	if m.showSuggestions {
		view += blurredStyle.Render("↑/↓ to navigate • Tab/Enter to complete • Ctrl+C to quit")
	} else {
		view += blurredStyle.Render("Type / for commands • Ctrl+C or Esc to quit")
	}

	return view
}

func main() {
	p := tea.NewProgram(initialModel())
	if _, err := p.Run(); err != nil {
		log.Fatal(err)
		os.Exit(1)
	}
}
