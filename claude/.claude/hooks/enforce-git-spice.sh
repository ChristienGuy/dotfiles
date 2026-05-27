#!/bin/bash

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command')

# Block gh pr create — use gs branch submit instead
if echo "$COMMAND" | grep -qE '\bgh\s+pr\s+create\b'; then
  echo "BLOCKED: Use \`gs branch submit --draft\` to create PRs, not \`gh pr create\`. (--draft is for creating a new PR only; omit it when updating an existing PR so its current draft/ready state is preserved.)" >&2
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
