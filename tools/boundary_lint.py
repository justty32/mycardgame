#!/usr/bin/env python3
"""Framework / game-tree boundary lint.

Layout: the repository root is a theme-neutral framework (FRAMEWORK_DIRS plus the
root-level router files); each game lives in its own tree under games/<game>/.

Rules
  R1  framework directories never name a concrete games/<x> path
      (the placeholder form games/<game>/ is allowed).
  R2  a game tree never references another game tree (games/<other>/ or a
      relative link that resolves into it).
  R3  terms listed in games/<G>/wf/forbidden-terms.txt appear only inside
      games/<G>/ (framework dirs, root files and other game trees are scanned;
      the shared index files directly under games/ are exempt).
  R4  every object_id in games/<G>/<pack_dir>/**/*.json (except mod_info.json)
      starts with the pack_prefix from games/<G>/wf/boundary.json, unless listed
      in its allowed_unprefixed_ids.

Usage: python3 tools/boundary_lint.py [--root DIR]
Exit 0 = no violations, 1 = violations, 2 = usage / environment error.
Standard library only.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path

# examples/ holds theme-neutral framework demo packs, so it obeys the same rules as the framework.
FRAMEWORK_DIRS = ("game", "tools", "tests", "analysis", "wf", "examples", ".claude")
GAMES_DIR = "games"
TERMS_FILE = Path("wf") / "forbidden-terms.txt"
BOUNDARY_FILE = Path("wf") / "boundary.json"
MAX_TEXT_BYTES = 4 * 1024 * 1024
# games/ followed by a concrete name; "games/<game>/" style placeholders are allowed.
CONCRETE_GAMES_PATH_RE = re.compile(r"(?<![A-Za-z0-9_.-])games/(?=[A-Za-z0-9_.-])")
GAMES_NAME_RE = re.compile(r"(?<![A-Za-z0-9_.-])games/([A-Za-z0-9_.-]+)")
MD_LINK_RE = re.compile(r"\]\(([^)\s]+)\)")


def list_files(root: Path) -> list[str]:
    """Tracked plus untracked-but-not-ignored files, as POSIX paths relative to root."""
    completed = None
    try:
        top = subprocess.run(["git", "-C", str(root), "rev-parse", "--show-toplevel"], capture_output=True, text=True,
                             check=False, stdin=subprocess.DEVNULL)
        # Only trust Git when root is the work-tree top; a subfolder of another repo may be ignored there.
        if top.returncode == 0 and Path(top.stdout.strip()).resolve() == root.resolve():
            completed = subprocess.run(["git", "-C", str(root), "ls-files", "-z", "--cached", "--others", "--exclude-standard"],
                                       capture_output=True, check=False, stdin=subprocess.DEVNULL)
    except OSError:
        completed = None
    if completed is not None and completed.returncode == 0:
        names = [n for n in completed.stdout.decode("utf-8", "replace").split("\0") if n]
        return sorted({n for n in names if (root / n).is_file() and not (root / n).is_symlink()})
    out = []
    for directory, dirs, files in os.walk(root):
        dirs[:] = [d for d in dirs if d not in (".git", ".godot", "artifacts", ".tools", "__pycache__")]
        for name in files:
            full = Path(directory) / name
            if not full.is_symlink():
                out.append(full.relative_to(root).as_posix())
    return sorted(out)


def read_text(path: Path) -> str | None:
    try:
        if path.stat().st_size > MAX_TEXT_BYTES:
            return None
        data = path.read_bytes()
    except OSError:
        return None
    if b"\0" in data:
        return None
    return data.decode("utf-8", "replace")


def load_terms(path: Path) -> list[str]:
    terms = []
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line and not line.startswith("#"):
            terms.append(line)
    return terms


def term_hits(text: str, terms: list[str]) -> list[tuple[int, str]]:
    hits = []
    lowered = text.lower()
    for term in terms:
        haystack, needle = (lowered, term.lower()) if term.isascii() else (text, term)
        start = haystack.find(needle)
        while start >= 0:
            hits.append((text.count("\n", 0, start) + 1, term))
            start = haystack.find(needle, start + len(needle))
    return hits


def line_of(text: str, offset: int) -> int:
    return text.count("\n", 0, offset) + 1


def classify(rel: str) -> tuple[str, str | None]:
    parts = rel.split("/")
    if parts[0] in FRAMEWORK_DIRS:
        return "framework", None
    if parts[0] == GAMES_DIR:
        return ("game", parts[1]) if len(parts) > 2 else ("games-index", None)
    if len(parts) == 1:
        return "root", None
    return "other", None


def lint(root: Path) -> list[str]:
    root = root.resolve()
    files = list_files(root)
    games_root = root / GAMES_DIR
    games = sorted(p.name for p in games_root.iterdir() if p.is_dir()) if games_root.is_dir() else []
    violations: list[str] = []
    terms_by_game = {}
    for game in games:
        terms_path = games_root / game / TERMS_FILE
        if terms_path.is_file():
            terms_by_game[game] = load_terms(terms_path)

    for rel in files:
        kind, owner = classify(rel)
        if kind in ("other", "games-index"):
            continue
        text = read_text(root / rel)
        if text is None:
            continue
        if kind == "framework":
            for match in CONCRETE_GAMES_PATH_RE.finditer(text):
                violations.append(f"R1 {rel}:{line_of(text, match.start())}: framework file names a concrete games/ path "
                                  "(use the games/<game>/ placeholder; routing belongs in root files)")
        if kind == "game":
            for match in GAMES_NAME_RE.finditer(text):
                name = match.group(1)
                if name != owner and name in games:
                    violations.append(f"R2 {rel}:{line_of(text, match.start())}: games/{owner} references games/{name}")
            if rel.endswith(".md"):
                for match in MD_LINK_RE.finditer(text):
                    target = match.group(1).split("#", 1)[0]
                    if not target or re.match(r"^[a-z]+:", target):
                        continue
                    resolved = os.path.normpath(os.path.join(os.path.dirname(rel), target)).replace(os.sep, "/")
                    parts = resolved.split("/")
                    if len(parts) > 2 and parts[0] == GAMES_DIR and parts[1] != owner:
                        violations.append(f"R2 {rel}:{line_of(text, match.start())}: link into games/{parts[1]}: {target}")
        for game, terms in terms_by_game.items():
            if kind == "game" and owner == game:
                continue
            for line, term in term_hits(text, terms):
                violations.append(f"R3 {rel}:{line}: term '{term}' is reserved to games/{game}/")

    for game in games:
        boundary_path = games_root / game / BOUNDARY_FILE
        if not boundary_path.is_file():
            if (games_root / game / "pack").is_dir():
                violations.append(f"R4 {GAMES_DIR}/{game}: has pack/ but no {BOUNDARY_FILE.as_posix()} declaring pack_prefix")
            continue
        try:
            boundary = json.loads(boundary_path.read_text(encoding="utf-8"))
            prefix = boundary["pack_prefix"]
            pack_dir = games_root / game / boundary.get("pack_dir", "pack")
            allowed = set(boundary.get("allowed_unprefixed_ids", []))
        except (ValueError, KeyError, TypeError) as error:
            violations.append(f"R4 {GAMES_DIR}/{game}/{BOUNDARY_FILE.as_posix()}: unreadable ({error})")
            continue
        if not prefix:
            violations.append(f"R4 {GAMES_DIR}/{game}/{BOUNDARY_FILE.as_posix()}: empty pack_prefix")
            continue
        for path in sorted(pack_dir.rglob("*.json")) if pack_dir.is_dir() else []:
            if path.name == "mod_info.json" or path.is_symlink():
                continue
            rel = path.relative_to(root).as_posix()
            try:
                data = json.loads(re.sub(r",(\s*[}\]])", r"\1", path.read_text(encoding="utf-8")))
            except ValueError as error:
                violations.append(f"R4 {rel}: not valid JSON ({error})")
                continue
            props = data.get("properties") if isinstance(data, dict) else None
            object_id = (props or {}).get("object_id", data.get("object_id") if isinstance(data, dict) else None)
            if object_id and not str(object_id).startswith(prefix) and object_id not in allowed:
                violations.append(f"R4 {rel}: object_id '{object_id}' lacks pack prefix '{prefix}' "
                                  f"(list deliberate framework patches in allowed_unprefixed_ids)")
    return violations


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="boundary_lint.py", description="Framework / game-tree boundary lint (R1-R4).")
    parser.add_argument("--root", help="Repository root (default: parent of tools/).")
    args = parser.parse_args(argv)
    root = Path(args.root) if args.root else Path(__file__).resolve().parent.parent
    if not root.is_dir():
        print(f"ERROR: --root is not a directory: {root}", file=sys.stderr)
        return 2
    violations = lint(root)
    for violation in violations:
        print(violation)
    print(f"BOUNDARY violations={len(violations)}")
    return 1 if violations else 0


if __name__ == "__main__":
    sys.exit(main())
