#!/usr/bin/env python3
import json
import os
import subprocess
import sys

base_url = os.environ.get("HOMEASSISTANT_URL") or os.environ.get("HASS_SERVER") or os.environ.get("HASS_URL")
token = os.environ.get("HOMEASSISTANT_TOKEN") or os.environ.get("HASS_TOKEN")

if not base_url or not token:
    sys.stderr.write("Error: HOMEASSISTANT_URL and HOMEASSISTANT_TOKEN must be set in encrypted env file.\n")
    sys.exit(1)

# Normalize base_url (strip /api/mcp, /api, or trailing slashes)
for suffix in ("/api/mcp", "/api"):
    if base_url.endswith(suffix):
        base_url = base_url[:-len(suffix)]
base_url = base_url.rstrip("/")

endpoint = os.environ.get("HA_REQ_ENDPOINT", "/api/")
if not endpoint.startswith("/"):
    endpoint = "/" + endpoint

raw_args_json = os.environ.get("HA_REQ_ARGS_JSON", "[]")
try:
    extra_args = json.loads(raw_args_json)
except Exception:
    extra_args = []

url = f"{base_url}{endpoint}"

cmd = ["curl", "-sS", "-H", f"Authorization: Bearer {token}", "-H", "Content-Type: application/json"]

has_data = any(a in ("-d", "--data", "--data-raw", "--data-binary") for a in extra_args)
has_method = any(a in ("-X", "--request") for a in extra_args)

if not has_method:
    if has_data:
        cmd.extend(["-X", "POST"])
    else:
        cmd.extend(["-X", "GET"])

cmd.extend(extra_args)
cmd.append(url)

res = subprocess.run(cmd)
sys.exit(res.returncode)
