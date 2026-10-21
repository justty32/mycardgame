#!/usr/bin/env python3
"""Claude Code PreToolUse hook (matcher "Bash"): block Godot launches without --headless.

Reads the hook JSON from stdin and inspects tool_input.command. Exit 2 with a
reason on stderr blocks the call; exit 0 lets it through. See
wf/workflows/common/user.md (desktop boundary): no window may ever open.

Rules (per shell segment, split on ; && || | & newline outside quotes;
$(...), `...` and <(...) bodies are checked as segments of their own):
- Segments whose command is read-only / file-only (cat, rg, grep, git, ls, sed,
  cp, ...) are ignored, so `rg godot` or `cat game/project.godot` pass.
- tools/game.ps1 (legacy GUI wrapper; every mode also runs `--version` without
  --headless) is always blocked.
- Opening project.godot with a file opener (xdg-open, start, Invoke-Item, ...)
  is always blocked (it launches the editor GUI).
- Any other segment that names a Godot executable (godot, godot4, godot-mono,
  Godot_v4*, *godot*.exe, $GODOT-like variables, flatpak org.godotengine.Godot),
  directly or through powershell.exe / cmd.exe / Start-Process / wsl / bash -c,
  must carry --headless before any standalone `--`, or it is blocked; this
  includes --version.
- tools/test_game.py and tools/test-game.ps1 always run the engine with
  --headless, so their --godot-path / -GodotPath value is not treated as a launch.

Self-test: python3 .claude/hooks/block_godot_gui.py --self-test
"""
from __future__ import annotations

import json
import re
import shlex
import sys

READ_ONLY = {
    "cat", "less", "more", "head", "tail", "grep", "egrep", "fgrep", "rg", "ag", "ls", "ll", "dir",
    "find", "fd", "git", "echo", "printf", "wc", "sort", "uniq", "diff", "cmp", "file", "stat",
    "sha1sum", "sha256sum", "sha512sum", "md5sum", "readlink", "realpath", "basename", "dirname",
    "test", "[", "[[", "which", "type", "whereis", "jq", "sed", "tree", "du", "df", "cut", "tr",
    "xxd", "od", "strings", "pwd", "cd", "true", "false", "mkdir", "cp", "mv", "rm", "touch", "ln",
    "chmod", "tee", "ps", "pgrep", "pidof", "tasklist", "tasklist.exe", "export", "unset", "declare", "local", "readonly", "gh", "column", "nl",
}
WRAPPERS = {"sudo", "nohup", "exec", "time", "nice", "setsid", "stdbuf", "timeout", "env", "builtin", "command"}
OPENERS = r"(?:xdg-open|gio\s+open|kde-open\d*|open|start|invoke-item|ii|explorer(?:\.exe)?)"

GODOT_PATTERNS = [
    re.compile(r"org\.godotengine\.godot"),
    re.compile(r"godot_v\d"),
    re.compile(r"godot[^'\"\n;|&<>]*?\.exe\b"),
    re.compile(r"(?:^|[\s'\"(=/\\&`@,\[])(?:godot4?(?:[-_]mono)?|godot4-mono)"
               r"(?:\.exe|\.x86_64|\.x86_32|\.arm64|\.64)?(?=$|[\s'\"`;|&)\],])"),
    re.compile(r"\$\{?(?:env:)?\w*godot\w*"),
]
GAME_PS1 = re.compile(r"(?<![\w-])game\.ps1\b")
TEST_RUNNER = re.compile(r"test_game\.py|test-game\.ps1")
RUNNER_PATH_ARG = re.compile(r"(?:--godot-path|-godotpath)(?:[=:]|\s+)(?:'[^']*'|\"[^\"]*\"|\S+)")
OPEN_PROJECT = re.compile(rf"(?:^|[\s'\"&;(]){OPENERS}\b[^\n]*project\.godot")
HEADLESS = re.compile(r"(?<![\w-])--headless(?![\w-])")
DOUBLE_DASH = re.compile(r"(?:(?<=\s)|^)--(?=\s|$)")
HEREDOC = re.compile(r"<<-?\s*(['\"]?)([A-Za-z_][\w]*)\1")


