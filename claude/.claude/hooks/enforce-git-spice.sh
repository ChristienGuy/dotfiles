#!/bin/bash

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command')

# Block gh pr create — use gs branch submit instead
if echo "$COMMAND" | grep -qE '\bgh\s+pr\s+create\b'; then
  echo "BLOCKED: Use \`gs branch submit\` to create PRs, not \`gh pr create\`. New PRs are draft automatically (spice.submit.draft=true); do NOT pass draft flags." >&2
  exit 2
fi

# Block draft-state-changing flags on `gs branch submit`.
# New PRs are draft by default via `spice.submit.draft=true`; a plain `gs branch submit`
# on an existing PR preserves its current draft/ready state. Passing --draft/--no-draft/--fill/-c
# overrides that and has repeatedly demoted human-set "ready" PRs back to draft. Never do it.
# To intentionally change draft state, the human runs the flag themselves.
if echo "$COMMAND" | grep -qE '\bgs\s+branch\s+submit\b' && echo "$COMMAND" | grep -qE '(--draft|--no-draft|--fill|[[:space:]]-c\b)'; then
  echo "BLOCKED: Do not pass --draft/--no-draft/--fill/-c to \`gs branch submit\`. New PRs are draft via config; plain \`gs branch submit\` preserves the PR's existing state. Run a plain \`gs branch submit\`. If you truly need to change draft state, do it yourself." >&2
  exit 2
fi

# Block git checkout -b — use gs branch create instead
if echo "$COMMAND" | grep -qE '\bgit\s+checkout\s+-b\b'; then
  echo "BLOCKED: Use \`gs branch create <name>\` to create branches, not \`git checkout -b\`." >&2
  exit 2
fi

# Block git switch -c / --create — use gs branch create instead
if echo "$COMMAND" | grep -qE '\bgit\s+switch\s+(-c|--create)\b'; then
  echo "BLOCKED: Use \`gs branch create <name>\` to create branches, not \`git switch -c\`." >&2
  exit 2
fi

# Block git push — use gs branch submit or gs stack submit instead
if echo "$COMMAND" | grep -qE '\bgit\s+push\b'; then
  echo "BLOCKED: Use \`gs branch submit\` or \`gs stack submit\` to push, not \`git push\`." >&2
  exit 2
fi

# Block mutations to the `origin` remote. Catches `git remote set-url|add|remove|rm|rename ... origin ...`
# in either argument position (e.g. `rename foo origin` as well as `rename origin foo`).
if echo "$COMMAND" | grep -qE '\bgit\s+remote\s+(set-url|add|remove|rm|rename)\b[^|;&]*\borigin\b'; then
  echo "BLOCKED: Refusing to modify the \`origin\` remote (set-url/add/remove/rename). If this is intentional, run the command yourself." >&2
  exit 2
fi

# Block `git config` writes targeting remote.origin.* (covers set, --unset, --add, --replace-all).
if echo "$COMMAND" | grep -qE '\bgit\s+config\b[^|;&]*\bremote\.origin\.'; then
  echo "BLOCKED: Refusing to modify \`remote.origin.*\` via git config. If this is intentional, run the command yourself." >&2
  exit 2
fi

exit 0
