# Contra LLM backend

A tiny Cloudflare Worker that proxies the iOS app to Google Gemini. It's the
only place an AI provider API key ever lives — the app itself never embeds
one. Each person you share the app with gets their own **access code**
(just a random string — not a Gemini key) with its own daily quota, so one
deployment can be shared by a small group safely.

```
iPhone (ContraLLM, access code "a1b2...") → this Worker → Gemini API
```

## Deploy (10 minutes, free tier)

Requires a free [Cloudflare](https://dash.cloudflare.com/sign-up) account
and a [Gemini API key](https://aistudio.google.com/apikey) (Google AI
Studio — has a genuinely free tier, not just a trial credit).

```bash
cd backend/worker
npm install -g wrangler   # one-time
wrangler login             # opens a browser to authorize
```

### 1. Get a Gemini API key

Go to [aistudio.google.com/apikey](https://aistudio.google.com/apikey) →
**Create API key**. The free tier has its own request-per-minute /
request-per-day caps set by Google, which is a real backstop against
runaway cost on top of the app-side daily limit below. If you outgrow the
free tier, Google Cloud Console lets you set a billing budget alert the
same way Anthropic does.

### 2. Create the usage-tracking KV namespace

```bash
wrangler kv namespace create USAGE_KV
```

Copy the `id` it prints into `wrangler.toml`, replacing the placeholder.

### 3. Set your Gemini key

```bash
wrangler secret put GEMINI_API_KEY
# paste your Gemini API key when prompted
```

### 4. Create an access code for each person

Generate one random code per person (10 people = 10 codes):

```bash
openssl rand -hex 8
```

Run that 10 times, then build one JSON object mapping code → name, e.g.:

```json
{"3f9a1b2c4d5e6f70": "Nueng", "8a7b6c5d4e3f2a10": "Ploy", "...": "..."}
```

```bash
wrangler secret put USER_TOKENS
# paste the JSON object above when prompted (all on one line)
```

Keep your own copy of which code belongs to which person somewhere safe —
the Worker only stores code → label, there's no way to look it up later
except by re-running `wrangler secret put` with an updated list.

Adjust `DAILY_LIMIT` in `wrangler.toml` if you want a different per-person
cap than the default (10/day).

### 5. Deploy

```bash
wrangler deploy
```

Wrangler prints your Worker's URL, e.g.:

```
https://contrallm-backend.<your-subdomain>.workers.dev
```

## Give each person their code

In the app: **Settings → AI**
1. Turn **off** "Use demo AI provider"
2. Turn on **Developer Mode**
3. Paste the Worker URL as the **Backend URL**
4. Paste **their own** access code as the **Backend secret**

Two different people must use two different codes — if everyone shares one
code, they all draw from the same daily quota.

## Endpoints

| Method | Path         | Used for                                             |
|--------|--------------|-------------------------------------------------------|
| GET    | `/health`    | liveness check (no auth, not quota-counted)            |
| POST   | `/v1/title`  | generate a workspace title from a source               |
| POST   | `/v1/chat`   | answer a question about a workspace's source            |
| POST   | `/v1/process`| turn extracted source text into notebook blocks + slides |

Every POST call requires `Authorization: Bearer <access code>` once
`USER_TOKENS` is set, and counts once against that code's daily quota. See
`src/index.js` for exact request/response shapes.

## Cost & safety notes

- Model defaults to `gemini-2.0-flash` (fast, cheap, generous free tier) —
  change via `MODEL` in `wrangler.toml` to any Gemini model name.
- Cloudflare Workers + KV free tier is generous (100k requests/day, 100k KV
  reads/day) — 10 people at 10 requests/day each won't come close.
- Gemini's free tier itself caps requests per minute/day — check current
  limits at [ai.google.dev/pricing](https://ai.google.dev/pricing). The
  per-code `DAILY_LIMIT` here is an extra layer on top so one person can't
  use up everyone else's share of that shared free-tier quota.
- If a code's holder hits their daily limit, only they are blocked (with a
  clear error) — everyone else is unaffected.

## Local test

```bash
curl -X POST https://<your-worker>.workers.dev/v1/chat \
  -H "content-type: application/json" \
  -H "authorization: Bearer <one of the access codes>" \
  -d '{"workspaceTitle":"Test","sourceName":"test.txt","sourceText":"The sky is blue because of Rayleigh scattering.","message":"why is the sky blue?"}'
```
