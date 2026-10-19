#!/usr/bin/env python3
"""Link a content pack into game/external/mods/<name>/ so the Godot editor can load it.

The install name comes from the pack's mod_info.json (the external/mods/<name>/ prefix
of its folder keys), exactly as tools/test_game.py --pack resolves it. The link path is
covered by the generic /game/external/mods/* rule in .gitignore, so linking leaves
`git status` clean.

Usage (from the project root):

    python3 tools/link_pack.py PACK_DIR                # create the link
    python3 tools/link_pack.py PACK_DIR --enable       # also enable it in game/external/mod_list.json
    python3 tools/link_pack.py PACK_DIR --unlink       # remove the link and the --enable line

--enable inserts one line into the tracked mod_list.json, so `git status` shows it
modified until --unlink removes exactly that line again; never commit it.

Linux/macOS: relative symlink. Windows: symlink (Developer Mode) or, failing that, a
directory junction via `mklink /J` -- the Windows path is written but NOT yet verified.
Exit 0 on success, 2 on usage or environment errors.
"""
from __future__ import annotations

import argparse
import os
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from test_game import RunnerError, resolve_pack_name, _is_link_or_junction  # noqa: E402

IS_WINDOWS = os.name == "nt"
ENABLE_PRIORITY = 10
MOD_LOAD_DATA_OPEN = '"mod_load_data": {'


def enable_line(name: str) -> str:
    return f'\t\t\t"external/mods/{name}/": {{"enabled": true, "load_priority": {ENABLE_PRIORITY}}},\n'


def _same_target(link: Path, pack_dir: Path) -> bool:
    try:
        return link.resolve() == pack_dir.resolve()
    except OSError:
        return False


def create_link(link: Path, pack_dir: Path) -> str:
    if _is_link_or_junction(str(link)):
        if _same_target(link, pack_dir):
            return "exists"
        raise RunnerError(f"{link} already links somewhere else ({os.path.realpath(link)}); --unlink first")
    if link.exists():
        raise RunnerError(f"{link} exists and is not a link; refusing to replace a real mod folder")
    link.parent.mkdir(parents=True, exist_ok=True)
    if not IS_WINDOWS:
        os.symlink(os.path.relpath(pack_dir, link.parent), link, target_is_directory=True)
        return "symlink"
    try:
        os.symlink(str(pack_dir), str(link), target_is_directory=True)
        return "symlink"
    except OSError:
        pass
    # Unverified: junctions need no Developer Mode; mklink is a cmd builtin.
    completed = subprocess.run(["cmd", "/c", "mklink", "/J", str(link), str(pack_dir)], capture_output=True,
                               text=True, check=False, stdin=subprocess.DEVNULL, creationflags=0x08000000)
    if completed.returncode != 0:
        raise RunnerError(f"mklink /J failed: {completed.stdout.strip()} {completed.stderr.strip()}")
    return "junction (unverified on Windows)"


def remove_link(link: Path) -> bool:
    if not _is_link_or_junction(str(link)):
        if link.exists():
            raise RunnerError(f"{link} is not a link; refusing to delete a real mod folder")
        return False
    if IS_WINDOWS and not os.path.islink(link):
        os.rmdir(link)  # removes the junction only, never the target contents
    else:
        os.unlink(link)
    return True


def set_enabled(mod_list: Path, name: str, enabled: bool) -> bool:
    """Insert or remove exactly one line so --unlink restores the file byte-for-byte."""
    text = mod_list.read_text(encoding="utf-8")
    line = enable_line(name)
    if enabled:
        if line in text:
            return False
        if f'"external/mods/{name}/"' in text:
            raise RunnerError(f"{mod_list} already lists external/mods/{name}/ in another form; edit it by hand")
        index = text.find(MOD_LOAD_DATA_OPEN)
        if index < 0:
            raise RunnerError(f"{mod_list} has no {MOD_LOAD_DATA_OPEN} block")
        end_of_line = text.index("\n", index) + 1
        text = text[:end_of_line] + line + text[end_of_line:]
    else:
        if line not in text:
            return False
        text = text.replace(line, "", 1)
    with open(mod_list, "w", encoding="utf-8", newline="") as handle:
        handle.write(text)
    return True


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="link_pack.py", description=__doc__.split("\n\n")[0])
    parser.add_argument("pack_dir", help="Content pack directory containing mod_info.json")
    parser.add_argument("--enable", action="store_true", help="Also enable the pack in game/external/mod_list.json (local change; never commit).")
    parser.add_argument("--unlink", action="store_true", help="Remove the link and the line --enable added.")
    parser.add_argument("--game-dir", help="Game directory (default: <project>/game).")
    args = parser.parse_args(argv)
    if args.enable and args.unlink:
        parser.error("--enable and --unlink are exclusive")
    project_root = Path(__file__).resolve().parent.parent
    game_dir = Path(args.game_dir).resolve() if args.game_dir else project_root / "game"
    pack_dir = Path(args.pack_dir).resolve()
    try:
        name = resolve_pack_name(pack_dir)
        link = game_dir / "external" / "mods" / name
        mod_list = game_dir / "external" / "mod_list.json"
        if args.unlink:
            removed = remove_link(link)
            disabled = set_enabled(mod_list, name, False) if mod_list.is_file() else False
            print(f"unlinked {link}: link {'removed' if removed else 'absent'}, mod_list line {'removed' if disabled else 'absent'}")
            return 0
        kind = create_link(link, pack_dir)
        print(f"linked {link} -> {pack_dir} ({kind})")
        if args.enable:
            changed = set_enabled(mod_list, name, True)
            print(f"mod_list.json: external/mods/{name}/ {'enabled' if changed else 'already enabled'} "
                  "(local change to a tracked file; run --unlink before committing)")
        return 0
    except (RunnerError, OSError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
