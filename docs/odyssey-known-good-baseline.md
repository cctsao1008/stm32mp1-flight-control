# ODYSSEY STM32MP157C Known-good Baseline

## 1. Purpose

This document defines the currently validated software/platform combination for the Odyssey STM32MP157C bring-up.

Its purpose is to provide a stable reference when later changes produce unexpected behavior.

A build should not be called a new known-good baseline until it has completed the verification checklist in this document.

---

## 2. Validated Software Baseline

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

The authoritative build source is now this repository using:

```text
third_party/buildroot/     pinned upstream Buildroot submodule
buildroot_external/        project-owned BR2_EXTERNAL tree
scripts/build.sh           build entry point
output/odyssey/            generated output
```

Validated Buildroot submodule commit:

```text
cb857ba4c87a93e5265a9e4a3f32071abf39e14a
```

Validated Linux build identification observed at runtime:

```text
Linux version 6.6.0
arm-buildroot-linux-gnueabihf-gcc.br_real
Buildroot 2026.05.1
```

---

## 3. Validated Boot Architecture

```text
SD card
  |
  +-- p1 fsbl1
  +-- p2 fsbl2
  +-- p3 ssbl
  +-- p4 rootfs
  |      |
  |      +-- /boot/extlinux/extlinux.conf
  |      +-- /boot/zImage
  |      +-- /boot/stm32mp157c-odyssey.dtb
  |
  +-- p5 devboot (FAT, convenience/debug only)
```

U-Boot boots from partition 4:

```text
Scanning mmc 0:4...
Found /boot/extlinux/extlinux.conf
```

`DEVBOOT` is not authoritative for boot.

---

## 4. Validated Rootfs Selection

Kernel command line:

```text
root=PARTLABEL=rootfs rootwait
```

This is intentional. Do not replace it with a fixed `/dev/mmcblkXp4` path because SD/eMMC enumeration may change between kernel versions or configurations.

Validated runtime evidence from the clean BR2_EXTERNAL image:

```text
Kernel command line: root=PARTLABEL=rootfs rootwait
Waiting for root device PARTLABEL=rootfs...
mmcblk0: p1 p2 p3 p4 p5
VFS: Mounted root (ext4 filesystem) readonly on device 179:4.
EXT4-fs (mmcblk0p4): re-mounted ... r/w.
```

Runtime shell verification:

```text
cat /proc/cmdline
root=PARTLABEL=rootfs rootwait

mount | grep ' on / '
/dev/root on / type ext4 (rw,relatime)
```

---

## 5. Validated USB CDC ACM Baseline

The working USB-C gadget path is:

```text
STM32MP15 USB FS pins PA11/PA12
        -> STM32 USBPHYC
        -> UTMI clock
        -> DWC2 UDC
        -> ConfigFS gadget g1
        -> acm.usb0
        -> /dev/ttyGS0
        -> BusyBox getty
        -> Windows USB Serial Device (COM25)
```

Validated runtime evidence:

```text
stm32-usbphyc 5a006000.usbphyc: registered rev:1.0
dwc2 49000000.usb-otg: EPs: 9, dedicated fifos, 952 entries in SPRAM
Starting USB CDC ACM gadget...
USB UDC: 49000000.usb-otg
dwc2 49000000.usb-otg: bound driver configfs-gadget.g1
USB CDC ACM gadget started
dwc2 49000000.usb-otg: new device is full-speed
dwc2 49000000.usb-otg: new address 52
```

Explicit gadget checks:

```text
ls -l /dev/ttyGS0
crw--w---- 1 root root 247, 0 ... /dev/ttyGS0

cat /sys/class/udc/49000000.usb-otg/state
configured

cat /sys/kernel/config/usb_gadget/g1/UDC
49000000.usb-otg
```

Windows enumeration:

```text
COM25    USB Serial Device (COM25)
```

The Buildroot login shell is functional over the CDC ACM connection.

---

## 6. Validated USB Device-tree Requirements

The final DTB must contain the equivalent of:

