#!/usr/bin/env bash
set -e

# State directories - Moltbot/Clawdbot overlap
# Binary might look for either depending on version
# State directories
# State directories
OPENCLAW_STATE="/root/.openclaw"
MOLT_STATE="/root/.moltbot"
CLAW_STATE="/root/.clawdbot"
CONFIG_FILE="$OPENCLAW_STATE/openclaw.json"
WORKSPACE_DIR="/root/openclaw-workspace"

mkdir -p "$OPENCLAW_STATE" "$MOLT_STATE" "$CLAW_STATE" "$WORKSPACE_DIR"
chmod 700 "$OPENCLAW_STATE" "$MOLT_STATE" "$CLAW_STATE"

# Tighten permissions on config if it exists
if [ -f "$CONFIG_FILE" ]; then
  chmod 600 "$CONFIG_FILE"
fi
if [ -f "$MOLT_STATE/clawdbot.json" ]; then
  chmod 600 "$MOLT_STATE/clawdbot.json"
fi

# Ensure credentials dir exists
mkdir -p "$MOLT_STATE/credentials"
chmod 700 "$MOLT_STATE/credentials"

# Universal Permission Hardening (Runtime Fail-safe)
# Start universal permission hardening
echo "🛡️ HARDENING CLI PERMISSIONS..."
chmod -R +x /usr/local/bin/ || true

# --- SEARCH & RESCUE: FIX PATHS FOR MISSING TOOLS ---
echo "🕵️ SEARCHING FOR MISSING TOOLS..."
POSSIBLE_PATHS=(
  "/root/.bun/bin"
  "/root/.openclaw/cache/.bun/bin"
  "/root/.openclaw/bin"
  "/root/.local/bin"
  "/home/node/.bun/bin"
  "/root/.bun/install/global/bin"
)

# Function to rescue a binary
rescue_binary() {
  local bin="$1"
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "  ❓ $bin not in PATH. Searching..."
    found=""
    for p in "${POSSIBLE_PATHS[@]}"; do
      if [ -f "$p/$bin" ]; then
        echo "  ✨ Found $bin at $p/$bin. Symlinking to /usr/local/bin..."
        ln -sf "$p/$bin" "/usr/local/bin/$bin"
        found="true"
        break
      fi
    done
    if [ -z "$found" ]; then
      # Last resort: deep search in standard dirs (limited depth to be fast)
      echo "  ⚠️ $bin still not found. Attempting deep search..."
      deep_find=$(find /root /usr -maxdepth 4 -name "$bin" -type f -executable | head -n 1)
      if [ -n "$deep_find" ]; then
        echo "  ✨ Found via deep search at $deep_find. Symlinking..."
        ln -sf "$deep_find" "/usr/local/bin/$bin"
      else
        echo "  ❌ Could not locate $bin anywhere."
      fi
    fi
  else
    echo "  ✅ $bin is already in PATH."
  fi
}

# Rescue critical tools
for target in openclaw moltbot gemini codex opencode claude kimi; do
  rescue_binary "$target"
done
# ----------------------------------------------------

# Tool Audit
echo "🔍 AUDITING AI TOOL SUITE..."
for tool in openclaw claude kimi opencode gemini codex; do
  if command -v "$tool" >/dev/null 2>&1; then
    echo "✅ $tool: $(command -v "$tool")"
  else
    echo "⚠️ $tool: NOT FOUND"
  fi
done

# Ensure aliases work for interactive sessions
echo "alias fd=fdfind" >> /root/.bashrc
echo "alias bat=batcat" >> /root/.bashrc
echo "alias ll='ls -alF'" >> /root/.bashrc
echo "alias molty='openclaw'" >> /root/.bashrc
echo "alias clawd='openclaw'" >> /root/.bashrc
echo "alias moltbot='openclaw'" >> /root/.bashrc
echo "alias claw='openclaw'" >> /root/.bashrc

# Generate config on first boot
if [ ! -f "$CONFIG_FILE" ]; then
  if command -v openssl >/dev/null 2>&1; then
    TOKEN="$(openssl rand -hex 24)"
  else
    TOKEN="$(node -e "console.log(require('crypto').randomBytes(24).toString('hex'))")"
    TOKEN="$(node -e "console.log(require('crypto').randomBytes(24).toString('hex'))")"
  fi

  # Auto-generate SearXNG Secret Key
  SEARXNG_SETTINGS="/app/searxng/settings.yml"
  if [ -f "$SEARXNG_SETTINGS" ]; then
      if grep -q "ultrasecretkey" "$SEARXNG_SETTINGS"; then
          echo "🔑 Generating new SearXNG secret key..."
          NEW_SECRET=$(openssl rand -hex 32)
          sed -i "s/ultrasecretkey/$NEW_SECRET/g" "$SEARXNG_SETTINGS"
          echo "✅ SearXNG secret key updated."
      fi
  fi
