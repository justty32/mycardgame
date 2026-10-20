#!/usr/bin/env python3
"""Synthetic diagnostics for tools/test_game.py.

Does not execute Godot. A fake engine (a Python script behind a platform launcher)
replays scripted stdout/stderr/log output and exit codes through the real
EngineRunner.invoke() so the verdict rules, durable evidence, timeout handling and
isolation helpers are exercised exactly as the real runner uses them.

Usage: python3 tests/test_runner_diagnostics.py
Exit 0 and prints "RUNNER DIAGNOSTICS PASS: N checks" on success; exit 1 on the
first failed assertion. Evidence: artifacts/runner-diagnostics/<uuid>/results.json
"""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
import time
import uuid
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(PROJECT_ROOT / "tools"))
import test_game as runner  # noqa: E402

IS_WINDOWS = os.name == "nt"
RUN_ROOT = PROJECT_ROOT / "artifacts" / "runner-diagnostics" / uuid.uuid4().hex
RUN_ROOT.mkdir(parents=True, exist_ok=True)
MANIFEST: dict = {"completed": False, "results": [], "note": "Synthetic diagnostics only; no Godot executed.",
                  "runner": {"name": runner.RUNNER_NAME, "version": runner.RUNNER_VERSION}}
CHECKS = 0

FAKE_ENGINE_SOURCE = r'''
import json, os, subprocess, sys, time
args = sys.argv[1:]
log_path = None
spec_path = None
i = 0
while i < len(args):
    if args[i] == "--log-file":
        log_path = args[i + 1]; i += 2; continue
    if args[i] == "--spec":
        spec_path = args[i + 1]; i += 2; continue
    i += 1
spec = json.load(open(spec_path, encoding="utf-8")) if spec_path else {}
if spec.get("wait_for_running_evidence", True):
    deadline = time.time() + 2
    observed = False
    while not observed and time.time() < deadline:
        try:
            saved = json.load(open(os.path.join(os.getcwd(), "results.json"), encoding="utf-8"))
            last = saved["results"][-1]
            observed = last["status"] == "running" and last["launched_pid"] in (os.getpid(), os.getppid())
        except Exception:
            observed = False
        if not observed:
            time.sleep(0.01)
    if not observed:
        print("FAIL: missing running evidence"); sys.exit(3)
if spec.get("version_line", "4.7.2.synthetic"):
    print(spec.get("version_line", "4.7.2.synthetic"))
for line in spec.get("stdout", []):
    print(line)
for line in spec.get("stderr", []):
    print(line, file=sys.stderr)
if log_path and spec.get("log"):
    with open(log_path, "a", encoding="utf-8") as handle:
        handle.write("\n".join(spec["log"]) + "\n")
sys.stdout.flush(); sys.stderr.flush()
if spec.get("spawn_child_pid_file"):
    child = subprocess.Popen([sys.executable, "-c", "import time; time.sleep(120)"],
                             creationflags=0x08000000 if os.name == "nt" else 0)
    with open(spec["spawn_child_pid_file"], "w") as handle:
        handle.write(str(child.pid))
if spec.get("sleep"):
    time.sleep(spec["sleep"])
sys.exit(spec.get("exit", 0))
'''


def assert_that(condition: bool, message: str) -> None:
    global CHECKS
    if not condition:
        runner.save_manifest(MANIFEST, RUN_ROOT / "results.json")
        print(f"ASSERT FAIL: {message}")
        print(f"Evidence: {RUN_ROOT}")
        sys.exit(1)
    CHECKS += 1
    print(f"PASS: {message}")


def make_fake_engine() -> Path:
    script = RUN_ROOT / "fake_engine.py"
    script.write_text(FAKE_ENGINE_SOURCE, encoding="utf-8")
    if IS_WINDOWS:
        launcher = RUN_ROOT / "fake_engine.cmd"
        launcher.write_text(f'@echo off\r\n"{sys.executable}" -I "{script}" %*\r\nexit /b %ERRORLEVEL%\r\n', encoding="utf-8")
    else:
        launcher = RUN_ROOT / "fake_engine.sh"
        launcher.write_text(f'#!/bin/sh\nexec "{sys.executable}" -I "{script}" "$@"\n', encoding="utf-8")
        launcher.chmod(0o755)
    return launcher


def new_runner(engine: Path, timeout: int = 10, patterns=None, historical_baseline: bool = False) -> runner.EngineRunner:
    env, _ = runner.build_engine_environment(RUN_ROOT)
    return runner.EngineRunner(engine=engine, run_root=RUN_ROOT, manifest=MANIFEST, env=env,
                               timeout_seconds=timeout, accepted_patterns=list(patterns or runner.DEFAULT_ACCEPTED_ENGINE_PATTERNS),
                               historical_baseline=historical_baseline, echo=lambda text: None)


