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
ARG GS_VERSION=v0.26.1
RUN apt-get update \
 && apt-get install -y --no-install-recommends bash-completion \
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
