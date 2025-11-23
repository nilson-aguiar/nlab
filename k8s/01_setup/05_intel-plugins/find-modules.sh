#!/bin/sh
set -e

KERNEL_VERSION=$(uname -r)
MODULES_BUILTIN=$(find /nix/store -maxdepth 1 -type d -regextype posix-extended -regex "/nix/store/[a-z0-9]{32}-linux-$(uname -r)$")

if [ -n "${MODULES_BUILTIN}" ]; then
  echo "--kconfig-file=${MODULES_BUILTIN}"
fi
