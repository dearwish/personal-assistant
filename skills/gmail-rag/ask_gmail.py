"""Answer a single question against the already-indexed Gmail inbox.

This is what OpenClaw's `gmail-chat` skill calls per Telegram message. It only
loads the persisted vector DB and queries it -- it does NOT touch Gmail, so it
needs no Google credentials and runs in a couple of seconds.

Usage:
    python ask_gmail.py "what did Stripe email me about last week?"
"""

import os
import sys

from dotenv import load_dotenv

from gmail_rag import build_app

load_dotenv(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".env"))


def main() -> None:
    question = " ".join(sys.argv[1:]).strip()
    if not question:
        sys.exit('usage: python ask_gmail.py "<your question>"')

    app = build_app()
    answer = app.query(question)
    # Print ONLY the answer to stdout -- the OpenClaw skill relays stdout verbatim.
    print(answer)


if __name__ == "__main__":
    main()
