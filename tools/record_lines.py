#!/usr/bin/env python3
"""Records every scripted line in the office with Piper, a free open-source
voice that runs on the build machine: no AI service, no daily limit.

    pip install piper-tts && python3 tools/record_lines.py

Reads data/dale_lines.gd (Dale) and data/coworker_lines.gd (the arcade crew),
writes audio/dale/<md5(line)[:12]>.mp3, which is where the game looks a line
up (scenes/office/dale_voice.gd play_line). Each speaker has their own voice.
Lines already recorded are kept, clips for lines that are gone are deleted.
Voice models download into ~/.cache/piper (the build caches it).
Needs ffmpeg for the mp3s.
"""
import ast
import hashlib
import os
import subprocess
import sys
import tempfile
import urllib.request
import wave

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "audio", "dale")
MODELS = os.path.expanduser("~/.cache/piper")
HF = "https://huggingface.co/rhasspy/piper-voices/resolve/main"
FALLBACK = "en_US-lessac-medium"
# Who sounds like whom (Piper voice name, speed: >1 slower).
VOICES = {
    "dale": ("en_US-norman-medium", 1.05),
    "gloria": ("en_US-amy-medium", 1.0),
    "kev": ("en_US-bryce-medium", 0.92),
    "bernie": ("en_US-kristin-medium", 1.0),
    "theo": ("en_US-ryan-medium", 1.0),
    "ray": ("en_GB-alan-medium", 1.1),
}


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


def model(name):
    os.makedirs(MODELS, exist_ok=True)
    onnx = os.path.join(MODELS, name + ".onnx")
    lang, rest = name.split("-", 1)
    speaker, quality = rest.rsplit("-", 1)
    base = "%s/%s/%s/%s/%s/%s" % (HF, lang.split("_")[0], lang, speaker, quality, name)
    for ext in (".onnx", ".onnx.json"):
        if not os.path.exists(onnx.replace(".onnx", ext)):
            urllib.request.urlretrieve(base + ext, onnx.replace(".onnx", ext))
    return onnx


def main():
    from piper import PiperVoice, SynthesisConfig

    os.makedirs(OUT, exist_ok=True)
    want = {}
    for line in dale_lines():
        want.setdefault(line.strip(), "dale")
    for who, lines in crew_lines().items():
        for line in lines:
            want.setdefault(line.strip(), who)
    want.pop("", None)
    files = {hashlib.md5(t.encode("utf8")).hexdigest()[:12] + ".mp3": (t, who) for t, who in want.items()}
    for f in os.listdir(OUT):
        if f not in files:
            os.remove(os.path.join(OUT, f))

    voices = {}
    made = kept = failed = 0
    for f, (text, who) in sorted(files.items(), key=lambda kv: kv[1][1]):
        out = os.path.join(OUT, f)
        if os.path.exists(out):
            kept += 1
            continue
        name, speed = VOICES.get(who, (FALLBACK, 1.0))
        try:
            if name not in voices:
                try:
                    voices[name] = PiperVoice.load(model(name))
                except Exception as e:
                    print("voice %s unavailable (%s), using %s" % (name, e, FALLBACK))
                    voices[name] = voices.get(FALLBACK) or PiperVoice.load(model(FALLBACK))
            with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
                wav = tmp.name
            with wave.open(wav, "wb") as wf:
                voices[name].synthesize_wav(text, wf, SynthesisConfig(length_scale=speed))
            subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", wav, "-ac", "1",
                            "-codec:a", "libmp3lame", "-q:a", "6", out], check=True)
            os.remove(wav)
            made += 1
        except Exception as e:
            print("failed (%s): %s" % (who, text), e)
            failed += 1
    print("Office lines: %d total, %d recorded, %d kept, %d failed" % (len(files), made, kept, failed))
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