def extract_substitutions(text: str) -> tuple[str, list[str]]:
    """Pull $( ), <( ), >( ) and backtick bodies out as extra segments."""
    subs: list[str] = []
    out: list[str] = []
    i, n, quote = 0, len(text), None
    while i < n:
        c = text[i]
        if quote == "'":
            out.append(c)
            if c == "'":
                quote = None
            i += 1
            continue
        if c == "\\" and i + 1 < n:
            out.append(text[i:i + 2])
            i += 2
            continue
        if c == "'" and quote is None:
            quote = "'"
            out.append(c)
            i += 1
            continue
        if c == '"':
            quote = None if quote == '"' else '"'
            out.append(c)
            i += 1
            continue
        if c in "$<>" and i + 1 < n and text[i + 1] == "(" and not (c == "$" and text[i + 2:i + 3] == "("):
            depth, j = 1, i + 2
            while j < n and depth:
                depth += {"(": 1, ")": -1}.get(text[j], 0)
                j += 1
            subs.append(text[i + 2:j - 1])
            out.append(" ")
            i = j
            continue
        if c == "`":
            j = text.find("`", i + 1)
            j = n if j < 0 else j
            subs.append(text[i + 1:j])
            out.append(" ")
            i = j + 1
            continue
        out.append(c)
        i += 1
    return "".join(out), subs


def split_segments(text: str) -> list[str]:
    """Split on shell separators outside quotes; heredoc bodies stay with their command."""
    segments: list[str] = []
    buf: list[str] = []
    i, n, quote = 0, len(text), None
    pending_heredocs: list[str] = []
    while i < n:
        c = text[i]
        if quote:
            buf.append(c)
            if c == "\\" and quote == '"' and i + 1 < n:
                buf.append(text[i + 1])
                i += 2
                continue
            if c == quote:
                quote = None
            i += 1
            continue
        if c == "\\" and i + 1 < n:
            buf.append(text[i:i + 2])
            i += 2
            continue
        if c in "'\"":
            quote = c
            buf.append(c)
            i += 1
            continue
        if c == "<" and text.startswith("<<", i) and not text.startswith("<<<", i):
            m = HEREDOC.match(text, i)
            if m:
                pending_heredocs.append(m.group(2))
                buf.append(m.group(0))
                i = m.end()
                continue
        if c == "\n" and pending_heredocs:
            # Heredoc body belongs to the current command.
            body_lines = []
            j = i + 1
            while pending_heredocs and j <= n:
                end = text.find("\n", j)
                end = n if end < 0 else end
                line = text[j:end]
                if line.strip() == pending_heredocs[0]:
                    pending_heredocs.pop(0)
                else:
                    body_lines.append(line)
                j = end + 1
            buf.append("\n<<BODY>>\n" + "\n".join(body_lines))
            segments.append("".join(buf))
            buf = []
            i = j
            continue
        if c in ";|&\n()":
            segments.append("".join(buf))
            buf = []
            i += 1
            continue
        buf.append(c)
        i += 1
    segments.append("".join(buf))
    return [s for s in segments if s.strip()]


def command_words(segment: str) -> list[str]:
    head = segment.split("\n<<BODY>>\n", 1)[0]
    try:
        words = shlex.split(head, posix=True)
    except ValueError:
        words = head.split()
    while words:
        w = words[0]
        base = re.split(r"[/\\]", w)[-1].lower()
        if re.match(r"^[A-Za-z_]\w*=", w):
            words = words[1:]
        elif base == "command" and len(words) > 1 and words[1] in ("-v", "-V"):
            return ["which"]
        elif base in WRAPPERS:
            words = words[1:]
            while words and (words[0].startswith("-") or re.match(r"^[\d.]+[smhd]?$", words[0])):
                words = words[1:]
        else:
            break
    return words


