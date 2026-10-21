#!/usr/bin/env python3
"""Synthetic checks for wf-lint.sh: git-ignored paths skipped, exit codes, strict mode.

Usage: python3 wf/tools/test_wf_lint.py   (needs bash + git; no Godot)
Exit 0 and prints "WF LINT TESTS PASS: N checks"; exit 1 on the first failure.
"""
from __future__ import annotations

import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

LINT = Path(__file__).resolve().parent / "wf-lint.sh"
CHECKS = 0


def check(condition: bool, message: str, detail: str = "") -> None:
    global CHECKS
    if not condition:
        print(f"ASSERT FAIL: {message}\n{detail}")
        sys.exit(1)
    CHECKS += 1
    print(f"PASS: {message}")


def write(root: Path, rel: str, text: str) -> None:
    path = root / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def lint(root: Path, *flags: str) -> tuple[int, str]:
    done = subprocess.run(["bash", str(LINT), *flags, "."], cwd=root, capture_output=True, text=True,
                          encoding="utf-8", stdin=subprocess.DEVNULL)
    return done.returncode, done.stdout + done.stderr


def build(root: Path, git: bool) -> None:
    write(root, "README.md", "[ok](wf/a.md#title)\n")
    write(root, "wf/a.md", "# Title\n")
    write(root, "wf/workflows/inbox/w.md", "[ok](../../a.md)\n")
    write(root, "wf/inbox/mail.md", "[bad](missing-mail.md)\n")
    write(root, "wf/archive/old.md", "[bad](missing-archive.md)\n")
    # ignored by .gitignore: must be skipped in git mode, scanned in plain-directory mode
    write(root, ".gitignore", "/artifacts/\n")
    write(root, "artifacts/snap/workflows/big.md", "[bad](missing-artifact.md)\n" + "x" * 9000)
    write(root, "artifacts/t.json", '{"contract": "wf-table/1", "columns": ["p_path"], "rows": [{"p_path": "nope.md"}]}')
    if git:
        subprocess.run(["git", "init", "-q", str(root)], check=True)


def main() -> None:
    base = Path(tempfile.mkdtemp(prefix="wf-lint-test-"))
    try:
        repo = base / "repo"
        build(repo, git=True)
        code, out = lint(repo, "--strict")
        check(code == 0, "git repo: ignored artifacts/, archive/ and mail inbox/ are not scanned; strict exit 0", out)
        check("missing-artifact" not in out and "nope.md" not in out, "git repo: no findings from ignored paths", out)
        write(repo, "wf/new.md", "[bad](missing-untracked.md)\n")
        write(repo, "wf/workflows/inbox/w.md", "[bad](missing-workflow-inbox.md)\n")
        code, out = lint(repo)
        check(code == 1 and "missing-untracked.md" in out and "missing-workflow-inbox.md" in out,
              "git repo: untracked md and workflows/inbox/ are scanned; broken -> exit 1", out)
        (repo / "wf/new.md").unlink()
        write(repo, "wf/workflows/inbox/w.md", "fine\n")
        write(repo, "wf/workflows/big.md", "y" * 9000)
        code, out = lint(repo)
        check(code == 0 and "OVERSIZE wf/workflows/big.md" in out, "non-strict: oversize alone is a warning (exit 0)", out)
        code, out = lint(repo, "--strict")
        check(code == 1 and "oversize=1" in out, "strict: oversize > 0 -> exit 1", out)

        plain = base / "plain"
        build(plain, git=False)
        code, out = lint(plain, "--strict")
        check(code == 1 and "missing-artifact.md" in out and "nope.md" in out,
              "plain directory: falls back to find and scans everything not pruned", out)
        check("missing-archive" not in out and "missing-mail" not in out, "plain directory: archive/ and mail inbox/ pruned", out)
    finally:
        shutil.rmtree(base, ignore_errors=True)
    print(f"WF LINT TESTS PASS: {CHECKS} checks")


if __name__ == "__main__":
    main()
