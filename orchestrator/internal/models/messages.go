package models

import (
	"os"
	"os/signal"
	"syscall"
	"time"

	tea "github.com/charmbracelet/bubbletea"
)

type BuildCompleteMsg struct{}
type BuildErrorMsg struct{ Err error }
type ShutdownMsg struct{ Signal os.Signal }
type CtrlCTimeoutMsg struct{}

func CtrlCTimeoutCmd() tea.Cmd {
	return tea.Tick(time.Second, func(time.Time) tea.Msg {
		return CtrlCTimeoutMsg{}
	})
}

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
		return ShutdownMsg{Signal: sig}
	}
}