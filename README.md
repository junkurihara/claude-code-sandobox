# Claude Code Sandbox

A Docker image that keeps [Claude Code](https://github.com/anthropics/claude-code)
running continuously on a Linux host. The container does almost nothing on its
own: it sets up an egress firewall and then `sleep infinity`. The real work
happens inside a long-lived `tmux` session, so Claude Code keeps running across
SSH disconnects and terminal closes.

## Features

- **Non-root by default.** Work runs as the `dev` user (uid/gid 1000). `sudo` is
  restricted to the firewall script only.
- **Egress firewall.** `init-firewall.sh` applies a default-DROP policy and an
  allowlist (GitHub IP ranges, `api.anthropic.com`, npm, crates.io, and a few
  optional telemetry domains). See [Firewall](#firewall) for caveats.
- **Persistent state via bind mounts.** Workspace, Claude config, and shell
  history live on the host, so they survive container recreation and
  `docker system prune --volumes`.
- **Preinstalled toolchain.** Node (LTS via `n`), Rust (rustup, stable), tmux,
  zsh, and common CLI tools.

## Prerequisites

- Docker Engine and the Docker Compose plugin
- Linux host (the firewall uses `iptables`/`ipset`; the container needs the
  `NET_ADMIN` and `NET_RAW` capabilities, already declared in
  `docker-compose.yml`)

## Quick start

```sh
# Build and start the container in the background.
docker compose up -d

# Attach to (or create) the persistent tmux session, then run `claude` inside.
./bin/cc
```

Detach from tmux with the prefix `Ctrl-Space` then `d`. The session keeps
running inside the container; re-run `./bin/cc` to reattach.

`bin/cc` is a thin host-side wrapper around:

```sh
docker exec -it claude-code tmux new-session -A -s main
```

You can override the container or session name:

```sh
CC_CONTAINER=claude-code CC_SESSION=main ./bin/cc
```

## Directory layout (host side)

These paths are bind-mounted into the container and are git-ignored:

| Host path        | Container path      | Purpose                          |
| ---------------- | ------------------- | -------------------------------- |
| `./cc-workspace` | `/workspace`        | Your code / working directory    |
| `./data/claude`  | `/home/dev/.claude` | Claude Code config + credentials |
| `./data/history` | `/commandhistory`   | Shell history                    |

> **Do not commit `data/`.** It contains Claude credentials. It is listed in
> `.gitignore`.

## Updating

[watchtower](https://github.com/nicholas-fedor/watchtower) updates a container
by stopping, removing, and recreating it, which would kill a live tmux/Claude
Code session. To get automatic updates without ever interrupting an active
session, this container uses a **pre-update lifecycle hook**
(`wt-preupdate.sh`):

- While a Claude Code process is running, the hook exits `75` (EX_TEMPFAIL),
  which tells watchtower to **postpone** the update until its next poll.
- Once Claude Code is no longer running, the hook exits `0` and watchtower
  recreates the container with the new image.

This requires lifecycle hooks to be enabled **on the watchtower service**
(not on this container):

```yaml
# in your watchtower service
environment:
  WATCHTOWER_LIFECYCLE_HOOKS: "true" # or run watchtower with --enable-lifecycle-hooks
```

Caveats:

- An idle Claude Code session sitting at its prompt is still a running process,
  so updates apply only after you fully **quit** Claude Code. If a session is
  always running, updates never apply.
- Verify the hook's process match works for your setup with
  `docker exec claude-code sh -c 'ps -ef | grep -i claude'`, and adjust the
  `pgrep` pattern in `wt-preupdate.sh` if needed.

You can always update manually instead:

```sh
docker compose pull   # or: docker compose build --pull
docker compose up -d
```

**Alternative — monitor-only.** If you would rather have watchtower only pull
and notify (never recreate), drop the lifecycle labels and use
`com.centurylinklabs.watchtower.monitor-only=true` instead, then apply updates
yourself with `docker compose up -d`.

## Firewall

`init-firewall.sh` runs at container start (via the entrypoint) and:

- Resolves the allowlisted domains **once** and pins their IPs in an ipset.
  If an upstream IP rotates (e.g. `api.anthropic.com`), connectivity can break
  until the container is restarted and the firewall re-runs.
- Allows the host's `/24` network, so the container can reach other services on
  the local network. Tighten this if that is not desired.

## CI / images

`.github/workflows/build.yml` builds the image and pushes it to both:

- Docker Hub: `jqtype/claude-code-sandbox`
- GHCR: `ghcr.io/<owner>/claude-code-sandbox`

It runs on push to `main`, on `v*` tags, on manual dispatch, and **daily on a
schedule** to pick up new Claude Code releases. The workflow resolves the latest
published `@anthropic-ai/claude-code` version from npm and passes it as a
concrete `CLAUDE_CODE_VERSION` build arg, so the build cache is busted only when
a new version actually exists. Each image is also tagged `cc-<version>` for
traceability.

Docker Hub push requires two repository secrets: `DOCKERHUB_USERNAME` and
`DOCKERHUB_TOKEN` (a Docker Hub access token). GHCR uses the built-in
`GITHUB_TOKEN`.

## Configuration

Build args (set in `docker-compose.yml`):

| Arg                   | Default      | Description                |
| --------------------- | ------------ | -------------------------- |
| `TZ`                  | `Asia/Tokyo` | Container timezone         |
| `CLAUDE_CODE_VERSION` | `latest`     | npm version of Claude Code |
| `USER_UID`            | `1000`       | uid of the `dev` user      |
| `USER_GID`            | `1000`       | gid of the `dev` user      |
