# Contra LLM backend

A tiny Cloudflare Worker that proxies the iOS app to Anthropic's API. It's
the only place an AI provider API key ever lives — the app itself never
embeds one.

```
iPhone (ContraLLM) → this Worker → Anthropic API
```

One deployment can be shared by everyone using the app: you hold the
Anthropic key, everyone else just points their app at your Worker's URL.

## Deploy (5 minutes, free tier)

Requires a free [Cloudflare](https://dash.cloudflare.com/sign-up) account
and an [Anthropic API key](https://console.anthropic.com/settings/keys).

```bash
cd backend/worker
npm install -g wrangler   # one-time
wrangler login             # opens a browser to authorize

wrangler secret put ANTHROPIC_API_KEY
# paste your Anthropic API key when prompted

# Optional but recommended if you're sharing this with other people:
# protects your Worker so only the app (which sends this same value) can use it.
wrangler secret put APP_SHARED_SECRET
# paste any random string you make up, e.g. output of: openssl rand -hex 24

wrangler deploy
```

Wrangler prints your Worker's URL, e.g.:

```
https://contrallm-backend.<your-subdomain>.workers.dev
```

## Point the app at it

In the app: **Settings → AI**
1. Turn **off** "Use demo AI provider"
2. Turn on **Developer Mode**
3. Paste the Worker URL as the **Custom backend URL**
4. If you set `APP_SHARED_SECRET`, paste the same value into **Backend secret**

Everyone you share the app with does the same — same URL, same shared
secret, no Anthropic key ever touches their device.

## Endpoints

| Method | Path         | Used for                                             |
|--------|--------------|-------------------------------------------------------|
| GET    | `/health`    | liveness check                                        |
| POST   | `/v1/title`  | generate a workspace title from a source               |
| POST   | `/v1/chat`   | answer a question about a workspace's source            |
| POST   | `/v1/process`| turn extracted source text into notebook blocks + slides |

All three POST endpoints take/return JSON — see `src/index.js` for exact
request/response shapes; that file is intentionally short and readable.

## Cost & abuse notes

- Model defaults to `claude-haiku-4-5-20251001` (fast, cheap) — change via
  the `MODEL` var in `wrangler.toml` or `wrangler secret put MODEL`.
- Cloudflare Workers free tier: 100,000 requests/day.
- Set `APP_SHARED_SECRET` before giving the URL to anyone — without it,
  anyone who discovers the Worker URL can spend your Anthropic budget.
- There's no per-user rate limiting yet. If you open this up to a group,
  consider adding one (e.g. Cloudflare Workers KV counters) before wide use.

## Local test

```bash
curl -X POST https://<your-worker>.workers.dev/v1/chat \
  -H "content-type: application/json" \
  -H "authorization: Bearer <APP_SHARED_SECRET if set>" \
  -d '{"workspaceTitle":"Test","sourceName":"test.txt","sourceText":"The sky is blue because of Rayleigh scattering.","message":"why is the sky blue?"}'
```
