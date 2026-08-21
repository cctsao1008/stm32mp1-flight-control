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

U-Boot currently boots from partition 4:

```text
Scanning mmc 0:4...
Found /boot/extlinux/extlinux.conf
```

`DEVBOOT` is not currently authoritative for boot.

---

## 4. Validated Rootfs Selection

Kernel command line:

```text
root=PARTLABEL=rootfs rootwait
```

This is intentional.

Do not replace it with:

```text
root=/dev/mmcblk0p4
```

because Linux 6.6 may enumerate:

```text
eMMC = mmcblk0
SD   = mmcblk1
```

The working boot sequence has demonstrated:

```text
Waiting for root device PARTLABEL=rootfs...
EXT4-fs (mmcblk1p4): mounted ...
VFS: Mounted root ...
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
        -> Windows USB Serial Device (COMxx)
```

Expected runtime log includes:

```text
stm32-usbphyc 5a006000.usbphyc: registered rev:1.0
dwc2 49000000.usb-otg: EPs: 9, dedicated fifos, 952 entries in SPRAM
USB UDC: 49000000.usb-otg
dwc2 49000000.usb-otg: bound driver configfs-gadget.g1
USB CDC ACM gadget started
dwc2 49000000.usb-otg: new device is full-speed
```

Expected UDC state while connected to Windows:

```bash
cat /sys/class/udc/49000000.usb-otg/state
```

Expected:

```text
configured
```

Expected terminal behavior:

```text
Welcome to Buildroot
buildroot login: root
#
```

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

The inherited Linux 6.6 SoC definition also supplies:

```text
clock-names = "otg", "utmi"
```

The previous Linux 5.10.1 failure:

```text
dwc2_core_reset: HANG! Soft Reset timeout GRSTCTL_CSFTRST
```

must not appear.

---

## 7. Validated DEVBOOT Layout

Expected GPT names:

```text
1  fsbl1
2  fsbl2
3  ssbl
4  rootfs
5  devboot
```

A validated generated image showed approximately:

```text
p1  206 KiB
p2  206 KiB
p3  1011 KiB
p4  60 MiB
p5  64 MiB
```

Expected DEVBOOT contents:

```text
zImage
stm32mp157c-odyssey.dtb
```

Verification:

```bash
sgdisk -p output/images/sdcard.img
mdir -i output/images/devboot.vfat ::
```

---

## 8. Known Non-blocking Messages

Some boot messages are not currently treated as baseline failures unless they correlate with real functional problems.

Examples observed during bring-up include:

```text
invalid MAC address in OTP 00:00:00:00:00:00
No ethernet found.
clk: failed to reparent ethck_k to pll4_p: -22
mdio_bus ... MDIO device at address 7 is missing.
Date/Time must be initialized
```

These are outside the validated USB CDC ACM and SD-rootfs bring-up scope.

The generated small GPT image may also report a backup-GPT placement warning after being written to a much larger SD card. That warning is tracked separately and does not invalidate the current five-partition boot result.

---

## 9. Artifact Hash Record

A known-good baseline should record hashes for the final deployable artifacts.

From the Buildroot directory:

```bash
cd ~/github/buildroot-2026.05.1

sha256sum \
  output/images/sdcard.img \
  output/images/zImage \
  output/images/stm32mp157c-odyssey.dtb \
  output/images/rootfs.ext4
```

Record them here when the current source tree is frozen:

```text
sdcard.img:                    <TO_BE_RECORDED>
zImage:                        <TO_BE_RECORDED>
stm32mp157c-odyssey.dtb:      <TO_BE_RECORDED>
rootfs.ext4:                   <TO_BE_RECORDED>
```

Do not invent or copy hashes from an older build. They must come from the exact frozen build being declared known-good.

---

## 10. Baseline Acceptance Checklist

A new baseline is accepted only when all applicable checks pass:

```text
[ ] Build completes successfully with make -j8
[ ] uname reports expected Linux version
[ ] final DTB contains FS OTG + USBPHYC + power dependency
[ ] GPT contains fsbl1/fsbl2/ssbl/rootfs/devboot
[ ] kernel command line uses PARTLABEL=rootfs
[ ] rootfs mounts successfully
[ ] S50usb-acm starts automatically
[ ] /dev/ttyGS0 exists
[ ] UDC is 49000000.usb-otg
[ ] UDC state reaches configured with Windows connected
[ ] Windows enumerates USB Serial Device (COMxx)
[ ] Buildroot login shell works over CDC ACM
[ ] DEVBOOT is Windows-readable
[ ] final SHA256 hashes are recorded
```

---

## 11. Change-control Rule

When changing any of the following, treat the previous baseline as a comparison reference rather than assuming compatibility:

```text
Buildroot version
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

For major platform changes, preserve the previous known-good artifact hashes and boot log until the new baseline passes the full acceptance checklist.
