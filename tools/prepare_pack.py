#!/usr/bin/env python3
"""Prepare a fresh, isolated playable pack copy; never launch an engine or GUI."""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import sys
import uuid

from test_game import (EXCLUDED_DIR_NAMES, EXCLUDED_FILE_NAMES, PACK_LOAD_PRIORITY_BASE, PACK_NAME_RE,
                       RunnerError, _is_link_or_junction, resolve_pack_name, sha256_file,
                       utc_now_iso)

PRIVATE_NAMES = EXCLUDED_DIR_NAMES | EXCLUDED_FILE_NAMES | {
    "saves", "override.cfg", "export_credentials.cfg", "credentials.json",
    ".aws", ".ssh", ".codex", "secrets",
}
PRIVATE_SUFFIXES = {".pem", ".key", ".p12", ".pfx"}


def checked_path(path: Path) -> Path:
    """Inspect lexical ancestors before resolve can hide a junction/symlink."""
    absolute = Path(os.path.abspath(path))
    for part in (absolute, *absolute.parents):
        if _is_link_or_junction(str(part)):
            raise RunnerError(f"Refusing linked path: {part}")
    return absolute.resolve()


def source_files(root: Path, *, framework: bool) -> list[Path]:
    files: list[Path] = []
    for directory, dirs, names in os.walk(root, followlinks=False):
        parent = Path(directory)
        for name in sorted(dirs + names):
            path = parent / name
            relative = path.relative_to(root).as_posix()
            excluded = (name in PRIVATE_NAMES or name.startswith(".env") or path.suffix.lower() in PRIVATE_SUFFIXES or
                        (framework and relative in {"external/mods", "external/mod_list.json"}))
            if excluded:
                if name in dirs:
                    dirs.remove(name)
                continue
            if _is_link_or_junction(str(path)):
                raise RunnerError(f"Refusing linked content: {path}")
            if path.is_file():
                files.append(path)
            elif not path.is_dir():
                raise RunnerError(f"Refusing non-regular content: {path}")
    return sorted(files)


def file_hashes(files: list[Path], root: Path) -> dict[str, str]:
    return {path.relative_to(root).as_posix(): sha256_file(path) for path in files}


def copy_files(files: list[Path], root: Path, target: Path) -> None:
    for source in files:
        checked_path(source)
        destination = target / source.relative_to(root)
        destination.parent.mkdir(parents=True, exist_ok=True)
        # Exclusive creation keeps unexpected pre-existing output from being replaced.
        with source.open("rb") as src, destination.open("xb") as dst:
            shutil.copyfileobj(src, dst)


def project_settings(text: str, run_id: str) -> str:
    """Keep all other project settings while setting pack profile and unique user://."""
    section = ""
    output: list[str] = []
    application = False
    game = False
    for line in text.splitlines():
        match = re.fullmatch(r"\s*\[([^]]+)\]\s*", line)
        if match:
            section = match[1]
            output.append(line)
            if section == "application":
                application = True
                output += ["config/use_custom_user_dir=true",
                           f'config/custom_user_dir_name="mycardgame-playable-{run_id}"']
            elif section == "game":
                game = True
                output.append('content_profile="pack"')
            continue
        key = line.split("=", 1)[0].strip()
        if (section == "application" and key in {
                "config/use_custom_user_dir", "config/custom_user_dir_name"}) or (
                section == "game" and key == "content_profile"):
            continue
        output.append(line)
    if not application:
        raise RunnerError("project.godot has no [application] section")
    if not game:
        output += ["", "[game]", "", 'content_profile="pack"']
    return "\n".join(output) + "\n"


