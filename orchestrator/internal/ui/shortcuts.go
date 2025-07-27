package ui

import "strings"

var ModeShortcuts = []string{
	"! for bash mode",
	"/ for commands",
	"@ for file paths",
	"# to memorize",
}

var GeneralShortcuts = []string{
	"double tap esc to clear input",
	"shift + tab to auto-accept edits",
	"ctrl + r for verbose output",
	"shift + e for newline",
	"ctrl + _ to undo",
	"ctrl + z to suspend",
}

func DistributeShortcuts(terminalWidth int) []string {
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
	maxRows := len(ModeShortcuts)
	generalPerCol := (len(GeneralShortcuts) + 1) / 2 // Split general shortcuts across 2 columns
	if generalPerCol > maxRows {
		maxRows = generalPerCol
	}

	// Create grid
	grid := make([][]string, maxRows)
	for i := range grid {
		grid[i] = make([]string, 3)
	}

	// Fill column 1 with mode shortcuts
	for i, shortcut := range ModeShortcuts {
		grid[i][0] = shortcut
	}

	// Fill columns 2&3 with general shortcuts
	for i, shortcut := range GeneralShortcuts {
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
	maxRows := len(ModeShortcuts)
	if len(GeneralShortcuts) > maxRows {
		maxRows = len(GeneralShortcuts)
	}

	// Create grid
	grid := make([][]string, maxRows)
	for i := range grid {
		grid[i] = make([]string, 2)
	}

	// Fill columns
	for i, shortcut := range ModeShortcuts {
		grid[i][0] = shortcut
	}
	for i, shortcut := range GeneralShortcuts {
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
	formatted = append(formatted, ModeShortcuts...)
	formatted = append(formatted, GeneralShortcuts...)
	return formatted
}