#!/usr/bin/env bash
# Restore this Omarchy setup on a fresh machine.
#
# Run AFTER a stock Omarchy install:
#   bash <(curl -fsSL https://raw.githubusercontent.com/nader-zouaoui/dotfiles/master/bootstrap.sh)
#
# Clones over anonymous HTTPS so it works before SSH keys are set up;
# pushes are rewritten to SSH via pushInsteadOf.
set -euo pipefail

REPO_HTTPS="https://github.com/nader-zouaoui/dotfiles.git"
CFG="${HOME}/.config"

if [ -e "$CFG/.git" ]; then
  echo "==> $CFG is already a git repo; pulling latest instead."
  git -C "$CFG" pull --ff-only
else
  mkdir -p "$CFG"
  git -C "$CFG" init -b master
  git -C "$CFG" remote add origin "$REPO_HTTPS"
  git -C "$CFG" fetch origin master
  # Overwrite stock Omarchy configs with ours. Untracked stock files are
  # left in place (and ignored via the whitelist .gitignore).
  git -C "$CFG" checkout -f -B master origin/master
fi

# Pull anonymously over HTTPS, push over SSH once keys exist.
git config --global url."git@github.com:nader-zouaoui/".pushInsteadOf "https://github.com/nader-zouaoui/"

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
git -C "$CFG" submodule update --init --recursive

# submodule update leaves detached HEADs; the sync service commits into
# nvim and backgrounds, so attach them to master. (pomodoro is third-party
# and stays detached at the pinned commit.)
for sub in nvim omarchy/backgrounds; do
  git -C "$CFG/$sub" checkout -q -B master origin/master
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
