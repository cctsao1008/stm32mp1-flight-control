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

The former locally modified upstream Buildroot working tree is no longer authoritative.

## Project defconfig

Path:

```text
buildroot_external/configs/stm32mp1_flight_odyssey_defconfig
```

Purpose:

- selects STM32MP157C Cortex-A7 target
- selects Linux 6.6
- selects U-Boot 2021.10
- selects TF-A v2.5
- selects the Odyssey DTB
- points kernel config, patch, overlay, and genimage paths into the BR2_EXTERNAL tree

Verification:

```bash
./scripts/build.sh
```

Compare generated Buildroot `.config` only after accounting for expected `BR2_EXTERNAL_*` and path metadata.

## Linux kernel config

Path:

```text
buildroot_external/board/odyssey/linux.config
```

Purpose:

```text
CONFIG_USB_GADGET=y
CONFIG_USB_DWC2_PERIPHERAL=y
CONFIG_USB_CONFIGFS=y
CONFIG_USB_CONFIGFS_ACM=y
CONFIG_PHY_STM32_USBPHYC=y
```

Generated artifact:

```text
output/odyssey/build/linux-6.6/.config
output/odyssey/images/zImage
```

Verification:

```bash
grep -E 'CONFIG_USB_DWC2_PERIPHERAL=|CONFIG_USB_GADGET=|CONFIG_USB_CONFIGFS=|CONFIG_USB_CONFIGFS_ACM=|CONFIG_PHY_STM32_USBPHYC=' \
  output/odyssey/build/linux-6.6/.config
```

The clean BR2_EXTERNAL build produced a kernel `.config` identical to the validated working configuration.

## Linux Device Tree patch

Path:

```text
buildroot_external/board/odyssey/patches/linux/9999-odyssey-enable-fs-usb-device.patch
```

Purpose:

- enable STM32 USBPHYC
- configure the integrated STM32MP15 FS OTG path
- use PA11/PA12 FS D+/D- pinctrl
- force peripheral mode
- provide the USB FS power dependency

Generated artifact:

```text
output/odyssey/images/stm32mp157c-odyssey.dtb
```

Verification:

```bash
./scripts/verify-image.sh
```

Validated final DTB SHA256:

```text
878fb69ca251bb38e9118521b3f2464276a6af408cf52688065b0251c7af2d50
```

The DTB is byte-identical across the historical validated build and repeated clean BR2_EXTERNAL builds.

## Rootfs overlay

Root path:

```text
buildroot_external/board/odyssey/overlay/
```

### extlinux.conf

```text
buildroot_external/board/odyssey/overlay/boot/extlinux/extlinux.conf
```

Purpose:

```text
root=PARTLABEL=rootfs rootwait
```

Runtime verification:

```text
cat /proc/cmdline
root=PARTLABEL=rootfs rootwait
```

### inittab

```text
buildroot_external/board/odyssey/overlay/etc/inittab
```

Purpose:

- preserve the validated Buildroot console configuration
- start a getty on `/dev/ttyGS0`

### S50usb-acm

```text
buildroot_external/board/odyssey/overlay/etc/init.d/S50usb-acm
```

Mode:

```text
100755
```

Purpose:

- mount ConfigFS as needed
- create gadget `g1`
- create `acm.usb0`
- bind the gadget to `49000000.usb-otg`

Runtime verification:

```text
/dev/ttyGS0 exists
/sys/class/udc/49000000.usb-otg/state = configured
/sys/kernel/config/usb_gadget/g1/UDC = 49000000.usb-otg
Windows = USB Serial Device (COM25)
```

## genimage layout

Path:

```text
buildroot_external/board/odyssey/genimage.cfg
```

Purpose:

Generate the validated SD-card GPT image with:

```text
fsbl1
fsbl2
ssbl
rootfs
devboot
```

`devboot` is a 64 MiB FAT convenience/debug partition containing:

```text
zImage
stm32mp157c-odyssey.dtb
```

Verification:

```bash
./scripts/verify-image.sh
```

## Build wrapper

```text
scripts/build.sh
```

Purpose:

- use `third_party/buildroot/`
- set `BR2_EXTERNAL=buildroot_external/`
- use `output/odyssey/`
- configure `stm32mp1_flight_odyssey_defconfig` on a fresh output tree
- build with `JOBS=8` by default

## Clean wrapper

```text
scripts/clean.sh
```

Purpose:

Remove generated Odyssey output without modifying source-controlled inputs.

## Verification wrapper

```text
scripts/verify-image.sh
```

Purpose:

- print artifact SHA256 values
- verify GPT partition layout
- verify DEVBOOT contents
- inspect final DTB USB OTG and USBPHYC nodes

## Historical files not used

The following former working-tree files are not active BR2_EXTERNAL inputs:

```text
genimage.cfg.bak
linux.config.before-usb-gadget
patches-linux-5.10-backup/*
```

The old Linux 5.10 DWC2 reset workaround is historical only and is not required by the validated Linux 6.6 USBPHYC/UTMI path.

## Validated end-to-end result

```text
clean recursive clone
    -> pinned Buildroot 2026.05.1
    -> BR2_EXTERNAL defconfig
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

This repository-owned path is now authoritative.
