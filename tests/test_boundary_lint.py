#!/usr/bin/env python3
"""Synthetic checks for tools/boundary_lint.py (rules R1-R4). No Godot, no Git needed.

Usage: python3 tests/test_boundary_lint.py
Exit 0 and prints "BOUNDARY LINT TESTS PASS: N checks"; exit 1 on the first failure.
Each case builds a throwaway tree under artifacts/boundary-lint-tests/<uuid>/.
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

# Synthetic trees spell the game-tree folder via GT so this framework file passes R1 itself.
GT = "game" + "s"
RUN_ROOT = PROJECT_ROOT / "artifacts" / "boundary-lint-tests" / uuid.uuid4().hex
CHECKS = 0


def check(condition: bool, message: str) -> None:
    global CHECKS
    if not condition:
        print(f"ASSERT FAIL: {message}\nEvidence: {RUN_ROOT}")
        sys.exit(1)
    CHECKS += 1
    print(f"PASS: {message}")


def write(root: Path, rel: str, text: str) -> None:
    rel, text = rel.replace("@G/", GT + "/"), text.replace("@G/", GT + "/")
    path = root / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def clean_tree(name: str) -> Path:
    root = RUN_ROOT / name
    write(root, "AGENTS.md", "framework router; games live in [games](@G/README.md)\n")
    write(root, "wf/a.md", "spec goes to `@G/<game>/design/specs/`\n")
    write(root, "game/x.gd", "var url = 'https://example.com/DesirePathGames/x'\n")
    write(root, "@G/README.md", "| [alpha](alpha/README.md) | Alpha Saga |\n| [beta](beta/README.md) | beta |\n")
    write(root, "@G/alpha/README.md", "Alpha Saga uses [framework](../../wf/a.md) and its own `@G/alpha/pack`.\n")
    write(root, "@G/alpha/wf/forbidden-terms.txt", "# reserved\nAlpha Saga\n秘詞\nalp_\n")
    write(root, "@G/alpha/wf/boundary.json", json.dumps({"pack_prefix": "alp_", "allowed_unprefixed_ids": ["card_shared"]}))
    write(root, "@G/alpha/pack/mod_info.json", json.dumps({"properties": {"object_id": "mod_data_alpha"}}))
    write(root, "@G/alpha/pack/cards/a.json", json.dumps({"properties": {"object_id": "alp_card"}}))
    write(root, "@G/alpha/pack/cards/patch.json", json.dumps({"properties": {"object_id": "card_shared"}}))
    write(root, "@G/beta/README.md", "beta tree\n")
    return root


def rules(root: Path) -> list[str]:
    return [v.split(" ", 1)[0] for v in boundary_lint.lint(root)]


def main() -> None:
    RUN_ROOT.mkdir(parents=True, exist_ok=True)
    check(boundary_lint.lint(clean_tree("clean")) == [], "clean tree: placeholders, root routing, games index and own-tree terms pass")
    check(boundary_lint.main(["--root", str(RUN_ROOT / "clean")]) == 0, "CLI exits 0 on a clean tree")

    cases = {
        "r1_concrete_path": ("wf/b.md", "see @G/alpha/design\n", ["R1"]),
        "r1_link": ("analysis/c.md", "[x](../@G/README.md)\n", ["R1"]),
        "r2_text": ("@G/beta/notes.md", "copy from @G/alpha/pack\n", ["R2"]),
        "r2_link": ("@G/beta/d.md", "[x](../alpha/README.md)\n", ["R2"]),
        "r3_framework_term": ("tools/t.py", "# ALPHA SAGA mention\n", ["R3"]),
        "r1_examples_path": ("examples/demo/README.md", "see @G/alpha/design\n", ["R1"]),
        "r3_examples_term": ("examples/demo/pack/cards.json", '{"name": "Alpha Saga"}\n', ["R3"]),
        "r3_other_game_term": ("@G/beta/e.md", "uses 秘詞 here\n", ["R3"]),
        "r3_root_file": ("README.md", "card alp_card\n", ["R3"]),
        "r4_prefix": ("@G/alpha/pack/enemies/x.json", json.dumps({"properties": {"object_id": "enemy_plain"}}), ["R4"]),
    }
    for name, (rel, text, expected) in cases.items():
        root = clean_tree(name)
        write(root, rel, text)
        got = rules(root)
        check(sorted(set(got)) == sorted(set(expected)) and got, f"{name}: injected violation reported as {expected} (got {got})")
        check(boundary_lint.main(["--root", str(root)]) == 1, f"{name}: CLI exits 1")

    root = clean_tree("r4_missing_boundary")
    (root / GT / "alpha/wf/boundary.json").unlink()
    check(rules(root) == ["R4"], "a game with pack/ but no boundary.json is reported")
    shutil.rmtree(RUN_ROOT, ignore_errors=True)
    print(f"BOUNDARY LINT TESTS PASS: {CHECKS} checks")


if __name__ == "__main__":
    main()
