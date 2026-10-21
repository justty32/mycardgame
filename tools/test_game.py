#!/usr/bin/env python3
"""Cross-platform isolated verification runner for the mycardgame Godot project.

Single source of truth for the pass/fail rules that tools/test-game.ps1 used to
hold; the PowerShell file is now a thin wrapper around this script.

Standard library only; Python 3.10+. Works on Linux and Windows. Never opens a
window: the engine always runs with --headless, display variables are removed
from the child environment, and on Windows the process is created without a
console window.

Usage (from the project root):

    python3 tools/test_game.py --suite All
    python3 tools/test_game.py --suite Smoke --godot-path /usr/bin/godot-mono
    python3 tools/test_game.py --suite Smoke --force-failure        # must exit 1
    python3 tools/test_game.py --suite Smoke --pack games/<game>/pack --pack-tests games/<game>/tests
    python3 tools/test_game.py --suite Smoke --content-profile pack --pack games/<game>/pack --pack-tests games/<game>/tests

--pack installs a content pack (a Slay-The-Robot mod directory) into each isolated
game copy under external/mods/<name>/ and enables it in that copy's mod_list.json;
the source game is never modified. --pack-tests copies a directory of pack probes
(*_probe.gd with check_loaded(global_data) -> {label: bool}) that Smoke calls.
--content-profile pack makes the engine skip its built-in example/test content
(Global.get_content_profile()), so a pack is checked without depending on it.

Exit status: 0 = verification passed, 1 = verification failed (including a
forced failure), 2 = usage / environment error before any engine run.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import platform
import re
import shutil
import signal
import subprocess
import sys
import threading
import time
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Callable, Optional

RUNNER_NAME = "test_game.py"
RUNNER_VERSION = "1.0.0"
IS_WINDOWS = os.name == "nt"

# Windows: CREATE_NO_WINDOW | CREATE_NEW_PROCESS_GROUP. No window may ever open.
WINDOWS_CREATION_FLAGS = 0x08000000 | 0x00000200

SUITE_CHOICES = ("All", "Dictionary", "Smoke", "Combat", "SaveLoad", "ResourceLifecycle",
                 "CombatVictory", "CombatDefeat", "Ctb", "Board", "Wave", "Field", "DualBoard", "Boardless", "BoardRemoved",
                 "PackScenario")
ALL_SUITES = ("ResourceLifecycle", "Dictionary", "Smoke", "CombatVictory", "CombatDefeat", "Ctb", "Board", "Wave", "Field", "DualBoard", "Boardless", "BoardRemoved", "SaveLoad")
SUITE_SCRIPTS = {
    "ResourceLifecycle": "resource_lifecycle.gd",
    "Dictionary": "dictionary_regression.gd",
    "Smoke": "framework_smoke.gd",
    "Boardless": "boardless_flow.gd",
    "BoardRemoved": "boardless_flow.gd",
    "CombatVictory": "combat_flow.gd",
    "CombatDefeat": "combat_flow.gd",
    "Ctb": "ctb_flow.gd",
    "Board": "board_flow.gd",
    "Wave": "wave_flow.gd",
    "Field": "field_flow.gd",
    "DualBoard": "dual_board_flow.gd",
    "SaveLoad": "save_load_flow.gd",
}
SUITE_MARKERS = {
    "ResourceLifecycle": "RESOURCE PASS:",
    "Dictionary": "DICTIONARY PASS:",
    "Smoke": "SMOKE PASS:",
    "CombatVictory": "COMBAT PASS:",
    "CombatDefeat": "COMBAT PASS:",
    "Ctb": "CTB PASS:",
    "Board": "BOARD PASS:",
    "Wave": "WAVE PASS:",
    "Field": "FIELD PASS:",
    "DualBoard": "DUAL_BOARD PASS:",
    "SaveLoad": "SAVELOAD PASS:",
}
SOURCE_HASH_PATHS = (
    "scripts/action_interceptors/ActionInterceptorProcessor.gd",
    "scripts/actions/BaseAsyncAction.gd",
    "autoload/ActionHandler.gd",
    "scripts/Root.gd",
    "scripts/ui/menus/BaseMenu.gd",
    "scripts/actions/card_actions/pick_card_actions/ActionBasePickCards.gd",
    "scripts/actions/card_actions/pick_card_actions/ActionPickCards.gd",
    "scripts/actions/card_actions/pick_card_actions/ActionPickDuplicateCards.gd",
    "scripts/actions/card_actions/pick_card_actions/ActionPickUpgradeCards.gd",
    "scripts/actions/card_actions/pick_card_actions/ActionCreateCards.gd",
    "scripts/ui/Map.gd",
    "autoload/FileLoader.gd",
    "data/SerializableData.gd",
    "autoload/Global.gd",
    "scripts/ui/menus/NewRunMenu.gd",
    "scripts/combat/CombatDirector.gd",
    "scripts/combat/board/BoardController.gd",
    "scripts/combat/UnitSpawner.gd",
    "scripts/combat/CombatActionPhases.gd",
    "scripts/combat/board/CombatBattlefield.gd",
    "scripts/combat/board/BoardPosition.gd",
    "scripts/combat/board/CrossBoardPolicy.gd",
    "scripts/combat/board/BoardData.gd",
    "scripts/combat/board/BoardPathfinding.gd",
    "scripts/combat/board/BoardMovementState.gd",
    "scripts/combat/board/FieldController.gd",
    "scripts/combat/board/FieldEventAction.gd",
    "scripts/combat/board/FieldPreview.gd",
    "scripts/ui/BoardActorPresentation.gd",
    "scripts/ui/BoardView.gd",
    "scripts/ui/Hand.gd",
    "autoload/HandManager.gd",
    "scripts/actions/BaseAction.gd",
    # optional-module boundary (core side and board module side)
    "scripts/combat/CombatModule.gd",
    "scripts/combat/CombatContentRequirements.gd",
    "scripts/combat/CardPlayAdapter.gd",
    "scripts/combat/controllers/EnemyIntentController.gd",
    "scripts/combatants/Enemy.gd",
    "scripts/ui/Combat.gd",
    "scripts/ui/card/Card.gd",
    "scripts/combat/board/BoardCombatModule.gd",
    "scripts/combat/board/BoardCardAdapter.gd",
    "scripts/combat/board/BoardCardInput.gd",
    "scripts/combat/board/BoardEnemyIntent.gd",
    "scripts/combat/board/BoardContentPolicy.gd",
    "scripts/ui/BoardCombatPresentation.gd",
)
# The optional board module: BoardRemoved deletes exactly these from its isolated copy and proves
# the core still imports and runs ordinary combat without them.
BOARD_MODULE_PATHS = (
    "scripts/combat/board",
    "scripts/actions/board_actions",
    "scripts/validators/board",
    "scripts/ui/BoardView.gd",
    "scripts/ui/BoardActorPresentation.gd",
    "scripts/ui/BoardCombatPresentation.gd",
)
EXCLUDED_DIR_NAMES = frozenset({".git", ".godot", ".import", ".saves", ".screenshots", ".mono"})
EXCLUDED_FILE_NAMES = frozenset({"profile.json", "user_settings.json"})
SAVE_REJECTION_CASES = ("missing", "malformed", "array", "scalar", "null", "no_properties",
                        "array_properties", "empty_properties", "array_patch_metadata",
                        "unknown_character")
# This exact SoundManager UID is present in its .gd.uid but not yet in a fresh cache.
COLD_CACHE_UID_ERROR = 'ERROR: Unrecognized UID: "uid://bjkhgdroa1wwd".'
SAVE_REJECTED_PREFIX = "ERROR: FileLoader.load_game(): Save rejected "
DEFAULT_ACCEPTED_ENGINE_PATTERNS = (r"^4\.7\.",)

CRASH_SIGNATURE_RE = re.compile(
    r"^(?:CrashHandlerException|handle_crash): Program crashed with signal \d+[^\r\n]*\r?$", re.M)
SHUTDOWN_RESOURCES_RE = re.compile(r"^ERROR: (\d+) resources still in use at exit", re.M)
SAVE_REJECTION_BLOCK_RE = re.compile(
    r"^EXPECTED SAVE REJECTION BEGIN: (\w+)\r?\n(.*?)^EXPECTED SAVE REJECTION END: \1\r?$", re.M | re.S)
SAVE_REJECTED_LINE_RE = re.compile(r"^ERROR: FileLoader\.load_game\(\): Save rejected ", re.M)
VERSION_LINE_RE = re.compile(r"^(\d+\.\d+(?:\.\d+)?\.[^\r\n]+|\d+\.\d+(?:\.\d+)?)\r?$", re.M)
SCRIPT_ERROR_OR_FAIL_RE = re.compile(r"SCRIPT ERROR:|FAIL:")
OBJECTDB_LEAK_TEXT = "ObjectDB instances leaked at exit"
PACK_MODS_PREFIX = "external/mods/"
PACK_LOAD_PRIORITY_BASE = 10
PACK_PROBE_GLOB = "*_probe.gd"
PACK_PROBE_DONE_MARKER = "PACK PROBE DONE: "
CONTENT_PROFILES = ("test", "pack")
PACK_NAME_RE = re.compile(r"^[A-Za-z0-9_][A-Za-z0-9_.-]*$")


class RunnerError(Exception):
    """A verification failure or environment problem that must stop the run."""


# --------------------------------------------------------------------------- utilities

def utc_now_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%fZ")


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    # Upper-case to stay byte-compatible with PowerShell Get-FileHash output.
    return digest.hexdigest().upper()


def get_exit_code_hex(exit_code: Optional[int]) -> Optional[str]:
    """Format an exit code as the unsigned 32-bit Win32 status (0xC0000005 style)."""
    if exit_code is None:
        return None
    return "0x{:08X}".format(int(exit_code) & 0xFFFFFFFF)


def normalize_posix_return_code(return_code: Optional[int]) -> tuple[Optional[int], Optional[int]]:
    """Map Popen.returncode to (shell-style exit code, signal number).

    POSIX reports a signal death as a negative return code; the shell convention
    is 128+N. Windows return codes are passed through unchanged with no signal.
    """
    if return_code is None:
        return None, None
    if return_code < 0 and not IS_WINDOWS:
        sig = -return_code
        return 128 + sig, sig
    return return_code, None


def get_native_crash_signatures(text: str) -> list[str]:
    """Exact Godot native-handler lines, not generic mentions of crashes or leaks."""
    seen: list[str] = []
    for match in CRASH_SIGNATURE_RE.finditer(text):
        value = match.group(0).rstrip("\r")
        if value not in seen:
            seen.append(value)
    return seen


def save_manifest(manifest: dict, path: Path) -> None:
    """Atomically replace results.json via a .pending temp file."""
    pending = Path(str(path) + ".pending")
    with open(pending, "w", encoding="utf-8", newline="\n") as handle:
        json.dump(manifest, handle, indent=2, ensure_ascii=False, default=str)
    os.replace(pending, path)


def confirm_log_writable(path: Path) -> None:
    """Open the exact target for append without truncating it.

    This is a preflight, not a guarantee against later permission changes.
    """
    try:
        with open(path, "ab"):
            pass
    except OSError as error:
        raise RunnerError(f"Engine log write preflight failed for '{path}': {error}") from error


def _run_git(args: list[str]) -> tuple[int, str]:
    try:
        completed = subprocess.run(["git", *args], capture_output=True, text=True, check=False,
                                   stdin=subprocess.DEVNULL,
                                   creationflags=WINDOWS_CREATION_FLAGS if IS_WINDOWS else 0)
    except OSError:
        return 127, ""
    return completed.returncode, completed.stdout


def _canonical(path: Path) -> str:
    text = os.path.normcase(os.path.normpath(os.path.abspath(str(path))))
    return text.rstrip("\\/")


def get_game_checkout_metadata(source_game: Path, project_root: Path,
                               run_git: Callable[[list[str]], tuple[int, str]] = _run_git) -> dict:
    """Describe the local Git layout of the game source.

    A source lock identifies upstream. Git here describes only the local layout;
    an outer repository commit must never be reported as the upstream commit.
    """
    source = _canonical(source_game)
    outer = _canonical(project_root)
    metadata: dict[str, Any] = {"layout": "unversioned_source", "repository_root": None,
                                "commit": None, "changes": []}
    if shutil.which("git") is None and run_git is _run_git:
        return metadata
    code, stdout = run_git(["-C", str(source_game), "rev-parse", "--show-toplevel"])
    if code != 0 or not stdout.strip():
        return metadata
    repository = _canonical(Path(stdout.strip()))
    if repository == source:
        metadata["layout"] = "independent_game_checkout"
        _, diff = run_git(["-C", str(source_game), "diff", "--name-only"])
        metadata["changes"] = [line for line in diff.splitlines() if line.strip()]
    elif repository == outer and source == _canonical(project_root / "game"):
        metadata["layout"] = "outer_repository_snapshot"
        _, diff = run_git(["-C", str(project_root), "diff", "--name-only", "--", "game"])
        metadata["changes"] = [line for line in diff.splitlines() if line.strip()]
    else:
        # A preserved artifacts copy can live inside an outer repository while
        # having no relationship to that repository's current game checkout.
        metadata["layout"] = "isolated_source_snapshot"
        return metadata
    metadata["repository_root"] = repository
    code, commit = run_git(["-C", repository, "rev-parse", "--verify", "HEAD"])
    if code == 0 and commit.strip():
        metadata["commit"] = commit.strip()
    return metadata


# --------------------------------------------------------------------------- engine discovery

def load_source_lock(project_root: Path) -> dict:
    with open(project_root / "tools" / "upstream.json", encoding="utf-8") as handle:
        return json.load(handle)


def accepted_engine_patterns(source_lock: dict, overrides: Optional[list[str]]) -> tuple[list[str], str]:
    """Return (regex list, provenance). CLI overrides replace the source-lock policy."""
    if overrides:
        return list(overrides), "cli"
    policy = source_lock.get("engine_policy") or {}
    patterns = policy.get("accepted_version_patterns")
    if patterns:
        return list(patterns), "tools/upstream.json engine_policy"
    return list(DEFAULT_ACCEPTED_ENGINE_PATTERNS), "runner default"


_ELF_MAGIC = b"\x7fELF"
_MACHO_MAGICS = (b"\xfe\xed\xfa\xce", b"\xfe\xed\xfa\xcf", b"\xce\xfa\xed\xfe", b"\xcf\xfa\xed\xfe",
                 b"\xca\xfe\xba\xbe")


def _file_magic(path: Path) -> bytes:
    try:
        with open(path, "rb") as handle:
            return handle.read(4)
    except OSError:
        return b""


def _is_windows_pe(path: Path) -> bool:
    return _file_magic(path)[:2] == b"MZ"


def _is_executable_file(path: Path) -> bool:
    """A launchable engine binary for this platform, never an archive or a foreign binary.

    Windows: a real PE .exe. Elsewhere the execute bit is not enough (drvfs on WSL marks every
    file executable, including .zip archives and Windows .exe files): require an ELF / Mach-O
    binary or a #! launcher script.
    """
    if not path.is_file():
        return False
    if IS_WINDOWS:
        return path.suffix.lower() == ".exe" and _is_windows_pe(path)
    if not os.access(path, os.X_OK):
        return False
    magic = _file_magic(path)
    return magic == _ELF_MAGIC or magic in _MACHO_MAGICS or magic[:2] == b"#!"


def is_wsl() -> bool:
    if IS_WINDOWS:
        return False
    try:
        return "microsoft" in platform.uname().release.lower()
    except Exception:  # noqa: BLE001 - best effort platform probe
        return False


WSL_ENGINE_HINT = ("Under WSL only Windows Godot builds are present: run the runner with the Windows Python "
                   "(python.exe tools/test_game.py ...) or tools/test-game.ps1 so the console build gets "
                   "CREATE_NO_WINDOW and APPDATA/LOCALAPPDATA/TEMP isolation. Linux python3 never launches a "
                   "Windows .exe.")


def _name_version_ok(name: str, patterns: list[str]) -> bool:
    match = re.search(r"[Gg]odot[_-]v?(\d+\.\d+(?:\.\d+)?)", name)
    if not match:
        return False
    return any(re.search(pattern, match.group(1) + ".") for pattern in patterns)


def discover_engine(project_root: Path, explicit: Optional[str], patterns: list[str]) -> tuple[Path, dict]:
    """Resolve the engine: explicit path, then .tools/, then PATH. Record how it was found.

    The returned path has symlinks resolved (e.g. /usr/bin/godot-mono -> /usr/lib/...);
    discovery["located"] keeps the path as it was found.
    """
    discovery: dict[str, Any] = {"method": None, "located": None, "candidates_considered": []}
    if explicit:
        candidate = Path(explicit).expanduser()
        if not candidate.exists():
            raise RunnerError(f"--godot-path does not exist: {candidate}")
        if not IS_WINDOWS and _is_windows_pe(candidate):
            raise RunnerError(f"--godot-path is a Windows binary ({candidate}). " + WSL_ENGINE_HINT)
        discovery["method"] = "explicit"
        discovery["located"] = str(candidate)
        return candidate.resolve(), discovery

    tools_dir = project_root / ".tools"
    foreign: list[Path] = []
    if tools_dir.is_dir():
        found: list[Path] = []
        for root, dirs, files in os.walk(tools_dir):
            depth = len(Path(root).relative_to(tools_dir).parts)
            if depth >= 3:
                dirs[:] = []
            for file_name in files:
                full = Path(root) / file_name
                if full.is_symlink():
                    continue
                lowered = file_name.lower()
                if not lowered.startswith("godot"):
                    continue
                if not _is_executable_file(full):
                    if not IS_WINDOWS and lowered.endswith(".exe") and _is_windows_pe(full):
                        foreign.append(full)
                        discovery["candidates_considered"].append(f"{full} (Windows binary; not launched from this platform)")
                    continue
                if not _name_version_ok(file_name, patterns):
                    discovery["candidates_considered"].append(f"{full} (version in name not accepted)")
                    continue
                found.append(full)
        if found:
            def rank(path: Path) -> tuple[int, str]:
                # Windows: the console build never opens a console/GUI window of its own.
                name = path.name.lower()
                console = 0 if (IS_WINDOWS and name.endswith("_console.exe")) else 1
                return (console, str(path))
            found.sort(key=rank)
            discovery["method"] = ".tools"
            discovery["located"] = str(found[0])
            discovery["candidates_considered"].extend(str(p) for p in found)
            return found[0].resolve(), discovery

    path_names = ["godot", "godot4", "godot-mono", "godot4-mono"]
    for name in path_names:
        located = shutil.which(name)
        discovery["candidates_considered"].append(f"PATH:{name} -> {located}")
        if located and not IS_WINDOWS and not _is_executable_file(Path(located).resolve()):
            discovery["candidates_considered"].append(f"PATH:{name} rejected (not a native executable)")
            continue
        if located:
            discovery["method"] = "PATH"
            discovery["located"] = located
            return Path(located).resolve(), discovery
    if is_wsl() or foreign:
        raise RunnerError("No native Godot executable found. " + WSL_ENGINE_HINT)
    raise RunnerError(
        "No Godot executable found. Pass --godot-path, place an accepted Godot_v4.x build under .tools/, "
        "or expose godot / godot4 / godot-mono on PATH.")


def launched_pid_kind(executable: Path) -> str:
    return "console_wrapper" if re.search(r"(?i)(?:_|\.)console\.exe$", executable.name) else "invoked_executable"


# --------------------------------------------------------------------------- isolation

def build_engine_environment(run_root: Path, isolate_appdata: bool = True) -> tuple[dict, dict]:
    """Child environment: no display, editor settings/cache/user:// under the run directory.

    Returns (env, description) where description is stored in results.json.
    """
    env = dict(os.environ)
    removed = []
    for key in ("DISPLAY", "WAYLAND_DISPLAY", "XDG_RUNTIME_DIR", "XAUTHORITY"):
        if key in env:
            env.pop(key)
            removed.append(key)
    iso_root = run_root / ("appdata" if IS_WINDOWS else "xdg")
    overrides: dict[str, str] = {}
    if IS_WINDOWS:
        if isolate_appdata:
            overrides["APPDATA"] = str(iso_root / "Roaming")
            overrides["LOCALAPPDATA"] = str(iso_root / "Local")
            overrides["TEMP"] = str(iso_root / "Temp")
            overrides["TMP"] = str(iso_root / "Temp")
        user_data_root = Path(overrides.get("APPDATA") or os.environ.get("APPDATA") or str(iso_root / "Roaming"))
    else:
        overrides["HOME"] = str(iso_root / "home")
        overrides["XDG_DATA_HOME"] = str(iso_root / "data")
        overrides["XDG_CONFIG_HOME"] = str(iso_root / "config")
        overrides["XDG_CACHE_HOME"] = str(iso_root / "cache")
        overrides["XDG_STATE_HOME"] = str(iso_root / "state")
        overrides["DOTNET_CLI_HOME"] = str(iso_root / "dotnet")
        overrides["NUGET_PACKAGES"] = str(iso_root / "nuget")
        overrides["DOTNET_CLI_TELEMETRY_OPTOUT"] = "1"
        overrides["DOTNET_NOLOGO"] = "1"
        env.setdefault("LANG", "C.UTF-8")
        user_data_root = Path(overrides["XDG_DATA_HOME"])
    for key, value in overrides.items():
        env[key] = value
        if os.sep in value:
            Path(value).mkdir(parents=True, exist_ok=True)
    description = {
        "removed": removed,
        "overrides": overrides,
        "user_data_root": str(user_data_root),
        "appdata_isolated": bool(isolate_appdata) if IS_WINDOWS else None,
    }
    return env, description


def _is_link_or_junction(path: str) -> bool:
    if os.path.islink(path):
        return True
    is_junction = getattr(os.path, "isjunction", None)
    if is_junction is not None:
        try:
            return bool(is_junction(path))
        except OSError:
            return False
    # Python 3.10/3.11 lack os.path.isjunction; lstat exposes the reparse tag
    # without following the directory into a user's linked content.
    if IS_WINDOWS:
        try:
            return getattr(os.lstat(path), "st_reparse_tag", 0) == 0xA0000003
        except OSError:
            return False
    return False


def copy_isolated_game(source_game: Path, destination: Path, user_data_root: Path,
                       isolated_name: str) -> dict:
    """Copy the game without Git/cache/user data and give it its own user://.

    Symlinks and junctions are skipped (robocopy /XJ analogue), never followed.
    """
    saves_source = _canonical(source_game / "external" / "saves")
    skipped: dict[str, list[str]] = {"dirs": [], "files": [], "links": []}

    def ignore(directory: str, names: list[str]) -> set[str]:
        out: set[str] = set()
        for name in names:
            full = os.path.join(directory, name)
            if _is_link_or_junction(full):
                out.add(name)
                skipped["links"].append(full)
            elif name in EXCLUDED_DIR_NAMES and os.path.isdir(full):
                out.add(name)
                skipped["dirs"].append(full)
            elif name in EXCLUDED_FILE_NAMES and os.path.isfile(full):
                out.add(name)
                skipped["files"].append(full)
            elif _canonical(Path(full)) == saves_source:
                out.add(name)
                skipped["dirs"].append(full)
        return out

    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copytree(str(source_game), str(destination), symlinks=False, ignore=ignore)
    if (destination / "external" / "saves" / "save.json").exists():
        raise RunnerError("Isolation failed: existing save was copied.")
    project_file = destination / "project.godot"
    text = project_file.read_text(encoding="utf-8")
    text = re.sub(r"(?m)^config/use_custom_user_dir=.*\r?\n", "", text)
    text = re.sub(r"(?m)^config/custom_user_dir_name=.*\r?\n", "", text)
    if "[application]" not in text:
        raise RunnerError("project.godot has no [application] section to attach a custom user dir to.")
    user_dir = user_data_root / isolated_name
    user_dir.mkdir(parents=True, exist_ok=True)
    confirm_log_writable(user_dir / "write-preflight.txt")
    text = text.replace(
        "[application]",
        f'[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="{isolated_name}"', 1)
    project_file.write_text(text, encoding="utf-8", newline="\n")
    return {"user_dir": str(user_dir), "skipped": skipped}


# --------------------------------------------------------------------------- content packs

def _load_lenient_json(path: Path) -> Any:
    """Godot's JSON reader accepts trailing commas (the shipped mod_list.json has one)."""
    text = path.read_text(encoding="utf-8")
    return json.loads(re.sub(r",(\s*[}\]])", r"\1", text))


