# dotfiles

My [Omarchy](https://omarchy.org) setup, versioned directly in `~/.config`.

## What's tracked

| Path | What | How |
|------|------|-----|
| `hypr/` | Hyprland config (bindings, monitors, autostart, …) | files |
| `omarchy/` | Omarchy shell config, custom plugins (`nader.*`), hooks, themes | files |
| `omarchy/backgrounds/` | Wallpapers used by the `nader.background` plugin | submodule → [backgrounds](https://github.com/nader-zouaoui/backgrounds) |
| `nvim/` | Neovim (LazyVim) config | submodule → [nvim](https://github.com/nader-zouaoui/nvim) |

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

## Day-to-day

The repo root is `~/.config`, so plain git works from anywhere inside it:

```bash
git -C ~/.config status
git -C ~/.config add -A && git -C ~/.config commit -m "..." && git -C ~/.config push
```

Neovim changes are committed inside `~/.config/nvim` (its own repo), then the
submodule pointer is bumped here.
