# Home Assistant Jinja2 Template Reference

The `/api/template` endpoint evaluates Jinja2 templates directly on the Home Assistant server. This is especially useful for querying complex state conditions, filtering entities without pulling megabytes of JSON from `/api/states`, and checking attributes.

Invoke using the REST helper:
```bash
ha-api.sh /api/template -d '{"template": "TEMPLATE_STRING"}'
```

---

## Useful Query Patterns

### 1. Count Entities by Domain
```jinja
{{ states.light | count }} lights, {{ states.sensor | count }} sensors, {{ states.binary_sensor | count }} binary sensors.
```

### 2. Find All Entities in a Specific State
Find all lights that are currently `on`:
```jinja
{{ states.light | selectattr('state', 'eq', 'on') | map(attribute='entity_id') | list }}
```

Find all unavailable entities across the entire system:
```jinja
{{ states | selectattr('state', 'in', ['unavailable', 'unknown']) | map(attribute='entity_id') | list }}
```

### 3. Filter by Device Class or Attribute
Find battery sensors with level below 20%:
```jinja
{% set low_battery = states.sensor
  | selectattr('attributes.device_class', 'defined')
  | selectattr('attributes.device_class', 'eq', 'battery')
  | selectattr('state', 'match', '^[0-9]+$')
  | map(attribute='state')
  | map('int')
  | select('lt', 20)
  | list %}
{{ low_battery }}
```

List low battery entities with their percentages:
```jinja
{% for s in states.sensor if s.attributes.device_class == 'battery' and s.state | int(100) < 20 %}
- {{ s.entity_id }}: {{ s.state }}%
{% endfor %}
```

### 4. Check an Area's Devices
Find all lights belonging to an area (e.g., `office`):
```jinja
{{ area_entities('office') | select('match', '^light\\.') | list }}
```

### 5. Check Sun / Time / Solar Elevation
```jinja
Sun elevation: {{ state_attr('sun.sun', 'elevation') }}°, Next dawn: {{ state_attr('sun.sun', 'next_dawn') }}
```

### 6. Format Entity List as Clean JSON
```jinja
{{ states.climate | map(attribute='entity_id') | list | to_json }}
```
