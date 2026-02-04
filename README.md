# Agent Manager (`am`)

A CLI tool for managing multiple AI coding agent sessions using tmux and fzf.

## Features

- **Interactive browser** - Browse and switch between agent sessions with fzf
- **Rich metadata** - See directory, git branch, agent type, and activity status
- **Live preview** - View terminal output from any session without attaching
- **Persistent sessions** - Sessions survive terminal close (tmux-based)
- **Multiple agent types** - Claude Code, Gemini CLI, Aider (extensible)

## Installation

### Prerequisites

Install required dependencies:

```bash
# macOS
brew install tmux fzf jq

# Ubuntu/Debian
sudo apt install tmux fzf jq

# Arch
sudo pacman -S tmux fzf jq
```

Version requirements:
- tmux >= 3.0
- fzf >= 0.40
- jq >= 1.6
- bash >= 4.0

### Install agent-manager

```bash
# Clone or download
git clone https://github.com/youruser/agent-manager.git
cd agent-manager

# Add to PATH (add to ~/.bashrc or ~/.zshrc)
export PATH="$PATH:$(pwd)"

# Or create symlink
ln -s "$(pwd)/am" /usr/local/bin/am
```

### Verify installation

```bash
am help
am version
```

## Quick Start

```bash
# Open interactive session browser
am

# Create new Claude session in current directory
am new

# Create session in specific directory
am new ~/code/myproject

# Create session with task description
am new ~/code/myproject -n "implement auth flow"

# Use different agent (gemini, aider)
am new -t gemini ~/code/myproject

# Attach to a session
am attach am-abc123

# Kill a session
am kill am-abc123

# See all sessions status
am status
```

## Usage

### Interactive Mode (default)

Just run `am` to open the fzf browser:

```
┌─────────────────────────────────────────────────────────────────────────┐
│ Agent Sessions | Enter:attach  Ctrl-N:new  Ctrl-X:kill  Ctrl-R:refresh  │
├─────────────────────────────────────────────────────────────────────────┤
│ > myapp/feature/auth [claude] (5m ago) "implement user auth"           │
│   myproject/main [claude] (2h ago)                                      │
│   tools/dev [gemini] (1d ago) "refactor build system"                   │
├─────────────────────────────────────────────────────────────────────────┤
│ Preview:                                                                │
│ Directory: /home/user/code/myapp                                       │
│ Branch: feature/auth                                                    │
│ Agent: claude | Running: 2h 15m | Last active: 5m ago                   │
│ ───────────────────────────────────────                                 │
│ > Reading src/auth/handler.ts...                                        │
│ > I'll implement the OAuth flow using...                                │
└─────────────────────────────────────────────────────────────────────────┘
```

### Keybindings

| Key | Action |
|-----|--------|
| `Enter` | Attach to selected session |
| `Ctrl-N` | Create new session |
| `Ctrl-X` | Kill selected session |
| `Ctrl-R` | Refresh session list |
| `Ctrl-P` | Toggle preview panel |
| `↑/↓` | Navigate sessions |
| `Esc` | Exit |

### Commands

```bash
am                      # Interactive browser (default)
am list                 # Same as above
am list --json          # Output JSON for scripting

am new [dir]            # Create new session
am new -t TYPE          # Specify agent type
am new -n "task"        # Add task description

am attach NAME          # Attach to session
am kill NAME            # Kill session
am kill --all           # Kill all sessions

am info NAME            # Show session details
am status               # Summary of all sessions
am help                 # Show help
```

## Configuration

Sessions and metadata are stored in `~/.agent-manager/`:

```
~/.agent-manager/
├── sessions.json       # Session metadata registry
└── config.yaml         # (future) User configuration
```

## Session Naming

Sessions are named with prefix `am-` followed by a 6-character hash:
- `am-abc123` - internal session name
- Display shows: `dirname/branch [agent] (time) "task"`

## Architecture

```
agent-manager/
├── am                  # Main executable
├── lib/
│   ├── utils.sh        # Common utilities
│   ├── registry.sh     # JSON metadata storage
│   ├── tmux.sh         # tmux wrapper functions
│   ├── agents.sh       # Agent launcher
│   └── fzf.sh          # fzf interface
├── tests/
│   └── test_all.sh     # Test suite
└── README.md
```

## Troubleshooting

### "Required command not found: tmux"

Install tmux: `brew install tmux` (macOS) or `apt install tmux` (Ubuntu)

### Sessions not showing

Run `am status` to check. Stale registry entries are cleaned automatically.

### Preview not working

Ensure the session exists and tmux is running. Try `tmux list-sessions`.

## Development

Run tests:

```bash
./tests/test_all.sh
```

Tests skip tmux-dependent tests if tmux isn't installed.

## License

MIT
