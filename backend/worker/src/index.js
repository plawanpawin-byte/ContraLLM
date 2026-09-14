/**
 * Contra LLM backend — a thin proxy between the iOS app and Anthropic.
 *
 * The app never embeds an AI provider API key. It calls this Worker, which
 * holds the real Anthropic key as a Cloudflare secret and forwards a small,
 * purpose-built set of endpoints:
 *
 *   POST /v1/title    -> generate a short workspace title from a source
 *   POST /v1/chat     -> answer a question about a workspace's source
 *   POST /v1/process  -> turn extracted source text into notebook + slides
 *   GET  /health      -> liveness check
 *
 * Deploy: see backend/README.md
 */

const ANTHROPIC_URL = "https://api.anthropic.com/v1/messages";
const ANTHROPIC_VERSION = "2023-06-01";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization",
};

function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json", ...CORS_HEADERS },
  });
}

function unauthorized() {
  return json({ error: "Unauthorized" }, 401);
}

function checkAuth(request, env) {
  if (!env.APP_SHARED_SECRET) return true; // open mode, no secret configured
  const header = request.headers.get("Authorization") || "";
  const expected = `Bearer ${env.APP_SHARED_SECRET}`;
  return header === expected;
}

async function callClaude(env, { system, prompt, maxTokens = 800 }) {
  const res = await fetch(ANTHROPIC_URL, {
    method: "POST",
    headers: {
      "x-api-key": env.ANTHROPIC_API_KEY,
      "anthropic-version": ANTHROPIC_VERSION,
      "content-type": "application/json",
    },
    body: JSON.stringify({
      model: env.MODEL || "claude-haiku-4-5-20251001",
      max_tokens: maxTokens,
      system,
      messages: [{ role: "user", content: prompt }],
    }),
  });

  if (!res.ok) {
    const text = await res.text().catch(() => "");
    throw new Error(`Anthropic API error ${res.status}: ${text.slice(0, 300)}`);
  }

  const data = await res.json();
  const text = (data.content || [])
    .filter((block) => block.type === "text")
    .map((block) => block.text)
    .join("\n")
    .trim();
  return text;
}

/** Pulls the first {...} or [...] JSON value out of a model response that
 * may have stray prose around it, and parses it. Throws if none found. */
function extractJSON(text) {
  const match = text.match(/(\{[\s\S]*\}|\[[\s\S]*\])/);
  if (!match) throw new Error("No JSON found in model response");
  return JSON.parse(match[0]);
}

function truncate(text, maxChars) {
  if (!text) return "";
  return text.length > maxChars ? text.slice(0, maxChars) + "\n…(truncated)" : text;
}

// ---------------------------------------------------------------------------
// Route handlers
// ---------------------------------------------------------------------------

