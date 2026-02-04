# AI Navigation Guide

Quick reference for AI agents working with this codebase.

## What This Is

CLI tool managing multiple AI coding sessions (Claude, Gemini) via tmux + fzf.

## Key Files

| File | Purpose |
|------|---------|
| `am` | Main entry point. Handles CLI args, routes to commands. |
| `lib/utils.sh` | Shared: colors, logging, time formatting, paths |
| `lib/registry.sh` | JSON storage for session metadata (`~/.agent-manager/sessions.json`) |
| `lib/tmux.sh` | tmux wrappers: create/kill/attach/capture sessions |
| `lib/agents.sh` | Agent lifecycle: launch, display formatting, kill |
| `lib/fzf.sh` | fzf UI: list generation, preview, main loop |

## Data Flow

```
User runs `am`
  → am (parse args)
  → fzf_main() (interactive UI)
  → tmux_attach() (connect to session)
```

```
User runs `am new ~/project`
  → agent_launch()
  → tmux_create_session()
  → registry_add()
  → tmux_send_keys (start claude/gemini)
```

## Key Functions

**Session lifecycle:**
- `agent_launch(dir, type, task)` - Creates session, registers, starts agent
- `agent_kill(name)` - Kills tmux + removes from registry

**Registry (JSON metadata):**
- `registry_add/get/update/remove/list` - CRUD for sessions.json
- `registry_gc()` - Remove entries for dead tmux sessions

**tmux:**
- `tmux_create_session(name, dir)` - New detached session
- `tmux_capture_pane(name, lines)` - Get terminal content for preview
- `tmux_get_activity(name)` - Last activity timestamp

**fzf:**
- `fzf_list_sessions()` - Format: `session|display_name`
- `fzf_preview(name)` - Renders preview panel
- `fzf_main()` - Main loop with keybindings

## Extension Points

**Add new agent type:**
```bash
# In lib/agents.sh, add to AGENT_COMMANDS:
declare -A AGENT_COMMANDS=(
    [claude]="claude"
    [gemini]="gemini"
    [newagent]="newagent-cli"  # Add here
)
```

**Add new CLI command:**
```bash
# In am, add case in main():
case "$cmd" in
    mycommand)
        shift
        cmd_mycommand "$@"
        ;;
```

**Modify preview display:**
Edit `agent_info()` in `lib/agents.sh` and `fzf_preview()` in `lib/fzf.sh`.

## Session Naming

Format: `am-XXXXXX` where XXXXXX = md5(directory + timestamp)[:6]

Display format: `dirname/branch [agent] (Xm ago) "task"`

## Dependencies

- tmux (session management)
- fzf (interactive UI)
- jq (JSON handling)

## Testing

```bash
./tests/test_all.sh  # Skips tmux tests if not installed
```

## Common Tasks

| Task | Where |
|------|-------|
| Change fzf keybindings | `lib/fzf.sh` → `fzf_main()` |
| Modify session display | `lib/agents.sh` → `agent_display_name()` |
| Add metadata field | `lib/registry.sh` → `registry_add()` |
| Change preview content | `lib/fzf.sh` → `fzf_preview()` |
