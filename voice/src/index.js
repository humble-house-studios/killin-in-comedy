// Dale's voice server. POST /talk with JSON:
//   { audio: base64 WAV (16 kHz mono) or text: "...",
//     persona: "system prompt from the game", history: [{role, content}] }
// Returns { heard, reply, audio: base64 (mp3 or wav), models: {...} }.
// POST /say { text } returns { audio } for one line.
// Each step tries a few Workers AI models in turn, so a renamed or missing
// model falls back instead of breaking the chat.

const HEAR = [
  ["@cf/openai/whisper-large-v3-turbo", (b64) => ({ audio: b64, language: "en" })],
  ["@cf/openai/whisper", (b64) => ({ audio: [...base64ToBytes(b64)] })],
];
const THINK = [
  "@cf/meta/llama-3.3-70b-instruct-fp8-fast",
  "@cf/meta/llama-3.1-8b-instruct-fast",
];
// Cloudflare voices, cheapest first: MeloTTS costs a sliver of what Aura
// does, so the free daily allowance lasts for many more replies.
const SPEAK = [
  ["@cf/myshell-ai/melotts", (text) => ({ prompt: text, lang: "en" })],
  ["@cf/deepgram/aura-2-en", (text) => ({ text, speaker: "zeus" })],
];

// Google Gemini's free tier is the last-resort voice for live replies when
// GEMINI_API_KEY is set. It gets the line and nothing else: any style note
// ("Say warmly: ...") can end up read out loud.
const GEMINI = "https://generativelanguage.googleapis.com/v1beta";
const GEMINI_VOICES = ["Achird", "Umbriel", "Puck"];
let geminiTts = null;

async function geminiModels(env) {
  if (geminiTts) return geminiTts;
  const r = await fetch(GEMINI + "/models?pageSize=200&key=" + env.GEMINI_API_KEY);
  const j = await r.json();
  if (!r.ok) throw new Error("gemini models " + r.status + " " + JSON.stringify(j).slice(0, 200));
  const names = (j.models || []).map((m) => m.name.replace("models/", "")).filter((n) => /tts/i.test(n));
  // Flash first (fast, roomier free limits), newest first.
  names.sort((a, b) => (/flash/.test(b) - /flash/.test(a)) || b.localeCompare(a));
  geminiTts = names;
  return names;
}

async function geminiSpeak(env, text, models, only = "") {
  let names;
  try {
    names = await geminiModels(env);
  } catch (e) {
    models.speak_error_gemini = String(e).slice(0, 200);
    return "";
  }
  for (const model of names.slice(0, 3)) {
    for (const voice of only ? [only] : GEMINI_VOICES) {
      const r = await fetch(GEMINI + "/models/" + model + ":generateContent?key=" + env.GEMINI_API_KEY, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          contents: [{ parts: [{ text }] }],
          generationConfig: {
            responseModalities: ["AUDIO"],
            speechConfig: { voiceConfig: { prebuiltVoiceConfig: { voiceName: voice } } },
          },
        }),
      });
      const j = await r.json().catch(() => ({}));
      const part = j.candidates && j.candidates[0] && j.candidates[0].content && (j.candidates[0].content.parts || []).find((p) => p.inlineData);
      if (r.ok && part) {
        const mime = part.inlineData.mimeType || "";
        const rate = parseInt((mime.match(/rate=(\d+)/) || [])[1] || "24000", 10);
        const pcm = base64ToBytes(part.inlineData.data);
        models.speak_seconds = Math.round((pcm.length / 2 / rate) * 10) / 10;
        models.speak = "gemini/" + model + "/" + voice;
        return /wav/i.test(mime) ? part.inlineData.data : bytesToBase64(wavFromPcm16(pcm, rate));
      }
      models["speak_error_gemini_" + model + "_" + voice] = r.status + " " + JSON.stringify(j).slice(0, 200);
      // Over the limit or a bad model: other voices won't help.
      if (/^(429|404)/.test(models["speak_error_gemini_" + model + "_" + voice] || "")) break;
    }
  }
  return "";
}

