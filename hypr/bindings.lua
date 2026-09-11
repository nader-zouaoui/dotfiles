-- Personal keybindings, ported from the pre-quattro bindings.conf

-- Application launchers
hl.unbind("SUPER + L") -- default: toggle workspace layout
hl.unbind("SUPER + SHIFT + P") -- default: Google Photos webapp
hl.unbind("SUPER + SHIFT + S") -- default: Google Maps webapp
hl.unbind("SUPER + SHIFT + F") -- default: File manager

o.bind("SUPER + B", "Browser", "omarchy-launch-browser")
o.bind("SUPER + SHIFT + T", "Activity", { tui = "btop" })
-- SUPER+SHIFT+N (Editor), SUPER+SHIFT+D (Docker), SUPER+SHIFT+O (Obsidian) and
-- SUPER+SHIFT+ALT+G (WhatsApp) are already bound identically by Omarchy's
-- defaults. Re-binding them here without hl.unbind made each fire twice.
o.bind("SUPER + SHIFT + F", "File manager", { launch = "nautilus --new-window" })

-- Tmux terminal (replace default with cwd-aware version)
hl.unbind("SUPER + ALT + RETURN")
o.bind("SUPER + ALT + RETURN", "Tmux", 'uwsm-app -- xdg-terminal-exec --dir="$(omarchy-cmd-terminal-cwd)" tmux new')

-- Omarchy menu on SUPER+SHIFT+P
o.bind("SUPER + SHIFT + P", "Omarchy menu", "omarchy-menu")

-- SUPER+T runs btop (default float-toggle unbound)
hl.unbind("SUPER + T")
o.bind("SUPER + T", "Activity", { tui = "btop" })

-- Region screenshot
o.bind("SUPER + SHIFT + S", "Screenshot of region", "omarchy-capture-screenshot region")

-- Vim-style focus on SUPER+HJKL (defaults on K/J unbound)
hl.unbind("SUPER + K")
hl.unbind("SUPER + J")
o.bind("SUPER + H", "Move focus left", hl.dsp.focus({ direction = "l" }))
o.bind("SUPER + J", "Move focus up", hl.dsp.focus({ direction = "u" }))
o.bind("SUPER + K", "Move focus down", hl.dsp.focus({ direction = "d" }))
o.bind("SUPER + L", "Move focus right", hl.dsp.focus({ direction = "r" }))

-- Keybindings menu moved to SUPER+SHIFT+K (SUPER+K now moves focus)
o.bind("SUPER + SHIFT + K", "Show key bindings", "omarchy-menu-keybindings")
