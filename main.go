package main

import (
	"fmt"
	"log"
	"os"

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
)

type model struct {
	textInput textinput.Model
	messages  []string
}

func initialModel() model {
	ti := textinput.New()
	ti.Placeholder = "Type your message..."
	ti.Focus()
	ti.CharLimit = 200
	ti.Width = 50

	return model{
		textInput: ti,
		messages:  []string{},
	}
}

func (m model) Init() tea.Cmd {
	return textinput.Blink
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	var cmd tea.Cmd

	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.Type {
		case tea.KeyCtrlC, tea.KeyEsc:
			return m, tea.Quit
		case tea.KeyEnter:
			if m.textInput.Value() != "" {
				m.messages = append(m.messages, m.textInput.Value())
				m.textInput.SetValue("")
			}
		}
	}

	m.textInput, cmd = m.textInput.Update(msg)
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
	
	// Input
	view += "Enter message:\n"
	view += m.textInput.View()
	view += "\n\n"
	view += blurredStyle.Render("Press Ctrl+C or Esc to quit")
	
	return view
}

func main() {
	p := tea.NewProgram(initialModel())
	if _, err := p.Run(); err != nil {
		log.Fatal(err)
		os.Exit(1)
	}
}