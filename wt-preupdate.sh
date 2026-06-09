#!/bin/sh
# Watchtower pre-update lifecycle hook.
#
# Runs inside the container right before watchtower would update it. The exit
# code controls what watchtower does next:
#   - exit 75 (EX_TEMPFAIL): postpone the update until the next poll
#   - exit 0:                allow the update (container is recreated)
#   - any other code:        logged as an error, but the update STILL proceeds
#
# We postpone whenever a Claude Code process is running, so an active session is
# never killed by an image update. Once Claude Code is no longer running, the
# next watchtower poll updates and recreates the container.
#
# The "[c]laude" pattern is the classic trick so this hook does not match its
# own command line. Verify the pattern matches your real process with
# `ps -ef | grep -i claude` inside the container and adjust if needed.
if pgrep -f '[c]laude' >/dev/null 2>&1; then
  echo "wt-preupdate: Claude Code is running; postponing update (exit 75)."
  exit 75
fi

echo "wt-preupdate: no Claude Code process; allowing update (exit 0)."
exit 0