// Gemini sends raw 16-bit mono PCM; wrap it so the game can play it.
function wavFromPcm16(pcm, rate) {
  const out = new Uint8Array(44 + pcm.length);
  const v = new DataView(out.buffer);
  const tag = (at, s) => { for (let i = 0; i < 4; i++) out[at + i] = s.charCodeAt(i); };
  tag(0, "RIFF"); v.setUint32(4, 36 + pcm.length, true); tag(8, "WAVE");
  tag(12, "fmt "); v.setUint32(16, 16, true); v.setUint16(20, 1, true); v.setUint16(22, 1, true);
  v.setUint32(24, rate, true); v.setUint32(28, rate * 2, true); v.setUint16(32, 2, true); v.setUint16(34, 16, true);
  tag(36, "data"); v.setUint32(40, pcm.length, true);
  out.set(pcm, 44);
  return out;
}

const TAPPED_OUT = "I'm all talked out for today. Free AI limit. Catch me tomorrow!";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type",
};

const FALLBACK_PERSONA =
  "You are Dale, a chubby, kind, nervous, funny coworker in Accounts Receivable. " +
  "Answer in one to three short spoken sentences.";

export default {
  async fetch(req, env) {
    if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS });
    if (req.method === "GET") return json({ ok: true, who: "dale-voice" });
    if (req.method !== "POST") return json({ error: "POST /talk" }, 405);
    let body;
    try {
      body = await req.json();
    } catch {
      return json({ error: "bad json" }, 400);
    }
    const models = {};
    // POST /groq: which Groq models this key can use (build diagnostics).
    if (new URL(req.url).pathname === "/groq") {
      try {
        const ids = await groqList(env);
        return json({ ids, hear: pick(ids, GROQ_HEAR_PREFS), think: pick(ids, GROQ_THINK_PREFS, NOT_CHAT) });
      } catch (e) {
        return json({ error: String(e).slice(0, 300) });
      }
    }
    // POST /say {text}: just Dale's voice for a line (the build pre-records
    // his story lines with it, so they play offline in the game).
    if (new URL(req.url).pathname === "/say") {
      const text = clip(body.text, 400).trim();
      if (!text) return json({ error: "no text" }, 400);
      // A named voice: Groq's from its list, Gemini's any capitalised name.
      const voice = typeof body.voice === "string" ? body.voice : "";
      const audio = body.engine === "groq" ? await groqSpeak(env, text, models, GROQ_VOICES.includes(voice) ? voice : "")
        : body.engine === "gemini" ? await geminiSpeak(env, text, models, /^[A-Z][a-z]+$/.test(voice) ? voice : "")
        : await speak(env, text, models);
      return json({ audio, models });
    }
    try {
      let heard = clip(body.text, 500).trim();
      if (!heard && typeof body.audio === "string" && body.audio.length > 100) {
        if (body.audio.length > 2_000_000) return json({ error: "That was a long one. Keep it short." });
        heard = clip(await hear(env, body.audio, models, typeof body.mime === "string" ? body.mime : "audio/wav"), 500).trim();
        // Whisper "hears" a lone "you" (or "thank you") in near-silence.
        if (/^(thank you|thanks for watching|you)[.!]?$/i.test(heard)) heard = "";
      }
      if (!heard) return json({ heard: "", reply: "", error: "Didn't catch that. Hold the button while you talk.", models });
      const reply = await think(env, body, heard, models);
      const audio = body.voice === false ? "" : await speak(env, reply, models);
      return json({ heard, reply, audio, models });
    } catch (e) {
      const msg = String(e && e.message ? e.message : e);
      // Free plan: 10,000 "neurons" a day, reset at midnight UTC.
      if (msg.includes("4006") || JSON.stringify(models).includes("4006")) return json({ error: TAPPED_OUT, models });
      return json({ error: msg.slice(0, 300), models }, 500);
    }
  },
};

// Groq (free key, very fast) hears and thinks when GROQ_API_KEY is set, so
// Cloudflare's free daily allowance goes to Dale's voice. Each falls back to
// the other.
const GROQ = "https://api.groq.com/openai/v1";
// Groq renames and retires models often, so Dale asks which ones exist and
// picks by these preferences (first match wins).
const GROQ_HEAR_PREFS = ["whisper-large-v3-turbo", "whisper"];
const GROQ_THINK_PREFS = ["llama-4-maverick", "llama-4-scout", "llama-3.3-70b", "kimi-k2", "qwen3", "gpt-oss-120b", "gpt-oss-20b", "llama"];
const NOT_CHAT = /whisper|tts|orpheus|playai|guard|prompt-guard|safeguard|compound|distil/i;
let groqModels = null;

