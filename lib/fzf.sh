#!/usr/bin/env bash
# fzf.sh - fzf interface functions

# Source dependencies if not already loaded
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
[[ -z "$AM_DIR" ]] && source "$SCRIPT_DIR/utils.sh"
[[ "$(type -t tmux_list_am_sessions)" != "function" ]] && source "$SCRIPT_DIR/tmux.sh"
[[ "$(type -t registry_get_field)" != "function" ]] && source "$SCRIPT_DIR/registry.sh"
[[ "$(type -t agent_display_name)" != "function" ]] && source "$SCRIPT_DIR/agents.sh"

# Ensure fzf is available
require_cmd fzf

# Generate session list for fzf
# Format: "session_name|display_name"
# Usage: fzf_list_sessions
fzf_list_sessions() {
    local session

    # Clean up stale registry entries first
    registry_gc >/dev/null 2>&1

    # Get sessions sorted by activity
    for session in $(tmux_list_am_sessions_with_activity | awk '{print $1}'); do
        local display
        display=$(agent_display_name "$session")
        echo "${session}|${display}"
    done
}

# Preview function for fzf
# Usage: fzf_preview <session_name>
fzf_preview() {
    local session_name="$1"

    if [[ -z "$session_name" ]]; then
        echo "No session selected"
        return
    fi

    if ! tmux_session_exists "$session_name"; then
        echo "Session not found: $session_name"
        return
    fi

    # Header with metadata
    echo -e "${BOLD}═══ Session Info ═══${RESET}"
    agent_info "$session_name"
    echo -e "${BOLD}═══ Terminal Output ═══${RESET}"
    echo ""

    # Capture pane content (last 100 lines)
    tmux_capture_pane "$session_name" 100
}

# Export functions for fzf subshells
_fzf_export_functions() {
    export AM_DIR AM_REGISTRY AM_SESSION_PREFIX
    export -f fzf_preview agent_info agent_display_name
    export -f registry_get_field registry_init
    export -f tmux_capture_pane tmux_session_exists tmux_get_activity tmux_get_created
    export -f format_time_ago format_duration dir_basename truncate abspath epoch_now
    export -f require_cmd log_info log_error log_warn log_success am_init
}

# Main fzf interface
# Usage: fzf_main
fzf_main() {
    _fzf_export_functions

    # Get the path to this script's directory for the preview command
    local lib_dir
    lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    # Check if any sessions exist
    local sessions
    sessions=$(fzf_list_sessions)

    if [[ -z "$sessions" ]]; then
        echo "No agent sessions found."
        echo ""
        echo "Create a new session with: am new [directory]"
        return 0
    fi

    # Build preview command that sources all libs
    local preview_cmd="source '$lib_dir/utils.sh' && source '$lib_dir/tmux.sh' && source '$lib_dir/registry.sh' && source '$lib_dir/agents.sh' && fzf_preview {1}"

    # Run fzf
    local selected
    selected=$(echo "$sessions" | fzf \
        --ansi \
        --delimiter='|' \
        --with-nth=2 \
        --header="Agent Sessions | Enter:attach  Ctrl-N:new  Ctrl-X:kill  Ctrl-R:refresh  Ctrl-P:preview" \
        --preview="$preview_cmd" \
        --preview-window="right:60%:wrap" \
        --bind="ctrl-r:reload(source '$lib_dir/utils.sh' && source '$lib_dir/tmux.sh' && source '$lib_dir/registry.sh' && source '$lib_dir/agents.sh' && fzf_list_sessions)" \
        --bind="ctrl-p:toggle-preview" \
        --bind="ctrl-x:execute-silent(source '$lib_dir/utils.sh' && source '$lib_dir/tmux.sh' && source '$lib_dir/registry.sh' && source '$lib_dir/agents.sh' && agent_kill {1})+reload(source '$lib_dir/utils.sh' && source '$lib_dir/tmux.sh' && source '$lib_dir/registry.sh' && source '$lib_dir/agents.sh' && fzf_list_sessions)" \
        --expect="ctrl-n" \
    )

    # Parse result
    local key session_name
    key=$(echo "$selected" | head -n1)
    session_name=$(echo "$selected" | tail -n1 | cut -d'|' -f1)

    # Handle expected keys
    case "$key" in
        ctrl-n)
            # New session - return special code
            echo "__NEW_SESSION__"
            return 0
            ;;
    esac

    # Attach to selected session
    if [[ -n "$session_name" ]]; then
        echo "$session_name"
    fi
}

# Simplified list output (no fzf, just print)
# Usage: fzf_list_simple
fzf_list_simple() {
    local session
    for session in $(tmux_list_am_sessions_with_activity | awk '{print $1}'); do
        local display
        display=$(agent_display_name "$session")
        echo "$display"
    done
}

# JSON output for scripting
# Usage: fzf_list_json
fzf_list_json() {
    registry_gc >/dev/null 2>&1

    local sessions=()
    local session

    for session in $(tmux_list_am_sessions_with_activity | awk '{print $1}'); do
        local directory branch agent_type task
        directory=$(registry_get_field "$session" "directory")
        branch=$(registry_get_field "$session" "branch")
        agent_type=$(registry_get_field "$session" "agent_type")
        task=$(registry_get_field "$session" "task")

        local activity
        activity=$(tmux_get_activity "$session")
        local created
        created=$(tmux_get_created "$session")

        sessions+=("$(jq -n \
            --arg name "$session" \
            --arg dir "$directory" \
            --arg branch "$branch" \
            --arg agent "$agent_type" \
            --arg task "$task" \
            --arg activity "$activity" \
            --arg created "$created" \
            '{name: $name, directory: $dir, branch: $branch, agent_type: $agent, task: $task, activity: ($activity | tonumber), created: ($created | tonumber)}'
        )")
    done

    # Combine into array
    if [[ ${#sessions[@]} -eq 0 ]]; then
        echo "[]"
    else
        printf '%s\n' "${sessions[@]}" | jq -s '.'
    fi
}
