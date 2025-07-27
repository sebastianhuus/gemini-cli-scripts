package main

import (
	"fmt"
	"log"
	"os"
	"strings"

	"gemini-orchestrator/internal/commands"
	"gemini-orchestrator/internal/models"
	"gemini-orchestrator/internal/ui"
	"gemini-orchestrator/internal/utils"
	tea "github.com/charmbracelet/bubbletea"
)

type orchestratorModel struct {
	models.Model
}

func (m orchestratorModel) Init() tea.Cmd {
	return models.ListenForSignals()
}

func (m orchestratorModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	var cmd tea.Cmd

	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.Width = msg.Width
		m.Height = msg.Height
		m.TextInput.Width = msg.Width - 6
		return m, nil
	case models.BuildCompleteMsg:
		m.IsBuilding = false
		if err := utils.ReloadOrchestrator(); err != nil {
			m.Messages = append(m.Messages, fmt.Sprintf("❌ Failed to reload: %v", err))
		}
		return m, nil
	case models.BuildErrorMsg:
		m.IsBuilding = false
		m.Messages = append(m.Messages, fmt.Sprintf("❌ Build failed: %v", msg.Err))
		return m, nil
	case models.ShutdownMsg:
		return m, tea.Quit
	case models.CtrlCTimeoutMsg:
		m.ShowExitConfirm = false
		return m, nil
	case tea.KeyMsg:
		return m.handleKeyMsg(msg)
	}

	// Update spinner if building
	if m.IsBuilding {
		var spinnerCmd tea.Cmd
		m.Spinner, spinnerCmd = m.Spinner.Update(msg)
		cmd = tea.Batch(cmd, spinnerCmd)
	}

	var textInputCmd tea.Cmd
	m.TextInput, textInputCmd = m.TextInput.Update(msg)
	m.UpdateSuggestions()
	return m, tea.Batch(cmd, textInputCmd)
}

func (m orchestratorModel) handleKeyMsg(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	switch msg.Type {
	case tea.KeyCtrlC:
		if m.ShowExitConfirm {
			return m, tea.Quit
		} else {
			m.ShowExitConfirm = true
			return m, models.CtrlCTimeoutCmd()
		}
	case tea.KeyEsc:
		if m.ShowExitConfirm {
			m.ShowExitConfirm = false
			return m, nil
		}
		return m, tea.Quit
	case tea.KeyBackspace:
		if m.ShowExitConfirm {
			m.ShowExitConfirm = false
		}
		if m.TextInput.Value() == "" {
			m.ShowHelp = false
			m.ShowSuggestions = false
			m.Suggestions = []string{}
			return m, nil
		}
	case tea.KeyRunes:
		if m.ShowExitConfirm {
			m.ShowExitConfirm = false
		}
		if len(msg.Runes) == 1 && string(msg.Runes[0]) == "?" && m.TextInput.Value() == "" {
			m.ShowHelp = !m.ShowHelp
			m.ShowSuggestions = false
			m.Suggestions = []string{}
			return m, nil
		}
	case tea.KeyEnter:
		return m.handleEnterKey()
	case tea.KeyUp:
		return m.handleNavigationKey(true)
	case tea.KeyDown:
		return m.handleNavigationKey(false)
	case tea.KeyTab:
		return m.handleTabKey()
	}
	return m, nil
}

func (m orchestratorModel) handleEnterKey() (tea.Model, tea.Cmd) {
	if m.ShowExitConfirm {
		m.ShowExitConfirm = false
	}
	if m.ShowSuggestions && len(m.Suggestions) > 0 {
		inputValue := strings.TrimSpace(m.Suggestions[m.SelectedSuggestion])
		m.TextInput.SetValue(inputValue)
		m.ShowSuggestions = false
	}

	if m.TextInput.Value() != "" {
		inputValue := strings.TrimSpace(m.TextInput.Value())
		return m, commands.HandleCommand(inputValue, &m.Model)
	}
	return m, nil
}

func (m orchestratorModel) handleNavigationKey(isUp bool) (tea.Model, tea.Cmd) {
	if m.ShowExitConfirm {
		m.ShowExitConfirm = false
	}
	if m.ShowSuggestions && len(m.Suggestions) > 0 {
		if isUp {
			if m.SelectedSuggestion > 0 {
				m.SelectedSuggestion--
			}
		} else {
			if m.SelectedSuggestion < len(m.Suggestions)-1 {
				m.SelectedSuggestion++
			}
		}
		return m, nil
	}
	return m, nil
}

func (m orchestratorModel) handleTabKey() (tea.Model, tea.Cmd) {
	if m.ShowExitConfirm {
		m.ShowExitConfirm = false
	}
	if m.ShowSuggestions && len(m.Suggestions) > 0 {
		completed := m.Suggestions[m.SelectedSuggestion] + " "
		m.TextInput.SetValue(completed)
		m.TextInput.SetCursor(len(completed))
		m.ShowSuggestions = false
		return m, nil
	}
	return m, nil
}

func (m orchestratorModel) View() string {
	return ui.RenderView(m.Model)
}

func main() {
	ui.ClearConsole()

	initialModel := models.InitialModel()
	wrappedModel := orchestratorModel{Model: initialModel}

	p := tea.NewProgram(wrappedModel)
	if _, err := p.Run(); err != nil {
		log.Fatal(err)
		os.Exit(1)
	}
}