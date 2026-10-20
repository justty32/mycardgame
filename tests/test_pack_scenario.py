#!/usr/bin/env python3
"""Generic PackScenario contract tests; Python fake processes only, never Godot."""
from __future__ import annotations

import contextlib
import io
import json
import os
from pathlib import Path
import sys
import unittest
from unittest import mock
import uuid

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
import test_game as runner

FAKE_ENGINE = r'''
import json, os, pathlib, sys, time
args = sys.argv[1:]
if "--version" in args:
    print("4.7.2.synthetic"); sys.exit(0)
if "--import" in args:
    sys.exit(0)
boardless = any(a.startswith("--boardless-phase=") for a in args)
phase = next(a.split("=",1)[1] for a in args if a.startswith(("--scenario-phase=", "--boardless-phase=")))
project = pathlib.Path(args[args.index("--path") + 1])
mode = os.environ.get("SCENARIO_SYNTHETIC_MODE", "")
state = project / "state.json"
if phase == "write":
    state.write_text(json.dumps({"pid":os.getpid(), "appdata":os.environ.get("APPDATA"), "home":os.environ.get("HOME")}))
elif phase == "read":
    previous = json.loads(state.read_text())
    assert previous["pid"] != os.getpid(), "fresh process required"
    assert previous["appdata"] == os.environ.get("APPDATA")
    assert previous["home"] == os.environ.get("HOME")
elif phase not in ("defeat", "scene_off"):
    print("FAIL: unknown scenario phase"); sys.exit(2)
if mode == "timeout":
    time.sleep(20)
if mode == "error":
    print("ERROR: unexpected test failure")
if mode == "save-error":
    print("ERROR: Save rejected: malformed")
if mode != "missing":
    print(("BOARDLESS PASS: " if boardless else "PACK SCENARIO PASS: ") + phase + ("-wrong" if mode == "wrong" else ""))
sys.exit(3 if mode == "exit" else 0)
'''