async function handleTitle(request, env) {
  const { sourceName = "", sourceType = "", sourceText = "" } = await request.json();

  const system =
    "You generate short, specific titles for a research/learning workspace. " +
    "Reply with the title text ONLY — no quotes, no punctuation at the end, no explanation. " +
    "Keep it under 8 words.";
  const prompt =
    `Source type: ${sourceType}\n` +
    `Source name: ${sourceName}\n` +
    (sourceText ? `Source excerpt:\n${truncate(sourceText, 3000)}\n\n` : "") +
    "Give a short, specific workspace title for this source.";

  const raw = await callClaude(env, { system, prompt, maxTokens: 40 });
  const title = raw.replace(/^["']|["']$/g, "").split("\n")[0].trim();
  return json({ title: title || sourceName || "Untitled" });
}

async function handleChat(request, env) {
  const {
    workspaceTitle = "",
    sourceName = "",
    sourceText = "",
    history = [],
    message = "",
  } = await request.json();

  const historyText = history
    .slice(-8)
    .map((turn) => `${turn.role === "user" ? "User" : "Assistant"}: ${turn.text}`)
    .join("\n");

  const system =
    "You are Contra, an AI research assistant embedded in a learning app. " +
    "You are discussing a specific source the user imported. Answer directly and concisely, " +
    "grounded in the provided source excerpt when possible. " +
    "Respond with STRICT JSON ONLY, matching exactly this shape, no markdown fences, no commentary:\n" +
    '{"text": "your answer, 1-4 sentences", "bullets": ["optional short bullet", ...up to 4], ' +
    '"followUps": ["a natural follow-up question", ...2-3 short ones]}\n' +
    'Use "bullets" only when a list genuinely helps; otherwise use [].';

  const prompt =
    `Workspace: ${workspaceTitle}\n` +
    `Source: ${sourceName}\n` +
    (sourceText ? `Source excerpt:\n${truncate(sourceText, 6000)}\n\n` : "") +
    (historyText ? `Conversation so far:\n${historyText}\n\n` : "") +
    `User's new message: ${message}`;

  const raw = await callClaude(env, { system, prompt, maxTokens: 700 });

  let parsed;
  try {
    parsed = extractJSON(raw);
  } catch {
    parsed = { text: raw, bullets: [], followUps: [] };
  }

  return json({
    text: String(parsed.text || raw || "").trim(),
    bullets: Array.isArray(parsed.bullets) ? parsed.bullets.slice(0, 4).map(String) : [],
    followUps: Array.isArray(parsed.followUps) ? parsed.followUps.slice(0, 3).map(String) : [],
  });
}

const NOTEBOOK_KINDS = [
  "heading", "paragraph", "keyIdea", "definition", "quote", "highlight",
  "citation", "researchFinding", "importantPoint", "question", "aiSummary",
];

async function handleProcess(request, env) {
  const { sourceName = "", sourceType = "", sourceText = "" } = await request.json();

  if (!sourceText || sourceText.trim().length < 20) {
    return json({ error: "sourceText is required and must have real content" }, 400);
  }

  const system =
    "You turn a source document into structured study material for a learning app. " +
    "Respond with STRICT JSON ONLY, no markdown fences, no commentary, matching exactly:\n" +
    '{"notebook": [{"kind": "<one of: ' + NOTEBOOK_KINDS.join(", ") + '>", ' +
    '"text": "block content", "caption": "optional short label or null"}, ...8-14 blocks], ' +
    '"slides": [{"title": "short title", "body": "1-3 sentences", ' +
    '"keyPoints": ["short point", ...0-4], "quote": "optional short quote or null", ' +
    '"hasCitation": true|false}, ...5-8 slides]}\n' +
    "Notebook should read like real study notes: start with a heading, include at least one " +
    "definition, one quote pulled from the source, one researchFinding or importantPoint, and " +
    "end with an aiSummary block. Ground everything in the given source text — do not invent facts.";

  const prompt =
    `Source type: ${sourceType}\n` +
    `Source name: ${sourceName}\n\n` +
    `Source text:\n${truncate(sourceText, 12000)}`;

  const raw = await callClaude(env, { system, prompt, maxTokens: 3000 });

  let parsed;
  try {
    parsed = extractJSON(raw);
  } catch (e) {
    return json({ error: `Model did not return valid JSON: ${e.message}` }, 502);
  }

  const notebook = Array.isArray(parsed.notebook)
    ? parsed.notebook
        .filter((b) => b && NOTEBOOK_KINDS.includes(b.kind) && typeof b.text === "string")
        .map((b) => ({
          kind: b.kind,
          text: b.text,
          caption: typeof b.caption === "string" ? b.caption : null,
        }))
    : [];

  const slides = Array.isArray(parsed.slides)
    ? parsed.slides
        .filter((s) => s && typeof s.title === "string" && typeof s.body === "string")
        .map((s) => ({
          title: s.title,
          body: s.body,
          keyPoints: Array.isArray(s.keyPoints) ? s.keyPoints.map(String).slice(0, 5) : [],
          quote: typeof s.quote === "string" ? s.quote : null,
          hasCitation: Boolean(s.hasCitation),
        }))
    : [];

  if (notebook.length === 0 || slides.length === 0) {
    return json({ error: "Model response had no usable notebook/slides content" }, 502);
  }

  return json({ notebook, slides });
}

// ---------------------------------------------------------------------------

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (request.method === "OPTIONS") {
      return new Response(null, { headers: CORS_HEADERS });
    }

    if (request.method === "GET" && url.pathname === "/health") {
      return json({ ok: true });
    }

    if (!checkAuth(request, env)) {
      return unauthorized();
    }

    try {
      if (request.method === "POST" && url.pathname === "/v1/title") {
        return await handleTitle(request, env);
      }
      if (request.method === "POST" && url.pathname === "/v1/chat") {
        return await handleChat(request, env);
      }
      if (request.method === "POST" && url.pathname === "/v1/process") {
        return await handleProcess(request, env);
      }
    } catch (err) {
      return json({ error: err.message || "Internal error" }, 500);
    }

    return json({ error: "Not found" }, 404);
  },
};