def resolve_pack_name(pack_dir: Path) -> str:
    """Install name of a pack = the external/mods/<name>/ prefix its mod_info.json declares.

    The folder keys are relative to the game root, so the pack only loads when it is
    installed under exactly that name; the source folder name (often just "pack") is irrelevant.
    """
    info_path = pack_dir / "mod_info.json"
    if not info_path.is_file():
        raise RunnerError(f"--pack has no mod_info.json: {pack_dir}")
    try:
        properties = (_load_lenient_json(info_path).get("properties") or {})
    except (ValueError, AttributeError) as error:
        raise RunnerError(f"--pack mod_info.json is not a JSON object with properties: {info_path}") from error
    keys = list((properties.get("mod_folder_to_load_data") or {}).keys())
    keys += list((properties.get("mod_script_file_paths") or {}).keys())
    names = set()
    for key in keys:
        if not key.startswith(PACK_MODS_PREFIX):
            raise RunnerError(f"--pack path '{key}' in {info_path} is not under {PACK_MODS_PREFIX}<name>/")
        names.add(key[len(PACK_MODS_PREFIX):].split("/", 1)[0])
    if not names and properties.get("mod_name"):
        names.add(str(properties["mod_name"]))
    if len(names) != 1:
        raise RunnerError(f"--pack {info_path} must declare exactly one {PACK_MODS_PREFIX}<name>/ prefix, found {sorted(names)}")
    name = names.pop()
    if not PACK_NAME_RE.match(name):
        raise RunnerError(f"--pack name '{name}' from {info_path} is not a plain folder name")
    return name


