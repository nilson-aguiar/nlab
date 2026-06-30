# StackChan Home Assistant & ESPHome Integration

StackChan is an AI desktop robot powered by the M5Stack flagship IoT development kit **CoreS3**. This document outlines the configuration, components, and calibration details for integrating StackChan with ESPHome and Home Assistant.

## Hardware Specifications
- **Main Controller**: ESP32-S3 (240 MHz dual-core, 16MB flash, 8MB PSRAM)
- **Display**: 2.0-inch capacitive touchscreen (ILI9342C)
- **Audio**: 1W speaker, dual microphones
- **Sensors**: Proximity sensor, 9-axis IMU, GC0308 camera
- **Connectivity**: Wi-Fi & BLE

---

## ESPHome Package Configuration
To build firmware for StackChan, reference the official BSP packages from M5Stack:

```yaml
packages:
  remote_package_files:
    url: https://github.com/m5stack/esphome-yaml
    files: [examples/kit/stackchan-bsp.factory.yaml]
    ref: main
    refresh: 0s
```

---

## Key Peripherals and Components

### 1. Power Management (AW9523B IO Expander)
The AW9523B is used for reset and power control via I2C:
- **`BOOST_EN`**: Must be enabled **first** to power the boost circuit.
- **`BUS_OUT_EN`** and **`USB_OTG_EN`**: Can be enabled after `BOOST_EN` is active to route power.

### 2. Audio Input (ES7210 Audio ADC)
- Interfaced via I2C.
- **Important**: When using the voice assistant pipeline, the `sample_rate` **must** be set to `16000` Hz.

### 3. Display (ILI9342C LCD)
- Interfaced via SPI.
- Maximum `data_rate` is limited to `40MHz`.
- Set `invert_colors: true` to correct the RGB color space.

### 4. Custom Servos (ftservo)
- Interfaced via UART.
- **Range limits**:
  - X-Axis (Pan): `-165°` to `165°`
  - Y-Axis (Tilt): `0°` to `90°`
- **Servo Power**: Controlled by **M5IOE1 IO Expander Pin 1**.

### 5. Touch Sensor (Si12T Capacitive Touch)
- Interfaced via I2C.
- Reports touch intensity states to Home Assistant: `HIGH`, `MEDIUM`, `LOW`, or `No touch`.

### 6. RGB Light Bar
- Driven by the NeoPixel driver on the **M5IOE1** board.
- Controlled automatically through the `light` component in ESPHome.

---

## Servo Calibration Procedure
If the head orientation is misaligned, perform the calibration:
1. Manually move StackChan to its **zero position** (facing straight forward, level head).
2. Press the **Servo Calibration** button on the Home Assistant entity card or ESPHome dashboard.
3. Wait **1 second** for the zero-position configuration to be successfully written to the ESP32 Non-Volatile Storage (NVS).
4. Restart/Reset the StackChan and slowly test the pan/tilt sliders to verify correctness.

> [!WARNING]
> Always verify the reachable range of motion before testing high servo angles to prevent mechanical/servo damage.

---

## Resources & References
- **Official GitHub Repository**: [m5stack/StackChan](https://github.com/m5stack/StackChan)
- **Local Clone Path**: [/Users/naguiar/workspace/nilson-aguiar/personal/homelab/StackChan](file:///Users/naguiar/workspace/nilson-aguiar/personal/homelab/StackChan) (Contains firmware source, remote control protocols, and mobile app code for references).

