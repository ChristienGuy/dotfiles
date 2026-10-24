#!/bin/bash

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command')

# Match only at command position (also inside wrappers, `sh -c '...'`, eval, backticks),
# so blocked text inside a grep pattern or a commit message does not trigger a block.
SEP='(^|[;&|({!`]|\$\(|[[:space:]]-[A-Za-z]*c[[:space:]]+["'"'"']?|eval[[:space:]]+["'"'"']?)'
WRAP='((then|do|else|elif|env|command|builtin|exec|eval|nohup|time|nice|sudo|xargs)([[:space:]]+-[^[:space:]]+)*[[:space:]]+)*'
START="$SEP[[:space:]]*([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*$WRAP"
# Global options before the subcommand, e.g. `git -C dir push`, `gh -R owner/repo pr create`.
OPTS='([[:space:]]+-{1,2}[A-Za-z][A-Za-z-]*(=[^[:space:]]*)?([[:space:]]+[^-[:space:]][^[:space:]]*)?)*'
GIT="git$OPTS[[:space:]]+"
GH="gh$OPTS[[:space:]]+"
# `gs` is a shell alias for `gh stack`.
STACK="(${GH}stack|gs)"

runs() { echo "$COMMAND" | grep -qE "$START$1"; }

block() {
  echo "BLOCKED: $1" >&2
  exit 2
}

if runs "${GH}pr[[:space:]]+create\b"; then
  block "Use \`gh stack submit --auto\` to open PRs, not \`gh pr create\`. --auto opens new PRs as drafts."
fi

# Only the human moves a PR out of draft.
if runs "${GH}pr[[:space:]]+ready\b" || echo "$COMMAND" | grep -qE 'markPullRequestReadyForReview'; then
  block "Do not mark PRs ready for review. The human changes draft state."
fi

# Without --auto the interactive editor defaults new PRs to ready; --open promotes new and existing PRs.
if runs "$STACK$OPTS[[:space:]]+(submit|link)\b" && echo "$COMMAND" | grep -qE '(^|[[:space:]])--open\b'; then
  block "Do not pass --open to \`gh stack submit\` or \`gh stack link\`. It marks PRs ready for review. The human changes draft state."
fi
if runs "$STACK$OPTS[[:space:]]+submit\b" && ! echo "$COMMAND" | grep -qE '(^|[[:space:]])--auto\b'; then
  block "Run \`gh stack submit --auto\`. Without --auto, new PRs can open as ready for review."
fi

if runs "${GIT}checkout[[:space:]]+-b\b" || runs "${GIT}switch[[:space:]]+(-c|--create)\b"; then
  block "Use \`gh stack init <branch>\` or \`gh stack add <branch>\` to create branches."
fi

if runs "${GIT}push\b"; then
  block "Use \`gh stack push\` or \`gh stack submit --auto\` to push, not \`git push\`."
fi

if runs "${GIT}remote[[:space:]]+(set-url|add|remove|rm|rename)\b[^|;&]*\borigin\b"; then
  block "Refusing to modify the \`origin\` remote (set-url/add/remove/rename). If this is intentional, run the command yourself."
fi

if runs "${GIT}config\b[^|;&]*\bremote\.origin\."; then
  block "Refusing to modify \`remote.origin.*\` via git config. If this is intentional, run the command yourself."
fi

exit 0
