#!/usr/bin/env bash
# Restore this Omarchy setup on a fresh machine.
#
# Run AFTER a stock Omarchy install:
#   bash <(curl -fsSL https://raw.githubusercontent.com/nader-zouaoui/dotfiles/master/bootstrap.sh)
#
# The dotfiles and backgrounds repos are public and clone anonymously over
# HTTPS. The nvim repo is PRIVATE: it restores only once GitHub auth exists
# (an SSH key, or `gh auth login`). Rerun this script after setting that up —
# it is safe to run repeatedly.
set -uo pipefail

REPO_HTTPS="https://github.com/nader-zouaoui/dotfiles.git"
CFG="${HOME}/.config"

# If SSH auth to GitHub already works, fetch everything over SSH (needed for
# the private nvim repo). Otherwise stay on anonymous HTTPS for the public
# repos and rewrite only pushes to SSH.
ssh_probe=$(ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -T git@github.com 2>&1 || true)
if [[ "$ssh_probe" == *"successfully authenticated"* ]]; then
  git config --global url."git@github.com:".insteadOf "https://github.com/"
  ssh_ok=1
  echo "==> GitHub SSH auth works; using SSH for all repos."
else
  git config --global url."git@github.com:nader-zouaoui/".pushInsteadOf "https://github.com/nader-zouaoui/"
  ssh_ok=0
  echo "==> No GitHub SSH auth yet; restoring public repos only."
fi

if [ -e "$CFG/.git" ]; then
  echo "==> $CFG is already a git repo; pulling latest."
  git -C "$CFG" pull --ff-only --no-recurse-submodules
else
  mkdir -p "$CFG"
  git -C "$CFG" init -b master
  git -C "$CFG" remote add origin "$REPO_HTTPS"
  git -C "$CFG" fetch origin master
  # Overwrite stock Omarchy configs with ours. Untracked stock files are
  # left in place (and ignored via the whitelist .gitignore).
  git -C "$CFG" checkout -f -B master origin/master
fi

# Submodules refuse to clone into a non-empty directory; a stock Omarchy
# install ships content in both of these, so move it aside first.
for sub in nvim omarchy/backgrounds; do
  dir="$CFG/$sub"
  if [ -d "$dir" ] && [ ! -e "$dir/.git" ] && [ -n "$(ls -A "$dir" 2>/dev/null)" ]; then
    mv "$dir" "$dir.pre-dotfiles.$(date +%s).bak"
    echo "==> Moved stock $sub aside."
  fi
done

git -C "$CFG" submodule sync --quiet
failed=""
for sub in omarchy/backgrounds omarchy/plugins/omarchy-pomodoro nvim; do
  git -C "$CFG" submodule update --init "$sub" || failed="$failed $sub"
done
if [ -n "$failed" ]; then
  echo "!!> Could not fetch:$failed"
  echo "    nvim is a private repo. Set up a GitHub SSH key (or 'gh auth"
  echo "    login'), then rerun this script to finish the restore."
fi

# submodule update leaves detached HEADs; the sync service commits into
# nvim and backgrounds, so attach them to master. (pomodoro is third-party
# and stays detached at the pinned commit.)
for sub in nvim omarchy/backgrounds; do
  [ -e "$CFG/$sub/.git" ] && git -C "$CFG/$sub" checkout -q -B master origin/master
done

# Start the auto-commit/push watcher.
command -v inotifywait >/dev/null || omarchy pkg add inotify-tools || true
if command -v systemctl >/dev/null; then
  systemctl --user daemon-reload || true
  systemctl --user enable --now dotfiles-sync.service || true
fi

echo "==> Done."
echo "    Reload with:  hyprctl reload && omarchy restart shell"
echo "    (or just log out and back in)"
