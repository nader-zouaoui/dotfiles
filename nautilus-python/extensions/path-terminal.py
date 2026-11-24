import os
import shutil

from gi import require_version

require_version("Nautilus", "4.1")

from gi.repository import GObject, Gio, Nautilus


class PathAndTerminalActions(GObject.GObject, Nautilus.MenuProvider):
    """Adds "Copy as Path" and "Open in Terminal" to the right-click menu."""

    def _paths(self, files):
        paths = []

        for file in files:
            location = file.get_location()
            path = location.get_path() if location else None
            if path and path not in paths:
                paths.append(path)

        return paths

    def _copy(self, _menu, paths):
        wl_copy = shutil.which("wl-copy")
        if wl_copy:
            Gio.Subprocess.new(
                [wl_copy, "--", "\n".join(paths)], Gio.SubprocessFlags.NONE
            )

    def _open_terminal(self, _menu, directory):
        terminal = shutil.which("xdg-terminal-exec")
        if not terminal:
            return

        launcher = Gio.SubprocessLauncher.new(Gio.SubprocessFlags.NONE)
        launcher.set_cwd(directory)
        launcher.spawnv([terminal])

    def _copy_item(self, name, paths):
        item = Nautilus.MenuItem(
            name=f"PathAndTerminal::{name}",
            label="Copy as Path" if len(paths) == 1 else "Copy as Paths",
            icon="edit-copy",
        )
        item.connect("activate", self._copy, paths)
        return item

    def _terminal_item(self, name, directory):
        item = Nautilus.MenuItem(
            name=f"PathAndTerminal::{name}",
            label="Open in Terminal",
            icon="utilities-terminal",
        )
        item.connect("activate", self._open_terminal, directory)
        return item

    # Right-click on selected files/folders
    def get_file_items(self, *args):
        files = args[0] if len(args) == 1 else args[1]
        paths = self._paths(files)
        if not paths:
            return []

        items = [self._copy_item("copy_path", paths)]

        if len(paths) == 1 and os.path.isdir(paths[0]):
            items.append(self._terminal_item("open_terminal", paths[0]))

        return items

    # Right-click on empty space in a folder
    def get_background_items(self, *args):
        folder = args[0] if len(args) == 1 else args[1]
        paths = self._paths([folder])
        if not paths:
            return []

        return [
            self._copy_item("copy_path_background", paths),
            self._terminal_item("open_terminal_background", paths[0]),
        ]
