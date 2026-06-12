FROM ubuntu:26.04

ARG TZ=Asia/Tokyo
ENV TZ="$TZ"
ARG CLAUDE_CODE_VERSION=latest
ARG NODE_VERSION=lts
ARG USERNAME=dev
ARG USER_UID=1000
ARG USER_GID=1000

ENV DEBIAN_FRONTEND=noninteractive

# Base tools + firewall deps + build deps + tmux + locales (for Japanese UTF-8)
RUN apt-get update && apt-get install -y --no-install-recommends \
  ca-certificates curl wget git gnupg2 \
  sudo zsh fzf less procps man-db unzip nano vim tmux \
  iptables ipset iproute2 dnsutils aggregate jq \
  build-essential pkg-config libssl-dev \
  locales \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# Generate UTF-8 locales and make them the default (for Japanese display/input in tmux etc.)
RUN locale-gen en_US.UTF-8 ja_JP.UTF-8 && update-locale LANG=en_US.UTF-8
ENV LANG=en_US.UTF-8 \
  LC_ALL=en_US.UTF-8

# Non-root work user (uid 1000)
RUN userdel -r ubuntu 2>/dev/null || true; \
  groupadd -g ${USER_GID} ${USERNAME} && \
  useradd -m -u ${USER_UID} -g ${USER_GID} -s /bin/zsh ${USERNAME} && \
  echo "${USERNAME} ALL=(root) NOPASSWD: /usr/local/bin/init-firewall.sh" \
  > /etc/sudoers.d/${USERNAME}-firewall && \
  chmod 0440 /etc/sudoers.d/${USERNAME}-firewall

# Install Node via n (LTS)
RUN curl -fsSL https://raw.githubusercontent.com/tj/n/master/bin/n -o /usr/local/bin/n && \
  chmod +x /usr/local/bin/n && \
  n ${NODE_VERSION} && \
  npm install -g npm@latest

# Install Claude Code globally via npm
RUN npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}

# Work/config directories (mount points for the bind mounts)
RUN mkdir -p /workspace /home/${USERNAME}/.claude /commandhistory && \
  touch /commandhistory/.bash_history && \
  chown -R ${USER_UID}:${USER_GID} /workspace /home/${USERNAME}/.claude /commandhistory

# Firewall script
COPY init-firewall.sh /usr/local/bin/init-firewall.sh
RUN chmod +x /usr/local/bin/init-firewall.sh

# Watchtower pre-update hook (postpones updates while Claude Code is running)
COPY wt-preupdate.sh /usr/local/bin/wt-preupdate
RUN chmod +x /usr/local/bin/wt-preupdate

# tmux config: set the prefix to Ctrl-Space (does not clash with emacs-style keybindings)
RUN printf '%s\n' \
  'unbind C-b' \
  'set -g prefix C-Space' \
  'bind C-Space send-prefix' \
  'set -g mouse on' \
  'set -g history-limit 50000' \
  'setw -g mode-keys emacs' \
  > /home/${USERNAME}/.tmux.conf && \
  chown ${USER_UID}:${USER_GID} /home/${USERNAME}/.tmux.conf

ENV DEVCONTAINER=true \
  SHELL=/bin/zsh \
  EDITOR=nano \
  CLAUDE_CONFIG_DIR=/home/${USERNAME}/.claude

# --- Switch to non-root. Install Rust into the user environment (rustup) ---
USER ${USERNAME}
WORKDIR /home/${USERNAME}

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
  | sh -s -- -y --default-toolchain stable --profile minimal \
  --component clippy --component rustfmt
ENV PATH="/home/${USERNAME}/.cargo/bin:${PATH}"

WORKDIR /workspace
