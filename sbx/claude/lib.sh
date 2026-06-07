# Shared helpers for build.sh.
# This file is meant to be sourced, not executed.

# Config names, baked in. The sandbox runs Claude Code against ~/.claude-personal.
#
# vm_dir_name MUST NOT be ".claude": sbx's claude-code template treats
# /home/agent/.claude/ as its own managed dir and rewrites settings.json on each
# boot, silently stripping our baked statusLine/hooks/plugins.
host_dir_name=".claude-personal"
vm_dir_name=".claude-personal"
image_name="claude-personal"

# Build the snapshot tree at $1 from ~/$host_dir_name.
build_snapshot() {
  local DST="$1"
  local SRC="$HOME/$host_dir_name"

  if [ ! -d "$SRC" ]; then
    echo "error: $SRC does not exist" >&2
    return 1
  fi

  # Items copied if present. Add new config items here as the config grows.
  local ALLOW=(
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

  # Items where missing-on-host means a broken sandbox — fail the build
  # instead of silently shipping an incomplete snapshot. Plugins in particular
  # is what bit us: a missing plugins/ dir produced an image with no MCPs and
  # nothing flagged the gap.
  local REQUIRED=(
    settings.json
    CLAUDE.md
    statusline-command.sh
    plugins
  )

  rm -rf "$DST"
  mkdir -p "$DST"

  local missing=()
  local item
  for item in "${ALLOW[@]}"; do
    if [ -e "$SRC/$item" ]; then
      cp -RL "$SRC/$item" "$DST/"
    fi
  done

  local req
  for req in "${REQUIRED[@]}"; do
    if [ ! -e "$DST/$req" ]; then
      missing+=("$req")
    fi
  done

  if [ ${#missing[@]} -gt 0 ]; then
    echo "error: required snapshot items missing from $SRC:" >&2
    local m
    for m in "${missing[@]}"; do
      echo "  - $m" >&2
    done
    return 1
  fi

  # Starship config (stow-linked to dotfiles/starship) — deref so a real file
  # lands in the snapshot.
  local STARSHIP_SRC="$HOME/.config/starship.toml"
  if [ -e "$STARSHIP_SRC" ]; then
    cp -L "$STARSHIP_SRC" "$DST/starship.toml"
  fi

  # settings.json references the host's /Users/<user>/.claude/statusline-command.sh
  # path (it's a stow link to a file that hardcodes that path). Rewrite to the
  # in-VM path under the config dir.
  if [ -f "$DST/settings.json" ]; then
    sed -i '' \
      -e "s|/Users/[^/]*/\.claude/statusline-command\.sh|/home/agent/${vm_dir_name}/statusline-command.sh|g" \
      "$DST/settings.json"
  fi

  # Plugin manifests record absolute installPaths under the host home. The
  # runtime bind-mounts /Users/<user>/projects/<workdir> as root:root, which
  # destroys any build-time symlink we'd put at /Users/<user>/<host_dir_name>.
  # Rewrite the manifests to point directly at the in-VM location.
  local f
  for f in "$DST/plugins/installed_plugins.json" "$DST/plugins/known_marketplaces.json"; do
    if [ -f "$f" ]; then
      sed -i '' \
        -e "s|/Users/[^/]*/${host_dir_name}/|/home/agent/${vm_dir_name}/|g" \
        "$f"
    fi
  done
}

