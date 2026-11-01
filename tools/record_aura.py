#!/usr/bin/env python3
"""Records Dale's scripted lines in his Aura voice ("zeus", Cloudflare) through
his voice server, as many as the free daily allowance allows; the rest stay
in Piper (tools/record_lines.py) until a later build gets to them.

    python3 tools/record_aura.py https://dale-voice.<you>.workers.dev

Writes audio/aura/<md5(line)[:12]>.mp3. The build copies these over the Piper
clips of the same name, so Aura wins wherever it exists. Stops at the first
"used up your daily allocation" so it doesn't hammer the limit.
"""
import base64
import hashlib
import json
import os
import sys
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from record_lines import ROOT, dale_lines  # noqa: E402

OUT = os.path.join(ROOT, "audio", "aura")


def main():
    url = sys.argv[1].rstrip("/") + "/say"
    os.makedirs(OUT, exist_ok=True)
    want = {hashlib.md5(t.strip().encode("utf8")).hexdigest()[:12] + ".mp3": t.strip() for t in dale_lines() if t.strip()}
    for f in os.listdir(OUT):
        if f not in want:
            os.remove(os.path.join(OUT, f))
    # Clips from the first days (same voice, same file names) are reused for
    # any line that hasn't changed: pass their folder as a second argument.
    seed = sys.argv[2] if len(sys.argv) > 2 else ""
    reused = 0
    if seed and os.path.isdir(seed):
        for f in want:
            src = os.path.join(seed, f)
            if not os.path.exists(os.path.join(OUT, f)) and os.path.exists(src) and os.path.getsize(src) > 1000:
                with open(src, "rb") as a, open(os.path.join(OUT, f), "wb") as b:
                    b.write(a.read())
                reused += 1
    if reused:
        print("reused %d clips from before" % reused)
    made = kept = 0
    out_of_allowance = False
    for f, text in want.items():
        path = os.path.join(OUT, f)
        if os.path.exists(path):
            kept += 1
            continue
        if out_of_allowance:
            continue
        req = urllib.request.Request(url, json.dumps({"text": text, "engine": "aura"}).encode(), {"Content-Type": "application/json",
                                     # Cloudflare turns away Python's default user agent.
                                     "User-Agent": "humble-house-build/1.0"})
        try:
            d = json.load(urllib.request.urlopen(req, timeout=60))
        except Exception as e:
            print("failed:", text, e)
            continue
        audio = d.get("audio", "")
        if len(audio) > 200:
            with open(path, "wb") as fh:
                fh.write(base64.b64decode(audio))
            made += 1
        elif "4006" in json.dumps(d.get("models", {})):
            out_of_allowance = True
        else:
            print("no audio:", text, json.dumps(d.get("models", {}))[:200])
    left = len(want) - made - kept
    print("Dale's Aura lines: %d total, %d recorded, %d kept, %d still in Piper%s"
          % (len(want), made, kept, left, " (daily allowance used up)" if out_of_allowance else ""))


if __name__ == "__main__":
    main()