def _write_mod_list(path: Path, mod_list: Any) -> None:
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        json.dump(mod_list, handle, indent="\t")


def drop_linked_mods(source_game: Path, isolated_game: Path, skipped_links: list[str]) -> list[str]:
    """Remove mod_list entries for mods that were links in the source (tools/link_pack.py).

    The copy skips links, so a locally enabled linked pack would point at a missing folder;
    a framework run must not depend on it. Use --pack to test that pack instead.
    """
    mods_root = _canonical(source_game / "external" / "mods")
    keys = []
    for link in skipped_links:
        parent, name = os.path.split(link)
        if _canonical(Path(parent)) == mods_root:
            keys.append(f"{PACK_MODS_PREFIX}{name}/")
    mod_list_path = isolated_game / "external" / "mod_list.json"
    if not keys or not mod_list_path.is_file():
        return []
    try:
        mod_list = _load_lenient_json(mod_list_path)
        load_data = mod_list["properties"]["mod_load_data"]
    except (OSError, ValueError, KeyError, TypeError) as error:
        raise RunnerError(f"Isolated mod_list.json cannot be read: {mod_list_path}: {error}") from error
    removed = [key for key in keys if load_data.pop(key, None) is not None]
    if removed:
        _write_mod_list(mod_list_path, mod_list)
    return removed


