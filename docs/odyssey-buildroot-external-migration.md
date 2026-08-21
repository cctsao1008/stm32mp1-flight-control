# Odyssey BR2_EXTERNAL Migration

## Status

Completed.

The validated Odyssey STM32MP157C Buildroot configuration has been migrated from a locally modified upstream Buildroot working tree into this repository's project-owned `BR2_EXTERNAL` tree.

The authoritative architecture is now:

```text
third_party/buildroot/     pinned upstream Buildroot submodule
        +
buildroot/                 project BR2_EXTERNAL tree
        +
scripts/                   build / clean / verify wrappers
        |
        v
output/odyssey/images/sdcard.img
```

## Authoritative inputs

```text
buildroot/configs/stm32mp1_flight_odyssey_defconfig
buildroot/board/odyssey/linux.config
buildroot/board/odyssey/genimage.cfg
buildroot/board/odyssey/patches/linux/9999-odyssey-enable-fs-usb-device.patch
buildroot/board/odyssey/overlay/boot/extlinux/extlinux.conf
buildroot/board/odyssey/overlay/etc/inittab
buildroot/board/odyssey/overlay/etc/init.d/S50usb-acm
```

Buildroot is pinned at:

```text
2026.05.1
cb857ba4c87a93e5265a9e4a3f32071abf39e14a
```

The migration build was validated from repository revision:

```text
e20e422730c2e6015a824faf0061ebe91fe9da38
```

## Validation result

A fresh recursive clone successfully completed a clean Buildroot build using only the pinned submodule and repository-owned BR2_EXTERNAL tree.

Validated results:

```text
Linux 6.6.0 boots on Odyssey
root=PARTLABEL=rootfs rootwait
rootfs mounts successfully
final DTB contains the validated USBPHYC / DWC2 FS-device configuration
no historical DWC2 soft-reset timeout
ConfigFS CDC ACM gadget binds automatically
/dev/ttyGS0 exists
UDC = 49000000.usb-otg
UDC state = configured
Windows enumerates USB Serial Device (COM25)
Buildroot shell is usable over CDC ACM
```

The final DTB is byte-for-byte identical across the historical validated build and repeated clean BR2_EXTERNAL builds:

```text
878fb69ca251bb38e9118521b3f2464276a6af408cf52688065b0251c7af2d50
```

## Historical working tree

The former `~/github/buildroot-2026.05.1` tree is no longer the project source of truth.

It may be kept temporarily as historical/debug evidence, but project changes must not be maintained there in parallel.

Historical/backup files such as the following are intentionally not active build inputs:

```text
genimage.cfg.bak
linux.config.before-usb-gadget
patches-linux-5.10-backup/*
```

The historical rootfs was also found to contain stale Linux 5.10.1 module metadata alongside Linux 6.6.0 metadata, reinforcing the use of clean repository builds as the authoritative baseline.

## Artifact reproducibility note

Functional reproducibility is validated.

Byte-for-byte image reproducibility is not yet enabled. Repeated clean builds show expected generated differences from:

```text
kernel UTS_VERSION timestamp
BusyBox embedded build timestamp
ext4 UUID / creation metadata
FAT volume serial / timestamps
GPT disk GUID
```

This is separate deterministic-build work and is not a BR2_EXTERNAL migration failure.

## Standard workflow

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

Clean generated output:

```bash
./scripts/clean.sh
```

## Source-of-truth rule

The repository `buildroot/` BR2_EXTERNAL tree is authoritative for Odyssey project-specific Buildroot inputs.

Do not duplicate or manually maintain those project files inside `third_party/buildroot/` or another upstream Buildroot checkout.
