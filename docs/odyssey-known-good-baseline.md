# ODYSSEY STM32MP157C Known-good Baseline

## Validated Software Baseline

```text
Buildroot:      2026.05.1
Linux:          6.6.0
U-Boot:         2021.10
TF-A / BL2:     v2.5
TF-A / SP_MIN:  v2.5
Board:          Seeed Studio Odyssey-STM32MP157C
CPU:            STM32MP157CAC Rev.B
Host:           WSL Ubuntu
Build jobs:     make -j8
```

Authoritative build source:

```text
third_party/buildroot/     pinned upstream Buildroot submodule
buildroot_external/        project-owned BR2_EXTERNAL tree
scripts/build.sh           build entry point
output/odyssey/            generated output
```

Pinned Buildroot commit:

```text
cb857ba4c87a93e5265a9e4a3f32071abf39e14a
```

## Validated Boot and Rootfs

```text
root=PARTLABEL=rootfs rootwait
```

The clean image boots Linux 6.6.0 and mounts the SD-card rootfs read/write.

## Validated USB CDC ACM Path

```text
PA11/PA12
    -> STM32 USBPHYC
    -> UTMI clock
    -> DWC2 UDC
    -> ConfigFS gadget g1 / acm.usb0
    -> /dev/ttyGS0
    -> BusyBox getty
    -> Windows USB Serial Device (COM25)
```

Validated checks:

```text
/dev/ttyGS0 exists
UDC = 49000000.usb-otg
UDC state = configured
Windows = USB Serial Device (COM25)
Buildroot login shell works over CDC ACM
```

The historical Linux 5.10.1 DWC2 soft-reset timeout is not present.

## Validated Device Tree

The final DTB contains the STM32MP15 FS OTG peripheral configuration with USBPHYC and OTG/UTMI clocks.

Validated DTB SHA256:

```text
878fb69ca251bb38e9118521b3f2464276a6af408cf52688065b0251c7af2d50
```

## Validated GPT / DEVBOOT Layout

```text
1  fsbl1     206 KiB
2  fsbl2     206 KiB
3  ssbl      1011 KiB
4  rootfs    60 MiB
5  devboot   64 MiB
```

DEVBOOT contains `zImage` and `stm32mp157c-odyssey.dtb` and is convenience/debug only.

## Hardware-validated Clean-build Hashes

```text
sdcard.img:                    82fafbb3ac93151cc0eba44b40ba75cc77ec5ffb43717441c5ac9655a31a0821
zImage:                        8b1141ad967f1a98f0278a5c5ae8a4ea1830597303c3f3d8043f99e699e5ebe9
stm32mp157c-odyssey.dtb:       878fb69ca251bb38e9118521b3f2464276a6af408cf52688065b0251c7af2d50
rootfs.ext4:                   c56a6e8fc011ce3e19e16019ba892f9b3eadc31c7dc9d6986263c32f5b0faa8e
```

These identify the hardware-validated build. Byte-for-byte deterministic rebuilds are tracked separately.

## Authoritative Board-owned Inputs

```text
buildroot_external/configs/stm32mp1_flight_odyssey_defconfig
buildroot_external/board/odyssey/linux.config
buildroot_external/board/odyssey/genimage.cfg
buildroot_external/board/odyssey/patches/linux/9999-odyssey-enable-fs-usb-device.patch
buildroot_external/board/odyssey/overlay/boot/extlinux/extlinux.conf
buildroot_external/board/odyssey/overlay/etc/inittab
buildroot_external/board/odyssey/overlay/etc/init.d/S50usb-acm
```

The repository `buildroot_external/` BR2_EXTERNAL tree is authoritative. The old modified upstream Buildroot checkout is historical/debug evidence only.

## Acceptance Status

```text
[x] clean recursive clone build
[x] pinned Buildroot submodule
[x] Linux 6.6.0 runtime
[x] final DTB validated
[x] GPT / DEVBOOT validated
[x] PARTLABEL=rootfs boot
[x] rootfs mounted read/write
[x] S50usb-acm auto-start
[x] /dev/ttyGS0
[x] UDC configured
[x] Windows COM25
[x] Buildroot login shell over CDC ACM
[x] buildroot_external/ promoted to authoritative project tree
```
