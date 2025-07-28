package models

import (
	"github.com/charmbracelet/bubbles/cursor"
	"github.com/charmbracelet/bubbles/spinner"
	"github.com/charmbracelet/bubbles/textinput"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

type Model struct {
	TextInput          textinput.Model
	Messages           []string
	Suggestions        []string
	SelectedSuggestion int
	ShowSuggestions    bool
	ShowHelp           bool
	Width              int
	Height             int
	Spinner            spinner.Model
	IsBuilding         bool
	ShowExitConfirm    bool
	ZshMode            bool
}

func InitialModel() Model {
	ti := textinput.New()
	ti.Placeholder = ""
	ti.Focus()
	ti.CharLimit = 200
	ti.Width = 50
	ti.Cursor.SetMode(cursor.CursorStatic)
	ti.Prompt = "> " // Default prompt

	s := spinner.New()
	s.Spinner = spinner.Dot
	s.Style = lipgloss.NewStyle().Foreground(lipgloss.Color("205"))

	return Model{
		TextInput:          ti,
		Messages:           []string{},
		Suggestions:        []string{},
		SelectedSuggestion: 0,
		ShowSuggestions:    false,
		ShowHelp:           false,
		Width:              80,
		Height:             24,
		Spinner:            s,
		IsBuilding:         false,
		ShowExitConfirm:    false,
		ZshMode:            false,
	}
}

func (m Model) Init() tea.Cmd {
	return nil
}

// UpdatePromptForZshMode updates the text input prompt based on Zsh mode
func (m *Model) UpdatePromptForZshMode() {
	if m.ZshMode {
		m.TextInput.Prompt = "! "
		// Apply pink styling to the prompt
		m.TextInput.PromptStyle = lipgloss.NewStyle().Foreground(lipgloss.Color("#FE8BC4"))
	} else {
		m.TextInput.Prompt = "> "
		// Reset to default styling
		m.TextInput.PromptStyle = lipgloss.NewStyle()
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

