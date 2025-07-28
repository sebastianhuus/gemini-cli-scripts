package utils

import (
	"fmt"
	"os"
	"os/exec"
	"strings"
	"syscall"

	"gemini-orchestrator/internal/models"
	tea "github.com/charmbracelet/bubbletea"
)

func BuildAndReloadCmd() tea.Cmd {
	return func() tea.Msg {
		// Get the current executable path
		execPath, err := os.Executable()
		if err != nil {
			return models.BuildErrorMsg{Err: fmt.Errorf("failed to get executable path: %w", err)}
		}

		// Get the source directory (where main.go is located)
		// This handles symlinks by getting the directory of the actual binary
		sourceDir := execPath
		if info, err := os.Lstat(execPath); err == nil && info.Mode()&os.ModeSymlink != 0 {
			// It's a symlink, resolve it
			if realPath, err := os.Readlink(execPath); err == nil {
				if !strings.HasPrefix(realPath, "/") {
					// Relative symlink, make it absolute
					sourceDir = execPath[:strings.LastIndex(execPath, "/")+1] + realPath
				} else {
					sourceDir = realPath
				}
			}
		}

		// Get the directory containing the executable (where main.go should be)
		sourceDir = sourceDir[:strings.LastIndex(sourceDir, "/")]

		// Build the new binary
		buildCmd := exec.Command("go", "build", "-o", execPath, "main.go")
		buildCmd.Dir = sourceDir

		output, err := buildCmd.CombinedOutput()
		if err != nil {
			return models.BuildErrorMsg{Err: fmt.Errorf("failed to build: %w\nOutput: %s", err, string(output))}
		}

		// Signal build completion
		return models.BuildCompleteMsg{}
	}
}

func ReloadOrchestrator() error {
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