cat >"$CONFIG_FILE" <<EOF
{
  "meta": {
    "lastTouchedVersion": "2026.1.30-1",
    "lastTouchedAt": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  },
  "wizard": {
    "lastRunMode": "local",
    "lastRunAt": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "lastRunVersion": "2026.1.30-1",
    "lastRunCommand": "doctor"
  },
  "diagnostics": {
    "otel": {
      "enabled": true
    }
  },
  "update": {
    "channel": "stable"
  },
  "channels": {
    "whatsapp": {
      "dmPolicy": "pairing",
      "groupPolicy": "allowlist",
      "mediaMaxMb": 50,
      "debounceMs": 0
    },
    "telegram": {
      "enabled": true,
      "botToken": "${TELEGRAM_BOT_TOKEN:-}",
      "dmPolicy": "pairing",
      "groupPolicy": "allowlist",
      "streamMode": "partial"
    },
    "discord": {
      "dm": {
        "policy": "pairing"
      },
      "groupPolicy": "allowlist"
    },
    "googlechat": {
      "dm": {
        "policy": "pairing"
      },
      "groupPolicy": "allowlist"
    },
    "slack": {
      "mode": "socket",
      "webhookPath": "/slack/events",
      "userTokenReadOnly": true,
      "dm": {
        "policy": "pairing"
      },
      "groupPolicy": "allowlist"
    },
    "signal": {
      "dmPolicy": "pairing",
      "groupPolicy": "allowlist"
    },
    "imessage": {
      "dmPolicy": "pairing",
      "groupPolicy": "allowlist"
    }
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": "anthropic:default",
        "fallbacks": []
      },
      "workspace": "/root/openclaw-workspace",
      "envelopeTimestamp": "on",
      "envelopeElapsed": "on",
      "cliBackends": {},
      "memorySearch": {
        "enabled": true,
        "experimental": {
          "sessionMemory": true
        },
        "provider": "gemini",
        "remote": {
          "batch": {
            "enabled": true,
            "wait": true
          }
        },
        "fallback": "gemini",
        "store": {
          "vector": {
            "enabled": true
          }
        },
        "sync": {
          "onSessionStart": true
        },
        "query": {
          "hybrid": {
            "enabled": true
          }
        },
        "cache": {
          "enabled": true
        }
      },
      "contextPruning": {
        "hardClear": {
          "enabled": false
        }
      },
      "compaction": {
        "mode": "default",
        "memoryFlush": {
          "enabled": true
        }
      },
      "elevatedDefault": "ask",
      "blockStreamingBreak": "text_end",
      "blockStreamingChunk": {
        "breakPreference": "sentence"
      },
      "maxConcurrent": 4,
      "subagents": {
        "maxConcurrent": 8,
        "model": {
          "primary": "anthropic:default",
          "fallbacks": []
        }
      },
      "sandbox": {
        "mode": "non-main",
        "scope": "session",
        "docker": {
          "host": "${DOCKER_HOST:-tcp://docker-proxy:2375}"
        },
        "browser": {
          "enabled": true
        }
      }
    },
    "list": [
      {
        "id": "main",
        "name": "default",
        "default": true,
        "workspace": "/root/openclaw-workspace"
      },
      {
        "id": "linkding",
        "name": "Linkding Agent",
        "workspace": "/root/openclaw-linkding"
      },
      {
        "id": "dbadmin",
        "name": "DB Administrator",
        "workspace": "/root/openclaw-dbadmin"
      }
    ]
  },
  "bindings": [],
  "tools": {
    "agentToAgent": {
      "enabled": true,
      "allow": ["main", "linkding", "dbadmin"]
    }
  },
  "messages": {
    "ackReactionScope": "group-mentions"
  },
  "commands": {
    "native": true,
    "nativeSkills": true,
    "text": true,
    "bash": true,
    "config": true,
    "debug": true,
    "restart": true,
    "useAccessGroups": true
  },
  "hooks": {
    "enabled": true,
    "token": "$TOKEN",
    "internal": {
      "enabled": true,
      "entries": {
        "boot-md": {
          "enabled": true
        },
        "command-logger": {
          "enabled": true
        },
        "session-memory": {
          "enabled": true
        }
      }
    }
  },
  "gateway": {
    "port": ${OPENCLAW_GATEWAY_PORT:-18789},
    "mode": "local",
    "bind": "lan",
    "controlUi": {
      "enabled": true,
      "allowInsecureAuth": false
    },
    "auth": {
      "mode": "token",
      "token": "$TOKEN"
    },
    "trustedProxies": [
      "*"
    ],
    "tailscale": {
      "mode": "off",
      "resetOnExit": false
    }
  },
  "skills": {
    "allowBundled": ["*"],
    "install": {
      "nodeManager": "npm"
    }
  },
  "plugins": {
    "entries": {
      "telegram": {
        "enabled": $([ -n "$TELEGRAM_BOT_TOKEN" ] && echo true || echo false)
      },
      "whatsapp": {
        "enabled": true
      },
      "discord": {
        "enabled": true
      },
      "googlechat": {
        "enabled": true
      },
      "slack": {
        "enabled": true
      },
      "signal": {
        "enabled": true
      },
      "imessage": {
        "enabled": false
      },
      "google-antigravity-auth": {
        "enabled": true
      }
    }
  }
}
EOF

fi

