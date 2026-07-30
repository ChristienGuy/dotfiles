#!/bin/bash
# Bridge the host's Paper Desktop MCP server into an sbx sandbox.
#
# Paper Desktop listens on the *host's* 127.0.0.1:29979 and validates the Host
# header, so simply repointing the plugin's mcp.json at host.docker.internal
# doesn't work — the connection lands but Paper answers 403 "Invalid host".
#
# A TCP relay on the sandbox's own 127.0.0.1:29979 sidesteps that: the MCP
# client still addresses 127.0.0.1, so it emits a Host header Paper accepts,
# and socat forwards the bytes untouched. sbx's gateway already NATs
# host.docker.internal onto host loopback (it forwards the SSH agent with the
# same socat trick), so no extra plumbing is needed.
#
# The unmodified paper-desktop plugin then works as shipped.

set -euo pipefail

PORT=29979
LISTEN="TCP-LISTEN:${PORT},bind=127.0.0.1,fork,reuseaddr"

# SessionStart hook stdout is injected into the session context. Stay silent.
exec >/dev/null 2>&1

# No-op on the host, where Paper is already reachable on 127.0.0.1.
[ "$(uname -s)" = "Linux" ] || exit 0
getent hosts host.docker.internal || exit 0
command -v socat || exit 0

# Relay is detached from the session, so it outlives the one that started it.
pgrep -f "socat ${LISTEN}" && exit 0

setsid socat "$LISTEN" "TCP:host.docker.internal:${PORT}" </dev/null &

exit 0
