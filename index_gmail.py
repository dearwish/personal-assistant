"""Build / refresh the persisted Gmail vector DB.

Run this:
  * ONCE interactively (in the RDP desktop session) the first time -- it opens a
    browser for the Google OAuth consent and writes the token. After that it's
    fully non-interactive.
  * On a schedule via cron to pick up new mail (see README).

embedchain's gmail loader reads `credentials.json` from the CURRENT WORKING
DIRECTORY and caches the OAuth token there, so always run this from the project
directory (the cron line in the README does `cd` first).
"""

import os

from dotenv import load_dotenv

from gmail_rag import DB_DIR, build_app

load_dotenv(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".env"))

# Which mail to index. Same Gmail search syntax you'd type in the Gmail box.
# Examples: "to: me label:inbox", "newer_than:90d", "from:boss@corp.com".
GMAIL_FILTER = os.environ.get("GMAIL_FILTER", "to: me label:inbox")


def main() -> None:
    app = build_app()
    print(f"Indexing Gmail (filter: {GMAIL_FILTER!r}) into {DB_DIR} ...")
    # embedchain de-dupes already-seen documents, so re-running only adds new mail.
    app.add(GMAIL_FILTER, data_type="gmail")
    print("Done. Vector DB is ready at", DB_DIR)


if __name__ == "__main__":
    main()
