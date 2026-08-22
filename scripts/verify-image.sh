#!/usr/bin/env bash

set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${ROOT_DIR}/output/odyssey"
IMAGES_DIR="${OUTPUT_DIR}/images"
BUILD_DIR="${OUTPUT_DIR}/build"
HOST_DIR="${OUTPUT_DIR}/host"

SDCARD="${IMAGES_DIR}/sdcard.img"
ZIMAGE="${IMAGES_DIR}/zImage"
DTB="${IMAGES_DIR}/stm32mp157c-odyssey.dtb"
ROOTFS="${IMAGES_DIR}/rootfs.ext4"
DEVBOOT="${IMAGES_DIR}/devboot.vfat"
TFA="${IMAGES_DIR}/tf-a-stm32mp157c-odyssey.stm32"
UBOOT="${IMAGES_DIR}/u-boot.stm32"
DTC="${HOST_DIR}/bin/dtc"

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
for f in "${SDCARD}" "${ZIMAGE}" "${DTB}" "${ROOTFS}" "${DEVBOOT}" "${TFA}" "${UBOOT}"; do
    [[ -f "${f}" ]] && sha256sum "${f}"
done

VMLINUX="${BUILD_DIR}/linux-6.6/vmlinux"
IMAGE="${BUILD_DIR}/linux-6.6/arch/arm/boot/Image"
BUSYBOX="${BUILD_DIR}/busybox-1.38.0/busybox"

if [[ -f "${VMLINUX}" || -f "${IMAGE}" || -f "${BUSYBOX}" ]]; then
    echo
    echo "===== Intermediate SHA256 ====="
    [[ -f "${VMLINUX}" ]] && sha256sum "${VMLINUX}"
    [[ -f "${IMAGE}" ]] && sha256sum "${IMAGE}"
    [[ -f "${BUSYBOX}" ]] && sha256sum "${BUSYBOX}"
fi

echo
echo "===== Reproducibility Metadata ====="
COMPILE_H="${BUILD_DIR}/linux-6.6/include/generated/compile.h"
if [[ -f "${COMPILE_H}" ]]; then
    grep -E 'UTS_VERSION|LINUX_COMPILE_(BY|HOST)' "${COMPILE_H}" || true
fi

if [[ -f "${BUSYBOX}" ]] && command -v strings >/dev/null 2>&1; then
    strings "${BUSYBOX}" | grep -m1 '^BusyBox v' || true
fi

DUMPE2FS="${HOST_DIR}/sbin/dumpe2fs"
if [[ ! -x "${DUMPE2FS}" ]]; then
    DUMPE2FS="$(command -v dumpe2fs || true)"
fi
if [[ -f "${ROOTFS}" && -n "${DUMPE2FS}" ]]; then
    "${DUMPE2FS}" -h "${ROOTFS}" 2>/dev/null | grep -E 'Filesystem UUID|Filesystem created|Last write time' || true
else
    echo "WARNING: ext4 metadata could not be reported."
fi

MDIR="${HOST_DIR}/bin/mdir"
if [[ ! -x "${MDIR}" ]]; then
    MDIR="$(command -v mdir || true)"
fi
if [[ -f "${DEVBOOT}" && -n "${MDIR}" ]]; then
    "${MDIR}" -i "${DEVBOOT}" :: 2>/dev/null | sed -n '1,6p'
else
    echo "WARNING: FAT metadata could not be reported."
fi

SGDISK="$(command -v sgdisk || true)"
if [[ -n "${SGDISK}" ]]; then
    "${SGDISK}" -p "${SDCARD}" | grep -E 'Disk identifier \(GUID\)|Number  Start' || true
else
    echo "WARNING: GPT GUID could not be reported because sgdisk is unavailable."
fi

echo
echo "===== GPT / Partition Table ====="
if [[ -n "${SGDISK}" ]]; then
    "${SGDISK}" -p "${SDCARD}"
elif command -v fdisk >/dev/null 2>&1; then
    fdisk -l "${SDCARD}"
else
    echo "WARNING: neither sgdisk nor fdisk is available."
fi

echo
echo "===== DEVBOOT Contents ====="
if [[ -f "${DEVBOOT}" && -n "${MDIR}" ]]; then
    "${MDIR}" -i "${DEVBOOT}" ::
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
echo "Verification script completed. Review the output against docs/odyssey-known-good-baseline.md and docs/odyssey-reproducible-build.md."