def write_json(path: Path, value: dict) -> None:
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def validate_prepared_game(game: Path) -> dict:
    """Read-only strict ledger verification before a runner copies a prepared game.

    ValueError is intentional: importing this helper from test_game's __main__
    must not depend on the identity of a second imported RunnerError class.
    """
    try:
        game = checked_path(game)
        artifact = game.parent
        if (game.name != "game" or artifact.parent.name != "playable" or
                artifact.parent.parent.name != "artifacts" or
                not re.fullmatch(r"[0-9a-f]{32}", artifact.name)):
            raise ValueError("Not an artifacts/playable/<UUID>/game copy")
        ledger = checked_path(artifact / "manifest.json")
        data = json.loads(ledger.read_text(encoding="utf-8"))
        if (data["format"] != "playable-copy/1" or data["status"] != "prepared" or
                checked_path(Path(data["project"])) != game / "project.godot" or
                data["content_profile"] != "pack" or not data["packs"]):
            raise ValueError("Prepared manifest identity/status/profile mismatch")
        if (game / "override.cfg").exists():
            raise ValueError("Prepared copy has an unrecorded project override")
        if file_hashes(source_files(game, framework=False), game) != data["output_hashes"]:
            raise ValueError("Prepared output differs from its complete hash ledger")
        project = (game / "project.godot").read_text(encoding="utf-8")
        required = {("game", "content_profile"): '"pack"',
                    ("application", "config/use_custom_user_dir"): "true",
                    ("application", "config/custom_user_dir_name"): f'"mycardgame-playable-{artifact.name}"'}
        observed: dict[tuple[str, str], list[str]] = {}
        section = ""
        for line in project.splitlines():
            header = re.fullmatch(r"\s*\[([^]]+)\]\s*", line)
            if header:
                section = header[1]
            elif "=" in line:
                key, value = line.split("=", 1)
                if (section, key.strip()) in required:
                    observed.setdefault((section, key.strip()), []).append(value.strip())
        if observed != {key: [value] for key, value in required.items()}:
            raise ValueError("Prepared project profile/user directory settings changed")
        expected = {"external/": {"enabled": True, "load_priority": 0}}
        seen = set()
        for index, pack in enumerate(data["packs"]):
            name = pack["name"]
            if not isinstance(name, str) or not PACK_NAME_RE.fullmatch(name) or name.casefold() in seen:
                raise ValueError("Invalid or duplicate prepared pack name")
            seen.add(name.casefold())
            installed = game / "external" / "mods" / name
            if (resolve_pack_name(installed) != name or
                    file_hashes(source_files(installed, framework=False), installed) != pack["files"]):
                raise ValueError(f"Installed pack differs from ledger: {name}")
            priority = PACK_LOAD_PRIORITY_BASE + index
            if pack["load_priority"] != priority:
                raise ValueError("Prepared pack priority differs from installation order")
            expected[f"external/mods/{name}/"] = {"enabled": True, "load_priority": priority}
        actual = json.loads((game / "external" / "mod_list.json").read_text(encoding="utf-8"))
        if actual != {"patch_data": {}, "properties": {"object_id": "mod_list", "mod_load_data": expected}}:
            raise ValueError("Prepared mod list includes unexpected content or settings")
        return {**data, "manifest_path": str(ledger), "manifest_sha256": sha256_file(ledger)}
    except (RunnerError, OSError, ValueError, KeyError, TypeError, AttributeError) as error:
        raise ValueError(f"Invalid prepared game: {error}") from error


