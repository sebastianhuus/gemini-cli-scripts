package ui

import (
	"fmt"

	"gemini-orchestrator/internal/models"
)

func RenderHeader() string {
	return TitleStyle.Render("Gemini CLI Orchestrator") + "\n\n"
}

func RenderContent(m models.Model) string {
	var content string

	// Messages history
	if len(m.Messages) > 0 {
		for _, msg := range m.Messages {
			content += MessageStyle.Render(fmt.Sprintf("> %s", msg)) + "\n"
		}
		content += "\n"
	}

	return content
}

func RenderInputBar(m models.Model) string {
	var inputBar string

	// Only show input if not building
	if !m.IsBuilding {
		// Input with full-width border
		inputBox := InputBoxStyle.Width(m.Width - 2) // Full width minus small margin
		inputBar += inputBox.Render(m.TextInput.View())
	}

	return inputBar
}

func RenderView(m models.Model) string {
	var view string

	// Composable UI layout
	view += RenderHeader()
	view += RenderContent(m)

	// Show building spinner if building
	if m.IsBuilding {
		view += SuggestionStyle.Render(fmt.Sprintf("%s Building and reloading...", m.Spinner.View())) + "\n\n"
	}

	view += RenderInputBar(m)

	// Only show UI elements if not building
	if !m.IsBuilding {
		if m.ShowExitConfirm {
			// Priority 1: Exit confirmation (overrides everything else)
			view += HelpTextStyle.Render("Press Ctrl+C again to exit (or Esc to cancel)")
		} else if m.ShowSuggestions && len(m.Suggestions) > 0 {
			// Priority 2: Suggestions dropdown
			view += "\n"
			for i, suggestion := range m.Suggestions {
				if i == m.SelectedSuggestion {
					view += SelectedSuggestionStyle.Render(suggestion) + "\n"
				} else {
					view += SuggestionStyle.Render(suggestion) + "\n"
				}
			}
			view += "\n"
			view += BlurredStyle.Render("↑/↓ to navigate • Tab to complete • Enter to execute")
		} else if m.ShowHelp {
			// Priority 3: Help shortcuts
			view += "\n"
			formattedShortcuts := DistributeShortcuts(m.Width)
			for _, shortcut := range formattedShortcuts {
				view += SuggestionStyle.Render(shortcut) + "\n"
			}
		} else {
			// Priority 4: Default help prompt
			view += HelpTextStyle.Render("? for shortcuts")
		}
	}

	view += "\n"
	view += "\n"

	return view
}

func ClearConsole() {
	fmt.Print("\033[2J\033[H")
}

func ComposeUI(m *models.Model) {
	// Reset UI state - Bubble Tea will handle the visual refresh automatically
	// This is the recommended approach rather than direct console manipulation
}