def install_packs(pack_dirs: list[Path], isolated_game: Path) -> list[dict]:
    """Copy packs into the isolated copy's external/mods/ and enable them in its mod_list.json only."""
    installed: list[dict] = []
    if not pack_dirs:
        return installed
    mod_list_path = isolated_game / "external" / "mod_list.json"
    try:
        mod_list = _load_lenient_json(mod_list_path)
        load_data = mod_list["properties"]["mod_load_data"]
    except (OSError, ValueError, KeyError, TypeError) as error:
        raise RunnerError(f"Isolated mod_list.json cannot take packs: {mod_list_path}: {error}") from error
    for index, pack_dir in enumerate(pack_dirs):
        name = resolve_pack_name(pack_dir)
        destination = isolated_game / "external" / "mods" / name
        if destination.exists():
            raise RunnerError(f"--pack '{name}' collides with an existing mod folder in the game copy: {destination}")
        skipped: list[str] = []

        def ignore(directory: str, names: list[str]) -> set[str]:
            out = set()
            for entry in names:
                full = os.path.join(directory, entry)
                if _is_link_or_junction(full) or (entry in EXCLUDED_DIR_NAMES and os.path.isdir(full)):
                    out.add(entry)
                    skipped.append(full)
            return out

        shutil.copytree(str(pack_dir), str(destination), symlinks=False, ignore=ignore)
        key = f"{PACK_MODS_PREFIX}{name}/"
        load_data[key] = {"enabled": True, "load_priority": PACK_LOAD_PRIORITY_BASE + index}
        files = []
        for path in sorted(p for p in destination.rglob("*") if p.is_file()):
            files.append({"path": path.relative_to(destination).as_posix(), "sha256": sha256_file(path)})
        installed.append({"source": str(pack_dir), "name": name, "mod_list_key": key,
                          "load_priority": PACK_LOAD_PRIORITY_BASE + index, "files": files, "skipped": skipped})
    _write_mod_list(mod_list_path, mod_list)
    return installed


def copy_pack_tests(test_dirs: list[Path], destination_root: Path) -> tuple[list[Path], list[dict]]:
    """Copy each pack-tests directory (top-level .gd files) and return the probe entry points."""
    probes: list[Path] = []
    hashes: list[dict] = []
    for index, test_dir in enumerate(test_dirs):
        if not test_dir.is_dir():
            raise RunnerError(f"--pack-tests is not a directory: {test_dir}")
        target = destination_root / f"{index}-{test_dir.parent.name}-{test_dir.name}"
        target.mkdir(parents=True, exist_ok=True)
        for test_file in sorted(test_dir.glob("*.gd")):
            if test_file.is_symlink():
                continue
            shutil.copy2(test_file, target / test_file.name)
            hashes.append({"path": f"{target.name}/{test_file.name}", "source": str(test_file),
                           "sha256": sha256_file(target / test_file.name)})
        found = sorted(target.glob(PACK_PROBE_GLOB))
        if not found:
            raise RunnerError(f"--pack-tests has no {PACK_PROBE_GLOB} entry point: {test_dir}")
        probes.extend(found)
    return probes, hashes


def build_user_args(selected: str, *, force_failure: bool = False, probes: Optional[list[Path]] = None,
                    content_profile: str = "test") -> list[str]:
    """Arguments after '--' for a suite script (one separator, as Godot expects)."""
    user: list[str] = [] if content_profile == "test" else [f"--content-profile={content_profile}"]
    if selected == "CombatVictory":
        user.append("--scenario=victory")
    elif selected == "CombatDefeat":
        user.append("--scenario=defeat")
    if selected == "Smoke":
        user += [f"--pack-probe={probe}" for probe in (probes or [])]
        if force_failure:
            user.append("--force-failure")
    return user


