#!/usr/bin/env python3
"""Checks for tools/new_pack.py: the generated tree must pass boundary lint. No Godot needed.

Usage: python3 -I tests/test_new_pack.py
Exit 0 and prints "NEW PACK TESTS PASS: N checks"; exit 1 on the first failure.
"""
from __future__ import annotations

import json
import shutil
import sys
import uuid
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(PROJECT_ROOT / "tools"))
import boundary_lint  # noqa: E402
import new_pack  # noqa: E402

GT = "game" + "s"
RUN_ROOT = PROJECT_ROOT / "artifacts" / "new-pack-tests" / uuid.uuid4().hex
CHECKS = 0


def check(condition: bool, message: str) -> None:
    global CHECKS
    if not condition:
        print(f"ASSERT FAIL: {message}\nEvidence: {RUN_ROOT}")
        sys.exit(1)
    CHECKS += 1
    print(f"PASS: {message}")


def main() -> int:
    RUN_ROOT.mkdir(parents=True)
    shutil.copytree(PROJECT_ROOT / GT / new_pack.TEMPLATE, RUN_ROOT / GT / new_pack.TEMPLATE)
    (RUN_ROOT / GT / "README.md").write_text("# index\n", encoding="utf-8")
    check(boundary_lint.lint(RUN_ROOT) == [], "template tree alone passes boundary lint")
    code, _ = new_pack.create(RUN_ROOT, "sample_game", "smp")
    check(code == 0, "create succeeds")
    target = RUN_ROOT / GT / "sample_game"
    check((target / "tests" / "sample_game_probe.gd").is_file(), "probe file renamed from token")
    check((target / "pack" / "colors" / "smp_color_base.json").is_file(), "color file uses the prefix")
    boundary = json.loads((target / "wf" / "boundary.json").read_text(encoding="utf-8"))
    check(boundary["pack_prefix"] == "smp_", "boundary.json declares smp_")
    info = json.loads((target / "pack" / "mod_info.json").read_text(encoding="utf-8"))
    check("external/mods/sample_game/colors/" in info["properties"]["mod_folder_to_load_data"], "mod_info paths use the name")
    leftovers = [p for p in target.rglob("*") if p.is_file() and "__" in (p.name + p.read_text(encoding="utf-8", errors="ignore")) and "__pycache__" not in p.parts]
    check(not leftovers, "no unreplaced __TOKEN__ placeholders remain")
    check(boundary_lint.lint(RUN_ROOT) == [], "generated tree passes boundary lint")
    check("sample_game" in (RUN_ROOT / GT / "README.md").read_text(encoding="utf-8"), "games index gets a row")
    for args, label in (("sample_game", "smp"), ("other", "smp"), ("_template", "tpl"), ("Bad Name", "bad"), ("fine", "x")):
        code, _ = new_pack.create(RUN_ROOT, args, label)
        check(code == 1, f"refuses name={args!r} prefix={label!r}")
    shutil.rmtree(RUN_ROOT)
    print(f"NEW PACK TESTS PASS: {CHECKS} checks")
    return 0


if __name__ == "__main__":
    sys.exit(main())