def invoke_fixture(engine_runner: runner.EngineRunner, name: str, spec: dict, expected_pass: bool, *,
                   version_probe: bool = True, marker: str | None = "SYNTHETIC PASS:", **kwargs) -> dict:
    spec_path = RUN_ROOT / f"{name}.spec.json"
    spec_path.write_text(json.dumps(spec), encoding="utf-8")
    caught = False
    try:
        engine_runner.invoke(name, RUN_ROOT, ["--spec", str(spec_path)], marker=marker, version_probe=version_probe, **kwargs)
    except runner.RunnerError:
        caught = True
    row = MANIFEST["results"][-1]
    assert_that(row["passed"] == expected_pass and caught == (not expected_pass), f"{name} verdict and exception agree")
    assert_that(row["launched_pid"] and row["launched_pid"] > 0 and row["launched_pid_kind"] == "invoked_executable",
                f"{name} records launched PID without claiming child engine identity")
    assert_that(str(row["started_utc"]).endswith("Z") and str(row["ended_utc"]).endswith("Z"), f"{name} records UTC start/end")
    durable = json.loads((RUN_ROOT / "results.json").read_text(encoding="utf-8"))
    assert_that(durable["results"][-1]["status"] == row["status"] and not durable["completed"],
                f"{name} result durable before whole run completion")
    return row


def process_alive(pid: int) -> bool:
    if IS_WINDOWS:
        out = subprocess.run(["tasklist", "/FI", f"PID eq {pid}", "/NH"], capture_output=True,
                             text=True, encoding="oem", errors="replace", check=True,
                             creationflags=runner.WINDOWS_CREATION_FLAGS, stdin=subprocess.DEVNULL).stdout
        return str(pid) in out
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    return True


