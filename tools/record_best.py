#!/usr/bin/env python3
"""Records the office's scripted lines in the best voice we have: Groq's
Orpheus, through Dale's voice server. Dale first, then the arcade crew, each
in their own voice. Groq's free voice allowance is small (~3,600 tokens a
day, shared with Dale's live replies), so a run records at most MAX lines and
the rest keep their Piper placeholder (tools/record_lines.py) until a later
run. Lines are only ever saved in this voice, never a lesser fallback.

    python3 tools/record_best.py https://dale-voice.<you>.workers.dev [MAX]

Writes audio/best/<md5(line)[:12]>.mp3; the build lays these over the Piper
clips of the same name. Needs ffmpeg.
"""
import base64
import hashlib
import json
import os
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from record_lines import ROOT, crew_lines, dale_lines  # noqa: E402

OUT = os.path.join(ROOT, "audio", "best")
# Groq Orpheus voices per character.
VOICES = {"dale": "troy", "gloria": "hannah", "kev": "austin", "bernie": "diana", "theo": "daniel", "ray": "autumn"}
ORDER = ["dale", "gloria", "kev", "bernie", "theo", "ray"]
# Groq also limits requests per minute.
PAUSE = 7.0


def wanted():
    lines = {"dale": dale_lines()}
    lines.update(crew_lines())
    out = {}
    for who in ORDER + [w for w in lines if w not in ORDER]:
        for t in lines.get(who, []):
            t = t.strip()
            f = hashlib.md5(t.encode("utf8")).hexdigest()[:12] + ".mp3"
            if t and f not in out:
                out[f] = (t, who)
    return out


def main():
    url = sys.argv[1].rstrip("/") + "/say"
    limit = int(sys.argv[2]) if len(sys.argv) > 2 else 35
    os.makedirs(OUT, exist_ok=True)
    want = wanted()
    for f in os.listdir(OUT):
        if f not in want:
            os.remove(os.path.join(OUT, f))
    have = sum(1 for f in want if os.path.exists(os.path.join(OUT, f)))
    made, why = 0, ""
    for f, (text, who) in want.items():
        if os.path.exists(os.path.join(OUT, f)):
            continue
        if made >= limit:
            why = "run limit"
            break
        body = json.dumps({"text": text, "engine": "groq", "voice": VOICES.get(who, "troy")}).encode()
        req = urllib.request.Request(url, body, {"Content-Type": "application/json",
                                                # Cloudflare turns away Python's default user agent.
                                                "User-Agent": "humble-house-build/1.0"})
        try:
            d = json.load(urllib.request.urlopen(req, timeout=90))
        except (urllib.error.URLError, ValueError) as e:
            print("failed:", who, text, e)
            continue
        audio = d.get("audio", "")
        if len(audio) < 200:
            info = json.dumps(d.get("models", {}))
            if "429" in info:
                why = "Groq's daily voice allowance used up"
                break
            print("no audio:", who, text, info[:300])
            continue
        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
            tmp.write(base64.b64decode(audio))
        subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", tmp.name, "-ac", "1",
                        "-codec:a", "libmp3lame", "-q:a", "4", os.path.join(OUT, f)], check=True)
        os.remove(tmp.name)
        made += 1
        time.sleep(PAUSE)
    left = len(want) - have - made
    print("Groq voice lines: %d total, %d recorded now, %d done before, %d still in Piper%s"
          % (len(want), made, have, left, " (%s)" % why if why else ""))


if __name__ == "__main__":
    main()
