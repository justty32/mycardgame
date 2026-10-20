#!/usr/bin/env python3
"""Synthetic pack-link regressions; no Godot, GUI, or real game modifications.

Run: python3 tests/test_link_pack.py
Fixtures, complete test output and hashes stay in artifacts/link-pack/<uuid>/.
Windows exercises a real mklink /J fallback, including paths containing spaces.
"""
from __future__ import annotations

import contextlib
import hashlib
import io
import json
import os
from pathlib import Path
import platform
import sys
import unittest
from unittest import mock
import uuid

PROJECT_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(PROJECT_ROOT / "tools"))
import link_pack  # noqa: E402
import test_game as runner  # noqa: E402

RUN_ROOT = PROJECT_ROOT / "artifacts" / "link-pack" / uuid.uuid4().hex
BASE = '{\n\t"properties": {\n\t\t"mod_load_data": {\n\t\t}\n\t}\n}\n'


class PackLinkTests(unittest.TestCase):
    def setUp(self) -> None:
        self.root = RUN_ROOT / self.id().split(".")[-1]
        self.root.mkdir(parents=True)

    def assert_owned(self, path: Path) -> None:
        # Resolve the parent rather than the link, so removal cannot be aimed
        # outside this test's fixture even when checking a junction itself.
        self.assertTrue(path.parent.resolve().is_relative_to(self.root.resolve()))

    def test_round_trip_line_endings_and_bom(self) -> None:
        for name, text in (("lf", BASE), ("crlf", BASE.replace("\n", "\r\n")),
                           ("mixed", BASE.replace('"mod_load_data": {\n', '"mod_load_data": {\r\n'))):
            for bom in (False, True):
                with self.subTest(line_endings=name, bom=bom):
                    path = self.root / f"{name}-{bom}.json"
                    original = (b"\xef\xbb\xbf" if bom else b"") + text.encode("utf-8")
                    path.write_bytes(original)
                    self.assertTrue(link_pack.set_enabled(path, "sample_pack", True))
                    enabled = path.read_bytes()
                    newline = "\n" if name == "lf" else "\r\n"
                    inserted = link_pack.enable_line("sample_pack", newline).encode("utf-8")
                    self.assertIn(inserted, enabled)
                    self.assertEqual(enabled.replace(inserted, b"", 1), original)
                    self.assertFalse(link_pack.set_enabled(path, "sample_pack", True))
                    self.assertEqual(path.read_bytes(), enabled)
                    self.assertTrue(link_pack.set_enabled(path, "sample_pack", False))
                    self.assertEqual(path.read_bytes(), original)
                    self.assertFalse(link_pack.set_enabled(path, "sample_pack", False))
                    self.assertEqual(path.read_bytes(), original)

    def test_refuse_existing_alternate_entry_without_writing(self) -> None:
        path = self.root / "mod_list.json"
        original = BASE.replace('"mod_load_data": {', '"mod_load_data": {\n"external/mods/sample_pack/": {}')
        path.write_bytes(original.encode())
        with self.assertRaises(runner.RunnerError):
            link_pack.set_enabled(path, "sample_pack", True)
        self.assertEqual(path.read_bytes(), original.encode())

    def test_missing_block_or_newline_does_not_write(self) -> None:
        path = self.root / "mod_list.json"
        for original in (b"{}", b'{"mod_load_data": {}}'):
            path.write_bytes(original)
            with self.assertRaises(runner.RunnerError):
                link_pack.set_enabled(path, "sample_pack", True)
            self.assertEqual(path.read_bytes(), original)

    def test_refuse_real_folder(self) -> None:
        target = self.root / "real folder"
        target.mkdir()
        sentinel = target / "keep.txt"
        sentinel.write_bytes(b"keep real folder")
        with self.assertRaises(runner.RunnerError):
            link_pack.create_link(target, self.root)
        self.assert_owned(target)
        with self.assertRaises(runner.RunnerError):
            link_pack.remove_link(target)
        self.assertEqual(sentinel.read_bytes(), b"keep real folder")

    @unittest.skipUnless(os.name == "nt", "requires real Windows junctions")
    def test_junction_command_failure_reports_environment_error(self) -> None:
        target = self.root / "link"
        pack = self.root / "pack"
        pack.mkdir()
        completed = link_pack.subprocess.CompletedProcess([], 1, None, None)
        with mock.patch.object(link_pack.os, "symlink", side_effect=OSError("fallback")), \
             mock.patch.object(link_pack.subprocess, "run", return_value=completed):
            with self.assertRaisesRegex(runner.RunnerError, "mklink /J failed"):
                link_pack.create_link(target, pack)
        self.assertTrue(pack.is_dir())
        self.assertFalse(target.exists())

    @unittest.skipUnless(os.name == "nt", "requires real Windows junctions")
    def test_windows_junction_cli_and_isolated_copy(self) -> None:
        pack = self.root / "pack source with spaces"
        pack.mkdir()
        (pack / "mod_info.json").write_text(json.dumps({"properties": {"mod_name": "sample_pack"}}), encoding="utf-8")
        sentinel = pack / "keep.txt"
        sentinel.write_bytes(b"target must survive unlink")
        source_hashes = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in pack.iterdir()}
        game = self.root / "fake game with spaces"
        (game / "external").mkdir(parents=True)
        (game / "project.godot").write_text('[application]\nconfig/name="Synthetic"\n', encoding="utf-8")
        mod_list = game / "external" / "mod_list.json"
        original = BASE.replace("\n", "\r\n").encode()
        mod_list.write_bytes(original)
        target = game / "external" / "mods" / "sample_pack"

        # Only the symlink attempt is mocked. subprocess.run still executes the
        # real Windows command, with CREATE_NO_WINDOW required by the test.
        real_run = link_pack.subprocess.run
        def run_hidden(*args, **kwargs):
            self.assertEqual(kwargs.get("creationflags"), 0x08000000)
            self.assertEqual(kwargs.get("encoding"), "oem")
            self.assertEqual(kwargs.get("errors"), "replace")
            self.assertEqual(args[0][:4], ["cmd", "/c", "mklink", "/J"])
            self.assertEqual(args[0][4:], [str(target), str(pack)])
            return real_run(*args, **kwargs)

        with mock.patch.object(link_pack.os, "symlink", side_effect=OSError("forced junction fallback")), \
             mock.patch.object(link_pack.subprocess, "run", side_effect=run_hidden) as command:
            self.assertEqual(link_pack.main([str(pack), "--game-dir", str(game), "--enable"]), 0)
            self.assertEqual(command.call_count, 1)
        self.assertEqual(os.lstat(target).st_reparse_tag, 0xA0000003)
        self.assertEqual(target.resolve(), pack.resolve())
        with mock.patch.object(runner.os.path, "isjunction", None, create=True):
            self.assertTrue(runner._is_link_or_junction(str(target)))
            self.assertFalse(runner._is_link_or_junction(str(pack)))
        self.assertEqual(link_pack.create_link(target, pack), "exists")
        alternate = self.root / "alternate target"
        alternate.mkdir()
        with self.assertRaises(runner.RunnerError):
            link_pack.create_link(target, alternate)

        copied = self.root / "isolated game"
        details = runner.copy_isolated_game(game, copied, self.root / "user data", "synthetic")
        self.assertIn(str(target), details["skipped"]["links"])
        self.assertFalse((copied / "external" / "mods" / "sample_pack").exists())
        self.assertEqual(runner.drop_linked_mods(game, copied, details["skipped"]["links"]),
                         ["external/mods/sample_pack/"])
        self.assertNotIn("external/mods/sample_pack/", (copied / "external" / "mod_list.json").read_text())
        self.assertNotEqual(mod_list.read_bytes(), original)

        self.assert_owned(target)
        self.assertEqual(link_pack.main([str(pack), "--game-dir", str(game), "--unlink"]), 0)
        self.assertFalse(target.exists())
        self.assertFalse(runner._is_link_or_junction(str(target)))
        self.assertEqual(mod_list.read_bytes(), original)
        self.assertEqual({p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in pack.iterdir()}, source_hashes)
        self.assert_owned(target)
        self.assertFalse(link_pack.remove_link(target))


def main() -> int:
    RUN_ROOT.mkdir(parents=True)
    output = io.StringIO()
    with contextlib.redirect_stdout(output), contextlib.redirect_stderr(output):
        result = unittest.TextTestRunner(stream=output, verbosity=2).run(
            unittest.defaultTestLoader.loadTestsFromTestCase(PackLinkTests))
    log = output.getvalue()
    (RUN_ROOT / "test.log").write_text(log, encoding="utf-8", newline="\n")
    hashes = {str(p.relative_to(PROJECT_ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
              for p in (PROJECT_ROOT / "tools/link_pack.py", Path(__file__).resolve(),
                        PROJECT_ROOT / "tools/test_game.py", RUN_ROOT / "test.log")}
    report = {"passed": result.wasSuccessful(), "tests": result.testsRun,
              "failures": len(result.failures), "errors": len(result.errors),
              "skipped": result.skipped, "platform": platform.platform(),
              "python": sys.version, "hashes": hashes,
              "scope": "Synthetic fixtures only; no Godot or GUI; fixtures retained."}
    (RUN_ROOT / "results.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(log, end="")
    print(f"Evidence: {RUN_ROOT}")
    return 0 if result.wasSuccessful() else 1


if __name__ == "__main__":
    raise SystemExit(main())
