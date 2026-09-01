#!/usr/bin/env bash
# dotfiles-sync: watch the tracked config paths and auto-commit + push.
#
# Runs as a systemd user service (dotfiles-sync.service). Waits for a quiet
# window after the last file event before syncing, so editor save-bursts and
# theme switches produce one commit, not dozens. Also wakes up periodically
# to retry pushes that failed while offline.
#
# Sync order matters: leaf repos (nvim, backgrounds) commit first, so the
# superproject commit picks up their new submodule pointers in the same pass.
set -u

CFG="$HOME/.config"
QUIET="${DOTFILES_SYNC_QUIET:-20}"        # seconds of silence before syncing
FALLBACK="${DOTFILES_SYNC_FALLBACK:-1800}" # periodic wake for push retries
EVENTS=(-e modify -e create -e delete -e move -e attrib)
EXCLUDE='(/\.git(/|$)|\.bak|\.swp$|~$|/4913$|\.tmp$)'
WATCH=(
  "$CFG/hypr" "$CFG/omarchy" "$CFG/nvim" "$CFG/dotfiles-sync"
  "$CFG/.gitignore" "$CFG/.gitmodules" "$CFG/README.md" "$CFG/bootstrap.sh"
)

# Headless-safe SSH: never prompt, and trust github.com on first contact
# (a freshly bootstrapped machine has no known_hosts entry yet).
export GIT_SSH_COMMAND="ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new"

log() { echo "$*"; }

sync_repo() {
  local repo=$1 label=$2
  [ -e "$repo/.git" ] || { log "skip $label: not a git repo"; return; }

  # Never commit from a detached HEAD (there is nowhere to push it).
  local branch
  branch=$(git -C "$repo" symbolic-ref --short -q HEAD) \
    || { log "skip $label: detached HEAD"; return; }

  git -C "$repo" add -A
  if ! git -C "$repo" diff --cached --quiet; then
    local files n msg
    files=$(git -C "$repo" diff --cached --name-only)
    n=$(printf '%s\n' "$files" | wc -l)
    msg=$(printf '%s\n' "$files" | head -3 | paste -sd , | sed 's/,/, /g')
    [ "$n" -gt 3 ] && msg="$msg (+$((n - 3)) more)"
    git -C "$repo" commit -q -m "auto($label): $msg" && log "committed $label: $msg"
  fi

  # Push anything unpushed, independent of tracking config; tolerate being
  # offline (the commit stays local and the next cycle retries).
  local ahead
  ahead=$(git -C "$repo" rev-list --count "origin/$branch..HEAD" 2>/dev/null || echo 1)
  if [ "${ahead:-1}" -gt 0 ]; then
    if git -C "$repo" push -q origin "$branch" 2>/dev/null; then
      log "pushed $label"
    else
      log "push failed for $label; will retry"
    fi
  fi
}

do_sync() {
  sync_repo "$CFG/nvim" nvim
  sync_repo "$CFG/omarchy/backgrounds" backgrounds
  sync_repo "$CFG" dotfiles
}

# Single instance.
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/dotfiles-sync.lock"
flock -n 9 || { log "another instance is running"; exit 0; }

command -v inotifywait >/dev/null \
  || { log "inotifywait not found; install inotify-tools"; exit 1; }

# Catch whatever changed while the service was down.
do_sync

while true; do
  inotifywait -qq -r "${EVENTS[@]}" --exclude "$EXCLUDE" \
    --timeout "$FALLBACK" "${WATCH[@]}"
  rc=$?
  if [ "$rc" -eq 1 ]; then
    log "inotifywait error; retrying in 60s"
    sleep 60
    continue
  fi
  if [ "$rc" -eq 0 ]; then
    # Debounce: keep resetting until a full quiet window passes (exit 2).
    while inotifywait -qq -r "${EVENTS[@]}" --exclude "$EXCLUDE" \
      --timeout "$QUIET" "${WATCH[@]}"; do :; done
  fi
  do_sync
done