def load_pack_scenario(test_dir: Path) -> dict:
    """Validate a portable scenario and its complete input tree before starting an engine."""
    if not test_dir.is_dir() or _is_link_or_junction(str(test_dir)):
        raise RunnerError(f"PackScenario tests must be a real directory: {test_dir}")
    files: list[Path] = []
    for directory, dirs, names in os.walk(test_dir):
        for name in dirs + names:
            path = Path(directory) / name
            if _is_link_or_junction(str(path)):
                raise RunnerError(f"PackScenario tests cannot contain links: {path}")
            if path.is_file():
                files.append(path)
            elif not path.is_dir():
                raise RunnerError(f"PackScenario tests contain a non-regular path: {path}")
    path = test_dir / "scenario.json"
    def unique_keys(pairs: list[tuple[str, Any]]) -> dict:
        result: dict = {}
        for key, value in pairs:
            if key in result:
                raise ValueError(f"duplicate key: {key}")
            result[key] = value
        return result
    try:
        data = json.loads(path.read_text(encoding="utf-8"), object_pairs_hook=unique_keys)
    except (OSError, ValueError) as error:
        raise RunnerError(f"Cannot read PackScenario manifest {path}: {error}") from error
    if not isinstance(data, dict) or set(data) != {"schema", "entry", "phases"} \
            or data["schema"] != "pack-scenario/1":
        raise RunnerError("PackScenario requires exactly schema='pack-scenario/1', entry, phases")
    entry = data["entry"]
    if not isinstance(entry, str) or not re.fullmatch(r"[A-Za-z0-9_-][A-Za-z0-9_./-]*\.gd", entry) \
            or any(part in ("", ".", "..") for part in entry.split("/")):
        raise RunnerError("PackScenario entry must be a relative POSIX .gd path without traversal")
    entry_path = test_dir / entry
    if not entry_path.is_file() or not entry_path.resolve().is_relative_to(test_dir.resolve()):
        raise RunnerError(f"PackScenario entry is missing or outside tests: {entry}")
    phases = data["phases"]
    if not isinstance(phases, list) or not 1 <= len(phases) <= 64 \
            or any(not isinstance(phase, str) or not re.fullmatch(r"[a-z][a-z0-9_-]{0,63}", phase) for phase in phases) \
            or len(set(phases)) != len(phases):
        raise RunnerError("PackScenario phases require 1-64 unique lowercase identifiers (max 64 characters)")
    return {**data, "source": str(path), "files": [
        {"path": file.relative_to(test_dir).as_posix(), "sha256": sha256_file(file)}
        for file in sorted(files)]}


def copy_pack_scenario(test_dir: Path, isolated_game: Path, scenario: dict) -> tuple[Path, list[dict]]:
    """Freeze all scenario inputs under res://pack_tests; reject changes since preflight."""
    current = load_pack_scenario(test_dir)
    if current != scenario:
        raise RunnerError("PackScenario inputs changed after preflight; start a new verification run")
    target = isolated_game / "pack_tests"
    if target.exists():
        raise RunnerError(f"PackScenario destination already exists: {target}")
    target.mkdir()
    hashes = []
    for record in scenario["files"]:
        source = test_dir / record["path"]
        destination = target / record["path"]
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, destination)
        if sha256_file(destination) != record["sha256"]:
            raise RunnerError(f"PackScenario input changed while copying: {source}")
        hashes.append({**record, "source": str(source)})
    return target / scenario["entry"], hashes


def run_pack_scenario(runner: EngineRunner, directory: Path, isolated_game: Path,
                      script_path: Path, scenario: dict, content_profile: str) -> None:
    """Fresh processes share exactly one copied project and isolated child environment."""
    run_script_phases(runner, directory,
                      ["--headless", "--path", str(isolated_game), "--script", str(script_path)],
                      [f"--content-profile={content_profile}"], scenario["phases"],
                      phase_argument="scenario-phase", marker_prefix="PACK SCENARIO PASS: ", log_prefix="scenario")


def remove_board_module(isolated_game: Path) -> list[str]:
    """Delete the optional board module (and .uid siblings) from an isolated copy only."""
    removed: list[str] = []
    for relative in BOARD_MODULE_PATHS:
        target = isolated_game / relative
        if target.is_dir():
            removed.extend(str(p.relative_to(isolated_game)).replace("\\", "/") for p in sorted(target.rglob("*")) if p.is_file())
            shutil.rmtree(target)
        elif target.is_file():
            for path in (target, target.with_name(target.name + ".uid")):
                if path.is_file():
                    removed.append(str(path.relative_to(isolated_game)).replace("\\", "/"))
                    path.unlink()
        else:
            raise RunnerError(f"Board module path missing before removal: {relative}")
    return removed


def source_tree_ledger(game_dir: Path) -> dict:
    """sha256 over every copied source file (sorted 'path sha256' lines): a complete fingerprint."""
    lines: list[str] = []
    for path in sorted(p for p in game_dir.rglob("*") if p.is_file()):
        relative = path.relative_to(game_dir).as_posix()
        if relative.startswith(".godot/"):
            continue
        lines.append(f"{relative} {sha256_file(path)}")
    return {"files": len(lines), "sha256": hashlib.sha256("\n".join(lines).encode("utf-8")).hexdigest()}


def run_script_phases(runner: EngineRunner, directory: Path, engine_args: list[str],
                      user_args: list[str], phases: list[str] | tuple[str, ...], *,
                      phase_argument: str, marker_prefix: str, log_prefix: str) -> None:
    """Stop at the first failed phase; each process retains the standard strict verdict."""
    for phase in phases:
        runner.invoke(f"{log_prefix}-{phase}", directory,
                      engine_args + ["--", *user_args, f"--{phase_argument}={phase}"],
                      marker=f"{marker_prefix}{phase}", exact_marker=True)


# --------------------------------------------------------------------------- verdict rules

def evaluate_phase_output(*, console_output: str, log_text: str, exit_code: Optional[int],
                          timed_out: bool, marker: Optional[str], version_probe: bool,
                          accepted_patterns: list[str], cold_import: bool,
                          save_rejections: bool, known_shutdown_resources: list[int],
                          historical_baseline: bool, output_streams_open: bool = False,
                          required_markers: Optional[list[str]] = None, exact_marker: bool = False) -> dict:
    """Pure judgment over a finished phase. Shared by the real runner and the synthetic tests."""
    combined = console_output + "\n" + log_text
    verdict: dict[str, Any] = {}
    crash = get_native_crash_signatures(combined)
    verdict["native_crash_signatures"] = crash
    passed = (not timed_out) and exit_code == 0 and not SCRIPT_ERROR_OR_FAIL_RE.search(combined) \
        and not crash and not output_streams_open
    if marker:
        found = marker in combined.splitlines() if exact_marker else marker in combined
        verdict["marker_found"] = found
        passed = passed and found
    if required_markers:
        missing = [m for m in required_markers if m not in combined]
        verdict["required_markers_missing"] = missing
        passed = passed and not missing
    if version_probe:
        version_match = VERSION_LINE_RE.search(combined)
        version = version_match.group(1) if version_match else ""
        accepted = bool(version) and any(re.search(p, version) for p in accepted_patterns)
        verdict["engine_version"] = version
        verdict["engine_version_accepted"] = accepted
        passed = passed and accepted
    errors = [line for line in re.split(r"\r?\n", combined) if line.startswith("ERROR:")]
    shutdown_counts = sorted({int(m.group(1)) for m in SHUTDOWN_RESOURCES_RE.finditer(combined)})
    warnings: list[str] = []
    for count in shutdown_counts:
        if count in known_shutdown_resources:
            prefix = f"ERROR: {count} resources still in use at exit"
            errors = [e for e in errors if not e.startswith(prefix)]
            warnings.append(f"retains {count} resources at shutdown; tracked issue, not a clean resource-lifetime result.")
    if save_rejections:
        # Canonical engine log preserves stdout/stderr order, unlike the separate console streams.
        blocks = list(SAVE_REJECTION_BLOCK_RE.finditer(log_text))
        valid = len(blocks) == len(SAVE_REJECTION_CASES)
        for case in SAVE_REJECTION_CASES:
            matching = [b for b in blocks if b.group(1) == case]
            valid = valid and len(matching) == 1
            if len(matching) == 1:
                valid = valid and len(SAVE_REJECTED_LINE_RE.findall(matching[0].group(2))) == 1
        valid = valid and len(SAVE_REJECTED_LINE_RE.findall(log_text)) == len(SAVE_REJECTION_CASES)
        verdict["save_rejection_blocks_valid"] = valid
        if valid:
            errors = [e for e in errors if not e.startswith(SAVE_REJECTED_PREFIX)]
        else:
            passed = False
    cold_uid = False
    if cold_import:
        cold_uid = COLD_CACHE_UID_ERROR in errors
        errors = [e for e in errors if e != COLD_CACHE_UID_ERROR]
    passed = passed and len(errors) == 0
    leak = OBJECTDB_LEAK_TEXT in combined
    if leak and not historical_baseline:
        passed = False
    verdict.update({
        "passed": passed,
        "cold_cache_uid_requires_recheck": cold_uid,
        "shutdown_resources": shutdown_counts,
        "objectdb_leak": leak,
        "unexpected_error_lines": sorted(set(errors)),
        "warnings": warnings,
    })
    return verdict


