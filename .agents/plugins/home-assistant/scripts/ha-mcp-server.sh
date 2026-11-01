#!/usr/bin/env bash
set -euo pipefail

# Ensure mise shims and local bin are in PATH
export PATH="$HOME/.local/share/mise/shims:$HOME/.local/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Locate encrypted env file
if [ -f "$PLUGIN_DIR/secrets/ha-mcp.enc.env" ]; then
  SECRETS_FILE="$PLUGIN_DIR/secrets/ha-mcp.enc.env"
elif [ -f "$HOME/.gemini/config/ha-mcp.enc.env" ]; then
  SECRETS_FILE="$HOME/.gemini/config/ha-mcp.enc.env"
else
  echo "Error: ha-mcp.enc.env not found in $PLUGIN_DIR/secrets or $HOME/.gemini/config" >&2
  exit 1
fi

export SOPS_AGE_KEY_FILE="${SOPS_AGE_KEY_FILE:-$HOME/.config/sops/age/keys.txt}"

# Locate ha-mcp binary
if command -v ha-mcp &>/dev/null; then
  HA_BIN="$(command -v ha-mcp)"
elif [ -f "$HOME/.local/bin/ha-mcp" ]; then
  HA_BIN="$HOME/.local/bin/ha-mcp"
else
  echo "Error: ha-mcp binary not found. Please install with 'uv tool install ha-mcp'." >&2
  exit 1
fi

exec sops exec-env "$SECRETS_FILE" "$HA_BIN" "$@"
