package models

import "strings"

var SlashCommands = []string{
	"/commit",
	"/pr",
	"/issue",
	"/help",
	"/clear",
	"/reload",
}

func (m *Model) UpdateSuggestions() {
	input := m.TextInput.Value()

	if strings.HasPrefix(input, "/") {
		m.ShowHelp = false
		m.ZshMode = false // Clear zsh mode when typing slash commands
		oldSuggestions := m.Suggestions
		m.Suggestions = []string{}
		for _, cmd := range SlashCommands {
			if strings.HasPrefix(cmd, input) {
				m.Suggestions = append(m.Suggestions, cmd)
			}
		}
		m.ShowSuggestions = len(m.Suggestions) > 0

		// Only reset selection if suggestions changed or if we had no suggestions before
		if len(oldSuggestions) == 0 || !slicesEqual(oldSuggestions, m.Suggestions) {
			m.SelectedSuggestion = 0
		} else if m.SelectedSuggestion >= len(m.Suggestions) {
			// Clamp selection if it's out of bounds
			m.SelectedSuggestion = len(m.Suggestions) - 1
		}
	} else {
		m.ShowSuggestions = false
		m.Suggestions = []string{}
	}
}