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
  "@cf/meta/llama-3.1-8b-instruct",
];
const SPEAK = [
  ["@cf/deepgram/aura-2-en", (text) => ({ text, speaker: "zeus" })],
  ["@cf/deepgram/aura-2-en", (text) => ({ text })],
  ["@cf/deepgram/aura-1", (text) => ({ text, speaker: "orion" })],
  ["@cf/myshell-ai/melotts", (text) => ({ prompt: text, lang: "en" })],
];

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
    // POST /say {text}: just Dale's voice for a line (the build pre-records
    // his story lines with it, so they play offline in the game).
    if (new URL(req.url).pathname === "/say") {
      const text = clip(body.text, 400).trim();
      if (!text) return json({ error: "no text" }, 400);
      return json({ audio: await speak(env, text, models), models });
    }
    try {
      let heard = clip(body.text, 500).trim();
      if (!heard && typeof body.audio === "string" && body.audio.length > 100) {
        if (body.audio.length > 2_000_000) return json({ error: "That was a long one. Keep it short." });
        heard = clip(await hear(env, body.audio, models), 500).trim();
      }
      if (!heard) return json({ heard: "", reply: "", error: "Didn't catch that. Hold the button while you talk.", models });
      const reply = await think(env, body, heard, models);
      const audio = body.voice === false ? "" : await speak(env, reply, models);
      return json({ heard, reply, audio, models });
    } catch (e) {
      return json({ error: String(e && e.message ? e.message : e).slice(0, 300), models }, 500);
    }
  },
};

async function hear(env, b64, models) {
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
  const messages = [{ role: "system", content: persona }];
  for (const m of history) {
    if (m && (m.role === "user" || m.role === "assistant")) messages.push({ role: m.role, content: clip(m.content, 600) });
  }
  messages.push({ role: "user", content: heard });
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

async function speak(env, text, models) {
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
    .replace(/\*[^*]*\*/g, "")
    .replace(/\([^)]*\)/g, "")
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
