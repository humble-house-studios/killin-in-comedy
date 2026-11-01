#!/usr/bin/env python3
"""Records every scripted line in the office through Dale's voice server,
in the best voice for each speaker:

  - Dale: Groq's Orpheus "troy" (Samuel's pick). Groq's free allowance is
    small and shared with Dale's live replies, so a run records at most
    GROQ_MAX of his lines; until a line has its Groq take, Gemini stands in.
  - The arcade crew: Gemini, each in their own voice.

    python3 tools/record_best.py <voice server url> [GROQ_MAX] [GEMINI_MAX]

Writes audio/best/<md5(line)[:12]>.mp3 (where the game looks a line up) and
audio/best/voices.json (which engine made each clip, so Dale's Gemini
stand-ins get replaced by Groq later). Each engine stops at its daily limit.
Needs ffmpeg.
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
from office_lines import ROOT, crew_lines, dale_lines  # noqa: E402

OUT = os.path.join(ROOT, "audio", "best")
MANIFEST = os.path.join(OUT, "voices.json")
GROQ_VOICE = "troy"
# Gemini voices per speaker (Dale's is only a stand-in until Groq gets to it).
GEMINI_VOICES = {"dale": "Achird", "gloria": "Kore", "kev": "Puck", "bernie": "Sulafat",
                 "theo": "Fenrir", "ray": "Gacrux"}
ORDER = ["dale", "gloria", "kev", "bernie", "theo", "ray"]
# Both services also limit requests per minute.
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


def say(url, text, engine, voice):
    body = json.dumps({"text": text, "engine": engine, "voice": voice}).encode()
    req = urllib.request.Request(url, body, {"Content-Type": "application/json",
                                            # Cloudflare turns away Python's default user agent.
                                            "User-Agent": "humble-house-build/1.0"})
    try:
        d = json.load(urllib.request.urlopen(req, timeout=120))
    except (urllib.error.URLError, ValueError) as e:
        return "", str(e)
    return d.get("audio", ""), json.dumps(d.get("models", {}))


def save(b64, path):
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        tmp.write(base64.b64decode(b64))
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", tmp.name, "-ac", "1",
                    "-codec:a", "libmp3lame", "-q:a", "4", path], check=True)
    os.remove(tmp.name)


def run(url, jobs, engine, voice_of, limit, made_by):
    """Record jobs [(file, text, who)] with one engine until limit or its daily cap."""
    made, why = 0, ""
    for f, text, who in jobs:
        if made >= limit:
            why = "run limit"
            break
        b64, info = say(url, text, engine, voice_of(who))
        if len(b64) < 200:
            if "429" in info or "RESOURCE_EXHAUSTED" in info:
                why = "daily limit"
                break
            print("no %s audio:" % engine, who, text, info[:300])
            continue
        save(b64, os.path.join(OUT, f))
        made_by[f] = engine
        made += 1
        time.sleep(PAUSE)
    return made, why


def main():
    url = sys.argv[1].rstrip("/") + "/say"
    groq_max = int(sys.argv[2]) if len(sys.argv) > 2 else 35
    gemini_max = int(sys.argv[3]) if len(sys.argv) > 3 else 120
    os.makedirs(OUT, exist_ok=True)
    want = wanted()
    made_by = {}
    if os.path.exists(MANIFEST):
        made_by = json.load(open(MANIFEST))
    for f in os.listdir(OUT):
        if f.endswith(".mp3") and f not in want:
            os.remove(os.path.join(OUT, f))
    # Clips from before the manifest: the old recorder only used Groq.
    made_by = {f: made_by.get(f, "groq") for f in want if os.path.exists(os.path.join(OUT, f))}

    # Dale in Groq: his lines without a Groq take yet.
    groq_jobs = [(f, t, w) for f, (t, w) in want.items() if w == "dale" and made_by.get(f) != "groq"]
    g_made, g_why = run(url, groq_jobs, "groq", lambda w: GROQ_VOICE, groq_max, made_by)
    # Gemini: stand-ins for Dale lines with no clip at all (he's the guide, so
    # first), then the crew.
    gem_jobs = [(f, t, w) for f, (t, w) in want.items() if w == "dale" and f not in made_by]
    gem_jobs += [(f, t, w) for f, (t, w) in want.items() if w != "dale" and f not in made_by]
    m_made, m_why = run(url, gem_jobs, "gemini", lambda w: GEMINI_VOICES.get(w, "Achird"), gemini_max, made_by)

    json.dump(made_by, open(MANIFEST, "w"), indent=0, sort_keys=True)
    dale = [f for f, (t, w) in want.items() if w == "dale"]
    crew = [f for f in want if f not in dale]
    print("Lines: Dale %d/%d in Groq (+%d Gemini stand-ins), crew %d/%d in Gemini; this run: %d Groq%s, %d Gemini%s"
          % (sum(made_by.get(f) == "groq" for f in dale), len(dale),
             sum(made_by.get(f) == "gemini" for f in dale),
             sum(f in made_by for f in crew), len(crew),
             g_made, " (%s)" % g_why if g_why else "", m_made, " (%s)" % m_why if m_why else ""))


if __name__ == "__main__":
    main()
