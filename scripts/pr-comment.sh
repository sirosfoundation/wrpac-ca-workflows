#!/usr/bin/env bash
# Create or update one comment per marker on a pull request, so a re-run
# replaces its earlier output instead of stacking a new comment each time.
#
#   pr-comment.sh <repo> <pr-number> <marker> <body-file>
set -euo pipefail
REPO="$1"; PR="$2"; MARKER="$3"; BODY_FILE="$4"

body="$(printf '<!-- %s -->\n' "$MARKER"; cat "$BODY_FILE")"
existing="$(gh api "repos/${REPO}/issues/${PR}/comments" --paginate \
  --jq ".[] | select(.body | startswith(\"<!-- ${MARKER} -->\")) | .id" | head -1)"

if [[ -n "$existing" ]]; then
  gh api -X PATCH "repos/${REPO}/issues/comments/${existing}" -f body="$body" >/dev/null
else
  gh api -X POST "repos/${REPO}/issues/${PR}/comments" -f body="$body" >/dev/null
fi
