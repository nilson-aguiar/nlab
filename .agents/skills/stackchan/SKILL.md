---
name: stackchan-integration
description: Guides development, configuration, and troubleshooting for the M5Stack StackChan CoreS3 robot in Home Assistant and ESPHome.
---
# StackChan Integration Guidelines

Use this skill when configuring, deploying, or troubleshooting the M5Stack StackChan CoreS3 robot integration in ESPHome or Home Assistant.

## BSP Package Import

### Upstream reference (original)
The official M5Stack BSP. Keep this as the canonical source — use it as the
starting point and to diff against when re-vendoring or checking for upstream fixes:
```yaml
packages:
  remote_package_files:
    url: https://github.com/m5stack/esphome-yaml
    files: [examples/kit/stackchan-bsp.factory.yaml]
    ref: main
    refresh: 0s
```

### Vendored copy (what this project actually uses)
A local copy of the upstream BSP has been vendored into this repo and is
referenced from the project's own GitHub repo instead of m5stack's. The copy
lives at `k8s/10_apps/01_home-assistant/base/esphome/stackchan/stackchan-bsp.factory.yaml`
and `stackchan.yaml` imports it like this:
```yaml
packages:
  bsp:
    url: https://github.com/nilson-aguiar/nlab
    ref: main
    files: [k8s/10_apps/01_home-assistant/base/esphome/stackchan/stackchan-bsp.factory.yaml]
    refresh: 0s
```

**Why vendored, and changes made vs upstream** (see the header comment in the
vendored file for the authoritative, always-current list):
1. `external_components` `source` pinned to a fixed m5stack commit (was tracking
   `main`) for reproducible builds.
2. `ltr_als_ps`: added `id:` to the `ambient_light` and proximity (`ps_counts`)
   sub-sensors so the main config can read them for auto-brightness and the
   proximity greeting (upstream exposes a name only, no id).

When upstream ships a fix, re-fetch the official file (above), re-apply changes
1 & 2, bump the pinned commit, and update the vendored copy's header.

## Key Configuration Constraints
1. **Power Sequence (AW9523B)**: Set `BOOST_EN` to true first to allow boost circuit to boot up before enabling `BUS_OUT_EN` or `USB_OTG_EN`.
2. **Audio Sample Rate (ES7210)**: For Voice Assistant pipelines, the audio ADC sample rate must be exactly `16000` Hz.
3. **Display Colors (ILI9342C)**: SPI configuration must set `invert_colors: true` to prevent color inversion on the 2.0-inch LCD.
4. **Servo Power (M5IOE1)**: Servos require enabling Pin 1 on the M5IOE1 Multi-function IO Expander.
5. **Servo Angles (ftservo)**: Limit X to `[-165°, 165°]` and Y to `[0°, 90°]` to protect hardware.
6. **Calibration**:
   - Align head straight forward at zero position.
   - Trigger the `Servo Calibration` button and wait 1s for NVS write.
   - Reset the ESP32 to load calibrated values.

## Log Triage
ESPHome StackChan logs are ~99% I2C / display / servo / touch chatter at `VERBOSE`
level, plus TCP-buffer backpressure spam during audio playback. Use the bundled
`filter-log.sh` (lives next to this file) to cut a log down to the
voice / audio / wake-word / error signal **before** reading or pasting it — it
turns a multi-thousand-line dump into a few dozen relevant lines and saves a lot
of tokens.

```bash
# default "voice" mode: voice_assistant + audio + wake word + errors
.agents/skills/stackchan/filter-log.sh <logfile>
.agents/skills/stackchan/filter-log.sh <logfile> all   # everything minus known noise
.agents/skills/stackchan/filter-log.sh <logfile> err   # warnings + errors only
cat <logfile> | .agents/skills/stackchan/filter-log.sh -   # read from stdin
```

When troubleshooting the voice pipeline, prefer this over reading raw logs. Trace
the expected turn: wake word → STT (`Starting STT by VAD`) → intent → TTS
(`Response URL`) → speaker `ANNOUNCING` → `Announcement finished playing` →
`micro_wake_word` restart. Watch for `Parent bus is busy` — the mic and speaker
share one half-duplex I2S bus and cannot run at once, so the mic must be fully
released before the speaker starts (and re-armed only after playback ends).

## Code References
- If you need to inspect custom/factory C++ firmware logic or remote controller protocol code, refer to the local clone of the official repository: [/Users/naguiar/workspace/nilson-aguiar/personal/homelab/StackChan](file:///Users/naguiar/workspace/nilson-aguiar/personal/homelab/StackChan).

