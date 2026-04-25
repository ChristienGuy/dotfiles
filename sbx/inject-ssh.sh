#!/usr/bin/env bash
# Inject a host SSH private key into a running sbx sandbox so git-over-SSH
# works inside it. The key is written to /home/agent/.ssh in the container's
# writable layer — it lives only as long as the sandbox does and is never
# baked into the image. Re-run this after `sbx rm` + recreate.
#
# Usage:
#   dotfiles/sbx/inject-ssh.sh <sandbox-name> [key-path]
#
# Defaults: key-path = ~/.ssh/id_ed25519
#
# Requires: openssh-client inside the sandbox (provided by the
# claude-personal Dockerfile).

set -euo pipefail

sandbox="${1:?usage: inject-ssh.sh <sandbox-name> [key-path]}"
key="${2:-$HOME/.ssh/id_ed25519}"

if [ ! -f "$key" ]; then
  echo "error: private key not found at $key" >&2
  exit 1
fi

cat "$key" | sbx exec -i "$sandbox" bash -c '
  set -euo pipefail
  umask 077
  mkdir -p ~/.ssh
  chmod 700 ~/.ssh
  cat > ~/.ssh/id_ed25519
  chmod 600 ~/.ssh/id_ed25519
  cat > ~/.ssh/config <<CFG
Host github.com
  User git
  IdentityFile ~/.ssh/id_ed25519
  IdentitiesOnly yes
  StrictHostKeyChecking accept-new
CFG
  chmod 600 ~/.ssh/config
'

# Smoke-test that the key actually authenticates. `ssh -T` to github.com
# always exits 1 ("does not provide shell access") even on success, so we
# inspect the message instead of the exit code.
output=$(sbx exec "$sandbox" ssh -o BatchMode=yes -T git@github.com 2>&1 || true)
if printf '%s\n' "$output" | grep -q "successfully authenticated"; then
  echo "ssh: github.com auth OK in $sandbox"
else
  echo "warning: ssh smoke test against github.com did not confirm auth:" >&2
  printf '%s\n' "$output" >&2
  exit 1
fi
