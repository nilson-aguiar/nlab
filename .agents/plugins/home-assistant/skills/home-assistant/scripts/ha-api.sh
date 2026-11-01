#!/usr/bin/env bash
set -euo pipefail

# Ensure mise shims and local bin are in PATH
export PATH="$HOME/.local/share/mise/shims:$HOME/.local/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

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

if [ $# -lt 1 ]; then
  echo "Usage: ha-api.sh <endpoint> [curl_options...]" >&2
  echo "Example: ha-api.sh /api/states" >&2
  echo "Example: ha-api.sh /api/template -d '{\"template\": \"{{ states.sensor | count }}\"}'" >&2
  exit 1
fi

export HA_REQ_ENDPOINT="$1"
shift

# Serialize remaining arguments to JSON array
export HA_REQ_ARGS_JSON="$(python3 -c 'import sys, json; print(json.dumps(sys.argv[1:]))' "$@")"

exec sops exec-env "$SECRETS_FILE" "$SCRIPT_DIR/ha-client.py"
