# Sandbox auth — why personal-only

sbx stores the Anthropic OAuth credential in a **single global slot**
(`docker/sandbox/default/anthropic`), not per-sandbox. The `.credentials.json`
inside each sandbox is a proxy-managed placeholder; the real token lives in that
one host-side slot and is injected out-of-band by sbx's proxy
(`gateway.docker.internal:3129`).

So every `/login` overwrites the same slot — last write wins for **all**
sandboxes. A separate `claude-work` image can't hold its own login alongside
personal; whichever account logged in most recently is the one every sandbox
uses. The Dockerfile/`CLAUDE_CONFIG_DIR` split isolates *config* (settings,
hooks, plugins, MCP state), never *auth*. That's why this repo builds one
flavor only.

`sbx secret set` is per-sandbox but its `--oauth` flag is global-only, so OAuth
(Max subscription) can't be scoped per sandbox today.

If you ever genuinely need two accounts at once, the workable options are:

- Give one sandbox an Anthropic Console **API key**, scoped per-sandbox:
  `echo $KEY | sbx secret set <sandbox> anthropic`. Trade-off: that sandbox
  bills per-token to the Console instead of the Max subscription.
- Separate macOS user accounts — full isolation incl. Keychain, but heavy.

Don't bake credentials into the image or snapshot: they'd land in image layers
and wouldn't survive token refresh anyway.
