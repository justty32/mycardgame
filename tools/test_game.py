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
                 "CombatVictory", "CombatDefeat")
ALL_SUITES = ("ResourceLifecycle", "Dictionary", "Smoke", "CombatVictory", "CombatDefeat", "SaveLoad")
SUITE_SCRIPTS = {
    "ResourceLifecycle": "resource_lifecycle.gd",
    "Dictionary": "dictionary_regression.gd",
    "Smoke": "framework_smoke.gd",
    "CombatVictory": "combat_flow.gd",
    "CombatDefeat": "combat_flow.gd",
    "SaveLoad": "save_load_flow.gd",
}
SUITE_MARKERS = {
    "ResourceLifecycle": "RESOURCE PASS:",
    "Dictionary": "DICTIONARY PASS:",
    "Smoke": "SMOKE PASS:",
    "CombatVictory": "COMBAT PASS:",
    "CombatDefeat": "COMBAT PASS:",
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
)
EXCLUDED_DIR_NAMES = frozenset({".git", ".godot", ".import", ".saves", ".screenshots"})
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
                                   stdin=subprocess.DEVNULL)
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


def _is_executable_file(path: Path) -> bool:
    if not path.is_file():
        return False
    if IS_WINDOWS:
        return path.suffix.lower() == ".exe"
    return os.access(path, os.X_OK)


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
        discovery["method"] = "explicit"
        discovery["located"] = str(candidate)
        return candidate.resolve(), discovery

    tools_dir = project_root / ".tools"
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
                    continue
                if not _name_version_ok(file_name, patterns):
                    discovery["candidates_considered"].append(f"{full} (version in name not accepted)")
                    continue
                found.append(full)
        if found:
            def rank(path: Path) -> tuple[int, int, str]:
                name = path.name.lower()
                console = 0 if (IS_WINDOWS and name.endswith("_console.exe")) else 1
                return (console, 0 if IS_WINDOWS or ".exe" not in name else 1, str(path))
            found.sort(key=rank)
            discovery["method"] = ".tools"
            discovery["located"] = str(found[0])
            discovery["candidates_considered"].extend(str(p) for p in found)
            return found[0].resolve(), discovery

    path_names = ["godot", "godot4", "godot-mono", "godot4-mono"]
    for name in path_names:
        located = shutil.which(name)
        discovery["candidates_considered"].append(f"PATH:{name} -> {located}")
        if located:
            discovery["method"] = "PATH"
            discovery["located"] = located
            return Path(located).resolve(), discovery
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


# --------------------------------------------------------------------------- verdict rules

def evaluate_phase_output(*, console_output: str, log_text: str, exit_code: Optional[int],
                          timed_out: bool, marker: Optional[str], version_probe: bool,
                          accepted_patterns: list[str], cold_import: bool,
                          save_rejections: bool, known_shutdown_resources: list[int],
                          historical_baseline: bool, output_streams_open: bool = False) -> dict:
    """Pure judgment over a finished phase. Shared by the real runner and the synthetic tests."""
    combined = console_output + "\n" + log_text
    verdict: dict[str, Any] = {}
    crash = get_native_crash_signatures(combined)
    verdict["native_crash_signatures"] = crash
    passed = (not timed_out) and exit_code == 0 and not SCRIPT_ERROR_OR_FAIL_RE.search(combined) \
        and not crash and not output_streams_open
    if marker:
        found = marker in combined
        verdict["marker_found"] = found
        passed = passed and found
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
               save_rejections: bool = False, version_probe: bool = False) -> dict:
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
                historical_baseline=self.historical_baseline, output_streams_open=streams_open)
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
                        help="All | Dictionary | Smoke | Combat | SaveLoad | ResourceLifecycle | CombatVictory | CombatDefeat")
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
    args = parser.parse_args(argv)
    if not 10 <= args.timeout_seconds <= 900:
        parser.error("--timeout-seconds must be between 10 and 900")
    if args.force_failure and args.suite != "Smoke":
        parser.error("--force-failure applies to --suite Smoke only")
    return args


def run(args: argparse.Namespace, echo: Callable[[str], None] = print) -> int:
    project_root = Path(args.project_root).resolve() if args.project_root else Path(__file__).resolve().parent.parent
    source_game = Path(args.source_game).resolve() if args.source_game else project_root / "game"
    if not (source_game / "project.godot").is_file():
        raise RunnerError(f"Missing project.godot under source game: {source_game}")
    source_lock_path = project_root / "tools" / "upstream.json"
    source_lock = load_source_lock(project_root)
    patterns, policy_source = accepted_engine_patterns(source_lock, args.accept_engine_version)
    engine, discovery = discover_engine(project_root, args.godot_path, patterns)

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
            isolation["user_dirs"][selected] = copy_info["user_dir"]
            manifest.setdefault("copy_exclusions", {})[selected] = {
                k: len(v) for k, v in copy_info["skipped"].items()}
            hashes = []
            for relative in SOURCE_HASH_PATHS:
                target = isolated_game / relative
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
            runner.save()
            import_args = ["--headless", "--path", str(isolated_game), "--editor", "--import"]
            import_record = runner.invoke("import", directory, import_args, cold_import=True,
                                          known_shutdown_resources=known_counts)
            if import_record["cold_cache_uid_requires_recheck"]:
                runner.invoke("import-verified", directory, import_args, known_shutdown_resources=known_counts)
            script_path = isolated_tests / SUITE_SCRIPTS[selected]
            test_args = ["--headless", "--path", str(isolated_game), "--script", str(script_path)]
            if selected == "CombatVictory":
                test_args += ["--", "--scenario=victory"]
            elif selected == "CombatDefeat":
                test_args += ["--", "--scenario=defeat"]
            if selected == "SaveLoad":
                for phase in ("write", "read", "rejected"):
                    runner.invoke(f"save-{phase}", directory,
                                  test_args + ["--", f"--phase={phase}", f"--source-game-path={source_game}"],
                                  marker=SUITE_MARKERS[selected], save_rejections=(phase == "rejected"))
            else:
                if selected == "Smoke" and args.force_failure:
                    test_args += ["--", "--force-failure"]
                runner.invoke(selected.lower(), directory, test_args, marker=SUITE_MARKERS[selected])
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
