#!/usr/bin/env python3
"""Deny a code write whose added comments breach Paddle comment discipline.

The org plugin's enforce-comment-style.sh only nudges, runs PostToolUse so the write
has already landed, and self-silences after one hit per file. An agent declined it on
DASH-2157 and kept 270 lines of comment prose. This blocks instead.
"""
import json
import re
import sys

LINE_COMMENT = {".ts", ".tsx", ".js", ".jsx", ".mts", ".cts", ".mjs", ".cjs", ".go", ".php"}
MAX_INLINE_RUN = 2

BANNED = [
    (re.compile(r"[─-╿]"), "box-drawing divider"),
    (re.compile(r"\b[A-Z]{2,5}-\d{2,6}\b"), "bare ticket reference"),
    (re.compile(r"(?<![\w#])#\d{3,6}\b"), "bare PR reference"),
    (re.compile(r"(?=[0-9a-f]*\d)(?=[0-9a-f]*[a-f])\b[0-9a-f]{7,40}\b"), "commit SHA"),
    (re.compile(r"\*\*[^*\n]+\*\*"), "bold shouting"),
]


def added_text(tool, ti):
    if tool == "Write":
        return ti.get("content") or ""
    if tool == "Edit":
        return ti.get("new_string") or ""
    if tool == "MultiEdit":
        edits = ti.get("edits")
        if not isinstance(edits, list):
            return ""
        return "\n".join(e.get("new_string") or "" for e in edits if isinstance(e, dict))
    return ""


def comment_spans(lines):
    """Yield (index, text, kind) for every comment line. kind is 'inline' or 'block'."""
    in_block = False
    for i, raw in enumerate(lines):
        s = raw.strip()
        if in_block:
            yield i, s, "block"
            if "*/" in s:
                in_block = False
            continue
        if s.startswith("/*"):
            yield i, s, "block"
            if "*/" not in s:
                in_block = True
            continue
        if s.startswith("//") or (s.startswith("#") and not s.startswith("#!")):
            yield i, s, "inline"


def find_violations(text):
    lines = text.split("\n")
    spans = list(comment_spans(lines))
    out = []

    run = []
    for i, s, kind in spans + [(-1, "", "sentinel")]:
        if kind == "inline" and (not run or i == run[-1][0] + 1):
            run.append((i, s))
            continue
        if len(run) > MAX_INLINE_RUN:
            out.append(
                "a %d-line inline comment run (max %d): %s"
                % (len(run), MAX_INLINE_RUN, run[0][1][:70])
            )
        run = [(i, s)] if kind == "inline" else []

    for _, s, _ in spans:
        for pat, name in BANNED:
            if pat.search(s):
                out.append("%s in a comment: %s" % (name, s[:70]))
                break
    return out


def main():
    try:
        payload = json.load(sys.stdin)
    except Exception:
        return 0
    if not isinstance(payload, dict):
        return 0
    tool = payload.get("tool_name")
    ti = payload.get("tool_input")
    if tool not in ("Write", "Edit", "MultiEdit") or not isinstance(ti, dict):
        return 0
    path = ti.get("file_path") or ""
    if not any(path.endswith(e) for e in LINE_COMMENT):
        return 0

    violations = find_violations(added_text(tool, ti))
    if not violations:
        return 0

    reason = (
        "Comment discipline (Paddle): this write is denied. Fix the comments, then retry.\n\n"
        + "\n".join("  - " + v for v in dict.fromkeys(violations))
        + "\n\nComments explain WHY, not WHAT. One line where you can, two at most. "
        "Default to no comment. Never put ticket or PR references, commit SHAs, "
        "box-drawing dividers, bold shouting, counts that rot, or rejected-alternative "
        "essays in code — they belong in the commit body or the PR. "
        "Do not restate the adjacent line. Prefer a better name over a comment.\n"
        "This hook blocks and does not self-silence. Shorten the prose; do not retry unchanged."
    )
    json.dump(
        {
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "deny",
                "permissionDecisionReason": reason,
            }
        },
        sys.stdout,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
