#!/usr/bin/env bash

set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGES_DIR="${ROOT_DIR}/output/odyssey/images"

SDCARD="${IMAGES_DIR}/sdcard.img"
ZIMAGE="${IMAGES_DIR}/zImage"
DTB="${IMAGES_DIR}/stm32mp157c-odyssey.dtb"
ROOTFS="${IMAGES_DIR}/rootfs.ext4"
DEVBOOT="${IMAGES_DIR}/devboot.vfat"
DTC="${ROOT_DIR}/output/odyssey/host/bin/dtc"

missing=0
for f in "${SDCARD}" "${ZIMAGE}" "${DTB}"; do
    if [[ ! -f "${f}" ]]; then
        echo "MISSING: ${f}"
        missing=1
    fi
done

if [[ "${missing}" -ne 0 ]]; then
    exit 1
fi

echo "===== Artifact SHA256 ====="
sha256sum "${SDCARD}" "${ZIMAGE}" "${DTB}"
if [[ -f "${ROOTFS}" ]]; then
    sha256sum "${ROOTFS}"
fi

echo
echo "===== GPT / Partition Table ====="
if command -v sgdisk >/dev/null 2>&1; then
    sgdisk -p "${SDCARD}"
elif command -v fdisk >/dev/null 2>&1; then
    fdisk -l "${SDCARD}"
else
    echo "WARNING: neither sgdisk nor fdisk is available."
fi

echo
echo "===== DEVBOOT Contents ====="
if [[ -f "${DEVBOOT}" ]] && command -v mdir >/dev/null 2>&1; then
    mdir -i "${DEVBOOT}" ::
elif [[ ! -f "${DEVBOOT}" ]]; then
    echo "WARNING: ${DEVBOOT} not found."
else
    echo "WARNING: mdir is not available."
fi

echo
echo "===== Final DTB USB Checks ====="
if [[ -x "${DTC}" ]]; then
    TMP_DTS="$(mktemp)"
    "${DTC}" -I dtb -O dts "${DTB}" > "${TMP_DTS}" 2>/dev/null

    echo "-- usb-otg@49000000 --"
    grep -A22 'usb-otg@49000000' "${TMP_DTS}" || true

    echo
    echo "-- usbphyc@5a006000 --"
    grep -A18 'usbphyc@5a006000' "${TMP_DTS}" || true

    echo
    echo "-- rootfs / devboot labels are verified from GPT output above --"
    rm -f "${TMP_DTS}"
else
    echo "WARNING: Buildroot dtc not found at ${DTC}."
fi

echo
echo "Verification script completed. Review the output against docs/odyssey-known-good-baseline.md."
