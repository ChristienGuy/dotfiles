FROM docker/sandbox-templates:claude-code

# Replace the base image's Node 20 with the current Active LTS (Node 24).
# Required for node:sqlite (>=22.13), used by jazz-tools/dist/mcp/server.js
# and a growing number of MCP servers. Verify the LTS line against
# https://nodejs.org/en/about/previous-releases before bumping the major.
USER root
RUN curl -fsSL https://deb.nodesource.com/setup_24.x | bash - \
 && apt-get install -y --no-install-recommends nodejs \
 && rm -rf /var/lib/apt/lists/* \
 && node --version \
 && node -e "require('node:sqlite')"

# git-spice (`gs`) — pinned. Bump GS_VERSION explicitly when upgrading.
# Auth piggybacks on `gh` (already in the base image), so no token baked in.
# openssh-client is installed here too: needed for git-over-SSH against
# github.com. sbx >=0.28 forwards the host SSH agent into the sandbox
# automatically (via SSH_AUTH_SOCK), so no key material ever enters the image.
ARG GS_VERSION=v0.26.1
RUN apt-get update \
 && apt-get install -y --no-install-recommends bash-completion openssh-client \
      fonts-dejavu fonts-liberation fontconfig \
 && mkdir -p /etc/ssh/ssh_config.d \
 && printf 'Host github.com\n  User git\n  StrictHostKeyChecking accept-new\n' \
      > /etc/ssh/ssh_config.d/github.conf \
 && rm -rf /var/lib/apt/lists/* \
 && case "$(uname -m)" in \
        aarch64) GS_ARCH=aarch64 ;; \
        x86_64)  GS_ARCH=x86_64 ;; \
        *) echo "unsupported arch: $(uname -m)" >&2; exit 1 ;; \
    esac \
 && tmpdir=$(mktemp -d) \
 && curl -fsSL "https://github.com/abhinav/git-spice/releases/download/${GS_VERSION}/git-spice.Linux-${GS_ARCH}.tar.gz" \
        | tar -xz -C "$tmpdir" git-spice \
 && install -m 0755 "$tmpdir/git-spice" /usr/local/bin/gs \
 && rm -rf "$tmpdir" \
 && gs --version \
 && gs shell completion bash > /etc/bash_completion.d/gs

# gh — install from GitHub's official apt repo (cli.github.com). The base
# image ships gh 2.46.0, which fails on `gh pr edit` because of a GraphQL
# deprecation warning for repository.pullRequest.projectCards (fixed in
# 2.47+). Floating version: future rebuilds pick up new releases.
RUN (type -p wget >/dev/null || (apt-get update && apt-get install -y --no-install-recommends wget)) \
 && mkdir -p -m 755 /etc/apt/keyrings \
 && out=$(mktemp) \
 && wget -nv -O"$out" https://cli.github.com/packages/githubcli-archive-keyring.gpg \
 && cat "$out" > /etc/apt/keyrings/githubcli-archive-keyring.gpg \
 && chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
 && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        > /etc/apt/sources.list.d/github-cli.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends gh \
 && rm -rf /var/lib/apt/lists/* \
 && gh --version

# rtk (Rust Token Killer) — pinned. Bump RTK_VERSION explicitly when upgrading.
# CLI proxy that compresses common dev command output before it reaches Claude's
# context. Hook entry (`rtk hook claude`) lives in the snapshot's settings.json,
# so this just needs to put `rtk` on PATH. Asymmetric Linux asset naming:
# musl on x86_64, gnu on aarch64.
ARG RTK_VERSION=v0.37.2
RUN case "$(uname -m)" in \
        aarch64) RTK_ASSET=rtk-aarch64-unknown-linux-gnu.tar.gz ;; \
        x86_64)  RTK_ASSET=rtk-x86_64-unknown-linux-musl.tar.gz ;; \
        *) echo "unsupported arch: $(uname -m)" >&2; exit 1 ;; \
    esac \
 && tmpdir=$(mktemp -d) \
 && curl -fsSL "https://github.com/rtk-ai/rtk/releases/download/${RTK_VERSION}/${RTK_ASSET}" \
        | tar -xz -C "$tmpdir" \
 && install -m 0755 "$tmpdir/rtk" /usr/local/bin/rtk \
 && rm -rf "$tmpdir" \
 && rtk --version

# workos CLI — pinned. Bump WORKOS_VERSION explicitly when upgrading.
# Used for AuthKit setup, org/user/role management, seed provisioning, and
# SSO/directory-sync debugging. Auth: WORKOS_API_KEY env var for management
# commands (no OAuth needed). The CLI auto-detects CLAUDE_CODE env and enters
# agent mode (no interactive prompts). @napi-rs/keyring has no D-Bus in the
# container, so --insecure-storage + ~/.workos/ file fallback is pre-staged.
ARG WORKOS_VERSION=0.15.2
RUN npm install -g "workos@${WORKOS_VERSION}" \
 && workos --version \
 && install -d -m 0700 -o agent -g agent /home/agent/.workos

# Make git-spice reuse gh CLI's auth without prompting.
# Stores {"type":"gh"} in a file-based stash (skipping the keyring,
# which isn't available in container sandboxes). gs will then shell
# out to `gh auth token` on every API call, so token rotation in gh
# propagates automatically. Requires gh CLI to be authenticated at
# runtime — typically via GH_TOKEN env var injected by the sandbox.
RUN git config --system spice.secret.backend file \
 && mkdir -p /home/agent/.config/git-spice \
 && printf '%s' '{"https://github.com":{"token":"{\"type\":\"gh\"}"}}' \
      > /home/agent/.config/git-spice/secrets.json \
 && chown -R agent:agent /home/agent/.config

# git-spice reads GITHUB_TOKEN; the sandbox proxy provides GH_TOKEN. Aliasing
# them in /etc/sandbox-persistent.sh (sourced via CLAUDE_ENV_FILE before every
# Bash tool call, and re-exported as BASH_ENV for non-interactive children)
# makes `gs auth status`, `gs repo sync`, `gs branch submit`, etc. work without
# a manual `gs auth login` per sandbox.
RUN printf '\n# git-spice reads GITHUB_TOKEN; the sandbox proxy provides GH_TOKEN.\nexport GITHUB_TOKEN="${GITHUB_TOKEN:-$GH_TOKEN}"\n' \
      >> /etc/sandbox-persistent.sh

# workos CLI: forward WORKOS_API_KEY from host (if set) and force file-based
# credential storage (no keyring in containers).
RUN printf '\n# workos CLI: forward API key and force file-based credential storage.\nexport WORKOS_API_KEY="${WORKOS_API_KEY:-}"\n' \
      >> /etc/sandbox-persistent.sh

# Global git pre-push hook: reject pushes targeting main/master.
# Uses core.hooksPath so every repo in the sandbox inherits the guard without
# needing per-repo .git/hooks setup.
RUN mkdir -p /etc/git/hooks \
 && printf '#!/bin/sh\nwhile read local_ref local_sha remote_ref remote_sha; do\n  case "$remote_ref" in\n    refs/heads/main|refs/heads/master)\n      echo "pre-push: refusing to push to $remote_ref" >&2\n      exit 1\n      ;;\n  esac\ndone\n' \
      > /etc/git/hooks/pre-push \
 && chmod +x /etc/git/hooks/pre-push \
 && git config --system core.hooksPath /etc/git/hooks

# pnpm: move the content-addressable store off the virtiofs-mounted source
# tree and force copy mode. esbuild's Go-based readdir intermittently misses
# hardlinked entries on virtiofs (node sees them, esbuild doesn't), which
# breaks vite/vitest optimizeDeps for any package whose dist/*.mjs files
# cross-import each other. Putting the store on container-local storage means
# pnpm copies into node_modules/.pnpm by default (cross-fs); package-import-method=copy
# is belt-and-suspenders so even same-fs installs don't hardlink. Baked into
# the agent user's ~/.npmrc since /etc/npmrc isn't a config path npm/pnpm
# read by default (the global path is $PREFIX/etc/npmrc).
RUN install -d -o agent -g agent /home/agent \
 && printf 'store-dir=/home/agent/.local/share/pnpm/store\npackage-import-method=copy\n' \
        > /home/agent/.npmrc \
 && chown agent:agent /home/agent/.npmrc

# Force polling-based file watchers for Node/Expo/Metro dev servers running
# against virtiofs-bind-mounted workspaces. Editor atomic-replace saves on the
# host change the underlying inode; native fsnotify across virtiofs misses
# these events. Polling is the boring reliable answer (~2-5% CPU). Disabling
# watchman avoids it racing the polling watcher and reporting stale state.
ENV CHOKIDAR_USEPOLLING=true
ENV CHOKIDAR_INTERVAL=400
ENV WATCHMAN_DISABLE=1

# claude-code — pinned. Bump CLAUDE_CODE_VERSION explicitly when upgrading.
# Native installer only (~/.local/bin/claude). `npm install -g` would create a
# parallel root-owned install that `claude doctor` flags as a duplicate and
# that the agent user can't auto-update. Pinning the version arg is both
# deterministic and bust-on-bump (Docker layer caching otherwise sticks to
# whatever was pulled the first time the layer was built).
ARG CLAUDE_CODE_VERSION=2.1.142
RUN curl -fsSL https://starship.rs/install.sh | sh -s -- --yes >/dev/null

USER agent

# Native installer stages the binary at ~/.local/bin/claude with versioned
# copies under ~/.local/share/claude/versions. Runs as `agent` so $HOME
# resolves to /home/agent.
RUN curl -fsSL https://claude.ai/install.sh | bash -s -- "${CLAUDE_CODE_VERSION}"

# Ensure ~/.local/bin wins over /usr/local/share/npm-global/bin so `which claude`
# always resolves to the native install. Without this, the base image's PATH
# finds the npm-global path first.
ENV PATH=/home/agent/.local/bin:$PATH

# In-VM Claude config dir name (".claude-personal"). Drives both
# CLAUDE_CONFIG_DIR and the COPY destination. NOTE: do NOT use bare ".claude"
# here — sbx's claude-code template treats /home/agent/.claude/ as its own
# managed directory and rewrites settings.json on first run, which silently
# strips our baked statusLine/hooks/plugins. build.sh sets this via --build-arg.
ARG CLAUDE_CONFIG_DIR_NAME=.claude-personal
ENV CLAUDE_CONFIG_DIR=/home/agent/${CLAUDE_CONFIG_DIR_NAME}

COPY --chown=agent:agent snapshot/ /home/agent/${CLAUDE_CONFIG_DIR_NAME}/

RUN chmod +x ${CLAUDE_CONFIG_DIR}/statusline-command.sh \
 && mkdir -p /home/agent/.config \
 && if [ -f ${CLAUDE_CONFIG_DIR}/starship.toml ]; then \
        mv ${CLAUDE_CONFIG_DIR}/starship.toml /home/agent/.config/starship.toml; \
    fi \
 && echo 'eval "$(starship init bash)"' >> /home/agent/.bashrc
