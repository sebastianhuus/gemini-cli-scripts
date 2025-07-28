package models

import (
	"encoding/json"
	"os"
	"path/filepath"
	"time"

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

// PersistentState represents the state that should be persisted across restarts
type PersistentState struct {
	Messages    []string `json:"messages"`
	ZshMode     bool     `json:"zsh_mode"`
	LastCommand string   `json:"last_command"`
	Timestamp   int64    `json:"timestamp"`
}

// getStateFilePath returns the path to the state file using os.UserConfigDir
func getStateFilePath() (string, error) {
	configDir, err := os.UserConfigDir()
	if err != nil {
		return "", err
	}
	
	appDir := filepath.Join(configDir, "gemini-orchestrator")
	if err := os.MkdirAll(appDir, 0755); err != nil {
		return "", err
	}
	
	return filepath.Join(appDir, "session-state.json"), nil
}

// SaveState saves the current model state to a JSON file
func (m *Model) SaveState() error {
	stateFilePath, err := getStateFilePath()
	if err != nil {
		return err
	}
	
	state := PersistentState{
		Messages:    m.Messages,
		ZshMode:     m.ZshMode,
		LastCommand: m.TextInput.Value(),
		Timestamp:   time.Now().Unix(),
	}
	
	data, err := json.MarshalIndent(state, "", "  ")
	if err != nil {
		return err
	}
	
	// Write to temporary file first, then rename for atomic operation
	tempFile := stateFilePath + ".tmp"
	if err := os.WriteFile(tempFile, data, 0644); err != nil {
		return err
	}
	
	return os.Rename(tempFile, stateFilePath)
}

// LoadState loads the previously saved state from JSON file
func (m *Model) LoadState() error {
	stateFilePath, err := getStateFilePath()
	if err != nil {
		return err
	}
	
	data, err := os.ReadFile(stateFilePath)
	if err != nil {
		return err // File doesn't exist or can't be read
	}
	
	var state PersistentState
	if err := json.Unmarshal(data, &state); err != nil {
		return err // Invalid JSON
	}
	
	// Restore the state
	m.Messages = state.Messages
	m.ZshMode = state.ZshMode
	m.UpdatePromptForZshMode()
	
	return nil
}

// CleanupStateFile removes the state file after successful restore
func CleanupStateFile() error {
	stateFilePath, err := getStateFilePath()
	if err != nil {
		return err
	}
	
	// Remove file, ignore error if file doesn't exist
	os.Remove(stateFilePath)
	return nil
}
