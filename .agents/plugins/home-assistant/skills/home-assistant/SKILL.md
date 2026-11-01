---
name: home-assistant
description: Comprehensive Home Assistant integration guide covering both ha-mcp (Model Context Protocol) tool usage and direct REST API interaction via encrypted secrets. Use when querying entities, executing services, inspecting history/logs, evaluating Jinja2 templates, or automating Home Assistant.
---

# Home Assistant Integration

This skill equips the agent to interact with Home Assistant via two complementary interfaces:
1. **`ha-mcp` Tools**: High-level, native tool calls (when the MCP server is connected).
2. **REST API Helper (`ha-api.sh`)**: Direct HTTP interaction with any Home Assistant API endpoint, secured with SOPS.

---

## 1. Choosing the Right Tool

| Task | Preferred Approach | Why |
| :--- | :--- | :--- |
| Quick entity state / attribute lookup | `ha-mcp` or `ha-api.sh /api/states/<id>` | Fast and targeted |
| Standard service execution (light on, climate set) | `ha-mcp` | Natural structured arguments |
| Complex multi-entity filtering or Jinja2 logic | `ha-api.sh /api/template` | Filters server-side; avoids pulling all states |
| Historical data or logbook inspection | `ha-api.sh /api/history/...` | Directly queries HA history database |
| Check configuration or view error log | `ha-api.sh /api/config/core/check_config` | Core administrative control |
| Fallback if MCP is disconnected | `ha-api.sh` | Directly interacts via HTTP without MCP daemon dependency |

---

## 2. Using the REST API Helper (`ha-api.sh`)

The helper script is located at:
[scripts/ha-api.sh](./scripts/ha-api.sh)

It automatically loads credentials from `secrets/ha-mcp.enc.env` using `sops exec-env` without exposing keys.

### Common Invocations

1. **Verify API Connection**:
   ```bash
   .agents/plugins/home-assistant/skills/home-assistant/scripts/ha-api.sh /api/
   ```

2. **Get Entity State**:
   ```bash
   .agents/plugins/home-assistant/skills/home-assistant/scripts/ha-api.sh /api/states/light.living_room
   ```

3. **Call a Service**:
   ```bash
   .agents/plugins/home-assistant/skills/home-assistant/scripts/ha-api.sh /api/services/light/turn_on -d '{"entity_id": "light.living_room", "brightness": 255}'
   ```

4. **Evaluate Jinja2 Template**:
   ```bash
   .agents/plugins/home-assistant/skills/home-assistant/scripts/ha-api.sh /api/template -d '{"template": "{{ states.light | selectattr(\"state\", \"eq\", \"on\") | map(attribute=\"entity_id\") | list }}"}'
   ```

5. **Validate Configuration**:
   ```bash
   .agents/plugins/home-assistant/skills/home-assistant/scripts/ha-api.sh /api/config/core/check_config
   ```

For the complete list of endpoints and template patterns, see:
* [API Endpoints Reference](./references/endpoints.md)
* [Jinja2 Template Reference](./references/templates.md)

---

## 3. Using `ha-mcp` Tools

When `ha-mcp` is running and connected (configured via the plugin's `mcp_config.json`):
* Tools like `ha_get_states`, `ha_call_service`, etc., appear directly in your active tool list.
* Prefer using these native tools for standard conversational turns (e.g. "turn off the kitchen lights" or "what is the temperature in the bedroom?").
* If an MCP tool returns an error or is unavailable, immediately fall back to the `ha-api.sh` REST script.

---

## 4. Operational Guidelines

* **Filter Server-Side**: Never query `/api/states` unfiltered if you only need 1 or 2 entities. Use `/api/states/<entity_id>` or evaluate a template via `/api/template` to keep context small and fast.
* **Service Safety**: Before calling disruptive services (rebooting the host, changing alarms, locking/unlocking doors), confirm intended target entity IDs.
* **Secret Integrity**: Always use `sops` to manage and modify `ha-mcp.enc.env`. Never write plaintext tokens to markdown or scripts.
