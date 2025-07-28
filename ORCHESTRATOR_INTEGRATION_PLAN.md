# Orchestrator Integration Plan

## Overview
Implement a Quit → Clear → Run Script → Clear → Relaunch loop with state persistence to integrate auto scripts into the Go orchestrator while avoiding TUI conflicts.

## Problem Statement
- Go orchestrator uses Bubble Tea directly
- Zsh scripts use Gum (built on Bubble Tea/Bubbles)
- Nesting TUI applications causes formatting conflicts and broken layouts
- Solution: NEVER embed them inside each other

## Architecture: State Persistence with Clean Separation

### 1. State Persistence Structure

Add to `models/app.go`:

```go
type PersistentState struct {
    Messages    []string `json:"messages"`
    LastCommand string   `json:"last_command"`
    Timestamp   int64    `json:"timestamp"`
}

func (m *Model) SaveState() error {
    state := PersistentState{
        Messages:    m.Messages,
        LastCommand: m.TextInput.Value(),
        Timestamp:   time.Now().Unix(),
    }
    
    data, _ := json.Marshal(state)
    return os.WriteFile(".orchestrator-state.json", data, 0644)
}

func (m *Model) LoadState() error {
    data, err := os.ReadFile(".orchestrator-state.json")
    if err != nil {
        return err
    }
    
    var state PersistentState
    if err := json.Unmarshal(data, &state); err != nil {
        return err
    }
    
    m.Messages = state.Messages
    // Add success message about script execution
    m.Messages = append(m.Messages, "✅ Script completed successfully")
    
    return nil
}
```

### 2. Command Handler with Relaunch Logic

Update `commands/handler.go`:

```go
import (
    "os"
    "os/exec"
)

func HandleCommand(inputValue string, m *models.Model) tea.Cmd {
    // Handle /commit command
    if strings.HasPrefix(inputValue, "/commit") {
        context := strings.TrimPrefix(inputValue, "/commit")
        context = strings.TrimSpace(context)
        
        // Save state before quit
        m.SaveState()
        
        return tea.Sequence(
            tea.Printf("Launching auto-commit..."),
            executeScriptAndRelaunch("auto-commit", context),
        )
    }
    
    // Handle /pr command  
    if strings.HasPrefix(inputValue, "/pr") {
        context := strings.TrimPrefix(inputValue, "/pr")
        context = strings.TrimSpace(context)
        
        m.SaveState()
        return executeScriptAndRelaunch("auto-pr", context)
    }
    
    // Handle /issue command
    if inputValue == "/issue" {
        m.SaveState()
        return executeScriptAndRelaunch("auto-issue", "")
    }
    
    // ... rest of existing commands
}

func executeScriptAndRelaunch(script, context string) tea.Cmd {
    return tea.ExecProcess(exec.Command("bash", "-c", 
        fmt.Sprintf(`
            clear
            reset  
            %s %s
            clear
            exec %s --restore
        `, script, context, os.Args[0])), nil)
}
```

### 3. Main Program with Restore Flag

Update `main.go`:

```go
func main() {
    ui.ClearConsole()

    initialModel := models.InitialModel()
    
    // Check for --restore flag
    if len(os.Args) > 1 && os.Args[1] == "--restore" {
        if err := initialModel.LoadState(); err == nil {
            // Clean up state file after successful restore
            os.Remove(".orchestrator-state.json")
        }
    }
    
    wrappedModel := orchestratorModel{Model: initialModel}

    p := tea.NewProgram(wrappedModel)
    if _, err := p.Run(); err != nil {
        log.Fatal(err)
        os.Exit(1)
    }
}
```

## Flow Diagram

```
User types "/commit fix bug"
    ↓
Orchestrator saves state to .orchestrator-state.json
    ↓  
Orchestrator quits
    ↓
Terminal clears + resets
    ↓
auto-commit "fix bug" runs (full Gum UI)
    ↓
Terminal clears again  
    ↓
Orchestrator relaunches with --restore flag
    ↓
State loads from .orchestrator-state.json
    ↓
User sees their message history + "✅ Script completed"
```

## Benefits

✅ **Zero code changes** to existing mature Zsh scripts  
✅ **Preserves all Gum UI sophistication** in scripts  
✅ **Clean user experience** - no broken formatting  
✅ **Minimal development effort** - just orchestration logic  
✅ **Maintains proven functionality** - scripts work exactly as designed  
✅ **No risk of introducing bugs** from porting/refactoring  
✅ **Seamless UX**: User sees continuous conversation flow  
✅ **Stateful**: Remembers entire session context

## Implementation Notes

- State file (`.orchestrator-state.json`) is automatically cleaned up after successful restore
- Terminal is reset both before and after script execution to ensure clean state
- Scripts run with full Gum UI capabilities - no degraded experience
- Each TUI owns the terminal completely during its execution (single-responsibility principle)
- Context is preserved seamlessly across the quit/relaunch cycle

## Why This Approach is Most Elegant

| Approach | Development Effort | Risk | UX Quality | Maintains Existing Scripts |
|----------|-------------------|------|------------|----------------------------|
| **Quit/Relaunch** | **Low** | **Low** | **High** | **✅ Yes** |
| Port to Go | High | High | Medium | ❌ No |  
| Headless mode | Medium | Medium | Low | ❌ Loses Gum |
| Extract to libraries | High | Medium | High | ❌ Requires rewrite |

This approach respects the design principle: "NEVER embed TUI applications inside each other" while providing a seamless user experience through intelligent state management.