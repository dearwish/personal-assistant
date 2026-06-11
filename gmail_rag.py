"""Shared embedchain RAG factory for the Gmail chat / OpenClaw integration.

Used by both index_gmail.py (builds the vector DB) and ask_gmail.py (queries it).

Design choices vs. the original 30-line tutorial:
  * The Chroma vector DB is PERSISTED to a fixed directory (not a tempdir), so
    indexing happens once and every query just loads it -- fast and cheap.
  * The answering model is GPT-4o via OpenRouter (OpenAI-API-compatible).
  * Embeddings run LOCALLY (sentence-transformers). OpenRouter has no embeddings
    endpoint, so we can't use it for that half of RAG.
"""

import os

from embedchain import App

# Resolve paths relative to this file so the scripts work from any cwd
# (cron and OpenClaw invoke them from elsewhere).
HERE = os.path.dirname(os.path.abspath(__file__))

# Where the persisted Chroma vector DB lives. Override with GMAIL_DB_DIR.
DB_DIR = os.environ.get("GMAIL_DB_DIR", os.path.join(HERE, "gmail_db"))


def _require(name: str) -> str:
    value = os.environ.get(name)
    if not value:
        raise SystemExit(
            f"Missing required env var: {name}. Set it in {os.path.join(HERE, '.env')}"
        )
    return value


def build_app() -> App:
    """Build an embedchain App pointed at the persisted Gmail vector DB."""
    api_key = _require("OPENROUTER_API_KEY")
    base_url = os.environ.get("OPENROUTER_BASE_URL", "https://openrouter.ai/api/v1")
    model = os.environ.get("RAG_MODEL", "openai/gpt-4o")

    # OpenRouter is OpenAI-API-compatible -- we just repoint the OpenAI client.
    # Belt-and-suspenders: some embedchain versions read base_url from the config
    # block below, others from these env vars. Embeddings are LOCAL (HuggingFace),
    # so repointing the OpenAI base URL only affects the chat model -- never the
    # embedder.
    os.environ.setdefault("OPENAI_API_KEY", api_key)
    os.environ["OPENAI_API_BASE"] = base_url
    os.environ["OPENAI_BASE_URL"] = base_url

    return App.from_config(
        config={
            "llm": {
                "provider": "openai",
                "config": {
                    "model": model,
                    "temperature": 0.5,
                    "api_key": api_key,
                    "base_url": base_url,
                },
            },
            "vectordb": {
                "provider": "chroma",
                "config": {"dir": DB_DIR, "collection_name": "gmail_inbox"},
            },
            "embedder": {
                # Local sentence-transformers model: no API key, runs on the VM.
                # To switch to OpenAI embeddings (needs a real OpenAI key, NOT an
                # OpenRouter one), use provider "openai". For Ollama, use
                # provider "ollama" with a model like "nomic-embed-text".
                "provider": "huggingface",
                "config": {"model": "sentence-transformers/all-MiniLM-L6-v2"},
            },
        }
    )