# Update TOKEN if it was not set (e.g. if config already existed)
if [ -z "$TOKEN" ]; then
  TOKEN="$(jq -r '.gateway.auth.token' "$CONFIG_FILE" 2>/dev/null || jq -r '.gateway.auth.token' "$OPENCLAW_STATE/openclaw.json" 2>/dev/null || echo "")"
fi

# Ensure all possible naming variations exist on every boot for robustness
cp -f "$CONFIG_FILE" "$MOLT_STATE/clawdbot.json" 2>/dev/null || true
cp -f "$CONFIG_FILE" "$MOLT_STATE/moltbot.json" 2>/dev/null || true
cp -f "$CONFIG_FILE" "$CLAW_STATE/moltbot.json" 2>/dev/null || true
cp -f "$CONFIG_FILE" "$CLAW_STATE/clawdbot.json" 2>/dev/null || true
ln -sf "$CONFIG_FILE" "$MOLT_STATE/config.json" 2>/dev/null || true
ln -sf "$CONFIG_FILE" "$CLAW_STATE/config.json" 2>/dev/null || true
ln -sf "$CONFIG_FILE" "$OPENCLAW_STATE/config.json" 2>/dev/null || true

# Run doctor --fix to handle any migrations or permission issues automatically
# Run doctor --fix to handle any migrations or permission issues automatically
if command -v openclaw >/dev/null 2>&1; then
  echo "🏥 RUNNING OPENCLAW DOCTOR..."
  openclaw doctor --fix || true
fi

# Seed Agent Workspaces
seed_agent() {
  local id="$1"
  local name="$2"
  local id="$1"
  local name="$2"
  local name="$2"
  local dir="/root/openclaw-$id"
  if [ "$id" = "main" ]; then dir="/root/openclaw-workspace"; fi

  if ! mkdir -p "$dir" 2>/dev/null; then
    echo "⚠️ WARNING: Could not create directory $dir. Check volume permissions."
    return 1
  fi

  if [ ! -f "$dir/AGENTS.md" ]; then
    if ! cat >"$dir/AGENTS.md" <<EOF; then
# AGENTS.md - $name
This is the workspace for $name.
EOF
      echo "⚠️ WARNING: Could not write to $dir/AGENTS.md. Permission denied."
    fi
  fi

  if [ ! -f "$dir/SOUL.md" ]; then
    case "$id" in
      linkding)
        cat >"$dir/SOUL.md" <<EOF
# SOUL.md - Linkding Agent
You are the Linkding Bookmark Assistant. Your primary goal is to help the user manage bookmarks.
EOF
        ;;
      dbadmin)
        cat >"$dir/SOUL.md" <<EOF
# SOUL.md - DB Administrator
You are the Database and Container Administrator. You monitor Postgres and manage SQLite subagent sandboxes.
EOF
        ;;
      *)
        cat >"$dir/SOUL.md" <<EOF
# SOUL.md - OpenClaw
You are OpenClaw, a helpful and premium AI assistant.
EOF
        ;;
    esac
  fi
}

seed_agent "main" "OpenClaw"
seed_agent "linkding" "Linkding Agent"
seed_agent "dbadmin" "DB Administrator"

# Export state directory for the binary
export OPENCLAW_STATE_DIR="$OPENCLAW_STATE"
export CLAWDBOT_STATE_DIR="$OPENCLAW_STATE"
export MOLTBOT_STATE_DIR="$OPENCLAW_STATE"

# Resolve public URL (Coolify injects SERVICE_URL_OPENCLAW)
BASE_URL="${SERVICE_URL_OPENCLAW:-http://localhost:18789}"

if [ "${OPENCLAW_PRINT_ACCESS:-1}" = "1" ]; then
  if [ "${OPENCLAW_BETA:-false}" = "true" ]; then
    echo "🧪 OPENCLAW BETA MODE ACTIVE"
  fi
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "🦞 OPENCLAW READY"
  echo ""
  echo "Dashboard:"
  echo "$BASE_URL/?token=$TOKEN"
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
fi

# Install QMD Skills (Context search)
if [ ! -d "skills/qmd-skills" ]; then
    echo "📦 Installing QMD Skills..."
    npx -y skills add http://github.com/levineam/qmd-skills >/dev/null 2>&1 || echo "⚠️ QMD Skills install warning (check logs)"
fi

# Cloudflare Tunnel Auto-Start
if [ -n "$CF_TUNNEL_TOKEN" ]; then
    echo "🚇 Starting Cloudflare Tunnel..."
    if command -v cloudflared >/dev/null; then
        # Run in background, output to log
        cloudflared tunnel run --token "$CF_TUNNEL_TOKEN" > /var/log/cloudflared.log 2>&1 &
        echo "✅ Cloudflare Tunnel active."
    else
        echo "⚠️ CF_TUNNEL_TOKEN set but 'cloudflared' binary missing."
    fi
fi

# Run the openclaw gateway using the global binary
exec openclaw gateway

echo ""
echo "💡 If you want to set up custom model and with custom API key, you can run this command first:"
echo "   exec openclaw onboard"
echo ""
