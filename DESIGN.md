# Agent Manager - Design Document

## Overview

A CLI tool for managing multiple AI coding agent sessions (Claude Code, Gemini CLI, etc.) using **tmux** for session persistence and **fzf** for an interactive browsing interface.

## Requirements

| Requirement | Value |
|-------------|-------|
| Use case | Both cross-project and same-project agents |
| Launch mode | Both from manager AND attach to existing |
| Agent types | Claude Code initially (extensible) |
| Persistence | Sessions must survive logout/reboot |
| Metadata | Rich: directory, branch, agent type, running time, last command |

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         agent-manager (am)                          │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌─────────────┐     ┌─────────────┐     ┌─────────────────────┐   │
│  │   am list   │────▶│     fzf     │────▶│   tmux attach/new   │   │
│  │  (default)  │     │  + preview  │     │                     │   │
│  └─────────────┘     └─────────────┘     └─────────────────────┘   │
│         │                   │                      │                │
│         ▼                   ▼                      ▼                │
│  ┌─────────────┐     ┌─────────────┐     ┌─────────────────────┐   │
│  │  Session    │     │  Preview    │     │  Agent Runner       │   │
│  │  Registry   │     │  Renderer   │     │  (claude, gemini)   │   │
│  │  (JSON)     │     │  (capture)  │     │                     │   │
│  └─────────────┘     └─────────────┘     └─────────────────────┘   │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

## Core Components

### 1. Session Registry (`~/.agent-manager/sessions.json`)

Stores metadata that tmux doesn't track natively:

```json
{
  "sessions": {
    "am-abc123": {
      "name": "am-abc123",
      "directory": "home/user/code/myapp",
      "branch": "feature/auth",
      "agent_type": "claude",
      "created_at": "2024-01-15T10:30:00Z",
      "last_command": "implement user auth flow",
      "pid": 12345
    }
  }
}
```

### 2. Session Naming Convention

```
am-<short-hash>
```

Where `<short-hash>` is derived from `directory + timestamp` for uniqueness.

The **display name** shown in fzf is composed from metadata:
```
myapp/feature/auth [claude] (2h ago) "implement user auth flow"
│       │             │        │        └── last command/task
│       │             │        └── activity indicator
│       │             └── agent type
│       └── git branch
└── directory basename
```

### 3. tmux Integration

**Why tmux over screen:**
- `capture-pane -p` outputs directly to stdout (no temp files)
- `session_activity` timestamp for detecting recent activity
- Rich format strings (`-F`) for scripting
- Plugin ecosystem (tmux-resurrect for reboot persistence)

**Session structure:**
```
tmux session: am-abc123
  └── window 0: agent
        └── pane 0: claude (or gemini, etc.)
```

### 4. Preview System

fzf preview will show:

```
┌─ Preview ────────────────────────────────────────────┐
│ 📁 home/user/code/myapp                           │
│ 🌿 feature/auth                                      │
│ 🤖 claude | Started: 2h 15m ago | Last active: 30s   │
│ ─────────────────────────────────────────────────────│
│ [Terminal output from tmux capture-pane]             │
│                                                      │
│ > Reading src/auth/handler.ts...                     │
│ > I'll implement the OAuth flow...                   │
│ > [tool calls shown here]                            │
│                                                      │
└──────────────────────────────────────────────────────┘
```

## CLI Interface

### Commands

```bash
# List/browse sessions (default action)
am                      # Opens fzf browser
am list                 # Same as above
am list --json          # Output JSON for scripting

# Create new session
am new                  # Interactive: pick directory, starts claude
am new /path/to/project # Start claude in specific directory
am new -t gemini        # Start gemini instead of claude
am new --name "my-task" # Custom display name

# Attach to session
am attach <session>     # Attach by name or fuzzy match

# Kill session
am kill <session>       # Kill specific session
am kill --all           # Kill all agent-manager sessions

# Session info
am info <session>       # Show detailed session info
am status               # Summary of all sessions
```