def main() -> None:
    # --- pure helpers -------------------------------------------------------------------------
    assert_that(runner.get_exit_code_hex(-1073741819) == "0xC0000005", "signed access-violation status preserves all 32 bits")
    assert_that(runner.get_exit_code_hex(0) == "0x00000000", "zero exit code formatting")
    assert_that(runner.get_exit_code_hex(None) is None, "unobserved exit is not converted to success")
    if IS_WINDOWS:
        assert_that(runner.normalize_posix_return_code(7) == (7, None), "Windows return codes pass through without signal")
    else:
        assert_that(runner.normalize_posix_return_code(-11) == (139, 11), "POSIX signal death maps to 128+N with signal recorded")
    assert_that(runner.get_native_crash_signatures("NOTE: CrashHandlerException is a handler; ObjectDB instances leaked") == [],
                "generic crash mention and leak are not native crash signatures")
    assert_that(len(runner.get_native_crash_signatures("handle_crash: Program crashed with signal 11\n")) == 1,
                "native Unix-style handler signature recognized")

    def judge(console: str, log: str = "", **overrides) -> dict:
        params = dict(console_output=console, log_text=log, exit_code=0, timed_out=False, marker="X PASS:",
                      version_probe=False, accepted_patterns=list(runner.DEFAULT_ACCEPTED_ENGINE_PATTERNS),
                      cold_import=False, save_rejections=False, known_shutdown_resources=[], historical_baseline=False)
        params.update(overrides)
        return runner.evaluate_phase_output(**params)

    assert_that(judge("X PASS:\nERROR: 1 resources still in use at exit")["passed"] is False,
                "resource retention fails even with exit 0 and PASS marker")
    hist = judge("X PASS:\nERROR: 1 resources still in use at exit", known_shutdown_resources=[1])
    assert_that(hist["passed"] and hist["shutdown_resources"] == [1] and hist["warnings"],
                "known shutdown count is tolerated only when explicitly listed and stays recorded")
    assert_that(judge("X PASS:\nWARNING: ObjectDB instances leaked at exit")["passed"] is False, "ObjectDB leak fails by default")
    leak_hist = judge("X PASS:\nWARNING: ObjectDB instances leaked at exit", historical_baseline=True)
    assert_that(leak_hist["passed"] and leak_hist["objectdb_leak"], "historical baseline tolerates leak text but records it")
    assert_that(judge("X PASS:\nERROR: unexpected")["unexpected_error_lines"] == ["ERROR: unexpected"]
                and judge("X PASS:\nERROR: unexpected")["passed"] is False, "any other ^ERROR line fails and is listed")
    assert_that(judge("X PASS:\nSCRIPT ERROR: boom")["passed"] is False, "SCRIPT ERROR fails")
    assert_that(judge("X PASS:", exit_code=1)["passed"] is False, "non-zero exit fails")
    assert_that(judge("X PASS:", timed_out=True)["passed"] is False, "timeout fails")
    v46 = judge("4.6.stable.official.89cea1439\nX PASS:", version_probe=True)
    assert_that(v46["engine_version"] == "4.6.stable.official.89cea1439" and not v46["engine_version_accepted"] and not v46["passed"],
                "4.6 is rejected under the default 4.7 policy")
    v46ok = judge("4.6.stable.official.89cea1439\nX PASS:", version_probe=True, accepted_patterns=[r"^4\.6\.", r"^4\.7\."])
    assert_that(v46ok["passed"], "4.6 is accepted again when the policy is widened")
    v472 = judge("4.7.2.stable.mono.arch_linux.ed1daf0bf\nX PASS:", version_probe=True)
    assert_that(v472["passed"] and v472["engine_version"] == "4.7.2.stable.mono.arch_linux.ed1daf0bf", "4.7.2 mono build accepted")
    assert_that(judge("junk\nX PASS:", version_probe=True)["passed"] is False, "missing version line fails the probe")
    cold = judge(runner.COLD_CACHE_UID_ERROR, marker=None, cold_import=True)
    assert_that(cold["passed"] and cold["cold_cache_uid_requires_recheck"], "cold cache UID is tolerated only for the cold import and flags a recheck")
    assert_that(judge(runner.COLD_CACHE_UID_ERROR, marker=None)["passed"] is False, "cold cache UID fails the verified re-import")

    def rejection_log(cases) -> str:
        return "".join(f"EXPECTED SAVE REJECTION BEGIN: {c}\n{runner.SAVE_REJECTED_PREFIX}{c}\nEXPECTED SAVE REJECTION END: {c}\n" for c in cases)

    good_log = rejection_log(runner.SAVE_REJECTION_CASES) + "SAVELOAD PASS: phase=rejected\n"
    rej = judge("", good_log, marker="SAVELOAD PASS:", save_rejections=True)
    assert_that(rej["passed"] and rej["save_rejection_blocks_valid"], "ten itemised rejection blocks are accepted")
    bad = judge("", rejection_log(runner.SAVE_REJECTION_CASES[:-1]) + "SAVELOAD PASS: phase=rejected\n", marker="SAVELOAD PASS:", save_rejections=True)
    assert_that(not bad["passed"] and not bad["save_rejection_blocks_valid"], "nine rejection blocks fail")
    stray = judge("", good_log + runner.SAVE_REJECTED_PREFIX + "stray\n", marker="SAVELOAD PASS:", save_rejections=True)
    assert_that(not stray["passed"], "a rejection line outside the blocks fails")

    # --- preflight -------------------------------------------------------------------------------
    preflight = RUN_ROOT / "preflight-existing.log"
    preflight.write_text("existing evidence", encoding="utf-8")
    runner.confirm_log_writable(preflight)
    assert_that(preflight.read_text(encoding="utf-8") == "existing evidence", "log preflight opens exact target without truncating evidence")

    engine = make_fake_engine()
    engine_runner = new_runner(engine)
    (RUN_ROOT / "blocked-log.log").mkdir()
    blocked_caught = False
    try:
        engine_runner.invoke("blocked-log", RUN_ROOT, ["--version"])
    except runner.RunnerError:
        blocked_caught = True
    blocked = MANIFEST["results"][-1]
    assert_that(blocked_caught and blocked["log_write_preflight"] == "failed" and blocked["launched_pid"] is None
                and "blocked-log.log" in blocked["error"], "unwritable log target fails before any process starts with path-specific evidence")

    # --- process fixtures ------------------------------------------------------------------------
    invoke_fixture(engine_runner, "normal", {"stdout": ["SYNTHETIC PASS:"]}, True)
    row = invoke_fixture(engine_runner, "native-text", {"stdout": ["SYNTHETIC PASS:", "CrashHandlerException: Program crashed with signal 11"]}, False)
    assert_that(row["exit_code_hex"] == "0x00000000" and len(row["native_crash_signatures"]) == 1, "native marker overrides successful exit and PASS text")
    row = invoke_fixture(engine_runner, "nonzero", {"stdout": ["SYNTHETIC PASS:"], "exit": 7}, False)
    assert_that(row["exit_code_hex"] == "0x00000007" and row["exit_code"] == 7, "ordinary failure exit retains hexadecimal evidence")
    invoke_fixture(engine_runner, "missing-marker", {}, False)
    invoke_fixture(engine_runner, "resource-leak", {"stdout": ["SYNTHETIC PASS:", "ERROR: 1 resources still in use at exit"]}, False)
    invoke_fixture(engine_runner, "object-leak", {"stdout": ["SYNTHETIC PASS:", "WARNING: ObjectDB instances leaked at exit"]}, False)
    invoke_fixture(engine_runner, "stderr-error", {"stderr": ["ERROR: something from stderr"], "stdout": ["SYNTHETIC PASS:"]}, False)
    row = invoke_fixture(engine_runner, "version-46", {"version_line": "4.6.stable.official.89cea1439", "stdout": ["SYNTHETIC PASS:"]}, False)
    assert_that(row["engine_version"] == "4.6.stable.official.89cea1439" and row["engine_version_accepted"] is False,
                "process-level version probe rejects 4.6 under default policy and records the version")
    # Non-probe path: the runner prepends --log-file; the fake engine writes the engine log.
    row = invoke_fixture(engine_runner, "cold-import", {"version_line": "", "log": [runner.COLD_CACHE_UID_ERROR]}, True,
                         version_probe=False, marker=None, cold_import=True)
    assert_that(row["cold_cache_uid_requires_recheck"] and (RUN_ROOT / "cold-import.log").exists(),
                "cold import through the real --log-file path flags the recheck")
    row = invoke_fixture(engine_runner, "save-rejected", {"version_line": "", "log": good_log.splitlines()}, True,
                         version_probe=False, marker="SAVELOAD PASS:", save_rejections=True)
    assert_that(row["save_rejection_blocks_valid"] and row["unexpected_error_lines"] == [], "rejection blocks read from the engine log, not console")
    hist_runner = new_runner(engine, historical_baseline=True)
    row = invoke_fixture(hist_runner, "historical", {"stdout": ["SYNTHETIC PASS:", "ERROR: 1 resources still in use at exit"]}, True,
                         known_shutdown_resources=[1])
    assert_that(row["shutdown_resources"] == [1], "historical baseline records the tolerated shutdown count")

    child_pid_file = RUN_ROOT / "timeout-child.pid"
    short_runner = new_runner(engine, timeout=10)
    short_runner.timeout_seconds = 1
    row = invoke_fixture(short_runner, "timeout", {"stdout": ["SYNTHETIC PASS:"], "sleep": 30, "spawn_child_pid_file": str(child_pid_file)}, False)
    assert_that(row["timed_out"] and row["status"] == "failed", "timeout remains failure even with prior PASS text")
    child_pid = int(child_pid_file.read_text().strip()) if child_pid_file.exists() else None
    time.sleep(0.5)
    assert_that(child_pid is not None and not process_alive(child_pid), "timeout termination stops the whole process tree the runner created")
    if not IS_WINDOWS:
        assert_that(row["exit_signal"] in (9, 15) and row["exit_code"] == 128 + row["exit_signal"] and row["exit_code_raw"] < 0,
                    "POSIX signal exit keeps raw Popen value and shell-style code")

    missing_runner = new_runner(RUN_ROOT / ("missing-engine.exe" if IS_WINDOWS else "missing-engine"))
    try:
        missing_runner.invoke("start-failure", RUN_ROOT, ["--version"], version_probe=True)
    except runner.RunnerError:
        pass
    last = MANIFEST["results"][-1]
    assert_that(last["status"] == "failed" and last["launched_pid"] is None and last["exit_code_hex"] is None,
                "start failure is durable with no invented PID or exit")

    source_text = (PROJECT_ROOT / "tools" / "test_game.py").read_text(encoding="utf-8")
    assert_that(runner.WINDOWS_CREATION_FLAGS & 0x08000000 == 0x08000000 and "STARTF_USESHOWWINDOW" in source_text,
                "Windows launches use CREATE_NO_WINDOW and a hidden startup window")
    assert_that('"--headless"' in source_text and source_text.count('"--headless"') >= 3, "every real engine invocation is headless")

    # --- environment isolation -------------------------------------------------------------------
    os.environ["DISPLAY"] = os.environ.get("DISPLAY", ":99")
    env, description = runner.build_engine_environment(RUN_ROOT)
    assert_that("DISPLAY" not in env and "WAYLAND_DISPLAY" not in env, "child environment carries no display variables")
    if IS_WINDOWS:
        assert_that(env["APPDATA"].startswith(str(RUN_ROOT)) and env["LOCALAPPDATA"].startswith(str(RUN_ROOT)),
                    "Windows APPDATA/LOCALAPPDATA redirected into the run directory")
        env2, _ = runner.build_engine_environment(RUN_ROOT, isolate_appdata=False)
        assert_that(env2.get("APPDATA") == os.environ.get("APPDATA"), "--no-isolate-appdata keeps the real APPDATA")
    else:
        assert_that(all(env[k].startswith(str(RUN_ROOT)) for k in ("HOME", "XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME")),
                    "HOME and XDG data/config/cache redirected into the run directory")
    assert_that(description["user_data_root"].startswith(str(RUN_ROOT)), "user:// root lives under the run directory")

    # --- isolated copy ---------------------------------------------------------------------------
    fake_source = RUN_ROOT / "fake-source"
    for relative in ("scripts/a.gd", ".git/HEAD", ".godot/cache.bin", "external/saves/save.json", "external/profile.json",
                     "external/user_settings.json", "external/mod_list.json", "sub/.godot/x", "sub/profile.json"):
        target = fake_source / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text("x", encoding="utf-8")
    (fake_source / "project.godot").write_text(
        "config_version=5\n\n[application]\n\nconfig/name=\"Fake\"\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name=\"old\"\n", encoding="utf-8")
    link_created = False
    try:
        os.symlink(str(fake_source / "scripts"), str(fake_source / "linked"), target_is_directory=True)
        link_created = True
    except (OSError, NotImplementedError):
        pass
    copy_root = RUN_ROOT / "copy" / "game"
    info = runner.copy_isolated_game(fake_source, copy_root, RUN_ROOT / "userdata", "mycardgame-tests/synthetic/Fake")
    assert_that((copy_root / "scripts" / "a.gd").exists() and (copy_root / "external" / "mod_list.json").exists(), "ordinary game files are copied")
    assert_that(not (copy_root / ".git").exists() and not (copy_root / ".godot").exists() and not (copy_root / "sub" / ".godot").exists(),
                "Git and cache directories are excluded at any depth")
    assert_that(not (copy_root / "external" / "saves").exists() and not (copy_root / "external" / "profile.json").exists()
                and not (copy_root / "external" / "user_settings.json").exists() and not (copy_root / "sub" / "profile.json").exists(),
                "saves, profile and settings never reach the isolated copy")
    if link_created:
        assert_that(not (copy_root / "linked").exists() and info["skipped"]["links"], "symlinks are skipped, not followed")
    project_text = (copy_root / "project.godot").read_text(encoding="utf-8")
    assert_that(project_text.count("config/use_custom_user_dir=") == 1 and 'config/custom_user_dir_name="mycardgame-tests/synthetic/Fake"' in project_text
                and '"old"' not in project_text, "project.godot gets exactly one isolated custom user dir")
    assert_that((Path(info["user_dir"]) / "write-preflight.txt").exists() and info["user_dir"].startswith(str(RUN_ROOT / "userdata")),
                "isolated user:// directory is created and write-checked")
    assert_that((fake_source / "project.godot").read_text(encoding="utf-8").count('"old"') == 1, "source project.godot is untouched")

    # --- content packs ---------------------------------------------------------------------------
    def write_json(path: Path, data) -> Path:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(data), encoding="utf-8")
        return path

    def pack_info(keys, scripts=None, name="sample_pack") -> dict:
        return {"patch_data": {}, "properties": {"object_id": "mod_data_sample", "mod_name": name,
                "mod_folder_to_load_data": {k: {"class_name": "CardData", "table_name": "_id_to_card_data"} for k in keys},
                "mod_script_file_paths": scripts or {}}}

    packs_root = RUN_ROOT / "packs"
    good_pack = packs_root / "good" / "pack"
    write_json(good_pack / "mod_info.json", pack_info(["external/mods/sample_pack/cards/"]))
    write_json(good_pack / "cards" / "smp_card.json", {"properties": {"object_id": "smp_card"}})
    assert_that(runner.resolve_pack_name(good_pack) == "sample_pack",
                "pack install name comes from the external/mods/<name>/ prefix in mod_info.json, not the folder name")
    named_only = packs_root / "named"
    write_json(named_only / "mod_info.json", pack_info([], name="only_named"))
    assert_that(runner.resolve_pack_name(named_only) == "only_named", "a pack without folder keys falls back to mod_name")
    bad_infos = {
        "missing": None,
        "mixed": pack_info(["external/mods/a/cards/", "external/mods/b/cards/"]),
        "outside": pack_info(["external/data/cards/"]),
        "script_mismatch": pack_info(["external/mods/a/cards/"], scripts={"external/mods/b/x.gd": ""}),
        "traversal": pack_info(["external/mods/../cards/"]),
    }
    for label, info in bad_infos.items():
        bad_dir = packs_root / f"bad-{label}"
        bad_dir.mkdir(parents=True, exist_ok=True)
        if info is not None:
            write_json(bad_dir / "mod_info.json", info)
        try:
            runner.resolve_pack_name(bad_dir)
            rejected = False
        except runner.RunnerError:
            rejected = True
        assert_that(rejected, f"pack name resolution rejects {label} mod_info.json")

    pack_game = RUN_ROOT / "pack_game"
    (pack_game / "external" / "mods" / "example_mod").mkdir(parents=True, exist_ok=True)
    original_list = '{"patch_data": {}, "properties": {"mod_load_data": {"external/": {"enabled": true, "load_priority": 0},\n' \
                    '"external/mods/example_mod/": {"enabled": false, "load_priority": 1},\n}, "object_id": "mod_list"}}'
    (pack_game / "external" / "mod_list.json").write_text(original_list, encoding="utf-8")
    pack_link_created = False
    try:
        os.symlink(str(RUN_ROOT), str(good_pack / "linked"), target_is_directory=True)
        pack_link_created = True
    except (OSError, NotImplementedError):
        pass
    installed = runner.install_packs([good_pack], pack_game)
    mod_list = json.loads((pack_game / "external" / "mod_list.json").read_text(encoding="utf-8"))
    load_data = mod_list["properties"]["mod_load_data"]
    assert_that((pack_game / "external" / "mods" / "sample_pack" / "cards" / "smp_card.json").is_file()
                and installed[0]["name"] == "sample_pack" and any(f["path"] == "cards/smp_card.json" and f["sha256"] for f in installed[0]["files"]),
                "pack is copied under external/mods/<name>/ and its file hashes are recorded")
    assert_that(load_data["external/mods/sample_pack/"] == {"enabled": True, "load_priority": runner.PACK_LOAD_PRIORITY_BASE}
                and load_data["external/"]["enabled"] is True and load_data["external/mods/example_mod/"]["enabled"] is False,
                "copied mod_list.json (trailing comma tolerated) enables the pack after base data and keeps other entries")
    if pack_link_created:
        assert_that(not (pack_game / "external" / "mods" / "sample_pack" / "linked").exists() and installed[0]["skipped"],
                    "symlinks inside a pack are skipped, not followed")
    try:
        runner.install_packs([good_pack], pack_game)
        collided = False
    except runner.RunnerError:
        collided = True
    assert_that(collided, "installing a pack over an existing mod folder is rejected")

    tests_dir = packs_root / "good" / "tests"
    tests_dir.mkdir(parents=True, exist_ok=True)
    (tests_dir / "sample_probe.gd").write_text("extends RefCounted\n", encoding="utf-8")
    (tests_dir / "helper.gd").write_text("extends RefCounted\n", encoding="utf-8")
    probes, probe_hashes = runner.copy_pack_tests([tests_dir], RUN_ROOT / "pack_tests_copy")
    assert_that([p.name for p in probes] == ["sample_probe.gd"] and len(probe_hashes) == 2 and all(h["sha256"] for h in probe_hashes),
                "pack tests are copied with hashes and only *_probe.gd become entry points")
    no_probe = packs_root / "noprobe"
    no_probe.mkdir(parents=True, exist_ok=True)
    (no_probe / "helper.gd").write_text("extends RefCounted\n", encoding="utf-8")
    try:
        runner.copy_pack_tests([no_probe], RUN_ROOT / "pack_tests_none")
        no_entry = False
    except runner.RunnerError:
        no_entry = True
    assert_that(no_entry, "a pack-tests directory without a probe entry point is rejected")
    smoke_args = runner.build_user_args("Smoke", force_failure=True, probes=probes)
    assert_that(smoke_args == [f"--pack-probe={probes[0]}", "--force-failure"]
                and runner.build_user_args("CombatDefeat", probes=probes) == ["--scenario=defeat"],
                "pack probes reach Smoke only, after one '--' separator together with other user args")
    missing_done = judge("X PASS:", required_markers=["PACK PROBE DONE: sample_probe.gd"])
    assert_that(not missing_done["passed"] and missing_done["required_markers_missing"] == ["PACK PROBE DONE: sample_probe.gd"],
                "a requested pack probe that never reports completion fails the phase")
    assert_that(judge("X PASS:\nPACK PROBE DONE: sample_probe.gd (1 assertions)", required_markers=["PACK PROBE DONE: sample_probe.gd"])["passed"],
                "a completed pack probe satisfies its required marker")
    for bad_args in (["--suite", "Smoke", "--pack-tests", "x"], ["--suite", "Dictionary", "--pack", "p", "--pack-tests", "x"]):
        try:
            runner.parse_args(bad_args)
            rejected = False
        except SystemExit:
            rejected = True
        assert_that(rejected, f"pack argument validation rejects {' '.join(bad_args)}")
    parsed = runner.parse_args(["--suite", "All", "--pack", "a", "--pack", "b", "--pack-tests", "t"])
    assert_that(parsed.pack == ["a", "b"] and parsed.pack_tests == ["t"], "--pack and --pack-tests are repeatable and accepted with All")

    # --- content profile ---------------------------------------------------------------------------
    assert_that(runner.build_user_args("Smoke", probes=probes, content_profile="pack")
                == ["--content-profile=pack", f"--pack-probe={probes[0]}"]
                and runner.build_user_args("Smoke") == [] and runner.build_user_args("CombatVictory", content_profile="test") == ["--scenario=victory"],
                "pack content profile is passed to the engine as a user arg; test profile adds nothing")
    for bad_args in (["--suite", "Smoke", "--content-profile", "pack"],
                     ["--suite", "All", "--content-profile", "pack", "--pack", "p"],
                     ["--suite", "Smoke", "--content-profile", "prod", "--pack", "p"]):
        try:
            runner.parse_args(bad_args)
            rejected = False
        except SystemExit:
            rejected = True
        assert_that(rejected, f"content profile validation rejects {' '.join(bad_args)}")
    parsed = runner.parse_args(["--suite", "Smoke", "--content-profile", "pack", "--pack", "p"])
    assert_that(parsed.content_profile == "pack" and runner.parse_args([]).content_profile == "test",
                "pack profile is accepted with Smoke and --pack; test is the default")

    # --- editor pack link (tools/link_pack.py) ---------------------------------------------------
    import link_pack  # noqa: E402 - tools/ is already on sys.path
    link_game = RUN_ROOT / "link_game"
    (link_game / "external" / "mods").mkdir(parents=True, exist_ok=True)
    shipped_list = '{\n\t"properties": {\n\t\t"mod_load_data": {\n\t\t\t"external/": {\n\t\t\t\t"enabled": true\n\t\t\t},\n\t\t},\n\t}\n}'
    (link_game / "external" / "mod_list.json").write_text(shipped_list, encoding="utf-8", newline="")
    if (good_pack / "linked").is_symlink():
        (good_pack / "linked").unlink()
    link_ok = True
    try:
        rc = link_pack.main([str(good_pack), "--game-dir", str(link_game), "--enable"])
    except OSError:
        link_ok = False
    if IS_WINDOWS:
        assert_that(link_ok and rc == 0, "Windows link_pack creates its link successfully")
    if link_ok:
        target = link_game / "external" / "mods" / "sample_pack"
        assert_that(rc == 0 and runner._is_link_or_junction(str(target)) and (target / "cards" / "smp_card.json").is_file()
                    and (IS_WINDOWS or not os.path.isabs(os.readlink(target))),
                    "link_pack creates a pack-named link (relative symlink on POSIX)")
        enabled_text = (link_game / "external" / "mod_list.json").read_text(encoding="utf-8")
        assert_that(link_pack.enable_line("sample_pack") in enabled_text and link_pack.main([str(good_pack), "--game-dir", str(link_game)]) == 0,
                    "link_pack --enable adds one mod_list line and re-linking the same target is idempotent")
        dropped = runner.drop_linked_mods(link_game, link_game, [str(link_game / "external" / "other")])
        assert_that(dropped == [] and runner.drop_linked_mods(link_game, link_game, [str(target)]) == ["external/mods/sample_pack/"]
                    and runner.drop_linked_mods(link_game, link_game, [str(target)]) == [],
                    "runner drops mod_list entries only for links directly under external/mods/ and only when present")
        (link_game / "external" / "mod_list.json").write_text(enabled_text, encoding="utf-8", newline="")
        assert_that(link_pack.main([str(good_pack), "--game-dir", str(link_game), "--unlink"]) == 0 and not target.exists()
                    and (link_game / "external" / "mod_list.json").read_text(encoding="utf-8") == shipped_list
                    and (good_pack / "cards" / "smp_card.json").is_file(),
                    "link_pack --unlink removes only the link and restores mod_list.json byte-for-byte")
        (target).mkdir()
        assert_that(link_pack.main([str(good_pack), "--game-dir", str(link_game)]) == 2 and link_pack.main([str(good_pack), "--game-dir", str(link_game), "--unlink"]) == 2
                    and target.is_dir(), "link_pack refuses to replace or delete a real mod folder")

    # --- checkout identity -----------------------------------------------------------------------
    state = {"repo": str(PROJECT_ROOT / "game")}

    def fake_git(args):
        if "--show-toplevel" in args:
            return 0, state["repo"] + "\n"
        if "--verify" in args:
            return 0, "test-checkout-commit\n"
        if "diff" in args:
            return 0, "test-modified-path\n"
        raise AssertionError("Unexpected synthetic Git command")

    checkout = runner.get_game_checkout_metadata(PROJECT_ROOT / "game", PROJECT_ROOT, run_git=fake_git)
    assert_that(checkout["layout"] == "independent_game_checkout" and checkout["commit"] == "test-checkout-commit"
                and checkout["changes"] == ["test-modified-path"], "independent game Git layout records a separate checkout identity")
    state["repo"] = str(PROJECT_ROOT)
    checkout = runner.get_game_checkout_metadata(PROJECT_ROOT / "game", PROJECT_ROOT, run_git=fake_git)
    assert_that(checkout["layout"] == "outer_repository_snapshot" and checkout["commit"] == "test-checkout-commit",
                "outer snapshot layout labels its commit as outer checkout metadata")
    checkout = runner.get_game_checkout_metadata(RUN_ROOT / "game", PROJECT_ROOT, run_git=fake_git)
    assert_that(checkout["layout"] == "isolated_source_snapshot" and checkout["commit"] is None,
                "artifacts copy does not inherit outer checkout commit identity")
    manifest = runner.build_manifest(suite="Smoke", run_id="synthetic", source_game=PROJECT_ROOT / "game",
                                     source_lock={"commit": "lock-commit", "engine_policy": {"baseline": "4.7"}},
                                     source_lock_sha256="X", checkout=checkout, historical_baseline=False, engine=engine,
                                     engine_discovery={}, accepted_patterns=[r"^4\.7\."], policy_source="test", isolation={},
                                     timeout_seconds=10, force_failure=False)
    assert_that(manifest["upstream_commit"] == "lock-commit" and manifest["engine_policy"]["baseline"] == "4.7",
                "upstream identity is always read from the source lock")

    # --- policy and CLI --------------------------------------------------------------------------
    lock = runner.load_source_lock(PROJECT_ROOT)
    patterns, source = runner.accepted_engine_patterns(lock, None)
    assert_that(any(re.search(p, "4.7.2.stable") for p in patterns) and not any(re.search(p, "4.6.stable") for p in patterns)
                and source.startswith("tools/upstream.json"), "source lock policy accepts 4.7.x and not 4.6 by default")
    patterns, source = runner.accepted_engine_patterns(lock, [r"^4\.6\."])
    assert_that(patterns == [r"^4\.6\."] and source == "cli", "--accept-engine-version replaces the policy")
    if IS_WINDOWS:
        discovery_root = RUN_ROOT / "engine-discovery"
        engine_dir = discovery_root / ".tools" / "godot-4.7"
        engine_dir.mkdir(parents=True)
        for name in ("Godot_v4.6-stable_win64_console.exe", "Godot_v4.7.2-stable_win64.exe",
                     "Godot_v4.7.2-stable_win64_console.exe"):
            (engine_dir / name).write_bytes(b"synthetic discovery fixture; never executed")
        selected, discovery = runner.discover_engine(discovery_root, None, runner.DEFAULT_ACCEPTED_ENGINE_PATTERNS)
        assert_that(selected.name == "Godot_v4.7.2-stable_win64_console.exe" and discovery["method"] == ".tools",
                    "Windows .tools discovery selects the accepted console build over GUI and old-version names")
        explicit = engine_dir / "Godot_v4.7.2-stable_win64.exe"
        selected, discovery = runner.discover_engine(discovery_root, str(explicit), runner.DEFAULT_ACCEPTED_ENGINE_PATTERNS)
        assert_that(selected == explicit.resolve() and discovery["method"] == "explicit",
                    "an explicit engine path overrides .tools preference without executing the fixture")
    for bad_args in (["--force-failure", "--suite", "All"], ["--timeout-seconds", "5"], ["--suite", "Nope"]):
        try:
            runner.parse_args(bad_args)
            rejected = False
        except SystemExit:
            rejected = True
        assert_that(rejected, f"argument validation rejects {' '.join(bad_args)}")
    parsed = runner.parse_args(["--suite", "saveload"])
    assert_that(parsed.suite == "SaveLoad" and runner.expand_suites("Combat") == ["CombatVictory", "CombatDefeat"]
                and runner.expand_suites("All") == list(runner.ALL_SUITES), "suite names are case-insensitive and expand like the PowerShell runner")
    assert_that(runner.parse_args(["--suite", "ctb"]).suite == "Ctb" and "Ctb" in runner.ALL_SUITES
                and runner.SUITE_SCRIPTS["Ctb"] == "ctb_flow.gd" and runner.SUITE_MARKERS["Ctb"] == "CTB PASS:"
                and runner.build_user_args("Ctb") == [] and runner.expand_suites("Ctb") == ["Ctb"],
                "Ctb suite (combat framework action timeline) is part of All with its own script and marker")
    assert_that(judge("CTB PASS: 10 checks, 0 failures", marker="CTB PASS:")["passed"]
                and not judge("CTB FAIL: 10 checks, 1 failures\nFAIL: order", marker="CTB PASS:")["passed"],
                "Ctb verdict needs the CTB PASS marker and no FAIL lines")
    assert_that(runner.parse_args(["--suite", "board"]).suite == "Board" and "Board" in runner.ALL_SUITES
                and runner.ALL_SUITES.index("Board") == runner.ALL_SUITES.index("Ctb") + 1
                and runner.SUITE_SCRIPTS["Board"] == "board_flow.gd" and runner.SUITE_MARKERS["Board"] == "BOARD PASS:"
                and runner.build_user_args("Board") == [] and runner.expand_suites("Board") == ["Board"],
                "Board suite (combat framework board / movement) is part of All after Ctb with its own script and marker")
    assert_that(judge("BOARD PASS: 10 checks, 0 failures", marker="BOARD PASS:")["passed"]
                and not judge("BOARD FAIL: 10 checks, 1 failures\nFAIL: move", marker="BOARD PASS:")["passed"],
                "Board verdict needs the BOARD PASS marker and no FAIL lines")
    assert_that(runner.parse_args(["--suite", "wave"]).suite == "Wave" and "Wave" in runner.ALL_SUITES
                and runner.ALL_SUITES.index("Wave") == runner.ALL_SUITES.index("Board") + 1
                and runner.SUITE_SCRIPTS["Wave"] == "wave_flow.gd" and runner.SUITE_MARKERS["Wave"] == "WAVE PASS:"
                and runner.build_user_args("Wave") == [] and runner.expand_suites("Wave") == ["Wave"],
                "Wave suite (combat framework waves) is part of All after Board with its own script and marker")
    assert_that(judge("WAVE PASS: 10 checks, 0 failures", marker="WAVE PASS:")["passed"]
                and not judge("WAVE FAIL: 10 checks, 1 failures\nFAIL: wave", marker="WAVE PASS:")["passed"],
                "Wave verdict needs the WAVE PASS marker and no FAIL lines")

    MANIFEST["completed"] = True
    MANIFEST["checks"] = CHECKS
    runner.save_manifest(MANIFEST, RUN_ROOT / "results.json")
    print(f"RUNNER DIAGNOSTICS PASS: {CHECKS} checks; evidence {RUN_ROOT}")


if __name__ == "__main__":
    main()
