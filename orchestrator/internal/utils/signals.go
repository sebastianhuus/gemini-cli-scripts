package utils

import (
	"os"
	"os/signal"
	"syscall"

	"gemini-orchestrator/internal/models"
	tea "github.com/charmbracelet/bubbletea"
)

func ListenForSignals() tea.Cmd {
	return func() tea.Msg {
		sigChan := make(chan os.Signal, 1)
		signal.Notify(sigChan,
			syscall.SIGINT,  // Ctrl+C
			syscall.SIGTERM, // Termination request
			syscall.SIGHUP,  // Terminal disconnection
			syscall.SIGQUIT, // Quit signal
		)

		sig := <-sigChan
		return models.ShutdownMsg{Signal: sig}
	}
}