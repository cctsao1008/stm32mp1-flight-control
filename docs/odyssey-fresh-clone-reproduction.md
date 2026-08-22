# Odyssey Fresh-clone Reproduction

## Status

Validated.

A fresh recursive clone of this repository successfully reproduced the Odyssey STM32MP157C platform using only the pinned Buildroot submodule and the project-owned BR2_EXTERNAL tree.

## Clone

```bash
git clone --recursive https://github.com/cctsao1008/stm32mp1-flight-control.git
cd stm32mp1-flight-control
```

Verify Buildroot:

```bash
git -C third_party/buildroot rev-parse HEAD
```

Expected:

```text
cb857ba4c87a93e5265a9e4a3f32071abf39e14a
```

## Build

```bash
./scripts/build.sh
```

The validated build uses:

```text
Buildroot:    2026.05.1
Linux:        6.6.0
U-Boot:       2021.10
TF-A:         v2.5
Defconfig:    stm32mp1_flight_odyssey_defconfig
BR2_EXTERNAL: buildroot_external/
Output:       output/odyssey/
```

## Static verification

```bash
./scripts/verify-image.sh
```

Validated static results:

```text
GPT:
  fsbl1
  fsbl2
  ssbl
  rootfs
  devboot

DEVBOOT:
  zImage
  stm32mp157c-odyssey.dtb

DTB:
  st,stm32mp15-fsotg + snps,dwc2
  clock-names = otg, utmi
  dr_mode = peripheral
  USBPHYC status = okay
```

The DTB SHA256 is reproducible across the historical validated tree and repeated clean repository builds:

```text
878fb69ca251bb38e9118521b3f2464276a6af408cf52688065b0251c7af2d50
```

## Hardware validation

The clean-generated `sdcard.img` was flashed to the Odyssey board and passed:

```text
U-Boot 2021.10 boot
Linux 6.6.0 boot
root=PARTLABEL=rootfs rootwait
rootfs mounted read/write
USBPHYC initialized
DWC2 UDC initialized
no DWC2 Soft Reset timeout
ConfigFS CDC ACM auto-start
/dev/ttyGS0 present
UDC = 49000000.usb-otg
UDC state = configured
Windows USB Serial Device (COM25)
Buildroot shell over CDC ACM
```

Explicit runtime evidence:

```text
cat /sys/class/udc/49000000.usb-otg/state
configured

cat /sys/kernel/config/usb_gadget/g1/UDC
49000000.usb-otg

cat /proc/cmdline
root=PARTLABEL=rootfs rootwait

mount | grep ' on / '
/dev/root on / type ext4 (rw,relatime)
```

Windows PowerShell showed:

```text
COM25    USB Serial Device (COM25)
```

## Hardware-validated clean-build hashes

```text
sdcard.img:                    82fafbb3ac93151cc0eba44b40ba75cc77ec5ffb43717441c5ac9655a31a0821
zImage:                        8b1141ad967f1a98f0278a5c5ae8a4ea1830597303c3f3d8043f99e699e5ebe9
stm32mp157c-odyssey.dtb:       878fb69ca251bb38e9118521b3f2464276a6af408cf52688065b0251c7af2d50
rootfs.ext4:                   c56a6e8fc011ce3e19e16019ba892f9b3eadc31c7dc9d6986263c32f5b0faa8e
```

These identify the validated build but are not all expected to repeat byte-for-byte until deterministic-build controls are enabled.

## Deterministic-build note

Repeated clean builds demonstrated that functional configuration is stable while some generated artifacts vary because of:

```text
kernel UTS_VERSION timestamp
BusyBox embedded build timestamp
ext4 filesystem UUID / creation metadata
FAT volume serial / timestamps
GPT disk GUID
```

The glibc binary and final DTB were reproducible between clean builds. Byte-for-byte full-image reproducibility is separate follow-up work.

## Source-of-truth rule

The repository-owned `buildroot_external/` BR2_EXTERNAL tree is authoritative.

Do not maintain duplicate project changes inside an upstream Buildroot checkout.
