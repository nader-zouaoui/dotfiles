#!/usr/bin/env bash
set -euo pipefail

TEAMS_RE='^teams-for-linux$'
SLACK_RE='^(Slack)$'

have() {
  hyprctl clients -j | jq -e --arg re "$1" '[ .[] | select(.class|test($re)) ] | length > 0' >/dev/null
}

addr_of() {
  hyprctl clients -j | jq -r --arg re "$1" '.[] | select(.class|test($re)) | .address' | head -n1
}

fix_layout() {
  # Only act if both exist
  if have "$TEAMS_RE" && have "$SLACK_RE"; then
    local t s
    t="$(addr_of "$TEAMS_RE")"
    s="$(addr_of "$SLACK_RE")"
    # Ensure workspace 5 + master layout + 50/50 split
    hyprctl dispatch movetoworkspace 5 "address:$t"
    hyprctl dispatch movetoworkspace 5 "address:$s"
    hyprctl dispatch workspace 5
    hyprctl dispatch layoutmsg "mfact exact 0.50"
    # Make Teams the master (left)
    hyprctl dispatch focuswindow "address:$t"
    hyprctl dispatch layoutmsg swapwithmaster
  fi
}

# Run once at start (catches already-open windows)
fix_layout

# Subscribe to Hyprland event socket; run fix each time a window opens
SOCK="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
socat -u - UNIX-CONNECT:"$SOCK" | while IFS= read -r line; do
  case "$line" in
    openwindow*|movewindow*|activewindow* )
      fix_layout
      ;;
  esac
done

