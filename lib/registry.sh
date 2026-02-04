#!/usr/bin/env bash
# registry.sh - Session metadata storage using JSON

# Source utils if not already loaded
[[ -z "$AM_DIR" ]] && source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

# Ensure jq is available
require_cmd jq

# Initialize registry file if needed
registry_init() {
    am_init
}

# Add a session to the registry
# Usage: registry_add <name> <directory> <branch> <agent_type> [task_description]
registry_add() {
    local name="$1"
    local directory="$2"
    local branch="$3"
    local agent_type="$4"
    local task="${5:-}"

    registry_init

    local created_at
    created_at=$(iso_timestamp)

    local tmp_file
    tmp_file=$(mktemp)

    jq --arg name "$name" \
       --arg dir "$directory" \
       --arg branch "$branch" \
       --arg agent "$agent_type" \
       --arg created "$created_at" \
       --arg task "$task" \
       '.sessions[$name] = {
           "name": $name,
           "directory": $dir,
           "branch": $branch,
           "agent_type": $agent,
           "created_at": $created,
           "task": $task
       }' "$AM_REGISTRY" > "$tmp_file" && mv "$tmp_file" "$AM_REGISTRY"
}

# Get a session from the registry
# Usage: registry_get <name>
# Returns JSON object or empty if not found
registry_get() {
    local name="$1"
    registry_init
    jq -r --arg name "$name" '.sessions[$name] // empty' "$AM_REGISTRY"
}

# Get a specific field from a session
# Usage: registry_get_field <name> <field>
registry_get_field() {
    local name="$1"
    local field="$2"
    registry_init
    jq -r --arg name "$name" --arg field "$field" '.sessions[$name][$field] // empty' "$AM_REGISTRY"
}

# Update a session field
# Usage: registry_update <name> <field> <value>
registry_update() {
    local name="$1"
    local field="$2"
    local value="$3"

    registry_init

    local tmp_file
    tmp_file=$(mktemp)

    jq --arg name "$name" \
       --arg field "$field" \
       --arg value "$value" \
       'if .sessions[$name] then .sessions[$name][$field] = $value else . end' \
       "$AM_REGISTRY" > "$tmp_file" && mv "$tmp_file" "$AM_REGISTRY"
}

# Remove a session from the registry
# Usage: registry_remove <name>
registry_remove() {
    local name="$1"
    registry_init

    local tmp_file
    tmp_file=$(mktemp)

    jq --arg name "$name" 'del(.sessions[$name])' "$AM_REGISTRY" > "$tmp_file" && mv "$tmp_file" "$AM_REGISTRY"
}

# List all sessions in the registry
# Usage: registry_list
# Returns newline-separated session names
registry_list() {
    registry_init
    jq -r '.sessions | keys[]' "$AM_REGISTRY" 2>/dev/null
}

# List all sessions with full data as JSON array
# Usage: registry_list_json
registry_list_json() {
    registry_init
    jq '.sessions | to_entries | map(.value)' "$AM_REGISTRY"
}

# Check if a session exists in registry
# Usage: registry_exists <name>
registry_exists() {
    local name="$1"
    registry_init
    jq -e --arg name "$name" '.sessions[$name] != null' "$AM_REGISTRY" &>/dev/null
}

# Garbage collection: remove registry entries for sessions that no longer exist in tmux
# Usage: registry_gc
registry_gc() {
    registry_init

    local removed=0
    local name

    for name in $(registry_list); do
        # Check if tmux session exists (using tmux_session_exists from tmux.sh if loaded)
        if ! tmux has-session -t "$name" 2>/dev/null; then
            registry_remove "$name"
            ((removed++))
        fi
    done

    if (( removed > 0 )); then
        log_info "Cleaned up $removed stale registry entries"
    fi

    echo "$removed"
}

# Count sessions in registry
# Usage: registry_count
registry_count() {
    registry_init
    jq '.sessions | length' "$AM_REGISTRY"
}

# Export registry to stdout as formatted JSON
# Usage: registry_export
registry_export() {
    registry_init
    jq '.' "$AM_REGISTRY"
}
