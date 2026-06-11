# Gmail Chat → OpenClaw → Telegram

Chat with your Gmail inbox **from Telegram**, using your existing
[OpenClaw](https://openclaw.ai/) assistant as the front-end.

This is a headless rework of the [Streamlit gmail tutorial](https://github.com/Shubhamsaboo/awesome-llm-apps/tree/main/advanced_llm_apps/chat_with_X_tutorials/chat_with_gmail):
same RAG engine (`embedchain`), but split into scripts that OpenClaw can call,
with a **persisted** vector DB so questions are fast and cheap.

```
You ──(Telegram)──▶ OpenClaw ──matches the "gmail-rag" skill──▶ ask_gmail.py
                       ▲                                              │
                       └──────────── answer ◀── GPT-4o (OpenRouter) ◀─┘
                                                  over your indexed inbox

index_gmail.py ──(cron, daily)──▶ refreshes the persisted Chroma vector DB
```

- **Answering model:** GPT-4o via OpenRouter (OpenAI-API-compatible).
- **Embeddings:** local `sentence-transformers` (OpenRouter has no embeddings API).
- **Telegram:** handled entirely by OpenClaw — you write no bot code.

---

## Files

| File | Role |
|------|------|
| `gmail_rag.py` | Shared embedchain config (model, embedder, persisted DB) |
| `index_gmail.py` | Builds/refreshes the vector DB from your inbox (interactive once, then cron) |
| `ask_gmail.py` | Loads the DB and answers one question — what OpenClaw calls per message |
| `SKILL.md` | The OpenClaw skill that wires it to Telegram |
| `.env.example` | Config template |

---

## Setup on the VM

Assumes you'll install at `/opt/gmail-rag` — change to taste. You have RDP into
the VM's desktop (Microsoft Remote Desktop), which we use for the one-time Google
sign-in.

### 1. Get the code onto the VM

```bash
sudo mkdir -p /opt/gmail-rag && sudo chown "$USER" /opt/gmail-rag
# copy this skill folder's contents into /opt/gmail-rag, e.g. from a clone:
cp -r skills/gmail-rag/* /opt/gmail-rag/
cd /opt/gmail-rag
```

### 2. Python env + deps

```bash
python3 -m venv venv
./venv/bin/pip install -r requirements.txt
```

> First install is heavy — `sentence-transformers` pulls in torch. On a small
> droplet this can take a few minutes and ~2 GB. If RAM is tight, see
> **Lighter embeddings** below.

### 3. Google Cloud credentials

Create an OAuth client for the Gmail API (the
[upstream tutorial](https://github.com/Shubhamsaboo/awesome-llm-apps/tree/main/advanced_llm_apps/chat_with_X_tutorials/chat_with_gmail)
has step-by-step), then download the client secret as **`credentials.json`** into
`/opt/gmail-rag/`. While the app is in "Testing", add your Gmail address as a
**Test user** on the OAuth consent screen.

### 4. Configure

```bash
cp .env.example .env
nano .env          # paste your OPENROUTER_API_KEY
```

### 5. First index — run it **interactively over RDP**

This first run opens a browser for Google's consent screen, so do it in the RDP
desktop session (where a browser exists), not over plain SSH:

```bash
cd /opt/gmail-rag && ./venv/bin/python index_gmail.py
```

Sign in, approve access. It writes the OAuth token next to the scripts and builds
the vector DB. **Every run after this is non-interactive** (it reuses the token).

### 6. Smoke test

```bash
./venv/bin/python ask_gmail.py "summarize the emails I got this week"
```

If you get a sensible answer, the RAG half is done.

### 7. Auto-refresh with cron

Pull in new mail daily (adjust time/frequency). `cd` first so the Gmail token is
found; `.env` is loaded by the script itself:

```bash
crontab -e
```

```cron
0 6 * * * cd /opt/gmail-rag && /opt/gmail-rag/venv/bin/python index_gmail.py >> /opt/gmail-rag/index.log 2>&1
```

(You can equally use OpenClaw's built-in cron instead of system cron.)

---

## Wire it into OpenClaw

OpenClaw skills live in the agent's skills directory and are markdown +
scripts. Install this one:

```bash
# Path depends on which agent runtime your OpenClaw uses (Claude Code / Codex).
# Common locations:
ln -s /opt/gmail-rag ~/.claude/skills/gmail-rag
#   or
ln -s /opt/gmail-rag ~/.codex/skills/gmail-rag
```

If `/opt/gmail-rag` isn't your install path, edit the paths inside `SKILL.md`
to match.

Make sure **Telegram is enabled** as a channel in your OpenClaw config (it's a
built-in channel — see the OpenClaw docs), then restart OpenClaw so it picks up
the new skill.

---

## Use it

Message your OpenClaw bot on Telegram:

> *"What did my landlord email me about?"*
> *"Any unpaid invoices in my inbox?"*
> *"Summarize the thread with Acme from last week."*

OpenClaw recognizes these as `gmail-rag` requests, runs `ask_gmail.py`, and
replies with the answer.

---

## Notes & knobs

- **embedchain version sensitivity.** embedchain's config field names have
  shifted across releases. Everything provider-specific is isolated in
  `gmail_rag.py` (the `llm` / `embedder` blocks). If a query errors on config,
  that one file is the only place to adjust.
- **Lighter embeddings.** If torch is too heavy for the droplet, switch the
  `embedder` block in `gmail_rag.py` to OpenAI embeddings (needs a *real OpenAI*
  key, not OpenRouter) or to Ollama (`provider: "ollama"`, model
  `nomic-embed-text`) if you already run Ollama for OpenClaw.
- **Costs.** Embeddings are free/local. You only pay OpenRouter for GPT-4o
  answers — a few cents per question's worth of tokens.
- **What indexing touches Gmail, querying doesn't.** `ask_gmail.py` never calls
  Gmail (no creds needed); it only reads the local vector DB. Only
  `index_gmail.py` talks to Google.
- **Scope.** `GMAIL_FILTER` in `.env` controls what gets indexed. Narrow it
  (e.g. `newer_than:180d`) to keep the index small and answers focused.
- **Secrets.** Don't commit `.env`, `credentials.json`, the OAuth token, or
  `gmail_db/`. Add them to `.gitignore` if you version this.