# --------------------------------------------------------------------------- process execution

class _StreamReader(threading.Thread):
    def __init__(self, stream):
        super().__init__(daemon=True)
        self.stream = stream
        self.chunks: list[bytes] = []
        self.start()

    def run(self) -> None:
        try:
            for chunk in iter(lambda: self.stream.read(65536), b""):
                self.chunks.append(chunk)
        except (OSError, ValueError):
            pass

    def text(self) -> str:
        return b"".join(self.chunks).decode("utf-8", "replace")


def terminate_process_tree(process: subprocess.Popen) -> None:
    """Stop only the process tree this runner created. Never kill by executable name."""
    if process.poll() is not None:
        return
    if IS_WINDOWS:
        try:
            subprocess.run(["taskkill", "/T", "/F", "/PID", str(process.pid)], capture_output=True,
                           check=False, creationflags=WINDOWS_CREATION_FLAGS, stdin=subprocess.DEVNULL)
        except OSError:
            pass
        if process.poll() is None:
            process.kill()
    else:
        try:
            os.killpg(process.pid, signal.SIGTERM)
        except ProcessLookupError:
            return
        deadline = time.monotonic() + 3
        while process.poll() is None and time.monotonic() < deadline:
            time.sleep(0.05)
        if process.poll() is None:
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass


class EngineRunner:
    """Runs engine phases inside one verification run and records them in results.json."""

    def __init__(self, *, engine: Path, run_root: Path, manifest: dict, env: dict,
                 timeout_seconds: int, accepted_patterns: list[str], historical_baseline: bool,
                 diagnostic_verbose: bool = False, echo: Callable[[str], None] = print):
        self.engine = engine
        self.run_root = run_root
        self.manifest = manifest
        self.results: list[dict] = manifest["results"]
        self.env = env
        self.timeout_seconds = timeout_seconds
        self.accepted_patterns = accepted_patterns
        self.historical_baseline = historical_baseline
        self.diagnostic_verbose = diagnostic_verbose
        self.echo = echo
        self.results_path = run_root / "results.json"

    def save(self) -> None:
        save_manifest(self.manifest, self.results_path)

    def invoke(self, name: str, directory: Path, engine_args: list[str], *, marker: Optional[str] = None,
               cold_import: bool = False, known_shutdown_resources: Optional[list[int]] = None,
               save_rejections: bool = False, version_probe: bool = False,
               required_markers: Optional[list[str]] = None, exact_marker: bool = False) -> dict:
        known_shutdown_resources = list(known_shutdown_resources or [])
        engine_log = directory / f"{name}.log"
        if version_probe:
            arguments = list(engine_args)
        else:
            arguments = ["--log-file", str(engine_log)] + (["--verbose"] if self.diagnostic_verbose else []) + list(engine_args)
        record: dict[str, Any] = {
            "name": name, "directory": str(directory), "executable": str(self.engine),
            "launched_pid": None, "launched_pid_kind": launched_pid_kind(self.engine),
            "started_utc": None, "ended_utc": None, "status": "starting",
            "exit_code": None, "exit_code_hex": None, "exit_code_raw": None, "exit_signal": None,
            "timed_out": False, "passed": False,
            "native_crash_signatures": [], "cold_cache_uid_requires_recheck": False,
            "log_write_preflight": "pending", "shutdown_resources": [], "seconds": 0,
            "command_arguments": arguments,
        }
        self.results.append(record)
        self.save()
        started_at = time.monotonic()
        process: Optional[subprocess.Popen] = None
        try:
            record["log_write_preflight"] = "failed"
            confirm_log_writable(engine_log)
            record["log_write_preflight"] = "passed"
            popen_kwargs: dict[str, Any] = {
                "cwd": str(directory), "env": self.env, "stdin": subprocess.DEVNULL,
                "stdout": subprocess.PIPE, "stderr": subprocess.PIPE,
            }
            if IS_WINDOWS:
                startupinfo = subprocess.STARTUPINFO()
                startupinfo.dwFlags |= subprocess.STARTF_USESHOWWINDOW
                startupinfo.wShowWindow = 0  # SW_HIDE
                popen_kwargs["creationflags"] = WINDOWS_CREATION_FLAGS
                popen_kwargs["startupinfo"] = startupinfo
            else:
                popen_kwargs["start_new_session"] = True
            try:
                process = subprocess.Popen([str(self.engine), *arguments], **popen_kwargs)
            except OSError as error:
                raise RunnerError(f"Cannot start {name}: {error}") from error
            record["launched_pid"] = process.pid
            record["started_utc"] = utc_now_iso()
            record["status"] = "running"
            self.save()
            stdout_reader = _StreamReader(process.stdout)
            stderr_reader = _StreamReader(process.stderr)
            timed_out = False
            try:
                process.wait(timeout=self.timeout_seconds)
            except subprocess.TimeoutExpired:
                timed_out = True
                # This process tree belongs to this invocation; never kill by executable name.
                terminate_process_tree(process)
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired as error:
                    raise RunnerError(f"{name} did not exit after timeout termination") from error
            record["timed_out"] = timed_out
            # A wrapper can exit while an inherited output handle remains open in a child.
            stdout_reader.join(5)
            stderr_reader.join(5)
            streams_open = stdout_reader.is_alive() or stderr_reader.is_alive()
            if streams_open:
                record["output_streams_open_after_exit"] = True
            output = stdout_reader.text() + "\n" + stderr_reader.text()
            (directory / f"{name}.console.log").write_text(output, encoding="utf-8", newline="\n")
            raw_code = process.returncode
            exit_code, exit_signal = normalize_posix_return_code(raw_code)
            log_text = engine_log.read_text(encoding="utf-8", errors="replace") if engine_log.exists() else ""
            verdict = evaluate_phase_output(
                console_output=output, log_text=log_text, exit_code=exit_code, timed_out=timed_out,
                marker=marker, version_probe=version_probe, accepted_patterns=self.accepted_patterns,
                cold_import=cold_import, save_rejections=save_rejections,
                known_shutdown_resources=known_shutdown_resources,
                historical_baseline=self.historical_baseline, output_streams_open=streams_open,
                required_markers=required_markers, exact_marker=exact_marker)
            for warning in verdict.pop("warnings"):
                self.echo(f"WARNING: {name} {warning}")
            record.update(verdict)
            record["status"] = "passed" if verdict["passed"] else "failed"
            elapsed = round(time.monotonic() - started_at, 1)
            self.echo(f"{name} : exit={exit_code}, passed={verdict['passed']} ({elapsed}s)")
            if streams_open:
                raise RunnerError(f"{name} output streams remained open after launched process exit")
            if not verdict["passed"]:
                raise RunnerError(f"{name} failed. Inspect {engine_log} and {name}.console.log")
            return record
        except Exception as error:  # noqa: BLE001 - recorded then re-raised
            record["status"] = "failed"
            record["error"] = str(error)
            raise
        finally:
            if process is not None:
                if process.poll() is None:
                    terminate_process_tree(process)
                    try:
                        process.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        pass
                if process.poll() is not None:
                    exit_code, exit_signal = normalize_posix_return_code(process.returncode)
                    record["exit_code_raw"] = process.returncode
                    record["exit_code"] = exit_code
                    record["exit_signal"] = exit_signal
                    record["exit_code_hex"] = get_exit_code_hex(exit_code)
                for stream in (process.stdout, process.stderr):
                    try:
                        if stream:
                            stream.close()
                    except OSError:
                        pass
            record["ended_utc"] = utc_now_iso()
            record["seconds"] = round(time.monotonic() - started_at, 2)
            self.save()


