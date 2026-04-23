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

exit 0
