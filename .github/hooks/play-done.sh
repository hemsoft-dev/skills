#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.toolName')
if [ "$TOOL_NAME" = "task_complete" ]; then
    SETTINGS="$SCRIPT_DIR/hooks-settings.json"
    if [ ! -f "$SETTINGS" ]; then
        # Fallback: check CWD-relative path (for when script runs in project context)
        SETTINGS=".github/hooks/hooks-settings.json"
    fi
    AUDIO_ENABLED=true
    if [ -f "$SETTINGS" ]; then
        AUDIO_ENABLED=$(jq -r '.audioEnabled // true' "$SETTINGS")
    fi
    if [ "$AUDIO_ENABLED" = "true" ]; then
        MP3="$SCRIPT_DIR/done.mp3"
        if [ ! -f "$MP3" ]; then MP3=".github/hooks/done.mp3"; fi
        ffplay -nodisp -autoexit -volume 50 "$MP3" &>/dev/null &
    fi
fi
