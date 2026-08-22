# Odyssey BR2_EXTERNAL Migration

## Status

Completed.

The validated Odyssey STM32MP157C Buildroot configuration has been migrated from a locally modified upstream Buildroot working tree into this repository's project-owned `BR2_EXTERNAL` tree.

The authoritative architecture is now:

```text
third_party/buildroot/     pinned upstream Buildroot submodule
        +
buildroot_external/        project BR2_EXTERNAL tree
        +
scripts/                   build / clean / verify wrappers
        |
        v
output/odyssey/images/sdcard.img
```

## Authoritative inputs

```text
buildroot_external/configs/stm32mp1_flight_odyssey_defconfig
buildroot_external/board/odyssey/linux.config
buildroot_external/board/odyssey/genimage.cfg
buildroot_external/board/odyssey/patches/linux/9999-odyssey-enable-fs-usb-device.patch
buildroot_external/board/odyssey/overlay/boot/extlinux/extlinux.conf
buildroot_external/board/odyssey/overlay/etc/inittab
buildroot_external/board/odyssey/overlay/etc/init.d/S50usb-acm
```

Buildroot is pinned at:

```text
2026.05.1
cb857ba4c87a93e5265a9e4a3f32071abf39e14a
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

The final DTB SHA256 remains:

```text
878fb69ca251bb38e9118521b3f2464276a6af408cf52688065b0251c7af2d50
```

## Hardware-validated clean-build hashes

```text
sdcard.img:                    82fafbb3ac93151cc0eba44b40ba75cc77ec5ffb43717441c5ac9655a31a0821
zImage:                        8b1141ad967f1a98f0278a5c5ae8a4ea1830597303c3f3d8043f99e699e5ebe9
stm32mp157c-odyssey.dtb:       878fb69ca251bb38e9118521b3f2464276a6af408cf52688065b0251c7af2d50
rootfs.ext4:                   c56a6e8fc011ce3e19e16019ba892f9b3eadc31c7dc9d6986263c32f5b0faa8e
```

These identify the validated build but are not all expected to repeat byte-for-byte until deterministic-build controls are enabled.

## Historical working tree

The former `~/github/buildroot-2026.05.1` tree is no longer the project source of truth. It may be retained as historical/debug evidence only.

The historical rootfs was found to contain stale Linux 5.10.1 module metadata alongside Linux 6.6.0 metadata, reinforcing the use of clean repository builds as the authoritative baseline.

## Artifact reproducibility note

Functional reproducibility is validated. Byte-for-byte image reproducibility is tracked separately because current generated output contains kernel/BusyBox build timestamps, ext4 metadata, FAT metadata, and GPT GUIDs.

## Standard workflow

```bash
git clone --recursive https://github.com/cctsao1008/stm32mp1-flight-control.git
cd stm32mp1-flight-control
./scripts/build.sh
./scripts/verify-image.sh
```

## Source-of-truth rule

The repository `buildroot_external/` BR2_EXTERNAL tree is authoritative for Odyssey project-specific Buildroot inputs.

Do not duplicate or manually maintain those project files inside `third_party/buildroot/` or another upstream Buildroot checkout.