# --------------------------------------------------------------------------- orchestration

def expand_suites(suite: str) -> list[str]:
    if suite == "All":
        return list(ALL_SUITES)
    if suite == "Combat":
        return ["CombatVictory", "CombatDefeat"]
    return [suite]


def normalize_suite(value: str) -> str:
    for choice in SUITE_CHOICES:
        if choice.lower() == value.lower():
            return choice
    raise argparse.ArgumentTypeError(f"invalid suite '{value}' (choose from {', '.join(SUITE_CHOICES)})")


def build_manifest(*, suite: str, run_id: str, source_game: Path, source_lock: dict, source_lock_sha256: str,
                   checkout: dict, historical_baseline: bool, engine: Path, engine_discovery: dict,
                   accepted_patterns: list[str], policy_source: str, isolation: dict,
                   timeout_seconds: int, force_failure: bool) -> dict:
    return {
        "suite": suite, "run_id": run_id, "source_game": str(source_game),
        "upstream_commit": source_lock.get("commit"),
        "source_lock_sha256": source_lock_sha256,
        "checkout": checkout,
        "historical_baseline": bool(historical_baseline),
        "source_hashes": {}, "test_hashes": {},
        "engine": str(engine), "completed": False, "results": [],
        "runner": {"name": RUNNER_NAME, "version": RUNNER_VERSION, "python": platform.python_version(),
                   "platform": platform.platform(), "os": os.name},
        "engine_discovery": engine_discovery,
        "engine_policy": {"accepted_version_patterns": accepted_patterns, "source": policy_source,
                          "baseline": (source_lock.get("engine_policy") or {}).get("baseline")},
        "isolation": isolation,
        "timeout_seconds": timeout_seconds,
        "force_failure": bool(force_failure),
        "exit_code_semantics": "win32_status" if IS_WINDOWS else "posix_shell (128+N for signal N; exit_code_raw keeps Popen value)",
    }


def parse_args(argv: Optional[list[str]] = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog="test_game.py",
        description="Isolated headless verification runner (Linux/Windows). Equivalent of the former test-game.ps1.")
    parser.add_argument("--suite", "-s", type=normalize_suite, default="All",
                        help="Framework suite (All) or an individual suite, including explicit PackScenario.")
    parser.add_argument("--godot-path", help="Engine executable. Default: .tools/ accepted build, then godot/godot4/godot-mono on PATH.")
    parser.add_argument("--source-game", help="Candidate game directory (default: <project>/game). Tests always come from <project>/tests.")
    parser.add_argument("--timeout-seconds", type=int, default=180, help="Per-process outer deadline, 10-900 (default 180).")
    parser.add_argument("--historical-baseline", action="store_true",
                        help="Historical red-test mode: tolerate the documented 1-resource shutdown retention and ObjectDB leak text. Never a pass standard.")
    parser.add_argument("--diagnostic-verbose", action="store_true", help="Add --verbose to engine runs.")
    parser.add_argument("--force-failure", action="store_true",
                        help="Smoke only: pass --force-failure to framework_smoke.gd. The run must then exit 1; this validates the failure exit path.")
    parser.add_argument("--accept-engine-version", action="append", metavar="REGEX",
                        help="Regex matched against the --version line (repeatable). Overrides tools/upstream.json engine_policy; e.g. '^4\\.6\\.' to allow 4.6 again.")
    parser.add_argument("--no-isolate-appdata", action="store_true",
                        help="Windows only: keep the real APPDATA/LOCALAPPDATA instead of redirecting them into the run directory.")
    parser.add_argument("--artifacts-root", help="Where run directories go (default: <project>/artifacts/verification).")
    parser.add_argument("--project-root", help="Override project root (default: parent of tools/).")
    parser.add_argument("--pack", action="append", metavar="DIR", default=[],
                        help="Content pack directory with mod_info.json (repeatable). Installed only into the isolated copies under external/mods/<name>/ and enabled there.")
    parser.add_argument("--pack-tests", action="append", metavar="DIR", default=[],
                        help="Smoke probes (repeatable) or one PackScenario directory with scenario.json. Requires --pack.")
    parser.add_argument("--content-profile", choices=CONTENT_PROFILES, default="test",
                        help="test (default): engine generates the built-in example/test content. pack: skip it so only "
                             "external data and enabled packs load (Smoke or PackScenario; needs --pack).")
    args = parser.parse_args(argv)
    prepared_candidate = args.suite == "PackScenario" and args.source_game and not args.pack
    if args.content_profile == "pack" and (args.suite not in ("Smoke", "PackScenario") or not (args.pack or prepared_candidate)):
        parser.error("--content-profile pack requires --suite Smoke or PackScenario and at least one --pack")
    if args.pack_tests and not args.pack and not prepared_candidate:
        parser.error("--pack-tests requires --pack")
    if args.pack_tests and "Smoke" not in expand_suites(args.suite) and args.suite != "PackScenario":
        parser.error("--pack-tests requires --suite Smoke, All or PackScenario")
    if args.suite == "PackScenario":
        if not (args.pack or prepared_candidate) or len(args.pack_tests) != 1:
            parser.error("PackScenario requires --pack (or a verified prepared --source-game) and exactly one --pack-tests")
        if prepared_candidate and args.content_profile != "pack":
            parser.error("A prepared PackScenario source requires --content-profile pack")
        if args.no_isolate_appdata or args.historical_baseline:
            parser.error("PackScenario requires isolated appdata and strict lifecycle checks")
    if not 10 <= args.timeout_seconds <= 900:
        parser.error("--timeout-seconds must be between 10 and 900")
    if args.force_failure and args.suite != "Smoke":
        parser.error("--force-failure applies to --suite Smoke only")
    return args


