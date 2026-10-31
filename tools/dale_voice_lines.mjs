// Pre-records Dale's story lines with his server's voice, so the game can play
// them like any other sound (no device text-to-speech, works offline).
//   node tools/dale_voice_lines.mjs https://dale-voice.<you>.workers.dev
// Reads every line in data/dale_lines.gd and writes audio/dale/<md5[:12]>.mp3
// (the game looks lines up by the same name). Lines already recorded are kept,
// so a build only pays for new or changed lines. Not committed (.gitignore);
// the deploy workflow caches them between builds.
import { readFileSync, writeFileSync, existsSync, mkdirSync, readdirSync, unlinkSync } from "node:fs";
import { createHash } from "node:crypto";

const url = (process.argv[2] || "").replace(/\/$/, "");
if (!url) {
  console.error("usage: node tools/dale_voice_lines.mjs <voice server url>");
  process.exit(1);
}
const src = readFileSync(new URL("../data/dale_lines.gd", import.meta.url), "utf8");
// Everything after PERSONA is the AI's prompt, not a spoken line.
const spoken = src.split("const PERSONA")[0];
const lines = new Set();
for (const m of spoken.matchAll(/"(dale|reply|hint)":\s*"((?:[^"\\]|\\.)*)"/g)) lines.add(unescape(m[2]));
for (const block of ["SMALL_TALK", "REACT", "AFTER"]) {
  const at = spoken.indexOf(`const ${block}`);
  if (at < 0) continue;
  const body = spoken.slice(at, spoken.indexOf("\n]", at) > 0 && block !== "REACT" ? spoken.indexOf("\n]", at) : spoken.indexOf("\n}", at));
  for (const m of body.matchAll(/"((?:[^"\\]|\\.)*)"/g)) {
    const t = unescape(m[1]);
    if (t.includes(" ")) lines.add(t);
  }
}
lines.delete("");

const dir = new URL("../audio/dale/", import.meta.url);
mkdirSync(dir, { recursive: true });
const want = new Map([...lines].map((t) => [createHash("md5").update(t, "utf8").digest("hex").slice(0, 12) + ".mp3", t]));
// Drop clips for lines that no longer exist.
for (const f of readdirSync(dir)) if (!want.has(f.replace(".wav", ".mp3"))) unlinkSync(new URL(f, dir));

let made = 0, kept = 0, failed = 0;
for (const [file, text] of want) {
  const out = new URL(file, dir);
  if (existsSync(out) || existsSync(new URL(file.replace(".mp3", ".wav"), dir))) { kept++; continue; }
  let ok = false;
  for (let attempt = 0; attempt < 3 && !ok; attempt++) {
    try {
      const r = await fetch(url + "/say", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ text }) });
      const j = await r.json();
      if (j.audio && j.audio.length > 200) {
        const bytes = Buffer.from(j.audio, "base64");
        // Some voices answer with WAV; keep the right extension for Godot.
        writeFileSync(bytes.subarray(0, 4).toString() === "RIFF" ? new URL(file.replace(".mp3", ".wav"), dir) : out, bytes);
        ok = true;
      } else if (attempt === 2) console.log("no audio:", text, JSON.stringify(j.models || j.error));
    } catch (e) {
      if (attempt === 2) console.log("failed:", text, String(e));
    }
  }
  ok ? made++ : failed++;
}
console.log(`Dale lines: ${want.size} total, ${made} recorded, ${kept} kept, ${failed} failed`);

function unescape(s) {
  return s.replace(/\\(["\\])/g, "$1");
}
