# Contra LLM

An AI Research & Learning Workspace for iPhone. Throw in something you want to
understand — a PDF, a link, a video, an audio file — and Contra turns it into
a small world you can read, listen to, explore, and ask questions about.

**Source → Understand → Learn → Listen → Explore → Ask AI**

---

## Concept

Import content from PDF, text, a website URL, a YouTube URL, a Google Docs
URL, or audio (MP3 / WAV / M4A). Contra analyzes the source and turns it into
four learning experiences:

1. **Voice** — talk with AI about the source through natural conversation
2. **Podcast** — an AI-hosted audio conversation built from the source
3. **Slides** — a clean, swipeable sequence of key ideas
4. **Notebook** — richly formatted AI notes: definitions, highlights, findings, citations

You can ask AI questions from anywhere inside a workspace.

## Features (V1)

- Home screen with a Source Prompt Bar (file import + URL/text input)
- File import for PDF, TXT, MP3, WAV, M4A via `fileImporter`
- URL classification for YouTube, Google Docs, and general websites
- Animated Processing screen with step-by-step status
- AI-generated (mock) workspace titles
- Workspace screen with a 2×2 grid: Voice / Podcast / Slides / Notebook
- Voice: conversation transcript, mic button, text prompt bar
- Podcast: cover, playback controls, seek bar, transcript, Ask AI
- Slides: horizontal paging, key points, quotes, citations, Ask AI
- Notebook: headings, key ideas, definitions, quotes, highlights, citations,
  research findings, important points, questions, AI summary — built with
  selective bold/underline/highlight/accent styling
- Universal `AIPromptBar` component reused across all four experiences
- Library (SwiftData-backed) of previously created workspaces
- Settings: General / AI / Voice / About, with a developer-mode custom backend endpoint
- Full offline demo mode — no API key required
- Empty/error states for every screen (no source, processing failed, network
  failed, AI error, unsupported file, audio unavailable, empty library)

## Architecture

```
ContraLLM/
├── App/                 App entry point, root TabView
├── Models/              SourceItem, Workspace (SwiftData), AIMessage,
│                         PodcastEpisode, Slide, NotebookBlock, VoiceProfile
├── Views/                Home, Processing, Workspace, Voice, Podcast,
│                         Slides, Notebook, Library, Settings
├── Components/           AIPromptBar, SourceInputBar, FeatureCard,
│                         LoadingView, ChatBubble, EmptyStateView
├── ViewModels/           HomeViewModel, ProcessingViewModel, ChatViewModel,
│                         PodcastViewModel
├── Services/
│   ├── AI/               AIChatService, EmbeddingService, APIConfiguration
│   ├── Source/            DocumentProcessingService
│   ├── Podcast/           PodcastService
│   ├── Speech/            SpeechToTextService, TextToSpeechService
│   └── Mock/               Mock*Service implementations + shared demo content
├── Persistence/          SwiftData ModelContainer + demo seed data
├── Utilities/             Theme (design tokens)
└── Resources/             Assets.xcassets (AppIcon, AccentColor)
```

### Provider independence

Every AI-adjacent capability is defined as a protocol (`AIChatService`,
`EmbeddingService`, `SpeechToTextService`, `TextToSpeechService`,
`PodcastService`, `DocumentProcessingService`). `ServiceContainer` is the one
place that wires concrete implementations to those protocols — currently the
`Mock*` demo providers, so the whole app works with zero configuration.
Swapping in OpenAI, Anthropic, Gemini, OpenRouter, vLLM, Ollama, ElevenLabs,
Whisper, or a custom backend means implementing the protocol and updating
`ServiceContainer` — no call site elsewhere changes.

### No hardcoded secrets

The iOS client never embeds an AI provider API key. `APIConfiguration`
describes only a backend base URL (plus an optional shared secret, not a
provider key):

```
iPhone → Contra Backend / API Gateway → AI Provider
```

A developer-mode custom endpoint (Settings → AI → Developer Mode) lets you
point the app at a local or staging backend for testing.

## Real AI backend (`backend/`)

`backend/worker` is a small Cloudflare Worker that proxies the app to
Anthropic — the one real, non-mock `AIChatService`/`DocumentProcessingService`
backend. It holds the Anthropic API key as a Cloudflare secret; the app never
sees it. One deployment can be shared by a group — each person gets their
own access code with its own daily request limit, so nobody can burn
through everyone else's quota (or your bill).

**Deploy it and turn on real AI:** see [`backend/README.md`](backend/README.md)
for the full setup (including setting a hard spend cap on Anthropic — do
that part first), then in the app go to **Settings → AI**, turn off
"Use demo AI provider", turn on Developer Mode, and paste in the Worker's
URL and your own access code.

