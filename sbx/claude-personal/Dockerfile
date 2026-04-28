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
# github.com. The private key itself is injected at runtime, never baked
# into the image — see dotfiles/sbx/inject-ssh.sh.
ARG GS_VERSION=v0.26.1
RUN apt-get update \
 && apt-get install -y --no-install-recommends bash-completion openssh-client \
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

RUN curl -fsSL https://starship.rs/install.sh | sh -s -- --yes >/dev/null \
 && npm install -g @anthropic-ai/claude-code@latest \
 && rm -rf /home/agent/.local/share/claude/versions \
 && ln -sf /usr/local/share/npm-global/bin/claude /home/agent/.local/bin/claude

USER agent

ENV CLAUDE_CONFIG_DIR=/home/agent/.claude-personal

COPY --chown=agent:agent snapshot/ /home/agent/.claude-personal/

RUN chmod +x /home/agent/.claude-personal/statusline-command.sh \
 && mkdir -p /home/agent/.config \
 && if [ -f /home/agent/.claude-personal/starship.toml ]; then \
        mv /home/agent/.claude-personal/starship.toml /home/agent/.config/starship.toml; \
    fi \
 && echo 'eval "$(starship init bash)"' >> /home/agent/.bashrc