def check_segment(segment: str) -> str | None:
    words = command_words(segment)
    if not words:
        return None
    first = re.split(r"[/\\]", words[0])[-1].lower()
    head, _, body = segment.partition("\n<<BODY>>\n")
    if first in READ_ONLY:
        if first in ("find", "fd") and re.search(r"\s-(?:exec|execdir|ok|okdir|x|X)\b|--exec", head):
            pass
        elif first == "sed" and re.search(r"(?:^|[;/\s'])e(?:\s|'|$)", head) and "godot" in head.lower():
            pass
        else:
            return None
    low = segment.lower()
    if GAME_PS1.search(low):
        return ("tools/game.ps1 is a legacy GUI launcher (Run opens a window; every mode runs "
                "`--version` without --headless). Use python3 tools/test_game.py instead.")
    if OPEN_PROJECT.search(low):
        return "Opening project.godot with a file opener launches the Godot editor GUI."
    if TEST_RUNNER.search(low):
        low = RUNNER_PATH_ARG.sub(" ", low)
    for pattern in GODOT_PATTERNS:
        m = pattern.search(low)
        if not m:
            continue
        rest = low[m.start():]
        dd = DOUBLE_DASH.search(rest)
        scope = low[:m.start()] + (rest[:dd.start()] if dd else rest)
        if HEADLESS.search(scope):
            return None
        return (f"Godot launch without --headless (matched {m.group(0).strip()!r}). Add --headless "
                "(also for --version) or use python3 tools/test_game.py.")
    return None


def check_command(command: str) -> str | None:
    queue = [command]
    seen = 0
    while queue and seen < 200:
        text = queue.pop(0)
        seen += 1
        stripped, subs = extract_substitutions(text)
        queue.extend(subs)
        for segment in split_segments(stripped):
            reason = check_segment(segment)
            if reason:
                return reason
    return None


