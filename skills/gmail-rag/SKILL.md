---
name: gmail-rag
description: >-
  Answer questions about the user's own Gmail inbox using a local RAG index.
  Use this whenever the user asks about their email or messages — what someone
  sent, when, summaries of threads, "did I get an email about X", invoices,
  receipts, who emailed me, etc. Do NOT use it for sending mail or for general
  web questions.
---

# Gmail Chat

The user's Gmail inbox is indexed into a local vector database on this machine.
A helper script answers questions against it.

## Answer a question about the user's email

Run the helper script with the user's question as a single quoted argument:

```bash
/opt/gmail-rag/venv/bin/python /opt/gmail-rag/ask_gmail.py "<the user's question, verbatim>"
```

- Pass the user's question through as-is (rephrase only to resolve pronouns like
  "it"/"that" using the conversation).
- The script prints the answer to stdout. **Relay that stdout to the user as the
  answer.** Do not add facts that aren't in it.
- Queries take a few seconds (it loads the index, then asks the model). That's
  expected — don't retry on a slow response.

## Refresh the index (only if asked for the very latest mail)

The index auto-refreshes on a schedule (cron). Only run this if the user
explicitly wants brand-new mail included right now:

```bash
cd /opt/gmail-rag && /opt/gmail-rag/venv/bin/python index_gmail.py
```

## Troubleshooting

- **`Missing required env var: OPENROUTER_API_KEY`** → the `.env` file at
  `/opt/gmail-rag/.env` is missing or not readable by this process.
- **An error mentioning `credentials.json` / `token` / OAuth** → the Gmail OAuth
  token needs to be (re)minted. Tell the user to run `index_gmail.py` once
  interactively from the RDP desktop session. (Only indexing touches Gmail;
  answering does not.)
- **`no such collection` / empty answers** → the inbox hasn't been indexed yet;
  run the refresh command above once.

> Adjust `/opt/gmail-rag` to wherever you installed the project on the VM.
