# Odyssey Buildroot Build Flow

## Overview

The validated Odyssey STM32MP157C platform is built from this repository using a pinned upstream Buildroot submodule plus a project-owned BR2_EXTERNAL tree.

```text
stm32mp1-flight-control/
        |
        +-- third_party/buildroot/
        |      Buildroot 2026.05.1
        |      pinned commit cb857ba...
        |
        +-- buildroot_external/
        |      project defconfig
        |      kernel config
        |      Linux patch
        |      rootfs overlay
        |      genimage layout
        |
        +-- scripts/build.sh
               |
               v
        output/odyssey/
```

## Configuration flow

```text
buildroot_external/configs/stm32mp1_flight_odyssey_defconfig
        |
        +-- Linux 6.6
        +-- U-Boot 2021.10
        +-- TF-A v2.5
        +-- kernel custom config
        +-- global patch directory
        +-- rootfs overlay
        +-- genimage post-image configuration
        |
        v
output/odyssey/.config
```

Project paths are expressed through:

```text
$(BR2_EXTERNAL_STM32MP1_FLIGHT_PATH)
```

so persistent project files are not stored inside upstream Buildroot.

## Linux flow

```text
buildroot_external/board/odyssey/linux.config
        +
buildroot_external/board/odyssey/patches/linux/9999-odyssey-enable-fs-usb-device.patch
        |
        v
Buildroot Linux 6.6 source
        |
        +-- generated kernel .config
        +-- patched Odyssey DTS
        |
        v
zImage + stm32mp157c-odyssey.dtb
```

Validated USB DT/runtime path:

```text
PA11/PA12
    -> STM32 USBPHYC
    -> UTMI clock
    -> DWC2 49000000.usb-otg
    -> peripheral mode
```

The final DTB SHA256 is stable across repeated clean builds:

```text
878fb69ca251bb38e9118521b3f2464276a6af408cf52688065b0251c7af2d50
```

## Rootfs flow

```text
Buildroot target skeleton/packages
        +
buildroot_external/board/odyssey/overlay/
        |
        +-- boot/extlinux/extlinux.conf
        +-- etc/inittab
        +-- etc/init.d/S50usb-acm
        |
        v
output/odyssey/target/
        |
        v
rootfs.ext4
```

The validated kernel command line is:

```text
root=PARTLABEL=rootfs rootwait
```

The USB gadget startup script creates ConfigFS gadget `g1`, ACM function `acm.usb0`, and binds it to `49000000.usb-otg`.

## Image flow

```text
TF-A
U-Boot
rootfs.ext4
zImage
DTB
        +
buildroot_external/board/odyssey/genimage.cfg
        |
        v
sdcard.img
```

Validated GPT layout:

```text
p1 fsbl1    206 KiB
p2 fsbl2    206 KiB
p3 ssbl     1011 KiB
p4 rootfs   60 MiB
p5 devboot  64 MiB
```

DEVBOOT contains:

```text
zImage
stm32mp157c-odyssey.dtb
```

Normal U-Boot boot still loads kernel and DTB from `/boot` on partition 4.

## Standard commands

Clone:

```bash
git clone --recursive https://github.com/cctsao1008/stm32mp1-flight-control.git
cd stm32mp1-flight-control
```

Build:

```bash
./scripts/build.sh
```

Verify:

```bash
./scripts/verify-image.sh
```

Clean:

```bash
./scripts/clean.sh
```

## Hardware acceptance

The clean BR2_EXTERNAL image has passed:

```text
U-Boot 2021.10
Linux 6.6.0
root=PARTLABEL=rootfs rootwait
rootfs read/write mount
USBPHYC initialization
DWC2 peripheral initialization
no historical DWC2 Soft Reset timeout
ConfigFS CDC ACM bind
/dev/ttyGS0
UDC configured
Windows USB Serial Device (COM25)
Buildroot login shell
```

## Reproducibility boundary

Functional reproduction from source is validated.

Full byte-for-byte image determinism is separate work because the current build embeds or generates timestamps, filesystem UUIDs, FAT metadata, and GPT GUIDs.

The repository-owned `buildroot_external/` tree is authoritative; do not maintain duplicate project changes inside an upstream Buildroot working tree.
