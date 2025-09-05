#!/bin/sh
set -e

KERNEL_VERSION=$(uname -r)
MODULES_BUILTIN=$(find /host-lib/modules/${KERNEL_VERSION} -name modules.builtin)

if [ -n "${MODULES_BUILTIN}" ]; then
  echo "--kconfig-file=${MODULES_BUILTIN}"
fi
