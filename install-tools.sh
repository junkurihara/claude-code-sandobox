#!/bin/bash
# install-tools — host-only helper to install extra apt packages into a running,
# firewall-locked container (e.g. valgrind/python3 for profiling).
#
# Intended to be run ONLY from the host as root:
#   docker exec -u 0 <container> install-tools valgrind python3
#
# It is deliberately NOT registered in the dev user's sudoers, and it requires
# root. The in-container dev user (and any agent running as it) therefore cannot
# invoke it. Only an operator with host-level docker access can, which grants no
# privilege they do not already have over the container.
#
# Flow: temporarily allow the Ubuntu apt mirrors through the firewall, install the
# requested packages, then restore the locked-down firewall on exit (even on
# failure) by re-running init-firewall.sh.
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "ERROR: must run as root, e.g.: docker exec -u 0 <container> $(basename "$0") <pkg>..." >&2
  exit 1
fi

if [ "$#" -eq 0 ]; then
  echo "Usage: $(basename "$0") <package>..." >&2
  exit 1
fi

# Ubuntu apt mirrors. archive/security are used on amd64; ports is used on arm64
# (e.g. Apple Silicon hosts). Adding the unused one is harmless.
APT_MIRRORS=(archive.ubuntu.com security.ubuntu.com ports.ubuntu.com)

# Detect whether the egress firewall is currently active. The init-firewall.sh
# setup creates the "allowed-domains" ipset; if it is absent the container is not
# locked down yet and apt can reach the network without any changes.
FIREWALL_ACTIVE=0
if ipset list allowed-domains >/dev/null 2>&1; then
  FIREWALL_ACTIVE=1
fi

# Re-resolve the apt mirrors and add their current IPs to the allowlist ipset.
# Done before each attempt because these mirrors use round-robin/CDN DNS, so the
# IP apt connects to can differ from a previously resolved one.
add_mirrors() {
  local domain ip ips
  for domain in "${APT_MIRRORS[@]}"; do
    ips=$(dig +noall +answer A "$domain" | awk '$4 == "A" {print $5}')
    for ip in $ips; do
      if [[ "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        ipset add -exist allowed-domains "$ip"
      fi
    done
  done
}

# Restore the canonical locked-down firewall by rebuilding it from scratch, which
# drops the temporary mirror entries. Runs on every exit path.
relock() {
  if [ "$FIREWALL_ACTIVE" -eq 1 ]; then
    echo "Restoring firewall..."
    /usr/local/bin/init-firewall.sh
  fi
}
trap relock EXIT

if [ "$FIREWALL_ACTIVE" -eq 1 ]; then
  echo "Temporarily allowing apt mirrors through the firewall..."
  add_mirrors
fi

# Install, retrying a few times: round-robin DNS can hand apt an IP that was not
# in the allowlist at resolution time, so we re-resolve and retry on failure.
attempt=1
max_attempts=3
until apt-get update && apt-get install -y --no-install-recommends "$@"; do
  if [ "$attempt" -ge "$max_attempts" ]; then
    echo "ERROR: apt failed after ${max_attempts} attempts" >&2
    exit 1
  fi
  echo "apt attempt ${attempt} failed; re-resolving mirrors and retrying..."
  [ "$FIREWALL_ACTIVE" -eq 1 ] && add_mirrors
  attempt=$((attempt + 1))
done

echo "Installed: $*"
echo "(firewall will be restored on exit)"
