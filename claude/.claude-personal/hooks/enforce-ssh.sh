#!/bin/bash

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command')

# Block mutations to the `origin` remote.
if echo "$COMMAND" | grep -qE '\bgit\s+remote\s+(set-url|add|rename|rm|remove|delete)\b[^|;&]*\borigin\b'; then
  echo "BLOCKED: changing the git remote named 'origin' requires explicit user approval. Ask first." >&2
  exit 2
fi

# Block `git config` rewrites of remote.origin.url and any insteadOf override
# (via `git config` or `git -c`) — both route around the SSH-only push rule.
if echo "$COMMAND" | grep -qE '\bgit\s+config\b[^|;&]*\bremote\.origin\.url\b|\bgit\s+config\b[^|;&]*\binsteadOf\b|\bgit\s+-c\s+[^|;&]*\binsteadOf\b'; then
  echo "BLOCKED: rewriting origin's URL via git config / insteadOf requires explicit user approval. Ask first." >&2
  exit 2
fi

# Block explicit-URL HTTPS pushes to github.com. SSH is the only sanctioned
# push path; if SSH fails, surface the error instead of routing around it.
if echo "$COMMAND" | grep -qE '\bgit\s+push\b[^|;&]*https?://[^|;&]*github\.com'; then
  echo "BLOCKED: SSH is the only allowed push path to github.com. If git push over SSH fails, surface the exact error instead of routing around it." >&2
  exit 2
fi

exit 0
