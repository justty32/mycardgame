#!/usr/bin/env python3
"""File-only playable-copy regressions. Fixtures remain in ignored artifacts/."""
from __future__ import annotations

import contextlib
import io
import json
from pathlib import Path
import sys
import unittest
from unittest import mock
import uuid

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
import prepare_pack as tool

RUN_ROOT = ROOT / "artifacts" / "prepare-pack-tests" / uuid.uuid4().hex


class PreparePackTests(unittest.TestCase):
    def setUp(self) -> None:
        self.root = RUN_ROOT / self.id().split(".")[-1]
        self.game = self.root / "game"
        self.pack = self.root / "input pack"
        self.write(self.game / "project.godot", '[application]\nconfig/name="fixture"\n'
                   'config/use_custom_user_dir=false\nconfig/custom_user_dir_name="personal"\n'
                   '[game]\ncontent_profile="test"\nother_setting=42\n')
        self.write(self.game / "external" / "mod_list.json", '{"personal list":true}')
        self.write(self.game / "external" / "mod_info.json", '{}')
        self.write(self.game / "scripts" / "fixture.gd", 'extends Node\n')
        self.write(self.pack / "mod_info.json", json.dumps({"properties": {
            "mod_folder_to_load_data": {"external/mods/fixture/cards/": {}}}}))
        self.write(self.pack / "cards" / "card.json", '{"fixture":true}')

    def write(self, path: Path, content: str) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")

    def snapshot(self, path: Path) -> dict:
        return {str(p.relative_to(path)): p.read_bytes() for p in path.rglob("*") if p.is_file()}

    def test_fresh_copy_preserves_sources_and_overrides_only_copy(self) -> None:
        for private in (".git/config", ".godot/cache", "external/saves/run.json", "external/profile.json",
                        "external/user_settings.json", "external/mods/personal/mod_info.json", "override.cfg",
                        ".env", "export_credentials.cfg", "nested/client.pem", "client.key", "client.p12", "client.pfx"):
            self.write(self.game / private, "private sentinel")
        self.write(self.pack / "profile.json", "pack private sentinel")
        before = self.snapshot(self.root)
        result = tool.prepare(self.root, [self.pack])
        project = Path(result["project"])
        copied = project.parent
        text = project.read_text(encoding="utf-8")
        self.assertIn('content_profile="pack"', text)
        self.assertNotIn('content_profile="test"', text)
        self.assertIn('other_setting=42', text)
        self.assertEqual(text.count("config/use_custom_user_dir="), 1)
        self.assertIn(result["user_directory_name"], text)
        self.assertEqual(self.snapshot(self.root / "game"), {
            str(Path(key).relative_to("game")): value for key, value in before.items()
            if Path(key).parts[0] == "game"})
        self.assertEqual(self.snapshot(self.pack), {
            str(Path(key).relative_to("input pack")): value for key, value in before.items()
            if Path(key).parts[0] == "input pack"})
        for path in copied.rglob("*"):
            if path.is_file():
                self.assertNotIn(b"private sentinel", path.read_bytes())
        data = json.loads((copied / "external/mod_list.json").read_text())
        self.assertEqual(data["properties"]["mod_load_data"], {
            "external/": {"enabled": True, "load_priority": 0},
            "external/mods/fixture/": {"enabled": True, "load_priority": 10}})
        manifest = json.loads(Path(result["manifest_path"]).read_text(encoding="utf-8"))
        self.assertEqual(manifest["status"], "prepared")
        self.assertFalse(manifest["engine_started"])
        self.assertEqual(manifest["source_hashes"]["project.godot"], tool.sha256_file(self.game / "project.godot"))
        self.assertEqual(manifest["output_hashes"]["project.godot"], tool.sha256_file(project))
        self.assertEqual(manifest["packs"][0]["files"]["cards/card.json"], tool.sha256_file(self.pack / "cards/card.json"))

    def test_existing_outside_and_non_uuid_outputs_refused_before_writes(self) -> None:
        occupied = self.root / "artifacts/playable" / uuid.uuid4().hex
        self.write(occupied / "keep.txt", "keep")
        before = self.snapshot(self.root)
        for output in (occupied, self.root / uuid.uuid4().hex, self.root / "artifacts/playable/not-a-uuid"):
            with self.subTest(output=output), self.assertRaises(tool.RunnerError):
                tool.prepare(self.root, [self.pack], output)
        self.assertEqual(self.snapshot(self.root), before)

    def test_links_rejected_without_following_or_writing(self) -> None:
        # The shared detector has real Windows junction tests in test_link_pack.
        # Here deterministic link classification exercises our preflight on every OS.
        detector = tool._is_link_or_junction
        for linked in (self.game, self.game / "scripts/fixture.gd", self.pack / "cards",
                       self.root / "artifacts"):
            with self.subTest(linked=linked), mock.patch.object(tool, "_is_link_or_junction",
                    side_effect=lambda p: Path(p) == linked or detector(p)):
                with self.assertRaisesRegex(tool.RunnerError, "linked"):
                    tool.prepare(self.root, [self.pack])
        self.assertFalse((self.root / "artifacts").exists())

    def test_missing_or_duplicate_pack_and_bad_project_leave_no_output(self) -> None:
        for packs in ([], [self.root / "missing"], [self.pack, self.pack]):
            with self.subTest(packs=packs), self.assertRaises(tool.RunnerError):
                tool.prepare(self.root, packs)
        self.write(self.game / "project.godot", '[game]\ncontent_profile="test"\n')
        with self.assertRaisesRegex(tool.RunnerError, "application"):
            tool.prepare(self.root, [self.pack])
        self.assertFalse((self.root / "artifacts").exists())

    def test_default_project_profile_and_manual_commands(self) -> None:
        self.write(self.game / "project.godot", '[application]\nconfig/name="fixture"\n')
        result = tool.prepare(self.root, [self.pack])
        self.assertIn('[game]\n\ncontent_profile="pack"', Path(result["project"]).read_text())
        self.assertEqual(tool.validate_prepared_game(Path(result["project"]).parent)["status"], "prepared")
        output = io.StringIO()
        with mock.patch.object(tool, "prepare", return_value=result), contextlib.redirect_stdout(output):
            self.assertEqual(tool.main(["--pack", str(self.pack)]), 0)
        self.assertIn(result["project"], output.getvalue())
        self.assertIn("No engine was started", output.getvalue())
        self.assertIn("--headless --editor --import", output.getvalue())

    def test_prepared_validation_accepts_exact_snapshot_rejects_tampering(self) -> None:
        result = tool.prepare(self.root, [self.pack])
        game = Path(result["project"]).parent
        verified = tool.validate_prepared_game(game)
        self.assertEqual(verified["manifest_sha256"], tool.sha256_file(Path(result["manifest_path"])))
        for relative in ("external/mods/fixture/cards/extra.json", "override.cfg"):
            copy = tool.prepare(self.root, [self.pack])
            altered = Path(copy["project"]).parent
            self.write(altered / relative, "{}")
            with self.subTest(relative=relative), self.assertRaises(ValueError):
                tool.validate_prepared_game(altered)
        self.write(game / "project.godot", '[application]\n[game]\ncontent_profile="test"\n')
        with self.assertRaises(ValueError):
            tool.validate_prepared_game(game)


if __name__ == "__main__":
    print(f"Fixtures retained: {RUN_ROOT}")
    unittest.main(verbosity=2)
