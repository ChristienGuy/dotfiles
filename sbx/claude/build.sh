#!/usr/bin/env bash
# Build the sbx image for one of the user's claude configs.
#
# Usage: build.sh [personal|work]   (default: personal)
#
#   personal → ~/.claude-personal → image claude-personal:latest
#   work     → ~/.claude           → image claude-work:latest
#
# Uses an explicit allowlist of files/dirs to bake in — everything else
# (credentials, sessions, history, caches, project state) stays out. Required
# items missing from the source dir cause a hard failure instead of producing
# a silently-broken image (see lib.sh).
set -euo pipefail

cd "$(dirname "$0")"

# shellcheck source=lib.sh
. ./lib.sh

flavor="${1:-personal}"
flavor_to_names "$flavor"

DST="./snapshot"
build_snapshot "$DST"

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