def prepare(project_root: Path, packs: list[Path], output: Path | None = None) -> dict:
    root = checked_path(project_root)
    source = checked_path(root / "game")
    allowed = checked_path(root / "artifacts" / "playable")
    target = checked_path(output) if output else allowed / uuid.uuid4().hex
    if target.parent != allowed or not re.fullmatch(r"[0-9a-f]{32}", target.name):
        raise RunnerError("Output must be artifacts/playable/<32-character lowercase UUID>")
    if target.exists():
        raise RunnerError(f"Refusing existing output: {target}")
    if not packs:
        raise RunnerError("At least one --pack is required")
    if not source.is_dir():
        raise RunnerError(f"Missing source game: {source}")
    files = source_files(source, framework=True)
    project_file = source / "project.godot"
    if project_file not in files:
        raise RunnerError("Missing regular project.godot")
    updated_project = project_settings(project_file.read_text(encoding="utf-8-sig"), target.name)
    originals = file_hashes(files, source)
    prepared_packs = []
    seen: set[str] = set()
    for candidate in packs:
        pack = checked_path(candidate)
        if not pack.is_dir():
            raise RunnerError(f"Missing pack directory: {pack}")
        contents = source_files(pack, framework=False)
        name = resolve_pack_name(pack)
        if name.casefold() in seen:
            raise RunnerError(f"Duplicate pack installation name: {name}")
        seen.add(name.casefold())
        prepared_packs.append((pack, name, contents, file_hashes(contents, pack)))

    # All validation precedes the only output reservation. Failures retain the
    # partial artifact for diagnosis; there is deliberately no removal/retry mode.
    allowed.mkdir(parents=True, exist_ok=True)
    checked_path(allowed)
    target.mkdir()
    manifest = {"format": "playable-copy/1", "status": "preparing", "created_at": utc_now_iso(),
                "project": str(target / "game" / "project.godot"),
                "source_game": str(source), "source_hashes": originals,
                "content_profile": "pack", "engine_started": False,
                "user_directory_name": f"mycardgame-playable-{target.name}", "packs": []}
    manifest_path = target / "manifest.json"
    write_json(manifest_path, manifest)
    destination = target / "game"
    copy_files(files, source, destination)
    load_data = {"external/": {"enabled": True, "load_priority": 0}}
    for index, (pack, name, contents, hashes) in enumerate(prepared_packs):
        installed = destination / "external" / "mods" / name
        copy_files(contents, pack, installed)
        if file_hashes(contents, pack) != hashes or file_hashes(source_files(installed, framework=False), installed) != hashes:
            raise RunnerError(f"Pack changed during preparation: {pack}")
        priority = PACK_LOAD_PRIORITY_BASE + index
        load_data[f"external/mods/{name}/"] = {"enabled": True, "load_priority": priority}
        manifest["packs"].append({"source": str(pack), "name": name,
                                  "load_priority": priority, "files": hashes})
    if file_hashes(files, source) != originals or file_hashes(source_files(destination, framework=True), destination) != originals:
        raise RunnerError("Framework changed during preparation")
    (destination / "project.godot").write_text(updated_project, encoding="utf-8", newline="\n")
    external = destination / "external"
    external.mkdir(exist_ok=True)
    write_json(external / "mod_list.json", {"patch_data": {}, "properties": {
        "object_id": "mod_list", "mod_load_data": load_data}})
    manifest["output_hashes"] = file_hashes(source_files(destination, framework=False), destination)
    manifest["status"] = "prepared"
    manifest["source_lock_sha256"] = (sha256_file(root / "tools" / "upstream.json")
                                      if (root / "tools" / "upstream.json").is_file() else None)
    write_json(manifest_path, manifest)
    manifest["manifest_path"] = str(manifest_path)
    return manifest


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pack", type=Path, action="append", required=True, metavar="DIR")
    parser.add_argument("--output", type=Path, help="New artifacts/playable/<UUID> root (default: generated UUID)")
    parser.add_argument("--godot-path", type=Path, help="Executable path to print in manual commands; never executed")
    args = parser.parse_args(argv)
    try:
        result = prepare(Path(__file__).resolve().parent.parent, args.pack, args.output)
    except (RunnerError, OSError, ValueError, TypeError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 2
    game = str(Path(result["project"]).parent)
    ps_game = "'" + game.replace("'", "''") + "'"
    executable = str(args.godot_path.absolute()) if args.godot_path else "godot"
    ps_engine = "'" + executable.replace("'", "''") + "'"
    shell_engine = shlex.quote(executable)
    print(f"Prepared project: {result['project']}\nManifest: {result['manifest_path']}")
    print("No engine was started. For the user to run manually (Godot 4.7.x):")
    print(f"PowerShell editor: & {ps_engine} --editor --path {ps_game}")
    print(f"POSIX editor: {shell_engine} --editor --path {shlex.quote(game)}")
    print("For direct play, import once first, then run:")
    print(f"PowerShell import: & {ps_engine} --headless --editor --import --path {ps_game}")
    print(f"PowerShell play: & {ps_engine} --path {ps_game}")
    print(f"POSIX import: {shell_engine} --headless --editor --import --path {shlex.quote(game)}")
    print(f"POSIX play: {shell_engine} --path {shlex.quote(game)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
