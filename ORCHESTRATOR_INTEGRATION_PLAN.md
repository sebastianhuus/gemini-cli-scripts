# Orchestrator Integration Plan

## Overview
Implement a Quit → Clear → Run Script → Clear → Relaunch loop with state persistence to integrate auto scripts into the Go orchestrator while avoiding TUI conflicts.

## Problem Statement
- Go orchestrator uses Bubble Tea directly
- Zsh scripts use Gum (built on Bubble Tea/Bubbles)
- Nesting TUI applications causes formatting conflicts and broken layouts
- Solution: NEVER embed them inside each other

## Implementation Status: ✅ PARTIALLY COMPLETE

The orchestrator has been implemented with a **Zsh mode** that provides the quit/clear/run/relaunch pattern, but without state persistence. Current implementation uses a simpler approach that still achieves clean TUI separation.

### ✅ Implemented Components

1. **Zsh Mode Toggle**: Users can enter Zsh mode by typing `!` on empty input
2. **Command Execution Pattern**: `executeZshCommandAndRelaunch()` in `commands/handler.go:71-88`
3. **Clean Terminal Handoff**: Clear → Reset → Command → Clear → Relaunch pattern
4. **TUI State Management**: ZshMode field in `models.Model` struct
5. **UI Indicators**: Visual feedback when in Zsh mode

### ❌ Missing Components (Original Plan)

1. **State Persistence**: No `.orchestrator-state.json` file system
2. **Restore Flag**: No `--restore` flag in main.go
3. **Script-Specific Commands**: `/commit`, `/pr`, `/issue` commands show "not yet implemented"

## Current Architecture: Zsh Mode Implementation

### Current Implementation in `commands/handler.go:62-88`

```go
func HandleZshCommand(inputValue string, m *models.Model) tea.Cmd {
    // Add command to history
    m.Messages = append(m.Messages, fmt.Sprintf("$ %s", inputValue))
    resetInput(m)
    
    // Execute the zsh command and relaunch
    return executeZshCommandAndRelaunch(inputValue)
}

func executeZshCommandAndRelaunch(command string) tea.Cmd {
    // Get the current executable path for relaunching
    execPath, err := os.Executable()
    if err != nil {
        execPath = os.Args[0] // Fallback to original command
    }
    
    // Create the command chain: clear && reset && [command] && clear && exec [orchestrator-path]
    cmdString := fmt.Sprintf(`
        clear
        reset
        %s
        clear
        exec %s
    `, command, execPath)
    
    return tea.ExecProcess(exec.Command("zsh", "-c", cmdString), nil)
}
```

### ZshMode Integration in `main.go:171-178` and `main.go:256-258`

```go
// Handle zsh mode toggle with "!"
if len(msg.Runes) == 1 && string(msg.Runes[0]) == "!" && m.TextInput.Value() == "" {
    m.ZshMode = !m.ZshMode
    // Clear other modes when entering zsh mode
    m.ShowSuggestions = false
    m.ShowHelp = false
    // Don't add any messages to chat history
    return m, nil
}

// Handle zsh mode commands
if m.ZshMode {
    return m, commands.HandleZshCommand(inputValue, &m.Model)
}
```

## Original Plan Components (Not Yet Implemented)

### 1. State Persistence Structure (PLANNED)

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

### 2. Enhanced Command Handler (PLANNED)

Update `/commit`, `/pr`, `/issue` commands in `commands/handler.go:26-45`:

```go
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

### 3. Main Program with Restore Flag (PLANNED)

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

## Current Flow Diagram (Zsh Mode - Working)

```
User types "!" to enter Zsh mode
    ↓
User types "auto-commit fix bug"
    ↓
Message added to history: "$ auto-commit fix bug"
    ↓  
Orchestrator quits
    ↓
Terminal clears + resets
    ↓
auto-commit "fix bug" runs (full Gum UI)
    ↓
Terminal clears again  
    ↓
Orchestrator relaunches automatically
    ↓
User returns to clean orchestrator interface
```

## Planned Flow Diagram (State Persistence - Not Implemented)

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
🔄 **Current UX**: Clean transition but no state persistence
🔄 **Planned UX**: Seamless conversation flow with state persistence

## Next Steps to Complete Original Plan

1. **Add State Persistence**: Implement `SaveState()` and `LoadState()` methods in `models/app.go`
2. **Add Restore Flag**: Update `main.go` to handle `--restore` flag and load state
3. **Enable Script Commands**: Replace "not yet implemented" messages in `/commit`, `/pr`, `/issue` handlers
4. **State Management**: Add success messages and cleanup logic for state files

## Current Implementation Notes

- **Zsh Mode**: Toggle with `!`, exit with backspace on empty input
- **Command Execution**: Any command in Zsh mode triggers quit/clear/run/relaunch
- **Terminal Reset**: Both before and after script execution for clean state
- **Scripts**: Run with full Gum UI capabilities - no degraded experience
- **TUI Separation**: Each TUI owns the terminal completely during execution

## Why This Approach is Most Elegant

| Approach | Development Effort | Risk | UX Quality | Maintains Existing Scripts |
|----------|-------------------|------|------------|----------------------------|
| **Current (Zsh Mode)** | **Low** | **Low** | **High** | **✅ Yes** |
| **Quit/Relaunch + State** | **Medium** | **Low** | **Very High** | **✅ Yes** |
| Port to Go | High | High | Medium | ❌ No |  
| Headless mode | Medium | Medium | Low | ❌ Loses Gum |
| Extract to libraries | High | Medium | High | ❌ Requires rewrite |

The current implementation successfully demonstrates the core principle: "NEVER embed TUI applications inside each other" while providing clean user experience. State persistence would enhance continuity but is not required for functional integration.