```dts
&pwr_regulators {
    vdd-supply = <&vdd>;
    vdd_3v3_usbfs-supply = <&vdd_usb>;
};

&usbphyc {
    status = "okay";
};

&usbotg_hs {
    compatible = "st,stm32mp15-fsotg", "snps,dwc2";
    pinctrl-names = "default";
    pinctrl-0 = <&usbotg_hs_pins_a &usbotg_fs_dp_dm_pins_a>;
    dr_mode = "peripheral";
    status = "okay";
};
```

The inherited Linux 6.6 SoC definition supplies the USBPHYC/UTMI clock dependency. The validated final DTB contains:

```text
compatible = "st,stm32mp15-fsotg", "snps,dwc2"
clock-names = "otg", "utmi"
dr_mode = "peripheral"
status = "okay"
```

The previous Linux 5.10.1 failure:

```text
dwc2_core_reset: HANG! Soft Reset timeout GRSTCTL_CSFTRST
```

is not present in the validated clean-build boot.

---

## 7. Validated DEVBOOT Layout

Expected GPT names and validated layout:

```text
1  fsbl1     206 KiB
2  fsbl2     206 KiB
3  ssbl      1011 KiB
4  rootfs    60 MiB
5  devboot   64 MiB
```

Validated DEVBOOT contents:

```text
zImage
stm32mp157c-odyssey.dtb
```

`DEVBOOT` is a convenience/debug FAT partition and does not control the normal boot path.

---

## 8. Known Non-blocking Messages

The following messages are not currently treated as baseline failures unless they correlate with a real functional problem:

```text
invalid MAC address in OTP 00:00:00:00:00:00
No ethernet found.
clk: failed to reparent ethck_k to pll4_p: -22
mdio_bus ... MDIO device at address 7 is missing.
Date/Time must be initialized
dwc2 ... supply vusb_d not found, using dummy regulator
dwc2 ... supply vusb_a not found, using dummy regulator
```

A freshly written ext4 rootfs may also perform journal recovery on first boot and then remount read/write. The validated image completed that recovery successfully.

---

## 9. Authoritative Clean BR2_EXTERNAL Baseline

The hardware-validated clean build was produced from the repository-owned BR2_EXTERNAL tree and flashed successfully to the Odyssey board.

Validated artifact hashes from that build:

```text
sdcard.img:                    82fafbb3ac93151cc0eba44b40ba75cc77ec5ffb43717441c5ac9655a31a0821
zImage:                        8b1141ad967f1a98f0278a5c5ae8a4ea1830597303c3f3d8043f99e699e5ebe9
stm32mp157c-odyssey.dtb:       878fb69ca251bb38e9118521b3f2464276a6af408cf52688065b0251c7af2d50
rootfs.ext4:                   c56a6e8fc011ce3e19e16019ba892f9b3eadc31c7dc9d6986263c32f5b0faa8e
```

These hashes identify the specific hardware-validated build, but not all generated artifacts are currently byte-for-byte reproducible across clean builds.

Known deterministic-build differences include:

```text
kernel UTS_VERSION build timestamp
BusyBox embedded build timestamp
ext4 filesystem UUID / creation metadata
FAT volume serial / timestamps
GPT disk GUID
```

Therefore functional acceptance and deterministic byte reproducibility are tracked separately.

### Directory-rename regression validation

After renaming the project external tree from `buildroot/` to `buildroot_external/`, a full clean rebuild and static verification were completed successfully.

Observed regression evidence:

```text
BR2_EXTERNAL resolves to buildroot_external/
overlay is checked and copied from buildroot_external/board/odyssey/overlay/
Linux 6.6 build completes
rootfs image generation completes
genimage completes
GPT layout remains fsbl1/fsbl2/ssbl/rootfs/devboot
DEVBOOT still contains zImage and stm32mp157c-odyssey.dtb
final DTB SHA256 remains 878fb69ca251bb38e9118521b3f2464276a6af408cf52688065b0251c7af2d50
scripts/verify-image.sh completes successfully
```

No Buildroot functional input was changed by the directory rename. New `zImage`, rootfs, FAT, GPT, and full-image hashes are expected to differ until deterministic-build controls are implemented.