async function groqList(env) {
  if (groqModels) return groqModels;
  const r = await fetch(GROQ + "/models", { headers: { Authorization: "Bearer " + env.GROQ_API_KEY } });
  const j = await r.json();
  if (!r.ok) throw new Error("groq models " + r.status + " " + JSON.stringify(j).slice(0, 150));
  groqModels = (j.data || []).filter((m) => m.active !== false).map((m) => m.id);
  return groqModels;
}

function pick(ids, prefs, skip) {
  for (const p of prefs) {
    const hit = ids.find((id) => id.toLowerCase().includes(p) && !(skip && skip.test(id)));
    if (hit) return hit;
  }
  return "";
}
// Groq's Orpheus: the best-sounding voice we have (Samuel's pick). Dale is
// "troy"; the build records each coworker in their own Orpheus voice.
const GROQ_TTS = "canopylabs/orpheus-v1-english";
const GROQ_VOICES = ["troy", "daniel", "austin", "hannah", "diana", "autumn"];

const EXT = { "audio/wav": "wav", "audio/mp4": "m4a", "audio/webm": "webm", "audio/ogg": "ogg", "audio/mpeg": "mp3", "audio/aac": "m4a" };

async function groqHear(env, b64, models, mime = "audio/wav") {
  const type = mime.split(";")[0];
  const form = new FormData();
  form.append("file", new Blob([base64ToBytes(b64)], { type }), "talk." + (EXT[type] || "m4a"));
  const hearModel = pick(await groqList(env), GROQ_HEAR_PREFS) || "whisper-large-v3-turbo";
  form.append("model", hearModel);
  form.append("language", "en");
  form.append("response_format", "json");
  const r = await fetch(GROQ + "/audio/transcriptions", { method: "POST", headers: { Authorization: "Bearer " + env.GROQ_API_KEY }, body: form });
  const j = await r.json();
  if (!r.ok) throw new Error("groq hear " + r.status + " " + JSON.stringify(j).slice(0, 150));
  models.hear = "groq/" + hearModel;
  return j.text || "";
}

async function groqThink(env, messages, models) {
  let last = "no groq chat model";
  const ids = await groqList(env);
  const tried = new Set();
  for (const pref of GROQ_THINK_PREFS) {
    const model = pick(ids.filter((id) => !tried.has(id)), [pref], NOT_CHAT);
    if (!model) continue;
    tried.add(model);
    if (tried.size > 3) break;
    const body = { model, messages, max_tokens: 160, temperature: 0.8 };
    // Reasoning models think first; keep that short so the answer fits.
    if (/gpt-oss|qwen3/i.test(model)) Object.assign(body, { max_tokens: 700, reasoning_effort: /qwen/i.test(model) ? "none" : "low" });
    const r = await fetch(GROQ + "/chat/completions", {
      method: "POST",
      headers: { Authorization: "Bearer " + env.GROQ_API_KEY, "Content-Type": "application/json" },
      body: JSON.stringify(body),
    });
    const j = await r.json();
    const text = cleanReply(j.choices && j.choices[0] && j.choices[0].message && j.choices[0].message.content);
    if (r.ok && text) {
      models.think = "groq/" + model;
      return text;
    }
    last = "groq think " + model + " " + r.status + " " + JSON.stringify(j).slice(0, 150);
    models["think_error_groq_" + model] = last;
  }
  throw new Error(last);
}

async function groqSpeak(env, text, models, only = "") {
  const model = GROQ_TTS;
  for (const voice of only ? [only] : ["troy", "daniel"]) {
    try {
      const r = await fetch(GROQ + "/audio/speech", {
        method: "POST",
        headers: { Authorization: "Bearer " + env.GROQ_API_KEY, "Content-Type": "application/json" },
        body: JSON.stringify({ model, voice, input: text, response_format: "wav" }),
      });
      if (!r.ok) {
        models["speak_error_groq_" + voice] = r.status + " " + (await r.text()).slice(0, 400);
        // Out for the day: another voice won't help.
        if (r.status === 429) break;
        continue;
      }
      const b64 = bytesToBase64(new Uint8Array(await r.arrayBuffer()));
      if (b64.length > 200) {
        models.speak = "groq/" + model + "/" + voice;
        return b64;
      }
    } catch (e) {
      models["speak_error_groq_" + voice] = String(e).slice(0, 150);
    }
  }
  return "";
}

