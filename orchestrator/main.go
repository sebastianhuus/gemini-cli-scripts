package main

import (
	"fmt"
	"log"
	"os"
	"os/exec"
	"strings"
	"syscall"

	"github.com/charmbracelet/bubbles/cursor"
	"github.com/charmbracelet/bubbles/spinner"
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
			Padding(0, 2)
	selectedSuggestionStyle = lipgloss.NewStyle().
				Foreground(lipgloss.Color("#4E5EDE")).
				Padding(0, 2)
	inputBoxStyle = lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).
			BorderForeground(lipgloss.Color("#CBC8C6")).
			Padding(0, 1)
	helpTextStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#CBC8C6")).
			MarginTop(1).
			Padding(0, 2)
	messageStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#CBC8C6"))
)

var slashCommands = []string{
	"/commit",
	"/pr",
	"/issue",
	"/help",
	"/clear",
	"/reload",
}

var modeShortcuts = []string{
	"! for bash mode",
	"/ for commands",
	"@ for file paths",
	"# to memorize",
}

var generalShortcuts = []string{
	"double tap esc to clear input",
	"shift + tab to auto-accept edits",
	"ctrl + r for verbose output",
	"shift + e for newline",
	"ctrl + _ to undo",
	"ctrl + z to suspend",
}

func distributeShortcuts(terminalWidth int) []string {
	// Try 3 columns first (modes + general shortcuts with different spacing)
	formatted := tryThreeColumnLayout(terminalWidth)
	if formatted != nil {
		return formatted
	}

	// Fallback to 2 columns (modes | all general shortcuts)
	formatted = tryTwoColumnLayout(terminalWidth)
	if formatted != nil {
		return formatted
	}

	// Fallback to 1 column (everything stacked)
	return tryOneColumnLayout()
}

func tryThreeColumnLayout(terminalWidth int) []string {
	// Mode shortcuts in column 1, general shortcuts distributed in columns 2&3
	maxRows := len(modeShortcuts)
	generalPerCol := (len(generalShortcuts) + 1) / 2 // Split general shortcuts across 2 columns
	if generalPerCol > maxRows {
		maxRows = generalPerCol
	}

	// Create grid
	grid := make([][]string, maxRows)
	for i := range grid {
		grid[i] = make([]string, 3)
	}

	// Fill column 1 with mode shortcuts
	for i, shortcut := range modeShortcuts {
		grid[i][0] = shortcut
	}

	// Fill columns 2&3 with general shortcuts
	for i, shortcut := range generalShortcuts {
		col := 1 + (i / generalPerCol)
		row := i % generalPerCol
		if col < 3 && row < maxRows {
			grid[row][col] = shortcut
		}
	}

	// Calculate widths: mode column uses 8 spaces, general columns use 4 spaces
	maxWidths := make([]int, 3)
	for _, row := range grid {
		for i, cell := range row {
			if len(cell) > maxWidths[i] {
				maxWidths[i] = len(cell)
			}
		}
	}

	// Calculate total width with mixed spacing
	totalWidth := maxWidths[0] + 8 + maxWidths[1] + 4 + maxWidths[2]
	if totalWidth > terminalWidth-10 {
		return nil // Doesn't fit
	}

	// Format with mixed spacing
	var formatted []string
	for _, row := range grid {
		var line string
		for i, cell := range row {
			if i == 0 {
				line = cell
			} else if cell != "" {
				spacing := 8 // Default to 8 spaces
				if i == 2 {
					spacing = 4 // 4 spaces between general columns
				}
				padding := maxWidths[i-1] - len(row[i-1]) + spacing
				line += strings.Repeat(" ", padding) + cell
			}
		}
		if strings.TrimSpace(line) != "" {
			formatted = append(formatted, line)
		}
	}

	return formatted
}

