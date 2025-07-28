package commands

import (
	"fmt"
	"os"
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
		
		// Save state before executing command
		if err := m.SaveState(); err != nil {
			// If state save fails, add error message but continue
			m.Messages = append(m.Messages, fmt.Sprintf("⚠️ Failed to save state: %v", err))
		}
		
		// Execute auto-commit with context
		command := "auto-commit"
		if context != "" {
			command += " " + context
		}
		return executeZshCommandAndRelaunch(command)
	}

	// Handle /pr command
	if strings.HasPrefix(inputValue, "/pr") {
		context := strings.TrimPrefix(inputValue, "/pr")
		context = strings.TrimSpace(context)
		
		// Add command to history
		m.Messages = append(m.Messages, inputValue)
		resetInput(m)
		
		// Save state before executing command
		if err := m.SaveState(); err != nil {
			// If state save fails, add error message but continue
			m.Messages = append(m.Messages, fmt.Sprintf("⚠️ Failed to save state: %v", err))
		}
		
		// Execute auto-pr with context
		command := "auto-pr"
		if context != "" {
			command += " " + context
		}
		return executeZshCommandAndRelaunch(command)
	}

	// Handle /issue command
	if inputValue == "/issue" {
		// Add command to history
		m.Messages = append(m.Messages, inputValue)
		resetInput(m)
		
		// Save state before executing command
		if err := m.SaveState(); err != nil {
			// If state save fails, add error message but continue
			m.Messages = append(m.Messages, fmt.Sprintf("⚠️ Failed to save state: %v", err))
		}
		
		// Execute auto-issue
		return executeZshCommandAndRelaunch("auto-issue")
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
	
	// Save state before executing command
	if err := m.SaveState(); err != nil {
		// If state save fails, add error message but continue
		m.Messages = append(m.Messages, fmt.Sprintf("⚠️ Failed to save state: %v", err))
	}
	
	// Execute the zsh command and relaunch
	return executeZshCommandAndRelaunch(inputValue)
}

func executeZshCommandAndRelaunch(command string) tea.Cmd {
	// Get the current executable path for relaunching
	execPath, err := os.Executable()
	if err != nil {
		execPath = os.Args[0] // Fallback to original command
	}
	
	// Create the command chain: clear && reset && [command] && clear && exec [orchestrator-path] --restore
	cmdString := fmt.Sprintf(`
		clear
		reset
		%s
		clear
		exec %s --restore
	`, command, execPath)
	
	return tea.ExecProcess(exec.Command("zsh", "-c", cmdString), nil)
}

func resetInput(m *models.Model) {
	m.TextInput.SetValue("")
	m.ShowSuggestions = false
	m.ShowHelp = false
}