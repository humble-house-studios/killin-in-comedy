"""Every spoken line in the office, read straight from the GDScript data
files: Dale's (data/dale_lines.gd) and the arcade crew's
(data/coworker_lines.gd). Used by tools/record_best.py.
"""
import ast
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def const(src, name):
    """The literal value of `const NAME := ...` in a GDScript file."""
    at = src.find("const %s :=" % name)
    if at < 0:
        return None
    i = src.index(":=", at) + 2
    while src[i] in " \t":
        i += 1
    if src.startswith('"""', i):
        return src[i + 3:src.index('"""', i + 3)]
    depth, j, in_str = 0, i, False
    while True:
        c = src[j]
        if in_str:
            if c == "\\":
                j += 1
            elif c == '"':
                in_str = False
        elif c == '"':
            in_str = True
        elif c in "[{":
            depth += 1
        elif c in "]}":
            depth -= 1
            if depth == 0:
                return ast.literal_eval(src[i:j + 1])
        j += 1


def dale_lines():
    src = open(os.path.join(ROOT, "data", "dale_lines.gd"), encoding="utf8").read()
    lines = []
    for ch in const(src, "CHAPTERS") or []:
        if ch.get("hint"):
            lines.append(ch["hint"])
        for step in ch.get("steps", []):
            for key in ("dale", "line"):
                if step.get(key):
                    lines.append(step[key])
            for c in step.get("choices", []):
                if c.get("reply"):
                    lines.append(c["reply"])
    for name in ("SMALL_TALK", "AFTER", "MIC_LINES"):
        lines += const(src, name) or []
    for group in (const(src, "REACT") or {}).values():
        lines += group
    return lines


def crew_lines():
    path = os.path.join(ROOT, "data", "coworker_lines.gd")
    if not os.path.exists(path):
        return {}
    src = open(path, encoding="utf8").read()
    out = {}
    for who, p in (const(src, "PEOPLE") or {}).items():
        lines = [p.get("gift_reply", ""), p.get("closed", "")]
        lines += p.get("hello", []) + p.get("after", [])
        for prompt in p.get("prompts", []):
            lines.append(prompt.get("line", ""))
            lines += [pair[1] for pair in prompt.get("replies", {}).values() if len(pair) > 1]
        lines += [r.get("line", "") for r in p.get("rewards", [])]
        out[who] = lines
    for cb in const(src, "CALLBACKS") or []:
        out.setdefault(cb["at"], []).append(cb.get("reply", ""))
    return out
