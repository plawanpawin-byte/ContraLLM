# Contra LLM backend

A tiny Cloudflare Worker that proxies the iOS app to OpenRouter. It's the
only place an AI provider API key ever lives — the app itself never embeds
one. Each person who uses the app gets their own **access code** (just a
random string — not an OpenRouter key) with its own daily quota.

```
iPhone (ContraLLM, access code "a1b2...") → this Worker → OpenRouter → model
```

## Deploy (10 minutes, free tier)

Requires a free [Cloudflare](https://dash.cloudflare.com/sign-up) account
and an [OpenRouter](https://openrouter.ai/keys) API key.

```bash
cd backend/worker
npm install -g wrangler   # one-time
wrangler login             # opens a browser to authorize
```

### 1. Get an OpenRouter API key

Go to [openrouter.ai/keys](https://openrouter.ai/keys) → **Create Key**.
OpenRouter lets you set a **credit limit on the key itself** (Settings →
Keys → edit the key's limit) — set that to a small number, e.g. $1-2, as a
hard backstop. Also pick a model tagged **`:free`** at
[openrouter.ai/models?max_price=0](https://openrouter.ai/models?max_price=0)
to keep real cost at $0 — the default in `wrangler.toml`
(`mistralai/mistral-7b-instruct:free`) is one, but free model availability
changes over time, so check that page if it ever stops responding and swap
`MODEL` for a current one.

### 2. Create the usage-tracking KV namespace

```bash
wrangler kv namespace create USAGE_KV
```

Copy the `id` it prints into `wrangler.toml`, replacing the placeholder.

### 3. Set your OpenRouter key

```bash
wrangler secret put OPENROUTER_API_KEY
# paste your OpenRouter API key when prompted
```

### 4. Create your access code

Even for one person, an access code is worth having — it's the only thing
standing between "just me" and "anyone who finds the Worker URL." Generate
one:

```bash
openssl rand -hex 8
```

```bash
wrangler secret put USER_TOKENS
# paste: {"<the code you generated>": "me"}
```

(If you're adding more people later, it's the same JSON object with more
entries — see the comment in `wrangler.toml`.)

`DAILY_LIMIT` in `wrangler.toml` defaults to 100/day, generous for one
person. Lower it if you want a tighter guardrail.

### 5. Deploy

```bash
wrangler deploy
```

Wrangler prints your Worker's URL, e.g.:

```
https://contrallm-backend.<your-subdomain>.workers.dev
```

## Turn it on in the app

**Settings → AI**
1. Turn **off** "Use demo AI provider"
2. Turn on **Developer Mode**
3. Paste the Worker URL as the **Backend URL**
4. Paste your access code as the **Backend secret**

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

- Use a `:free`-tagged model (see step 1) and real cost is $0.
- If you switch to a paid model, **the credit limit you set on the
  OpenRouter key itself (step 1) is the real backstop** — once hit, the key
  simply stops working. The app-side `DAILY_LIMIT` is a courtesy guardrail
  on top, not a substitute for that.
- Cloudflare Workers + KV free tier is generous (100k requests/day) — far
  more than one person will ever use.

## Local test

```bash
curl -X POST https://<your-worker>.workers.dev/v1/chat \
  -H "content-type: application/json" \
  -H "authorization: Bearer <your access code>" \
  -d '{"workspaceTitle":"Test","sourceName":"test.txt","sourceText":"The sky is blue because of Rayleigh scattering.","message":"why is the sky blue?"}'
```
