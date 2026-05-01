#!/usr/bin/env bash
# Build the sbx image for one of the user's claude configs.
#
# Usage: build.sh [personal|work]   (default: personal)
#
#   personal → ~/.claude-personal → image claude-personal:latest
#   work     → ~/.claude           → image claude-work:latest
#
# Uses an explicit allowlist of files/dirs to bake in — everything else
# (credentials, sessions, history, caches, project state) stays out.
set -euo pipefail

cd "$(dirname "$0")"

flavor="${1:-personal}"

# host_dir_name: where the source config lives on the host (~/<host_dir_name>).
# vm_dir_name:   where it lands inside the sandbox (/home/agent/<vm_dir_name>).
# These must NOT both be ".claude" for the work flavor: sbx's claude-code
# template treats /home/agent/.claude/ as its own managed directory and
# overwrites settings.json (plus .claude.json, .credentials.json, etc.) on
# first run, which silently strips our baked statusLine/hooks/enabledPlugins.
# Personal works by accident because it lives at /home/agent/.claude-personal/.
case "$flavor" in
  personal)
    host_dir_name=".claude-personal"
    vm_dir_name=".claude-personal"
    image_name="claude-personal"
    ;;
  work)
    host_dir_name=".claude"
    vm_dir_name=".claude-work"
    image_name="claude-work"
    ;;
  *)
    echo "usage: $0 [personal|work]" >&2
    exit 1
    ;;
esac

SRC="$HOME/$host_dir_name"
DST="./snapshot"

if [ ! -d "$SRC" ]; then
  echo "error: $SRC does not exist" >&2
  exit 1
fi

# Explicit allowlist — add items here as either config grows.
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

# Both settings.json files reference the host's /Users/<user>/.claude/statusline-command.sh
# path (personal's settings.json is a stow link to a file that hardcodes the
# work-style path). Rewrite to the in-VM path under whichever config dir this
# build is targeting.
if [ -f "$DST/settings.json" ]; then
  sed -i '' \
    -e "s|/Users/[^/]*/\.claude/statusline-command\.sh|/home/agent/${vm_dir_name}/statusline-command.sh|g" \
    "$DST/settings.json"
fi

# Plugin manifests record absolute installPaths under the host home. The runtime
# bind-mounts /Users/<user>/projects/<workdir> as root:root, which destroys any
# build-time symlink we'd put at /Users/<user>/<host_dir_name>. Rewrite the
# manifests to point directly at the in-VM location. Trailing slash on the
# search pattern keeps the .claude flavor from matching .claude-personal paths.
for f in "$DST/plugins/installed_plugins.json" "$DST/plugins/known_marketplaces.json"; do
  if [ -f "$f" ]; then
    sed -i '' \
      -e "s|/Users/[^/]*/${host_dir_name}/|/home/agent/${vm_dir_name}/|g" \
      "$f"
  fi
done

IMAGE="${image_name}:latest"
TAR="$(mktemp -t "${image_name}".XXXXXX.tar)"
trap 'rm -f "$TAR"; rm -rf "$DST"' EXIT

docker build \
  --build-arg "CLAUDE_CONFIG_DIR_NAME=${vm_dir_name}" \
  -t "$IMAGE" .

# sbx runs in its own microVM with its own Docker daemon — it cannot see
# host-local images. Export the host image and load it into sbx's template store.
docker save "$IMAGE" -o "$TAR"
sbx template load "$TAR"

echo
echo "Built and loaded $IMAGE into sbx."
echo "Run with: sbx run --template $IMAGE claude"