func tryTwoColumnLayout(terminalWidth int) []string {
	// Mode shortcuts in column 1, all general shortcuts in column 2
	maxRows := len(modeShortcuts)
	if len(generalShortcuts) > maxRows {
		maxRows = len(generalShortcuts)
	}

	// Create grid
	grid := make([][]string, maxRows)
	for i := range grid {
		grid[i] = make([]string, 2)
	}

	// Fill columns
	for i, shortcut := range modeShortcuts {
		grid[i][0] = shortcut
	}
	for i, shortcut := range generalShortcuts {
		grid[i][1] = shortcut
	}

	// Calculate widths
	maxWidths := make([]int, 2)
	for _, row := range grid {
		for i, cell := range row {
			if len(cell) > maxWidths[i] {
				maxWidths[i] = len(cell)
			}
		}
	}

	// Check if it fits
	totalWidth := maxWidths[0] + 8 + maxWidths[1]
	if totalWidth > terminalWidth-10 {
		return nil
	}

	// Format
	var formatted []string
	for _, row := range grid {
		var line string
		for i, cell := range row {
			if i == 0 {
				line = cell
			} else if cell != "" {
				padding := maxWidths[i-1] - len(row[i-1]) + 8
				line += strings.Repeat(" ", padding) + cell
			}
		}
		if strings.TrimSpace(line) != "" {
			formatted = append(formatted, line)
		}
	}

	return formatted
}

func tryOneColumnLayout() []string {
	// Stack everything in one column
	var formatted []string
	formatted = append(formatted, modeShortcuts...)
	formatted = append(formatted, generalShortcuts...)
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
	spinner            spinner.Model
	isBuilding         bool
}

func initialModel() model {
	ti := textinput.New()
	ti.Placeholder = "Type your message..."
	ti.Focus()
	ti.CharLimit = 200
	ti.Width = 50
	ti.Cursor.SetMode(cursor.CursorStatic)

	s := spinner.New()
	s.Spinner = spinner.Dot
	s.Style = lipgloss.NewStyle().Foreground(lipgloss.Color("205"))

	return model{
		textInput:          ti,
		messages:           []string{},
		suggestions:        []string{},
		selectedSuggestion: 0,
		showSuggestions:    false,
		showHelp:           false,
		width:              80,
		height:             24,
		spinner:            s,
		isBuilding:         false,
	}
}

type buildCompleteMsg struct{}
type buildErrorMsg struct{ err error }

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

func buildAndReloadCmd() tea.Cmd {
	return func() tea.Msg {
		// Get the current working directory to find go.mod
		wd, err := os.Getwd()
		if err != nil {
			return buildErrorMsg{err: fmt.Errorf("failed to get working directory: %w", err)}
		}

		// Get the current executable path and name
		execPath, err := os.Executable()
		if err != nil {
			return buildErrorMsg{err: fmt.Errorf("failed to get executable path: %w", err)}
		}

		// Build the new binary
		buildCmd := exec.Command("go", "build", "-o", execPath, "main.go")
		buildCmd.Dir = wd
		
		if err := buildCmd.Run(); err != nil {
			return buildErrorMsg{err: fmt.Errorf("failed to build: %w", err)}
		}

		// Signal build completion
		return buildCompleteMsg{}
	}
}

func reloadOrchestrator() error {
	// Prepare arguments (skip program name)
	args := os.Args[1:]

	// Get the current executable path
	execPath, err := os.Executable()
	if err != nil {
		return fmt.Errorf("failed to get executable path: %w", err)
	}

	// Use syscall.Exec to replace the current process with the newly built binary
	env := os.Environ()
	return syscall.Exec(execPath, append([]string{execPath}, args...), env)
}

