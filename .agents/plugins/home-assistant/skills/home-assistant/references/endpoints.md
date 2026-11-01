# Home Assistant REST API Reference

The Home Assistant REST API allows full programmatic control and inspection. All requests must include:
* `Authorization: Bearer <LONG_LIVED_ACCESS_TOKEN>`
* `Content-Type: application/json`

Use the helper script `ha-api.sh` to call these endpoints with automatic secret decryption.

---

## 1. System & Discovery

### Check API Status
* **GET** `/api/`
* Returns: `{"message": "API running."}`

### Check Configuration
* **GET** `/api/config`
* Returns core metadata: location, components loaded, unit system, version, etc.

### Validate Configuration
* **POST** `/api/config/core/check_config`
* Trigger YAML validation (useful after modifying package or automation files).
* Returns: `{"result": "valid", "errors": null}`

### Get Error Logs
* **GET** `/api/error_log`
* Returns plain-text error log from the Home Assistant core process.

---

## 2. Entities & States

### List All States
* **GET** `/api/states`
* Returns an array of state objects for all tracked entities.

### Get State of an Entity
* **GET** `/api/states/<entity_id>`
* Example: `ha-api.sh /api/states/light.living_room`
* Returns:
  ```json
  {
    "entity_id": "light.living_room",
    "state": "on",
    "attributes": {
      "brightness": 255,
      "friendly_name": "Living Room Light"
    },
    "last_changed": "2026-11-01T12:00:00.000000+00:00",
    "last_updated": "2026-11-01T12:00:00.000000+00:00"
  }
  ```

### Manually Set State of an Entity
* **POST** `/api/states/<entity_id>`
* Payload:
  ```json
  {
    "state": "22.5",
    "attributes": {
      "unit_of_measurement": "°C",
      "friendly_name": "Custom Temperature"
    }
  }
  ```
  *(Note: Setting state via REST changes representation in the state machine; for physical devices, call a service instead).*

---

## 3. Services

### List Available Services
* **GET** `/api/services`
* Returns list of domains (e.g. `light`, `switch`, `climate`) and their supported services with field schemas.

### Call a Service
* **POST** `/api/services/<domain>/<service>`
* Examples:
  * Turn on light:
    ```bash
    ha-api.sh /api/services/light/turn_on -d '{"entity_id": "light.living_room", "brightness": 200}'
    ```
  * Trigger automation:
    ```bash
    ha-api.sh /api/services/automation/trigger -d '{"entity_id": "automation.good_morning"}'
    ```
  * Reload automations/scripts/core:
    ```bash
    ha-api.sh /api/services/automation/reload
    ha-api.sh /api/services/homeassistant/reload_all
    ```

---

## 4. History & Logbook

### Query History
* **GET** `/api/history/period/<timestamp>`
* Query parameters:
  * `filter_entity_id=<entity_id>,<entity_id>`
  * `end_time=<timestamp>`
  * `minimal_response=true`
* Example:
  ```bash
  ha-api.sh "/api/history/period/2026-11-01T00:00:00Z?filter_entity_id=sensor.indoor_temp"
  ```

### Query Logbook
* **GET** `/api/logbook/<timestamp>`
* Query parameters:
  * `entity=<entity_id>`
  * `end_time=<timestamp>`

---

## 5. Templates

### Render Template
* **POST** `/api/template`
* Payload: `{"template": "<Jinja2 template string>"}`
* Evaluates dynamic Jinja2 expressions against the live Home Assistant state machine. See [templates.md](./templates.md) for advanced patterns.
