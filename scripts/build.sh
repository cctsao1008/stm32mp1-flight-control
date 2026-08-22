#!/usr/bin/env bash

set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILDROOT_DIR="${ROOT_DIR}/third_party/buildroot"
EXTERNAL_DIR="${ROOT_DIR}/buildroot_external"
OUTPUT_DIR="${ROOT_DIR}/output/odyssey"
DEFCONFIG="stm32mp1_flight_odyssey_defconfig"
JOBS="${JOBS:-8}"

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

if [[ ! -f "${BUILDROOT_DIR}/Makefile" ]]; then
    echo "ERROR: Buildroot submodule is not initialized."
    echo "Run: git submodule update --init --recursive"
    exit 1
fi

if [[ ! -f "${EXTERNAL_DIR}/configs/${DEFCONFIG}" ]]; then
    echo "ERROR: ${EXTERNAL_DIR}/configs/${DEFCONFIG} is not present."
    echo "The project BR2_EXTERNAL tree should be under buildroot_external/."
    exit 1
fi

if [[ -z "${SOURCE_DATE_EPOCH:-}" ]]; then
    SOURCE_DATE_EPOCH="$(git -C "${ROOT_DIR}" log -1 --format=%ct HEAD 2>/dev/null || true)"
fi

if [[ -n "${SOURCE_DATE_EPOCH:-}" ]]; then
    export SOURCE_DATE_EPOCH
    echo "SOURCE_DATE_EPOCH=${SOURCE_DATE_EPOCH}"
else
    echo "WARNING: SOURCE_DATE_EPOCH could not be derived; Buildroot will use its reproducible-build fallback."
fi

mkdir -p "${OUTPUT_DIR}"

if [[ ! -f "${OUTPUT_DIR}/.config" ]]; then
    echo "Configuring ${DEFCONFIG}..."
    make -C "${BUILDROOT_DIR}" \
        O="${OUTPUT_DIR}" \
        BR2_EXTERNAL="${EXTERNAL_DIR}" \
        "${DEFCONFIG}" || exit $?
fi

echo "Building Odyssey image with -j${JOBS}..."
make -C "${BUILDROOT_DIR}" \
    O="${OUTPUT_DIR}" \
    BR2_EXTERNAL="${EXTERNAL_DIR}" \
    -j"${JOBS}"
