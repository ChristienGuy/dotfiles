#!/bin/bash

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command')

# Match only where a command starts (line start, or after ; & | ( or $( plus optional VAR=x prefixes),
# so text inside a grep pattern or a commit message does not trigger a block.
START='(^|[;&|(]|\$\()[[:space:]]*([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*'

runs() { echo "$COMMAND" | grep -qE "$START$1"; }

block() {
  echo "BLOCKED: $1" >&2
  exit 2
}

if runs 'gh[[:space:]]+pr[[:space:]]+create\b'; then
  block "Use \`gh stack submit --auto\` to open PRs, not \`gh pr create\`. --auto opens new PRs as drafts."
fi

# Only the human moves a PR out of draft.
if runs 'gh[[:space:]]+pr[[:space:]]+ready\b' || echo "$COMMAND" | grep -qE 'markPullRequestReadyForReview'; then
  block "Do not mark PRs ready for review. The human changes draft state."
fi

# Without --auto the interactive editor defaults new PRs to ready; --open promotes new and existing PRs.
if runs 'gh[[:space:]]+stack[[:space:]]+(submit|link)\b' && echo "$COMMAND" | grep -qE '(^|[[:space:]])--open\b'; then
  block "Do not pass --open to \`gh stack submit\` or \`gh stack link\`. It marks PRs ready for review. The human changes draft state."
fi
if runs 'gh[[:space:]]+stack[[:space:]]+submit\b' && ! echo "$COMMAND" | grep -qE '(^|[[:space:]])--auto\b'; then
  block "Run \`gh stack submit --auto\`. Without --auto, new PRs can open as ready for review."
fi

# Stacks opened with git-spice before the switch to gh-stack: --draft/--no-draft/--fill/-c demote ready PRs.
if runs 'gs[[:space:]]+branch[[:space:]]+submit\b' && echo "$COMMAND" | grep -qE '(--draft|--no-draft|--fill|[[:space:]]-c\b)'; then
  block "Do not pass --draft/--no-draft/--fill/-c to \`gs branch submit\`. Run it plain. The human changes draft state."
fi

if runs 'git[[:space:]]+checkout[[:space:]]+-b\b' || runs 'git[[:space:]]+switch[[:space:]]+(-c|--create)\b'; then
  block "Use \`gh stack init <branch>\` or \`gh stack add <branch>\` to create branches."
fi

if runs 'git[[:space:]]+push\b'; then
  block "Use \`gh stack push\` or \`gh stack submit --auto\` to push, not \`git push\`."
fi

if runs 'git[[:space:]]+remote[[:space:]]+(set-url|add|remove|rm|rename)\b[^|;&]*\borigin\b'; then
  block "Refusing to modify the \`origin\` remote (set-url/add/remove/rename). If this is intentional, run the command yourself."
fi

if runs 'git[[:space:]]+config\b[^|;&]*\bremote\.origin\.'; then
  block "Refusing to modify \`remote.origin.*\` via git config. If this is intentional, run the command yourself."
fi

exit 0