With it enabled: `generateWorkspaceTitle` and chat (`AIChatService`) call
real Claude, and `DocumentProcessingService` extracts real text — PDFKit for
PDF/text files, a lightweight HTML strip for websites — then asks the
backend to turn that into grounded notebook blocks and slides. YouTube,
Google Docs, and audio sources don't have an extraction path wired up yet
(transcript fetch / speech-to-text), so those still fall back to demo
content even with real AI turned on. If the backend is unreachable or
misconfigured, processing degrades to demo content automatically rather than
failing the screen.

Podcast audio and speech-to-text/text-to-speech remain mocked — see Known
limitations below.

## Requirements

- Xcode 15+ (iOS 17 SDK)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) to generate the `.xcodeproj`
- No CocoaPods / SPM dependencies — Apple frameworks only

## Local development (macOS)

```bash
brew install xcodegen
xcodegen generate
open ContraLLM.xcodeproj
```

Build and run on the iOS 17+ simulator or a device from Xcode.

> This repository does not commit a `.xcodeproj` — it is generated
> reproducibly from `project.yml` by XcodeGen, both locally and in CI.

## GitHub Actions build

`.github/workflows/build-ios.yml` builds an **unsigned** IPA on a
`macos-latest` GitHub-hosted runner:

Checkout → install XcodeGen → generate project → validate → `xcodebuild`
Release build for `iphoneos` with code signing disabled → package the `.app`
into `Payload/` → zip to `ContraLLM-unsigned.ipa` → upload as the
`ContraLLM-IPA` artifact.

It runs on every push that touches app source, and can also be triggered
manually via **Actions → Build iOS IPA → Run workflow**.

The IPA is published two ways so it stays downloadable even if your
account's Actions artifact storage is full:

- **Actions artifact** named `ContraLLM-IPA` (zip you extract)
- **GitHub Release** named `build-<run number>` with `ContraLLM-unsigned.ipa`
  attached directly (release assets don't count against Actions storage quota)

## Download the IPA

**Option A — from Releases (recommended, always available):**

1. Open this repository on GitHub
2. Go to the **Releases** section (right sidebar, or `/releases`)
3. Open the latest `build-N` release
4. Download `ContraLLM-unsigned.ipa` from its assets

**Option B — from Actions artifact:**

1. Open this repository on GitHub
2. Go to **Actions**
3. Select **Build iOS IPA**
4. Click **Run workflow** (or open the latest run)
5. Wait for the build to finish
6. Download the **ContraLLM-IPA** artifact
7. Extract the zip — you'll get `ContraLLM-unsigned.ipa`

## Installing with Sideloadly

1. Install and open [Sideloadly](https://sideloadly.io/) on your computer
2. Connect your iPhone via USB (or Wi-Fi, per Sideloadly's setup)
3. Drag `ContraLLM-unsigned.ipa` into Sideloadly, or click the IPA field and select it
4. Enter the Apple ID you want to sign the app with, following Sideloadly's
   own signing flow
5. Click **Start** and wait for Sideloadly to sign and install the app
6. On your iPhone, go to **Settings → General → VPN & Device Management** and
   trust the developer certificate for the installed app
7. Launch **Contra** from your home screen

> Never store your Apple ID or password in this repository. Sideloadly
> handles signing locally on your machine.

## Backend integration

The app is built to talk to a backend, not to AI providers directly. To wire
up a real backend:

1. Implement the `Services/*` protocols against your backend's REST/streaming API
2. Point `APIConfiguration.baseURL` at your backend (via Settings' developer
   mode, or a build-time default)
3. Update `ServiceContainer` to use the production implementations instead
   of the `Mock*` ones
4. Keep all provider secrets server-side; the client only ever calls your backend

## AI provider architecture

```
iPhone (ContraLLM)
   │  protocols: AIChatService, PodcastService, TextToSpeechService, ...
   ▼
Contra Backend / API Gateway   ← secrets live here (GitHub Secrets / server env)
   ▼
AI Provider (OpenAI / Anthropic / Gemini / OpenRouter / vLLM / Ollama / ElevenLabs / Whisper / ...)
```

## Known limitations

- By default the app uses mock/demo providers — no network calls, no API
  key required. Real AI chat and document processing are available by
  deploying `backend/` and switching it on in Settings (see above);
  podcast/speech still use mock providers either way.
- Real document processing only extracts text on-device for PDF, plain
  text/document files, and websites (basic HTML strip). YouTube, Google
  Docs, and audio sources still use demo content since transcript
  fetch/speech-to-text aren't wired up yet.
- Podcast audio playback is UI-complete but has no real synthesized audio
  file in demo mode (no `audioURL`)
- Speech-to-text/text-to-speech are stubbed; wiring to Apple's Speech
  framework, a backend, or ElevenLabs/Whisper is a drop-in swap via the
  existing protocols
- The generated IPA is unsigned — signing/installation is handled by
  Sideloadly, not this repository
- CI build verification requires GitHub Actions (a `macos-latest` runner);
  there is no macOS available in the authoring environment for this project
