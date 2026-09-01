# dotfiles

My [Omarchy](https://omarchy.org) setup, versioned directly in `~/.config`.

## What's tracked

| Path | What | How |
|------|------|-----|
| `hypr/` | Hyprland config (bindings, monitors, autostart, …) | files |
| `omarchy/` | Omarchy shell config, custom plugins (`nader.*`), hooks, themes | files |
| `omarchy/backgrounds/` | Wallpapers used by the `nader.background` plugin | submodule → [backgrounds](https://github.com/nader-zouaoui/backgrounds) |
| `nvim/` | Neovim (LazyVim) config | submodule → [nvim](https://github.com/nader-zouaoui/nvim) |
| `omarchy/plugins/omarchy-pomodoro/` | Third-party bar plugin | submodule → [omarchy-pomodoro](https://github.com/rodrigojacarei/omarchy-pomodoro) |
| `dotfiles-sync/` + `systemd/user/dotfiles-sync.service` | Auto-commit/push watcher | files |

Everything else in `~/.config` is ignored via a whitelist `.gitignore`.

## Restore on a fresh Omarchy install

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/nader-zouaoui/dotfiles/master/bootstrap.sh)
```

Then log out and back in (or `hyprctl reload && omarchy restart shell`).

The script clones this repo into `~/.config` (overwriting stock configs),
moves the stock `nvim/` and `omarchy/backgrounds/` aside, and pulls both
submodules. It clones over HTTPS so it works before SSH keys are set up;
pushes are rewritten to SSH.

## Day-to-day: automatic sync

`dotfiles-sync.service` (systemd user unit, enabled by the bootstrap) watches
the tracked paths with inotify and, after 20s of quiet, auto-commits and
pushes — leaf repos first (`nvim`, `backgrounds`), then this repo, so
submodule pointer bumps land in the same pass. Push failures (offline) are
retried on the next change or within 30 minutes.

```bash
systemctl --user status dotfiles-sync   # is it running?
journalctl --user -u dotfiles-sync -f   # what is it doing?
```

Manual git still works from anywhere inside `~/.config`
(`git -C ~/.config status`); the service only commits what you leave dirty.