class PackScenarioTests(unittest.TestCase):
    def setUp(self):
        self.root = ROOT / "artifacts" / "pack-scenario-tests" / uuid.uuid4().hex
        self.tests = self.root / "tests"
        self.tests.mkdir(parents=True)
        self.spec = {"schema": "pack-scenario/1", "entry": "entry.gd", "phases": ["write", "read", "defeat"]}
        (self.tests / "entry.gd").write_text("extends SceneTree\n", encoding="utf-8")
        (self.tests / "nested").mkdir()
        (self.tests / "nested" / "helper.gd").write_text("extends RefCounted\n", encoding="utf-8")
        self.write_spec()

    def write_spec(self):
        (self.tests / "scenario.json").write_text(json.dumps(self.spec), encoding="utf-8")

    def fake_engine(self):
        script = self.root / "fake_engine.py"
        script.write_text(FAKE_ENGINE, encoding="utf-8")
        if os.name == "nt":
            executable = self.root / "fake_engine.cmd"
            executable.write_text(f'@echo off\n"{sys.executable}" -I "{script}" %*\nexit /b %ERRORLEVEL%\n', encoding="utf-8")
        else:
            executable = self.root / "fake_engine"
            executable.write_text(f'#!/bin/sh\nexec "{sys.executable}" -I "{script}" "$@"\n', encoding="utf-8")
            executable.chmod(0o700)
        return executable

    def test_parse_constraints(self):
        valid = ["--suite", "PackScenario", "--pack", "input", "--pack-tests", "tests"]
        self.assertEqual(runner.parse_args(valid + ["--content-profile", "pack"]).suite, "PackScenario")
        self.assertNotIn("PackScenario", runner.expand_suites("All"))
        for extra in (["--pack-tests", "other"], ["--historical-baseline"], ["--no-isolate-appdata"]):
            with self.subTest(extra=extra), contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
                runner.parse_args(valid + extra)
        for args in (["--suite", "PackScenario"], ["--suite", "PackScenario", "--pack", "input"]):
            with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
                runner.parse_args(args)

    def test_schema_and_path_rejections(self):
        for entry in ("../entry.gd", "/entry.gd", "C:/entry.gd", "res://entry.gd", "sub\\entry.gd", "./entry.gd", "nested//helper.gd", "absent.gd", "entry.py"):
            self.spec["entry"] = entry
            self.write_spec()
            with self.subTest(entry=entry), self.assertRaises(runner.RunnerError):
                runner.load_pack_scenario(self.tests)
        self.spec["entry"] = "entry.gd"
        for phases in ([], ["write", "write"], ["../write"], ["WRITE"], [1], "write", ["a" * 65], [f"phase{i}" for i in range(65)]):
            self.spec["phases"] = phases
            self.write_spec()
            with self.subTest(phases=phases), self.assertRaises(runner.RunnerError):
                runner.load_pack_scenario(self.tests)
        for raw in ('{}', '[]', '{', '{"schema":"pack-scenario/1","schema":"pack-scenario/1","entry":"entry.gd","phases":["write"]}'):
            (self.tests / "scenario.json").write_text(raw)
            with self.assertRaises(runner.RunnerError):
                runner.load_pack_scenario(self.tests)

    def test_copy_and_hash_every_input(self):
        scenario = runner.load_pack_scenario(self.tests)
        game = self.root / "game"
        game.mkdir()
        entry, hashes = runner.copy_pack_scenario(self.tests, game, scenario)
        self.assertEqual(entry, game / "pack_tests" / "entry.gd")
        self.assertEqual({item["path"] for item in hashes}, {"scenario.json", "entry.gd", "nested/helper.gd"})
        self.assertEqual((game / "pack_tests/nested/helper.gd").read_bytes(), (self.tests / "nested/helper.gd").read_bytes())
        with self.assertRaises(runner.RunnerError):
            runner.copy_pack_scenario(self.tests, game, scenario)
        (self.tests / "entry.gd").write_text("changed")
        with self.assertRaises(runner.RunnerError):
            runner.copy_pack_scenario(self.tests, game, scenario)

    def test_links_rejected_without_following(self):
        # Exercise platform-independent rejection without requiring Windows link privileges.
        original = runner._is_link_or_junction
        with mock.patch.object(runner, "_is_link_or_junction", side_effect=lambda path: Path(path).name == "nested" or original(path)):
            with self.assertRaisesRegex(runner.RunnerError, "links"):
                runner.load_pack_scenario(self.tests)

    def test_process_verdicts_and_shared_state(self):
        executable = self.fake_engine()
        scenario = runner.load_pack_scenario(self.tests)
        for mode in ("", "missing", "wrong", "error", "save-error", "exit", "timeout", "unknown"):
            with self.subTest(mode=mode):
                directory = self.root / (mode or "success")
                directory.mkdir()
                game = directory / "game"
                game.mkdir()
                env, isolation = runner.build_engine_environment(directory)
                env["SCENARIO_SYNTHETIC_MODE"] = mode
                manifest = {"results": [], "isolation": isolation}
                engine = runner.EngineRunner(engine=executable, run_root=directory, manifest=manifest, env=env,
                                             timeout_seconds=1 if mode == "timeout" else 10, accepted_patterns=[],
                                             historical_baseline=False, echo=lambda _: None)
                spec = {**scenario, "phases": ["unknown"]} if mode == "unknown" else scenario
                if mode:
                    with self.assertRaises(runner.RunnerError):
                        runner.run_pack_scenario(engine, directory, game, self.tests / "entry.gd", spec, "pack")
                    self.assertEqual(len(manifest["results"]), 1, "failed phase stops later phases")
                    self.assertFalse(manifest["results"][0]["passed"])
                else:
                    runner.run_pack_scenario(engine, directory, game, self.tests / "entry.gd", spec, "pack")
                    self.assertEqual([r["name"] for r in manifest["results"]], ["scenario-write", "scenario-read", "scenario-defeat"])
                    self.assertEqual(len({r["launched_pid"] for r in manifest["results"]}), 3)
                for result in manifest["results"]:
                    self.assertIn("--headless", result["command_arguments"])
                    self.assertEqual(result["directory"], str(directory))
                    self.assertIsNotNone(result["ended_utc"])

    def make_project_pack(self):
        project = self.root / "project"
        game = project / "game"
        (project / "tools").mkdir(parents=True)
        (project / "tools/upstream.json").write_text("{}")
        for relative in runner.SOURCE_HASH_PATHS:
            path = game / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("# synthetic source\n")
        (game / "project.godot").write_text('[application]\nconfig/name="Synthetic"\n')
        (game / "external").mkdir(exist_ok=True)
        (game / "external/mod_list.json").write_text('{"properties":{"mod_load_data":{}}}')
        pack = self.root / "pack"
        pack.mkdir()
        (pack / "mod_info.json").write_text('{"properties":{"mod_name":"synthetic"}}')
        return project, pack

    def test_full_runner_records_pack_and_scenario_inputs(self):
        project, pack = self.make_project_pack()
        args = runner.parse_args(["--suite", "PackScenario", "--pack", str(pack), "--pack-tests", str(self.tests),
                                  "--project-root", str(project), "--content-profile", "pack"])
        with mock.patch.object(runner, "discover_engine", return_value=(self.fake_engine(), {"method": "synthetic"})):
            self.assertEqual(runner.run(args, echo=lambda _: None), 0)
        manifests = list((project / "artifacts/verification").glob("*/results.json"))
        self.assertEqual(len(manifests), 1)
        manifest = json.loads(manifests[0].read_text())
        self.assertTrue(manifest["completed"])
        self.assertEqual(manifest["content_profile"], "pack")
        self.assertEqual(manifest["pack_scenario"]["phases"], self.spec["phases"])
        self.assertEqual(len(manifest["pack_test_hashes"]["PackScenario"]), 3)
        self.assertEqual(manifest["packs"]["PackScenario"][0]["files"][0]["sha256"], runner.sha256_file(pack / "mod_info.json"))
        self.assertEqual([item["name"] for item in manifest["results"]],
                         ["version", "import", "scenario-write", "scenario-read", "scenario-defeat"])

    def test_prepared_copy_requires_matching_manifest_and_pack_hashes(self):
        from prepare_pack import prepare
        project, pack = self.make_project_pack()
        prepared = prepare(project, [pack])
        prepared_game = Path(prepared["project"]).parent
        args = runner.parse_args(["--suite", "PackScenario", "--source-game", str(prepared_game),
                                  "--pack-tests", str(self.tests), "--project-root", str(project), "--content-profile", "pack"])
        with mock.patch.object(runner, "discover_engine", return_value=(self.fake_engine(), {"method": "synthetic"})):
            self.assertEqual(runner.run(args, echo=lambda _: None), 0)
            manifest_path = next((project / "artifacts/verification").glob("*/results.json"))
            manifest = json.loads(manifest_path.read_text())
            self.assertEqual(manifest["prepared_source"]["format"], "playable-copy/1")
            self.assertEqual(manifest["packs"]["PackScenario"], prepared["packs"])
            self.assertIn("project.godot", manifest["prepared_source"]["output_hashes"])
            (prepared_game / "external/mods/synthetic/unrecorded.json").write_text("{}")
            with mock.patch.object(runner.EngineRunner, "invoke") as invoke, self.assertRaises(runner.RunnerError):
                runner.run(args, echo=lambda _: None)
            invoke.assert_not_called()

    def test_boardless_uses_four_strict_phases_in_all(self):
        project, _pack = self.make_project_pack()
        (project / "tests").mkdir()
        (project / "tests/boardless_flow.gd").write_text("extends SceneTree\n")
        args = runner.parse_args(["--suite", "Boardless", "--project-root", str(project)])
        self.assertIn("Boardless", runner.expand_suites("All"))
        with mock.patch.object(runner, "discover_engine", return_value=(self.fake_engine(), {"method": "synthetic"})):
            self.assertEqual(runner.run(args, echo=lambda _: None), 0)
        manifest = json.loads(next((project / "artifacts/verification").glob("*/results.json")).read_text())
        phases = manifest["results"][2:]
        self.assertEqual([item["name"] for item in phases],
                         ["boardless-write", "boardless-read", "boardless-defeat", "boardless-scene_off"])
        self.assertEqual(len({item["directory"] for item in phases}), 1)
        self.assertTrue(all(item["marker_found"] for item in phases))


if __name__ == "__main__":
    unittest.main(verbosity=2)
