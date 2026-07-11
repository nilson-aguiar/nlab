# Kitchen Exhaustor IR Control Setup

This document details the configuration for integrating a kitchen exhaustor controlled by an IR Blaster (`IR Remote` / `ir_remote` via Zigbee2MQTT) in Home Assistant.

## Key Features
- **Independent State Tracking**: Fan speed and lights are tracked in separate entities.
- **Out-of-Sync Recovery**: Direct helpers (`input_boolean` / `input_select`) are exposed in the UI, allowing manual state synchronization without sending IR commands.
- **Power Sequencing**: Turning on the fan from an off state automatically sends the power IR toggle, waits 1 second, and then sends the speed code.
- **Battery Alerts**: Instant notification when the remote goes offline, plus a daily morning check (10:00 AM) if battery is below 20% or offline.

---

## 1. Directory Structure Setup (Packages)

To use this configuration, your Home Assistant instance must be set up to read configurations from folders and subfolders using **Packages**. 

Add the `packages` block inside the `homeassistant:` section of your `/config/configuration.yaml`:

```yaml
homeassistant:
  media_dirs:
    media: "/config/media"
    recording: /config/recordings  
  # Enable packages to load recursively from folders/subfolders:
  packages: !include_dir_named packages/
```

---

## 2. Package Configuration

All the required entities (helpers, scripts, templates, and automations) are consolidated into a single package file: [kitchen_exhaustor.yaml](kitchen_exhaustor.yaml).

1. Create a directory named `/config/packages/` (if it doesn't already exist) on your Home Assistant configuration volume.
2. Copy the contents of the [kitchen_exhaustor.yaml](kitchen_exhaustor.yaml) file into `/config/packages/kitchen_exhaustor.yaml`.
3. Verify your configuration under **Developer Tools > YAML > Check Configuration** and restart Home Assistant.

---

## 3. Lovelace Dashboard Card Configuration

Use a `vertical-stack` to group your controls nicely. This includes your primary smart entities, as well as a separate grid block containing direct helper switches.

> [!TIP]
> Toggling the switches under **Force Sync (No IR Sent)** will directly update the state inside Home Assistant *without* firing the IR blaster, allowing you to resynchronize states easily if they get mismatched.

```yaml
type: vertical-stack
cards:
  - type: grid
    title: Kitchen Exhaustor
    columns: 2
    square: false
    cards:
      - type: tile
        entity: fan.kitchen_exhaustor
        features:
          - type: fan-preset-modes
            style: icons
            preset_modes:
              - "off"
              - "low"
              - "medium"
              - "high"
        card_mod:
          style:
            hui-card-features $ hui-fan-preset-modes-card-feature $ ha-control-select $: |
              /* Override the icons to use standard MDI speed icons */
              div#option-off ha-icon,
              div#option-off ha-attribute-icon {
                --card-mod-icon: mdi:power !important;
              }
              div#option-low ha-icon,
              div#option-low ha-attribute-icon {
                --card-mod-icon: mdi:fan-speed-1 !important;
              }
              div#option-medium ha-icon,
              div#option-medium ha-attribute-icon {
                --card-mod-icon: mdi:fan-speed-2 !important;
              }
              div#option-high ha-icon,
              div#option-high ha-attribute-icon {
                --card-mod-icon: mdi:fan-speed-3 !important;
              }
      - type: tile
        entity: light.kitchen_exhaustor_light
  - type: grid
    title: Force Sync (No IR Sent)
    columns: 2
    square: false
    cards:
      - type: tile
        entity: input_boolean.kitchen_exhaustor_power
        name: Sync Vent Power
        icon: mdi:sync
      - type: tile
        entity: input_boolean.kitchen_exhaustor_light
        name: Sync Light State
        icon: mdi:sync
```