func executeZshCommand(command string, args string, m *model) {
	// Build the full command
	var cmd *exec.Cmd
	if args != "" {
		cmd = exec.Command("zsh", "-c", fmt.Sprintf("%s %s", command, args))
	} else {
		cmd = exec.Command("zsh", "-c", command)
	}
	
	// Set up to capture output
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin
	
	// Add status message
	if args != "" {
		m.messages = append(m.messages, fmt.Sprintf("🔄 Running: %s %s", command, args))
	} else {
		m.messages = append(m.messages, fmt.Sprintf("🔄 Running: %s", command))
	}
	
	// Execute the command
	err := cmd.Run()
	if err != nil {
		m.messages = append(m.messages, fmt.Sprintf("❌ Command failed: %v", err))
	} else {
		m.messages = append(m.messages, fmt.Sprintf("✅ Command completed successfully"))
	}
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	var cmd tea.Cmd

	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
		m.textInput.Width = msg.Width - 6 // Account for border and padding
		return m, nil
	case buildCompleteMsg:
		// Build completed successfully, now reload
		m.isBuilding = false
		if err := reloadOrchestrator(); err != nil {
			m.messages = append(m.messages, fmt.Sprintf("❌ Failed to reload: %v", err))
		}
		return m, nil
	case buildErrorMsg:
		// Build failed
		m.isBuilding = false
		m.messages = append(m.messages, fmt.Sprintf("❌ Build failed: %v", msg.err))
		return m, nil
	case tea.KeyMsg:
		switch msg.Type {
		case tea.KeyCtrlC, tea.KeyEsc:
			return m, tea.Quit
		case tea.KeyBackspace:
			// Exit modes when backspacing on empty input
			if m.textInput.Value() == "" {
				m.showHelp = false
				m.showSuggestions = false
				m.suggestions = []string{}
				return m, nil
			}
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
				inputValue := strings.TrimSpace(m.textInput.Value())
				
				// Handle /reload command
				if inputValue == "/reload" {
					// Start building process
					m.isBuilding = true
					m.textInput.SetValue("")
					m.showSuggestions = false
					m.showHelp = false
					return m, tea.Batch(m.spinner.Tick, buildAndReloadCmd())
				}
				
				// Handle /commit command
				if strings.HasPrefix(inputValue, "/commit") {
					// Extract everything after /commit as a single parameter
					commitMsg := strings.TrimSpace(strings.TrimPrefix(inputValue, "/commit"))
					if commitMsg != "" {
						// Quote the message to handle spaces and special characters
						executeZshCommand("auto-commit", fmt.Sprintf(`"%s"`, commitMsg), &m)
					} else {
						executeZshCommand("auto-commit", "", &m)
					}
					m.textInput.SetValue("")
					m.showSuggestions = false
					m.showHelp = false
					return m, nil
				}
				
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

	// Update spinner if building
	if m.isBuilding {
		var spinnerCmd tea.Cmd
		m.spinner, spinnerCmd = m.spinner.Update(msg)
		cmd = tea.Batch(cmd, spinnerCmd)
	}

	var textInputCmd tea.Cmd
	m.textInput, textInputCmd = m.textInput.Update(msg)
	m.updateSuggestions()
	return m, tea.Batch(cmd, textInputCmd)
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

	// Show building spinner if building
	if m.isBuilding {
		view += suggestionStyle.Render(fmt.Sprintf("%s Building and reloading...", m.spinner.View())) + "\n\n"
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
		formattedShortcuts := distributeShortcuts(m.width)
		for _, shortcut := range formattedShortcuts {
			view += suggestionStyle.Render(shortcut) + "\n"
		}
	}

	if m.showSuggestions {
		view += "\n"
		view += blurredStyle.Render("↑/↓ to navigate • Tab/Enter to complete")
	} else if !m.showHelp {
		view += helpTextStyle.Render("? for shortcuts")
	}

	view += "\n"
	view += "\n"

	return view
}

func clearConsole() {
	fmt.Print("\033[2J\033[H")
}

func main() {
	clearConsole()
	p := tea.NewProgram(initialModel())
	if _, err := p.Run(); err != nil {
		log.Fatal(err)
		os.Exit(1)
	}
}