async function hear(env, b64, models, mime) {
  if (env.GROQ_API_KEY) {
    try {
      return await groqHear(env, b64, models, mime);
    } catch (e) {
      models.hear_error_groq = String(e).slice(0, 150);
    }
  }
  let last;
  for (const [model, input] of HEAR) {
    try {
      const r = await env.AI.run(model, input(b64));
      models.hear = model;
      return (r && (r.text || (r.transcription_info && r.text))) || "";
    } catch (e) {
      last = e;
      models["hear_error_" + model] = String(e).slice(0, 120);
    }
  }
  throw last;
}

async function think(env, body, heard, models) {
  const persona = clip(body.persona, 8000) || FALLBACK_PERSONA;
  const history = Array.isArray(body.history) ? body.history.slice(-12) : [];
  // The reply is read straight out loud, so: words only.
  const messages = [{ role: "system", content: persona + "\n\nWrite only the words Dale says out loud. No stage directions, no brackets, no emotion or tone labels." }];
  for (const m of history) {
    if (m && (m.role === "user" || m.role === "assistant")) messages.push({ role: m.role, content: clip(m.content, 600) });
  }
  messages.push({ role: "user", content: heard });
  if (env.GROQ_API_KEY) {
    try {
      return await groqThink(env, messages, models);
    } catch (e) {
      models.think_error_groq = String(e).slice(0, 150);
    }
  }
  let last;
  for (const model of THINK) {
    try {
      const r = await env.AI.run(model, { messages, max_tokens: 140, temperature: 0.8 });
      const text = cleanReply(r && (r.response || (r.choices && r.choices[0]?.message?.content)));
      if (text) {
        models.think = model;
        return text;
      }
    } catch (e) {
      last = e;
      models["think_error_" + model] = String(e).slice(0, 120);
    }
  }
  if (last) throw last;
  return "Sorry, I zoned out. Spreadsheet brain. Say that again?";
}

// Dale's live-reply voice, best first: Groq's Orpheus (Samuel's pick, and
// the voice his lines are recorded in), then Gemini, then Cloudflare.
async function speak(env, text, models) {
  if (env.GROQ_API_KEY) {
    const b64 = await groqSpeak(env, text, models);
    if (b64) return b64;
  }
  if (env.GEMINI_API_KEY) {
    const b64 = await geminiSpeak(env, text, models);
    if (b64) return b64;
  }
  for (const [model, input] of SPEAK) {
    try {
      const r = await env.AI.run(model, input(text));
      const b64 = await audioToBase64(r);
      if (b64 && b64.length > 200) {
        models.speak = model;
        return b64;
      }
    } catch (e) {
      models["speak_error_" + model] = String(e).slice(0, 120);
    }
  }
  return "";
}

// Workers AI hands back audio in a few shapes, depending on the model.
async function audioToBase64(r) {
  if (!r) return "";
  if (typeof r === "string") return r;
  if (typeof r.audio === "string") return r.audio;
  let buf;
  if (r instanceof Response) buf = await r.arrayBuffer();
  else if (r instanceof ReadableStream) buf = await new Response(r).arrayBuffer();
  else if (r instanceof ArrayBuffer) buf = r;
  else if (ArrayBuffer.isView(r)) buf = r.buffer.slice(r.byteOffset, r.byteOffset + r.byteLength);
  else if (r.audio instanceof ReadableStream) buf = await new Response(r.audio).arrayBuffer();
  if (!buf) return "";
  return bytesToBase64(new Uint8Array(buf));
}

// The model may add stage directions or quotes; Dale just talks.
function cleanReply(text) {
  if (typeof text !== "string") return "";
  return text
    .replace(/<think>[\s\S]*?<\/think>/gi, "")
    .replace(/\*[^*]*\*/g, "")
    .replace(/\([^)]*\)/g, "")
    .replace(/\[[^\]]*\]/g, "")
    .replace(/^\s*(say|said|speaking|in a)\b[^:]{0,60}:\s*/i, "")
    .replace(/^\s*(Dale\s*:)\s*/i, "")
    .replace(/^["']|["']$/g, "")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, 400);
}

function clip(v, n) {
  return typeof v === "string" ? v.slice(0, n) : "";
}

function json(obj, status = 200) {
  return new Response(JSON.stringify(obj), { status, headers: { "Content-Type": "application/json", ...CORS } });
}

function base64ToBytes(b64) {
  const s = atob(b64);
  const out = new Uint8Array(s.length);
  for (let i = 0; i < s.length; i++) out[i] = s.charCodeAt(i);
  return out;
}

function bytesToBase64(bytes) {
  let s = "";
  for (let i = 0; i < bytes.length; i += 0x8000) s += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
  return btoa(s);
}
