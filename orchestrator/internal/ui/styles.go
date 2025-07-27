package ui

import "github.com/charmbracelet/lipgloss"

var (
	FocusedStyle = lipgloss.NewStyle().Foreground(lipgloss.Color("205"))
	BlurredStyle = lipgloss.NewStyle().Foreground(lipgloss.Color("240"))
	TitleStyle   = lipgloss.NewStyle().
			Background(lipgloss.Color("62")).
			Foreground(lipgloss.Color("230")).
			Padding(0, 1).
			MarginBottom(1)
	SuggestionStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#CBC8C6")).
			Padding(0, 2)
	SelectedSuggestionStyle = lipgloss.NewStyle().
				Foreground(lipgloss.Color("#4E5EDE")).
				Padding(0, 2)
	InputBoxStyle = lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).
			BorderForeground(lipgloss.Color("#CBC8C6")).
			Padding(0, 1)
	HelpTextStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#CBC8C6")).
			MarginTop(1).
			Padding(0, 2)
	MessageStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#CBC8C6"))
)

func InitSpinnerStyle() lipgloss.Style {
	return lipgloss.NewStyle().Foreground(lipgloss.Color("205"))
}