---

## 10. Historical Known-good Artifact Record

Before the BR2_EXTERNAL migration, the modified upstream Buildroot working tree produced:

```text
sdcard.img:                    863bfe155e523340a891fad8693b39562997352760c2f66c14b860da253b3992
zImage:                        3b09a7ffbc6df19ff7dbca35a916a77d86bf89739f0a59601b775289bbdbfa92
stm32mp157c-odyssey.dtb:       878fb69ca251bb38e9118521b3f2464276a6af408cf52688065b0251c7af2d50
rootfs.ext4:                   8eb0f4e0ebc02dc85b4b9c026135b94e379399dcaf40e4d54bf52631b35aa9b5
devboot.vfat:                  bfa76560eefb5c0e9fae1693324fb69eef2b1735d3ea601a4039aee9a8fd880b
tf-a-stm32mp157c-odyssey.stm32: 3ca5ce1d77c3c33fa033f04507cfd8583ca48429203abcd6915b399df2b2fc2a
u-boot.stm32:                  70fa1d13430d7e11de08cbe5e2b0e0306251044fad42ab0027056a158d75b366
```

That historical rootfs was later found to contain stale `/lib/modules/5.10.1/` metadata alongside Linux 6.6.0 module metadata. Its hashes are preserved for historical comparison only and are no longer the authoritative clean-build target.

---

## 11. Authoritative Board-owned Inputs

The project-owned build inputs are now:

```text
buildroot_external/configs/stm32mp1_flight_odyssey_defconfig
buildroot_external/board/odyssey/linux.config
buildroot_external/board/odyssey/genimage.cfg
buildroot_external/board/odyssey/patches/linux/9999-odyssey-enable-fs-usb-device.patch
buildroot_external/board/odyssey/overlay/boot/extlinux/extlinux.conf
buildroot_external/board/odyssey/overlay/etc/inittab
buildroot_external/board/odyssey/overlay/etc/init.d/S50usb-acm
```

Historical/backup files from the former modified upstream Buildroot working tree are not active inputs:

```text
genimage.cfg.bak
linux.config.before-usb-gadget
patches-linux-5.10-backup/*
```

The repository `buildroot_external/` BR2_EXTERNAL tree is authoritative. Do not maintain duplicate project changes inside an upstream Buildroot checkout.

---

## 12. Baseline Acceptance Checklist

The clean BR2_EXTERNAL baseline has passed:

```text
[x] Build completes successfully with make -j8 from a clean recursive clone
[x] pinned Buildroot submodule is used
[x] runtime reports Linux 6.6.0
[x] final DTB contains FS OTG + USBPHYC + power/UTMI dependency
[x] DTB is byte-identical across repeated clean builds
[x] GPT contains fsbl1/fsbl2/ssbl/rootfs/devboot
[x] kernel command line uses PARTLABEL=rootfs
[x] rootfs mounts successfully and remounts read/write
[x] S50usb-acm starts automatically
[x] /dev/ttyGS0 exists
[x] UDC is 49000000.usb-otg
[x] UDC state reaches configured with Windows connected
[x] Windows enumerates USB Serial Device (COM25)
[x] Buildroot login shell works over CDC ACM
[x] DEVBOOT contains zImage and stm32mp157c-odyssey.dtb
[x] historical and clean-build SHA256 values compared
[x] kernel/BusyBox byte differences explained as timestamp metadata
[x] clean BR2_EXTERNAL build promoted to authoritative baseline
[x] buildroot_external directory rename passed clean-build/static regression verification
```

Byte-for-byte deterministic image generation is a separate follow-up objective.

---

## 13. Change-control Rule

When changing any of the following, treat this baseline as a comparison reference rather than assuming compatibility:

```text
Buildroot version
Buildroot submodule revision
Linux version
U-Boot version
TF-A version
kernel config
Device Tree patch
rootfs overlay
extlinux.conf
genimage.cfg
USB gadget descriptor configuration
```

For major platform changes, preserve the previous known-good artifact hashes and boot log until the new baseline passes the applicable functional acceptance checklist.
