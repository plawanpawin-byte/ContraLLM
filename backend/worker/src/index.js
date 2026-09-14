/**
 * Contra LLM backend — a thin proxy between the iOS app and OpenRouter.
 *
 * The app never embeds an AI provider API key. It calls this Worker, which
 * holds the real OpenRouter key as a Cloudflare secret and forwards a small,
 * purpose-built set of endpoints:
 *
 *   POST /v1/title    -> generate a short workspace title from a source
 *   POST /v1/chat     -> answer a question about a workspace's source
 *   POST /v1/process  -> turn extracted source text into notebook + slides
 *   GET  /health      -> liveness check
 *
 * Auth + per-user daily quota: each person gets their own access code (not
 * an OpenRouter key — just a random string you hand out). USER_TOKENS maps
 * each code to a label; DAILY_LIMIT caps how many AI requests that code can
 * make per UTC day, counted in the USAGE_KV KV namespace. This is a
 * best-effort guardrail on top of whatever spend limit you set on your
 * OpenRouter account. See backend/README.md.
 *
 * Deploy: see backend/README.md
 */

const OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions";

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

function unauthorized(message = "Unauthorized") {
  return json({ error: message }, 401);
}

function parseUserTokens(env) {
  if (!env.USER_TOKENS) return null;
  try {
    return JSON.parse(env.USER_TOKENS); // { "<token>": "<label>", ... }
  } catch {
    return null;
  }
}

/** Resolves the caller's access code from the Authorization header against
 * USER_TOKENS. Returns { token, label } on success, null if no code was
 * configured (open mode) — the caller still needs to check `unauthorizedReason`
 * separately when a code WAS required but didn't match. */
function resolveUser(request, env) {
  const tokens = parseUserTokens(env);
  if (!tokens) return { open: true };

  const header = request.headers.get("Authorization") || "";
  const provided = header.startsWith("Bearer ") ? header.slice(7) : "";
  if (!provided || !(provided in tokens)) return null;

  return { open: false, token: provided, label: tokens[provided] };
}

/** Checks and increments today's usage count for a user's access code.
 * Returns { allowed, remaining }. Counting is best-effort (not perfectly
 * atomic under heavy concurrent use), which is fine for a small shared
 * group — it's a courtesy guardrail, not a hard financial backstop. */
async function checkAndConsumeQuota(env, user) {
  if (user.open || !env.USAGE_KV) {
    return { allowed: true, remaining: null }; // no KV bound = no metering
  }

  const limit = Number(env.DAILY_LIMIT || 20);
  const day = new Date().toISOString().slice(0, 10); // UTC YYYY-MM-DD
  const key = `usage:${user.token}:${day}`;

  const current = Number((await env.USAGE_KV.get(key)) || "0");
  if (current >= limit) {
    return { allowed: false, remaining: 0 };
  }

  await env.USAGE_KV.put(key, String(current + 1), { expirationTtl: 172800 });
  return { allowed: true, remaining: limit - current - 1 };
}

async function callOpenRouter(env, { system, prompt, maxTokens = 800 }) {
  const model = env.MODEL || "mistralai/mistral-7b-instruct:free";

  const res = await fetch(OPENROUTER_URL, {
    method: "POST",
    headers: {
      "authorization": `Bearer ${env.OPENROUTER_API_KEY}`,
      "content-type": "application/json",
      // OpenRouter asks for these but doesn't require them to work.
      "HTTP-Referer": "https://github.com/plawanpawin-byte/ContraLLM",
      "X-Title": "Contra LLM",
    },
    body: JSON.stringify({
      model,
      max_tokens: maxTokens,
      messages: [
        { role: "system", content: system },
        { role: "user", content: prompt },
      ],
    }),
  });

  if (!res.ok) {
    const text = await res.text().catch(() => "");
    throw new Error(`OpenRouter API error ${res.status}: ${text.slice(0, 300)}`);
  }

  const data = await res.json();
  const text = (data.choices?.[0]?.message?.content || "").trim();
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

  const raw = await callOpenRouter(env, { system, prompt, maxTokens: 40 });
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

  const raw = await callOpenRouter(env, { system, prompt, maxTokens: 700 });

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

  const raw = await callOpenRouter(env, { system, prompt, maxTokens: 3000 });

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

    const user = resolveUser(request, env);
    if (!user) {
      return unauthorized("Unknown or missing access code.");
    }

    // Cheap auth check the app uses for its "Test Connection" button — valid
    // access code + reachable Worker, without spending a quota slot or
    // calling the AI provider.
    if (request.method === "GET" && url.pathname === "/v1/verify") {
      return json({ ok: true, label: user.open ? null : user.label });
    }

    const quota = await checkAndConsumeQuota(env, user);
    if (!quota.allowed) {
      return json(
        { error: "Daily limit reached for this access code. Try again tomorrow (UTC)." },
        429
      );
    }
    const extraHeaders = quota.remaining !== null ? { "X-Quota-Remaining": String(quota.remaining) } : {};

    try {
      let response;
      if (request.method === "POST" && url.pathname === "/v1/title") {
        response = await handleTitle(request, env);
      } else if (request.method === "POST" && url.pathname === "/v1/chat") {
        response = await handleChat(request, env);
      } else if (request.method === "POST" && url.pathname === "/v1/process") {
        response = await handleProcess(request, env);
      } else {
        return json({ error: "Not found" }, 404);
      }
      for (const [k, v] of Object.entries(extraHeaders)) response.headers.set(k, v);
      return response;
    } catch (err) {
      return json({ error: err.message || "Internal error" }, 500);
    }
  },
};