### fzf Keybindings

| Key | Action |
|-----|--------|
| `Enter` | Attach to selected session |
| `Ctrl-N` | Create new session (prompts for directory) |
| `Ctrl-X` | Kill selected session |
| `Ctrl-R` | Refresh session list |
| `Ctrl-D` | Detach from current (when inside tmux) |
| `Ctrl-P` | Toggle preview panel |
| `Tab` | Multi-select (for bulk operations) |

## Implementation Plan

### Phase 1: Core Infrastructure

1. **Session Registry Module**
   - JSON file management with atomic writes
   - CRUD operations for session metadata
   - Garbage collection (clean up stale entries)

2. **tmux Wrapper Module**
   - Create sessions with proper naming
   - Capture pane content
   - Get session activity timestamps
   - Attach/detach handling

3. **Agent Launcher Module**
   - Launch Claude Code in a tmux pane
   - Parse directory and detect git branch
   - Store initial command/task description

### Phase 2: fzf Interface

4. **List Generator**
   - Merge tmux sessions with registry metadata
   - Format for fzf display (rich metadata)
   - Sort by activity (most recent first)

5. **Preview Renderer**
   - Capture pane content via `tmux capture-pane`
   - Add metadata header
   - Handle color/formatting

6. **Main fzf Loop**
   - Key bindings for all actions
   - Reload after mutations
   - Handle edge cases (no sessions, etc.)

### Phase 3: Polish & Persistence

7. **Reboot Persistence**
   - Integrate tmux-resurrect or implement custom solution
   - Registry survives, tmux sessions need restoration
   - On launch, reconcile registry with actual tmux state

8. **Configuration**
   - `~/.agent-manager/config.yaml`
   - Customizable display format
   - Default agent type
   - Preview window settings

## File Structure

```
agent-manager/
├── am                      # Main executable (bash)
├── lib/
│   ├── registry.sh         # Session registry functions
│   ├── tmux.sh             # tmux wrapper functions
│   ├── agents.sh           # Agent launcher functions
│   ├── fzf.sh              # fzf interface functions
│   └── utils.sh            # Common utilities
├── config/
│   └── default.yaml        # Default configuration
└── DESIGN.md               # This file
```

## Technical Details

### Capturing Preview Content

```bash
# Get last 50 lines of pane content with ANSI colors
tmux capture-pane -t "$session" -p -S -50 -e
```

### Activity Detection

```bash
# Get session activity timestamp (seconds since epoch)
tmux list-sessions -F '#{session_name} #{session_activity}' \
  | grep "^$session " | cut -d' ' -f2

# Compare with current time for "X ago" display
now=$(date +%s)
age=$((now - activity))
```

### Git Branch Detection

```bash
# Get current branch for a directory
git -C "$directory" branch --show-current 2>/dev/null || echo "no branch"
```

### Session Creation Flow

```bash
# 1. Generate session name
name="am-$(echo "$directory$timestamp" | md5sum | head -c6)"

# 2. Create tmux session
tmux new-session -d -s "$name" -c "$directory"

# 3. Register metadata
registry_add "$name" "$directory" "$branch" "$agent_type"

# 4. Launch agent in the session
tmux send-keys -t "$name" "claude" Enter
```

## Dependencies

- **Required:**
  - tmux >= 3.0
  - fzf >= 0.40
  - bash >= 4.0
  - jq (for JSON handling)
  - git (for branch detection)

- **Optional:**
  - tmux-resurrect (for reboot persistence)
  - bat (for syntax highlighting in preview)

## Future Enhancements

1. **Multi-agent types:** Gemini CLI, Cursor, Aider, etc.
2. **Session groups:** Group related sessions
3. **Task tracking:** Integration with todo systems
4. **Remote sessions:** SSH tunnel support
5. **Web UI:** Optional browser-based view
6. **Notifications:** Alert when agent needs input
