#!/usr/bin/env bash
# Commit everything under the state checkout and push, rebasing on a
# concurrent push up to three times. The HSM jobs are serialized by a
# concurrency group, so a conflict here means a human pushed to the state
# repository, which the ruleset is meant to prevent; the retry covers the
# Pages workflow or a merge commit, not a real conflict.
#
#   commit-state.sh <state-dir> <message>
set -euo pipefail
cd "$1"; MSG="$2"

git config user.name  "wrpac-ca[bot]"
git config user.email "wrpac-ca@users.noreply.github.com"
git add -A
if git diff --cached --quiet; then
  echo "state unchanged"
  echo "changed=false" >> "${GITHUB_OUTPUT:-/dev/null}"
  exit 0
fi
git commit -q -m "$MSG"
for attempt in 1 2 3; do
  if git push -q origin HEAD; then
    echo "changed=true" >> "${GITHUB_OUTPUT:-/dev/null}"
    echo "sha=$(git rev-parse HEAD)" >> "${GITHUB_OUTPUT:-/dev/null}"
    exit 0
  fi
  echo "push rejected, rebasing (attempt $attempt)"
  git pull -q --rebase origin HEAD
done
echo "could not push state after 3 attempts" >&2
exit 1
