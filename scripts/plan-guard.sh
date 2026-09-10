#!/usr/bin/env bash
# Refuse to re-register a revoked client unless this change touched its spec.
#
#   plan-guard.sh <plan-file> <changed-files-file>
#
# apply treats "entry revoked, spec not revoked" as a re-registration and mints
# a new certificate. That is right when a party comes back deliberately, and
# wrong when the entry was revoked out of band (the emergency revoke workflow)
# and the spec has simply not caught up yet: the next unrelated merge would
# silently undo the revocation. A spec edited in the same change is the signal
# that a human meant it.
set -euo pipefail
PLAN="$1"; CHANGED="$2"; rc=0
# Plan lines are "ACTION  CLIENT  REASON" with a header row.
while IFS= read -r line; do
  kind="$(awk '{print $1}' <<<"$line")"
  id="$(awk '{print $2}' <<<"$line")"
  [[ "$kind" == "issue" && "$line" == *"re-registering a revoked client"* ]] || continue
  if ! grep -Eq "^clients/${id}\.ya?ml$" "$CHANGED"; then
    echo "::error::${id} is revoked in the register but not in its spec, and this change did not touch clients/${id}.yaml. Set 'revoked: true' to reconcile, or edit the spec deliberately to re-register."
    rc=1
  fi
done < <(tail -n +2 "$PLAN")
exit $rc