def run(args: argparse.Namespace, echo: Callable[[str], None] = print) -> int:
    project_root = Path(args.project_root).resolve() if args.project_root else Path(__file__).resolve().parent.parent
    source_game = Path(args.source_game).absolute() if args.source_game else project_root / "game"
    if not (source_game / "project.godot").is_file():
        raise RunnerError(f"Missing project.godot under source game: {source_game}")
    source_lock_path = project_root / "tools" / "upstream.json"
    source_lock = load_source_lock(project_root)
    patterns, policy_source = accepted_engine_patterns(source_lock, args.accept_engine_version)
    engine, discovery = discover_engine(project_root, args.godot_path, patterns)
    pack_dirs = [Path(p).resolve() for p in args.pack]
    pack_test_dirs = [Path(p).absolute() for p in args.pack_tests]
    scenario = load_pack_scenario(pack_test_dirs[0]) if args.suite == "PackScenario" else None
    prepared = None
    if args.suite == "PackScenario" and not pack_dirs:
        # Lazy import: preparation reuses our pure hash/pack helpers; it never starts an engine.
        from prepare_pack import validate_prepared_game
        try:
            prepared = validate_prepared_game(source_game)
        except ValueError as error:
            raise RunnerError(f"Prepared PackScenario source rejected: {error}") from error
    for pack_dir in pack_dirs:
        resolve_pack_name(pack_dir)  # fail with exit 2 before any engine run

    run_id = datetime.now().strftime("%Y%m%d-%H%M%S") + "-" + uuid.uuid4().hex[:8]
    artifacts_root = Path(args.artifacts_root).resolve() if args.artifacts_root else project_root / "artifacts" / "verification"
    run_root = artifacts_root / run_id
    run_root.mkdir(parents=True, exist_ok=False)
    env, isolation = build_engine_environment(run_root, isolate_appdata=not args.no_isolate_appdata)
    isolation["user_dirs"] = {}
    checkout = get_game_checkout_metadata(source_game, project_root)
    manifest = build_manifest(
        suite=args.suite, run_id=run_id, source_game=source_game, source_lock=source_lock,
        source_lock_sha256=sha256_file(source_lock_path), checkout=checkout,
        historical_baseline=args.historical_baseline, engine=engine, engine_discovery=discovery,
        accepted_patterns=patterns, policy_source=policy_source, isolation=isolation,
        timeout_seconds=args.timeout_seconds, force_failure=args.force_failure)
    manifest["content_profile"] = args.content_profile
    manifest["packs"] = {}
    manifest["pack_test_hashes"] = {}
    if scenario is not None:
        manifest["pack_scenario"] = scenario
    if prepared is not None:
        manifest["prepared_source"] = prepared
    runner = EngineRunner(engine=engine, run_root=run_root, manifest=manifest, env=env,
                          timeout_seconds=args.timeout_seconds, accepted_patterns=patterns,
                          historical_baseline=args.historical_baseline,
                          diagnostic_verbose=args.diagnostic_verbose, echo=echo)
    exit_status = 1
    try:
        runner.save()
        version_record = runner.invoke(
            "version", run_root,
            ["--headless", "--log-file", str(run_root / "version.log"), "--version"], version_probe=True)
        manifest["engine_version"] = version_record.get("engine_version")
        manifest["source_changes"] = checkout.get("changes", [])
        known_counts = [1] if args.historical_baseline else []
        for selected in expand_suites(args.suite):
            directory = run_root / selected
            directory.mkdir(parents=True, exist_ok=True)
            isolated_game = directory / "game"
            isolated_name = f"mycardgame-tests/{run_id}/{selected}"
            copy_info = copy_isolated_game(source_game, isolated_game, Path(isolation["user_data_root"]), isolated_name)
            if prepared is not None:
                try:
                    if validate_prepared_game(source_game) != prepared:
                        raise ValueError("prepared inputs changed after preflight")
                    for relative, digest in prepared["output_hashes"].items():
                        if relative == "project.godot":  # Only the copy's custom user:// was rewritten.
                            continue
                        copied = isolated_game / relative
                        if not copied.is_file() or sha256_file(copied) != digest:
                            raise ValueError(f"prepared snapshot hash mismatch: {relative}")
                except ValueError as error:
                    raise RunnerError(f"Prepared PackScenario copy rejected: {error}") from error
            isolation["user_dirs"][selected] = copy_info["user_dir"]
            manifest.setdefault("copy_exclusions", {})[selected] = {
                k: len(v) for k, v in copy_info["skipped"].items()}
            if selected == "BoardRemoved":
                manifest.setdefault("board_module_removed", {})[selected] = remove_board_module(isolated_game)
            manifest.setdefault("source_tree", {})[selected] = source_tree_ledger(isolated_game)
            hashes = []
            for relative in SOURCE_HASH_PATHS:
                target = isolated_game / relative
                if selected == "BoardRemoved" and any(relative == m or relative.startswith(m + "/") for m in BOARD_MODULE_PATHS):
                    continue
                if not target.is_file():
                    raise RunnerError(f"Missing source hash target: {target}")
                hashes.append({"path": relative, "sha256": sha256_file(target)})
            manifest["source_hashes"][selected] = hashes
            isolated_tests = directory / "tests"
            isolated_tests.mkdir(parents=True, exist_ok=True)
            test_hashes = []
            for test_file in sorted((project_root / "tests").glob("*.gd")):
                if test_file.is_symlink():
                    continue
                shutil.copy2(test_file, isolated_tests / test_file.name)
                test_hashes.append({"path": test_file.name, "sha256": sha256_file(isolated_tests / test_file.name)})
            manifest["test_hashes"][selected] = test_hashes
            dropped = drop_linked_mods(source_game, isolated_game, copy_info["skipped"]["links"])
            if dropped:
                manifest.setdefault("linked_mods_dropped", {})[selected] = dropped
                echo(f"NOTE: {selected} copy drops linked mod entries {dropped}; use --pack to test them")
            manifest["packs"][selected] = install_packs(pack_dirs, isolated_game)
            if prepared is not None:
                manifest["packs"][selected] = prepared["packs"]
            probes: list[Path] = []
            if selected == "Smoke" and pack_test_dirs:
                probes, pack_hashes = copy_pack_tests(pack_test_dirs, directory / "pack_tests")
                manifest["pack_test_hashes"][selected] = pack_hashes
            scenario_script = None
            if selected == "PackScenario":
                scenario_script, pack_hashes = copy_pack_scenario(pack_test_dirs[0], isolated_game, scenario)
                manifest["pack_test_hashes"][selected] = pack_hashes
            runner.save()
            import_args = ["--headless", "--path", str(isolated_game), "--editor", "--import"]
            import_record = runner.invoke("import", directory, import_args, cold_import=True,
                                          known_shutdown_resources=known_counts)
            if import_record["cold_cache_uid_requires_recheck"]:
                runner.invoke("import-verified", directory, import_args, known_shutdown_resources=known_counts)
            if selected == "PackScenario":
                run_pack_scenario(runner, directory, isolated_game, scenario_script, scenario, args.content_profile)
                continue
            script_path = isolated_tests / SUITE_SCRIPTS[selected]
            test_args = ["--headless", "--path", str(isolated_game), "--script", str(script_path)]
            user_args = build_user_args(selected, force_failure=args.force_failure, probes=probes,
                                        content_profile=args.content_profile)
            if selected == "Boardless":
                run_script_phases(runner, directory, test_args, user_args,
                                  ("write", "read", "defeat", "scene_off"), phase_argument="boardless-phase",
                                  marker_prefix="BOARDLESS PASS: ", log_prefix="boardless")
            elif selected == "BoardRemoved":
                run_script_phases(runner, directory, test_args, user_args,
                                  ("removed", "defeat"), phase_argument="boardless-phase",
                                  marker_prefix="BOARDLESS PASS: ", log_prefix="board-removed")
            elif selected == "SaveLoad":
                for phase in ("write", "read", "rejected"):
                    runner.invoke(f"save-{phase}", directory,
                                  test_args + ["--", *user_args, f"--phase={phase}", f"--source-game-path={source_game}"],
                                  marker=SUITE_MARKERS[selected], save_rejections=(phase == "rejected"))
            else:
                required = [f"{PACK_PROBE_DONE_MARKER}{probe.name}" for probe in probes]
                runner.invoke(selected.lower(), directory, test_args + (["--", *user_args] if user_args else []),
                              marker=SUITE_MARKERS[selected], required_markers=required)
        manifest["completed"] = True
        manifest["known_shutdown_issues"] = any(r.get("shutdown_resources") for r in manifest["results"])
        manifest["verdict"] = "PASS_WITH_KNOWN_SHUTDOWN_ISSUES" if manifest["known_shutdown_issues"] else "PASS"
        if args.force_failure:
            # The control run passed when it was required to fail: the failure exit path is broken.
            manifest["verdict"] = "FORCE_FAILURE_NOT_DETECTED"
            manifest["error"] = "Smoke passed although --force-failure was requested."
            echo(f"VERIFICATION {manifest['verdict']}: {run_root}")
            exit_status = 1
        else:
            echo(f"VERIFICATION {manifest['verdict']}: {run_root}")
            exit_status = 0
    except RunnerError as error:
        manifest["error"] = str(error)
        if args.force_failure and manifest["results"] and manifest["results"][-1]["name"] == "smoke" \
                and not manifest["results"][-1]["passed"]:
            manifest["verdict"] = "FORCED_FAILURE_DETECTED"
            echo(f"VERIFICATION {manifest['verdict']} (expected exit 1): {run_root}")
        else:
            manifest["verdict"] = "FAIL"
            echo(f"VERIFICATION FAIL: {error}")
        exit_status = 1
    finally:
        runner.save()
        echo(f"Evidence: {run_root}")
    return exit_status


def main(argv: Optional[list[str]] = None) -> int:
    args = parse_args(argv)
    try:
        return run(args)
    except RunnerError as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
