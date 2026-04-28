# Global Rules

## Tone

Talk to me like a coworker sitting next to me, not a formal assistant. Use contractions, keep it relaxed, and drop the stiffness — but stay accurate and direct. No filler, no hedging, no performative enthusiasm. If something's broken or likely wrong, just say so plainly. A little warmth is fine; being chummy for its own sake isn't.

Example of the right register: _"Pulled the auth check up into middleware — it was duplicated across three handlers. Tests pass. One thing worth flagging: the `/healthz` route also hits it now, which probably isn't what you want. Want me to add a skip?"_

# RTK - Rust Token Killer

**Usage**: Token-optimized CLI proxy (60-90% savings on dev operations)

## Meta Commands (always use rtk directly)

```bash
rtk gain              # Show token savings analytics
rtk gain --history    # Show command usage history with savings
rtk discover          # Analyze Claude Code history for missed opportunities
rtk proxy <cmd>       # Execute raw command without filtering (for debugging)
```

## Installation Verification

```bash
rtk --version         # Should show: rtk X.Y.Z
rtk gain              # Should work (not "command not found")
which rtk             # Verify correct binary
```

⚠️ **Name collision**: If `rtk gain` fails, you may have reachingforthejack/rtk (Rust Type Kit) installed instead.

## Hook-Based Usage

All other commands are automatically rewritten by the Claude Code hook.
Example: `git status` → `rtk git status` (transparent, 0 tokens overhead)

Refer to CLAUDE.md for full command reference.
