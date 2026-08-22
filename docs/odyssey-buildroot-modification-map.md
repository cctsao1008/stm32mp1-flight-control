# Odyssey Buildroot Modification Map

## Purpose

This document maps each project-owned Buildroot input to its purpose, generated artifact, and verification method.

The current source-of-truth architecture is:

```text
third_party/buildroot/     pinned upstream Buildroot 2026.05.1 submodule
buildroot_external/        project-owned BR2_EXTERNAL tree
scripts/                   build / clean / verify wrappers
output/odyssey/            generated output
```

## Project defconfig

```text
buildroot_external/configs/stm32mp1_flight_odyssey_defconfig
```

Selects STM32MP157C, Linux 6.6, U-Boot 2021.10, TF-A v2.5, the Odyssey DTB, and the project-owned kernel/patch/overlay/genimage paths.

## Linux kernel config

```text
buildroot_external/board/odyssey/linux.config
```

Key persistent options include USB gadget, DWC2 peripheral, ConfigFS ACM, and STM32 USBPHYC support.

## Linux Device Tree patch

```text
buildroot_external/board/odyssey/patches/linux/9999-odyssey-enable-fs-usb-device.patch
```

Enables USBPHYC and the STM32MP15 integrated FS OTG peripheral path using PA11/PA12.

Validated final DTB SHA256:

```text
878fb69ca251bb38e9118521b3f2464276a6af408cf52688065b0251c7af2d50
```

## Rootfs overlay

```text
buildroot_external/board/odyssey/overlay/
```

Important files:

```text
buildroot_external/board/odyssey/overlay/boot/extlinux/extlinux.conf
buildroot_external/board/odyssey/overlay/etc/inittab
buildroot_external/board/odyssey/overlay/etc/init.d/S50usb-acm
```

`S50usb-acm` remains executable (`100755`) and creates ConfigFS gadget `g1`, ACM function `acm.usb0`, and binds it to `49000000.usb-otg`.

## genimage layout

```text
buildroot_external/board/odyssey/genimage.cfg
```

Generates the validated GPT image with `fsbl1`, `fsbl2`, `ssbl`, `rootfs`, and `devboot`.

## Build wrapper

```text
scripts/build.sh
```

Uses:

```text
BUILDROOT_DIR=<repo>/third_party/buildroot
EXTERNAL_DIR=<repo>/buildroot_external
OUTPUT_DIR=<repo>/output/odyssey
```

## Verification

```bash
./scripts/build.sh
./scripts/verify-image.sh
```

Validated end-to-end result:

```text
clean recursive clone
    -> pinned Buildroot 2026.05.1
    -> buildroot_external/ BR2_EXTERNAL
    -> Linux 6.6 build
    -> validated DTB/GPT/DEVBOOT
    -> flash sdcard.img
    -> Linux boots from PARTLABEL=rootfs
    -> USBPHYC + DWC2 initialize
    -> ConfigFS CDC ACM binds
    -> /dev/ttyGS0
    -> UDC configured
    -> Windows COM25
    -> Buildroot login shell
```

The old modified upstream Buildroot checkout and historical 5.10 backup files are not active project inputs.
