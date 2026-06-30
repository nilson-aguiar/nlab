#!/usr/bin/env bash
# Filter noisy ESPHome StackChan logs down to the lines that matter.
#
# The CoreS3 logs are ~99% I2C/display/servo/touch chatter at VERBOSE level.
# This strips that noise so the audio / voice-assistant / wake-word / error
# lines are readable (and cheap to paste into a chat for debugging).
#
# Usage:
#   ./filter-log.sh logs-1            # voice + audio + errors (default)
#   ./filter-log.sh logs-1 all        # everything except the known noise
#   ./filter-log.sh logs-1 err        # warnings + errors only
#   cat logs-1 | ./filter-log.sh -    # read from stdin
#
# Prefer ripgrep (rg) if available, fall back to grep.

set -euo pipefail

src="${1:--}"
mode="${2:-voice}"

# Lines that are almost always pure noise on this board.
NOISE='i2c\.idf|FT63X6|touchscreen|mipi_spi|\[V\]\[sensor|esp32_camera|Sending 7 jobs|TCP buffer space'

# Signal we care about for the voice pipeline.
SIGNAL='voice_assistant|micro_wake_word|mww|media_player|speaker|i2s|wake|vad|tts|stt|announc|microphone|aw88|es7210|pipeline|\bapi\b|client|\[E\]|\[W\]'

read_src() { if [[ "$src" == "-" ]]; then cat; else cat "$src"; fi; }

if command -v rg >/dev/null 2>&1; then
  filter_noise() { rg -v "$NOISE"; }
  keep_signal()  { rg -i "$SIGNAL"; }
  keep_err()     { rg '\[E\]|\[W\]'; }
else
  filter_noise() { grep -Ev "$NOISE"; }
  keep_signal()  { grep -iE "$SIGNAL"; }
  keep_err()     { grep -E '\[E\]|\[W\]'; }
fi

case "$mode" in
  voice) read_src | keep_signal | filter_noise ;;
  all)   read_src | filter_noise ;;
  err)   read_src | keep_err ;;
  *) echo "unknown mode: $mode (use: voice | all | err)" >&2; exit 1 ;;
esac
