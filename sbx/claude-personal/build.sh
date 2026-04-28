#!/usr/bin/env bash
# Build the claude-personal sbx image from ~/.claude-personal.
#
# Uses an explicit allowlist of files/dirs to bake in — everything else
# (credentials, sessions, history, caches, project state) stays out.
set -euo pipefail

cd "$(dirname "$0")"

SRC="$HOME/.claude-personal"
DST="./snapshot"

if [ ! -d "$SRC" ]; then
  echo "error: $SRC does not exist" >&2
  exit 1
fi

# Explicit allowlist — add items here as your personal config grows.
ALLOW=(
  settings.json
  CLAUDE.md
  RTK.md
  keybindings.json
  statusline-command.sh
  agents
  commands
  hooks
  skills
  plugins
)

rm -rf "$DST"
mkdir -p "$DST"

for item in "${ALLOW[@]}"; do
  if [ -e "$SRC/$item" ]; then
    cp -RL "$SRC/$item" "$DST/"
  fi
done

# Starship config (stow-linked to dotfiles/starship) — deref so a real file
# lands in the image.
STARSHIP_SRC="$HOME/.config/starship.toml"
if [ -e "$STARSHIP_SRC" ]; then
  cp -L "$STARSHIP_SRC" "$DST/starship.toml"
fi

# The baked settings.json references the host absolute path to the statusline
# script. Rewrite to the in-VM path where the Dockerfile places it.
if [ -f "$DST/settings.json" ]; then
  sed -i '' \
    -e 's|/Users/[^/]*/\.claude/statusline-command\.sh|/home/agent/.claude-personal/statusline-command.sh|g' \
    "$DST/settings.json"
fi

# Plugin manifests record absolute installPaths under the host home. The runtime
# bind-mounts /Users/<user>/projects/<workdir> as root:root, which destroys any
# build-time symlink we'd put at /Users/<user>/.claude-personal. Rewrite the
# manifests to point directly at the in-VM location.
for f in "$DST/plugins/installed_plugins.json" "$DST/plugins/known_marketplaces.json"; do
  if [ -f "$f" ]; then
    sed -i '' \
      -e 's|/Users/[^/]*/\.claude-personal|/home/agent/.claude-personal|g' \
      "$f"
  fi
done

IMAGE="claude-personal:latest"
TAR="$(mktemp -t claude-personal.XXXXXX.tar)"
trap 'rm -f "$TAR"; rm -rf "$DST"' EXIT

docker build -t "$IMAGE" .

# sbx runs in its own microVM with its own Docker daemon — it cannot see
# host-local images. Export the host image and load it into sbx's template store.
docker save "$IMAGE" -o "$TAR"
sbx template load "$TAR"

echo
echo "Built and loaded $IMAGE into sbx."
echo "Run with: sbx run --template $IMAGE claude --dangerously-skip-permissions"
