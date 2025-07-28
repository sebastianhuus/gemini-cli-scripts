package commands

import (
	"fmt"
	"os/exec"
	"strings"

	"gemini-orchestrator/internal/models"
	"gemini-orchestrator/internal/ui"
	"gemini-orchestrator/internal/utils"
	tea "github.com/charmbracelet/bubbletea"
)

func HandleCommand(inputValue string, m *models.Model) tea.Cmd {
	// Handle /reload command
	if inputValue == "/reload" {
		// Start building process
		m.IsBuilding = true
		m.TextInput.SetValue("")
		m.ShowSuggestions = false
		m.ShowHelp = false
		return tea.Batch(m.Spinner.Tick, utils.BuildAndReloadCmd())
	}

	// Handle /commit command
	if strings.HasPrefix(inputValue, "/commit") {
		context := strings.TrimPrefix(inputValue, "/commit")
		context = strings.TrimSpace(context)
		
		// Add command to history
		m.Messages = append(m.Messages, inputValue)
		resetInput(m)
		
		// Execute auto-commit with context
		command := "auto-commit"
		if context != "" {
			command += " " + context
		}
		return executeZshCommand(command)
	}

	// Handle /pr command
	if strings.HasPrefix(inputValue, "/pr") {
		context := strings.TrimPrefix(inputValue, "/pr")
		context = strings.TrimSpace(context)
		
		// Add command to history
		m.Messages = append(m.Messages, inputValue)
		resetInput(m)
		
		// Execute auto-pr with context
		command := "auto-pr"
		if context != "" {
			command += " " + context
		}
		return executeZshCommand(command)
	}

	// Handle /issue command
	if inputValue == "/issue" {
		// Add command to history
		m.Messages = append(m.Messages, inputValue)
		resetInput(m)
		
		// Execute auto-issue
		return executeZshCommand("auto-issue")
	}

	// Handle /clear command
	if inputValue == "/clear" {
		// Clear entire display and reset to initial state
		ui.ComposeUI(m)
		m.Messages = []string{"/clear\n  ⎿  (no content)"}
		resetInput(m)
		return nil
	}

	// Default: add message to history
	m.Messages = append(m.Messages, m.TextInput.Value())
	resetInput(m)
	return nil
}

func HandleZshCommand(inputValue string, m *models.Model) tea.Cmd {
	// Add command to history
	m.Messages = append(m.Messages, fmt.Sprintf("$ %s", inputValue))
	resetInput(m)
	
	// Execute the zsh command
	return executeZshCommand(inputValue)
}

func executeZshCommand(command string) tea.Cmd {
	// Create the command chain: clear && reset && [command] && clear
	cmdString := fmt.Sprintf(`
		clear
		reset
		%s
		clear
		echo "Script completed. Returning to orchestrator..."
		sleep 1
	`, command)
	
	return tea.ExecProcess(exec.Command("zsh", "-c", cmdString), nil)
}

func resetInput(m *models.Model) {
	m.TextInput.SetValue("")
	m.ShowSuggestions = false
	m.ShowHelp = false
}