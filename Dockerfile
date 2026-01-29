FROM node:lts-bookworm-slim

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install Core & Power Tools
# Note: Debian "slim" images are minimal. We need to install common tools.
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    wget \
    git \
    build-essential \
    software-properties-common \
    python3 \
    python3-pip \
    python3-venv \
    jq \
    lsof \
    openssl \
    ca-certificates \
    golang-go \
    gnupg \
    # Power Tools: ripgrep, fd, fzf, bat
    ripgrep fd-find fzf bat \
    # Document & Office Tools: pandoc, pdf, images
    pandoc \
    poppler-utils \
    ffmpeg \
    imagemagick \
    graphviz \
    sqlite3 \
    # Security: Pass (GPG)
    pass \
    && rm -rf /var/lib/apt/lists/*

# Install rbw (Bitwarden CLI) - Support both AMD64 and ARM64
# Temporarily disabled for ARM64 compatibility - building from source is required or valid deb url
# RUN ARCH=$(dpkg --print-architecture) && \
#     if [ "$ARCH" = "amd64" ]; then \
#     URL="https://git.tozt.net/rbw/releases/deb/rbw_1.12.1_amd64.deb"; \
#     elif [ "$ARCH" = "arm64" ]; then \
#     URL="https://git.tozt.net/rbw/releases/deb/rbw_1.12.1_arm64.deb"; \
#     else \
#     echo "Unsupported architecture: $ARCH" && exit 1; \
#     fi && \
#     curl -L --output rbw.deb "$URL" && \
#     dpkg -i rbw.deb && \
#     rm rbw.deb

# Install Cloudflare Tunnel (cloudflared)
RUN ARCH=$(dpkg --print-architecture) && \
    curl -L --output cloudflared.deb "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${ARCH}.deb" && \
    dpkg -i cloudflared.deb && \
    rm cloudflared.deb

# Install GitHub CLI (gh)
RUN mkdir -p -m 755 /etc/apt/keyrings && \
    wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null && \
    chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null && \
    apt-get update && \
    apt-get install -y gh && \
    rm -rf /var/lib/apt/lists/*

# Install uv (Python tool manager)
ENV UV_INSTALL_DIR="/usr/local/bin"
RUN curl -LsSf https://astral.sh/uv/install.sh | sh

# Install Bun
# Note: Bun install script works better with unzip
RUN apt-get update && apt-get install -y unzip && rm -rf /var/lib/apt/lists/* && \
    curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:${PATH}"

# Install Vercel & Marp (Slides) & QMD (Search)
# Node & NPM are already provided by base image
# QMD requires bun and global install
RUN npm install -g vercel @marp-team/marp-cli && \
    bun install -g https://github.com/tobi/qmd && \
    hash -r

# Configure QMD Persistence
ENV XDG_CACHE_HOME="/home/node/.moltbot/cache"

# Install Python Tools (IPython, Office Libs)
# Use --break-system-packages because we are in a container/appliance
RUN pip3 install ipython \
    csvkit \
    openpyxl \
    python-docx \
    pypdf \
    --break-system-packages

# Add aliases for standard tool names (Debian/Ubuntu quirks)
RUN ln -s /usr/bin/fdfind /usr/bin/fd || true && \
    ln -s /usr/bin/batcat /usr/bin/bat || true

# Set up working directory
WORKDIR /app

# Set PATH for global npm binaries - standard location for root typically /usr/local, but we keep node's structure or just use global
ENV PATH="/usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/games"

# Run Moltbot install scripts as root
ARG MOLT_BOT_BETA=false
ENV MOLT_BOT_BETA=${MOLT_BOT_BETA} \
    CLAWDBOT_NO_ONBOARD=1 \
    # Allow running as root for standard tools
    NPM_CONFIG_UNSAFE_PERM=true

# Install Moltbot (as root, installs to /usr/local/bin or similar usually, need to check install.sh behavior or assume standard)
# Actually the install script might try to install to ~/.npm-global if not root. As root, it might install to /usr/local/bin. 
# We'll install to a fixed path or rely on PATH.
RUN curl -fsSL https://molt.bot/install.sh | bash

# Install AI Tool Suite (globally as root)
RUN npm install -g @google/gemini-cli @openai/codex opencode-ai && \
    curl -fsSL https://claude.ai/install.sh | sh -s -- -y && \
    curl -LsSf https://code.kimi.com/install.sh | sh -s -- -y

# Symlink tools if needed, but installing as root usually puts them in PATH.
# Just in case:
RUN ln -sf /root/.claude/bin/claude /usr/local/bin/claude || true && \
    ln -sf /root/.kimi/bin/kimi /usr/local/bin/kimi || true

# Copy local scripts
COPY scripts/bootstrap.sh /app/scripts/bootstrap.sh
COPY scripts/molt-approve.sh /usr/local/bin/molt-approve
RUN chmod +x /app/scripts/bootstrap.sh /usr/local/bin/molt-approve

# Expose the application port
EXPOSE 18789

# Set entrypoint
CMD ["bash", "/app/scripts/bootstrap.sh"]