# STM32MP1 Flight-control BR2_EXTERNAL Tree

This directory owns the project-specific Buildroot configuration for the Seeed Odyssey STM32MP157C platform.

## Authoritative architecture

```text
third_party/buildroot/     pinned upstream Buildroot 2026.05.1 submodule
buildroot/                 this project-owned BR2_EXTERNAL tree
scripts/                   build / clean / verify wrappers
output/odyssey/            generated output
```

The BR2_EXTERNAL migration has passed clean-clone build and hardware runtime validation. This directory is the source of truth for persistent Odyssey Buildroot customizations.

## Defconfig

```text
configs/stm32mp1_flight_odyssey_defconfig
```

## Board files

```text
board/odyssey/linux.config
board/odyssey/genimage.cfg
board/odyssey/patches/linux/9999-odyssey-enable-fs-usb-device.patch
board/odyssey/overlay/boot/extlinux/extlinux.conf
board/odyssey/overlay/etc/inittab
board/odyssey/overlay/etc/init.d/S50usb-acm
```

## Build

From the repository root:

```bash
./scripts/build.sh
```

## Verify

```bash
./scripts/verify-image.sh
```

## Clean

```bash
./scripts/clean.sh
```

## Validated runtime

The clean repository build has been validated on Odyssey hardware with:

```text
Linux 6.6.0
root=PARTLABEL=rootfs rootwait
USBPHYC initialized
DWC2 peripheral UDC
ConfigFS CDC ACM
/dev/ttyGS0
UDC state configured
Windows USB Serial Device (COM25)
Buildroot login shell over USB-C
```

## Ownership rule

Do not maintain duplicate project changes inside `third_party/buildroot/` or another upstream Buildroot checkout.

The old modified `~/github/buildroot-2026.05.1` tree may be retained only as historical/debug evidence.

Historical files such as the following are not active project inputs:

```text
genimage.cfg.bak
linux.config.before-usb-gadget
patches-linux-5.10-backup/*
```

## Deterministic-build note

Functional reproducibility is validated. Full byte-for-byte image reproducibility is separate follow-up work because current generated artifacts include kernel/BusyBox build timestamps and filesystem/GPT generated metadata.