SHOULD_BLOCK = [
    "godot --path game",
    "godot-mono --version",
    "godot4 --path game --editor",
    "/usr/bin/godot-mono --path game",
    "GODOT=x godot-mono --path game",
    "timeout 30 godot-mono --path game --script t.gd",
    "nohup godot --path game &",
    "cd game && godot",
    "ls; godot-mono --path game",
    "godot-mono --headless --version; godot-mono --path game",
    "godot --path game -- --headless",
    "'.tools/godot-4.7/Godot_v4.7.2-stable_win64_console.exe' --path game",
    "./Godot_v4.7.2-stable_linux.x86_64 --path game",
    "powershell.exe -Command \"& '.tools/godot-4.7/Godot_v4.7.2-stable_win64.exe' --path game\"",
    "pwsh -c \"Start-Process -FilePath 'C:/Tools/Godot/Godot.exe' -ArgumentList '--path','game'\"",
    "cmd.exe /c \"C:\\Godot\\godot.exe --path game\"",
    "cmd.exe /c start \"\" \"C:\\Program Files\\Godot\\Godot_v4.7.2-stable_win64.exe\"",
    "wsl godot --path game",
    "bash -c 'godot-mono --path game'",
    "sh -c \"godot4 --version\"",
    "$GODOT --path game",
    "\"${GODOT_BIN}\" --version",
    "pwsh -c '& $env:GODOT --path game'",
    "flatpak run org.godotengine.Godot --path game",
    "echo $(godot-mono --version)",
    "echo `godot --version`",
    "pwsh -File tools/game.ps1",
    "powershell.exe -ExecutionPolicy Bypass -File ./tools/game.ps1 -Mode Smoke",
    "./tools/game.ps1 -Mode Import",
    "pwsh tools/game.ps1 -Mode Run -GodotPath x --headless",
    "xdg-open game/project.godot",
    "cmd.exe /c start game\\project.godot",
    "pwsh -c 'Invoke-Item game/project.godot'",
    "find . -name godot -exec godot --path game \\;",
    "python3 -c \"import subprocess; subprocess.run(['godot', '--path', 'game'])\"",
    "python3 - <<'EOF'\nimport subprocess\nsubprocess.run(['godot-mono', '--version'])\nEOF",
    "bash <<EOF\ngodot --path game\nEOF",
    "env DISPLAY=:0 godot --path game",
    "sudo -E godot4-mono --path game",
    "x=$(godot --version)",
    "python3 tools/test_game.py --suite Smoke; godot --path game",
    "pwsh -c \"./tools/test-game.ps1 -Suite Smoke; & $GodotPath --path game\"",
]
SHOULD_ALLOW = [
    "godot --headless --path game --script t.gd",
    "godot-mono --headless --version",
    "godot-mono --headless --path game/ --editor --import",
    "'.tools/godot-4.7/Godot_v4.7.2-stable_win64_console.exe' --headless --version",
    "powershell.exe -Command \"& 'C:/Godot/Godot_v4.7.2-stable_win64_console.exe' --headless --version\"",
    "godot --headless --path game -- --force-failure",
    "rg godot",
    "rg -n 'godot-mono --path' wf/",
    "grep -rn godot tools/",
    "ls .tools/",
    "ls .tools/godot-4.7/",
    "cat game/project.godot",
    "cat project.godot",
    "sed -n '1,20p' game/project.godot",
    "head -5 game/project.godot | grep config",
    "test -f game/project.godot && echo ok",
    "command -v git godot godot-mono",
    "which godot-mono",
    "git log --oneline -- game/project.godot",
    "git commit -m \"docs: godot --path game 要加 --headless\"",
    "git commit -F - <<'EOF'\ngodot 不帶 headless 會被擋\ngodot-mono --path game\nEOF",
    "cat > /tmp/x.md <<'EOF'\ngodot --path game\nEOF",
    "echo 'godot --path game'",
    "git commit -m \"$(cat <<'EOF'\nfix: godot --path game 改 headless\nEOF\n)\"",
    "python3 tools/test_game.py --suite Smoke",
    "python3 tools/test_game.py --suite Smoke --godot-path /usr/bin/godot-mono",
    "python3 tools/test_game.py --suite All --godot-path=\"$GODOT\"",
    "pwsh -File ./tools/test-game.ps1 -Suite Smoke -GodotPath 'C:/path/to/Godot_v4.7.2-stable_win64_console.exe'",
    "powershell.exe -NoProfile -Command \"./tools/test-game.ps1 -Suite All -GodotPath '.tools/godot-4.7-mono/Godot_v4.7.2-stable_mono_win64/Godot_v4.7.2-stable_mono_win64_console.exe'\"",
    "bash wf/tools/wf-lint.sh --strict .",
    "python3 tools/boundary_lint.py",
    "cp tools/game.ps1 /tmp/",
    "cat tools/game.ps1",
    "rg -n game.ps1 wf",
    "git add tools/game.ps1",
    "sha512sum .tools/Godot_v4.7.2-stable_win64.exe.zip",
    "ls -la .tools/godot-4.7/Godot_v4.7.2-stable_win64_console.exe",
    "find .tools -name '*godot*'",
    "ps aux | grep -i godot",
    "pgrep -a godot | head",
    "tasklist.exe | grep -i godot",
]


def self_test() -> int:
    failures = 0
    for cmd in SHOULD_BLOCK:
        if not check_command(cmd):
            failures += 1
            print(f"FAIL (should block): {cmd!r}")
    for cmd in SHOULD_ALLOW:
        reason = check_command(cmd)
        if reason:
            failures += 1
            print(f"FAIL (should allow): {cmd!r} -> {reason}")
    total = len(SHOULD_BLOCK) + len(SHOULD_ALLOW)
    print(f"self-test: {total - failures}/{total} passed ({len(SHOULD_BLOCK)} block, {len(SHOULD_ALLOW)} allow)")
    return 1 if failures else 0


def main() -> int:
    if "--self-test" in sys.argv[1:]:
        return self_test()
    try:
        payload = json.load(sys.stdin)
    except (ValueError, OSError):
        return 0
    if not isinstance(payload, dict) or payload.get("tool_name", "Bash") != "Bash":
        return 0
    command = (payload.get("tool_input") or {}).get("command")
    if not isinstance(command, str):
        return 0
    reason = check_command(command)
    if reason:
        print(f"Blocked by .claude/hooks/block_godot_gui.py: {reason} "
              "(desktop boundary: wf/workflows/common/user.md)", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
