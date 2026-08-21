# ODYSSEY STM32MP157C USB CDC ACM Bring-up Notes

## 1. Purpose

This document records the end-to-end investigation, findings, modifications, and final working solution for enabling a **USB CDC ACM serial console over the USB-C port** on the **Seeed Studio Odyssey STM32MP157C** board.

The final result is:

- Booting Linux from SD card
- Enumerating the board as a **USB Serial Device** on Windows
- Exposing `/dev/ttyGS0` on Linux
- Running a login shell over USB CDC ACM
- Accessing Buildroot shell from Windows terminal via COM port

---

## 2. Initial Problem Statement

The original goal was to use the Odyssey STM32MP157C board as a **USB CDC ACM gadget** over its USB-C port, so that Windows could detect it as a COM port and use it as a serial console.

### Initial observed symptoms

On Windows 11:

- Device appeared as a Linux USB gadget/composite device
- Hardware identity initially included `VID_1D6B&PID_0104`
- Windows selected the inbox USB composite stack
- Device failed to start with:
  - `CM_PROB_FAILED_START`
  - Code 10
  - `STATUS_NO_SUCH_DEVICE`
- Zadig did not help and no useful alternative binding path was available

On the board side:

- USB gadget behavior from the original image was unreliable
- The desired CDC ACM function was not available as a stable COM port
- Later Buildroot bring-up showed `USB UDC not found` until the underlying controller issue was fixed

---

## 3. Early Windows-side Investigation

### 3.1 Initial assumption

The issue initially looked like a Windows driver problem because:

- Windows detected the device
- `usbccgp` was involved
- The composite device failed to start
- No working COM port was created

### 3.2 Important finding

This was **not fundamentally a Windows driver-download problem**.

The Windows failure was a symptom of an incomplete device-side USB gadget bring-up. The real problems were in:

- STM32MP15 FS OTG controller enablement
- Linux DWC2 / USBPHYC support
- Device Tree clock and power dependencies
- Gadget configuration

---

## 4. Buildroot Direction

Because the original image did not provide a clean and controllable USB gadget setup, the project moved to a custom Buildroot image.

### Buildroot baseline

Used:

- Buildroot `2026.05.1`
- Target baseline: `stm32mp157c_odyssey_defconfig`

Key generated artifacts included:

- `sdcard.img`
- `zImage`
- `stm32mp157c-odyssey.dtb`
- TF-A image
- U-Boot image
- root filesystem image

---

## 5. Image Layout and DEVBOOT Partition

A FAT32 `DEVBOOT` partition was added for convenient access to the kernel and DTB from Windows.

The final GPT layout became:

1. `fsbl1`
2. `fsbl2`
3. `ssbl`
4. `rootfs`
5. `devboot`

Example final layout:

```text
Number  Start (sector)    End (sector)  Size       Code  Name
   1              34             445   206.0 KiB   8300  fsbl1
   2             446             857   206.0 KiB   8300  fsbl2
   3             858            2879   1011.0 KiB  8300  ssbl
   4            2880          125759   60.0 MiB    8300  rootfs
   5          125760          256831   64.0 MiB    0700  devboot
```

Important note:

- U-Boot continued to boot from partition 4 (`rootfs`) and `/boot/extlinux/extlinux.conf`
- `DEVBOOT` is a convenience partition, not the authoritative boot partition

---

## 6. CDC ACM Kernel Configuration

The Buildroot kernel configuration was updated to include USB gadget and ConfigFS ACM support.

Relevant kernel options:

```text
CONFIG_USB_DWC2_PERIPHERAL=y
CONFIG_USB_GADGET=y
CONFIG_USB_CONFIGFS=y
CONFIG_USB_CONFIGFS_ACM=y
CONFIG_USB_LIBCOMPOSITE=y
CONFIG_USB_F_ACM=y
CONFIG_USB_U_SERIAL=y
CONFIG_CONFIGFS_FS=y
```

A startup script was added:

```text
/etc/init.d/S50usb-acm
```

The script:

- mounts ConfigFS if needed
- creates gadget `g1`
- creates `acm.usb0`
- links the function into the configuration
- finds the first available UDC
- binds the gadget
- exposes `/dev/ttyGS0`

Lab VID/PID used during bring-up:

```text
VID = 0525
PID = A4A7
```

These are suitable for development/testing only and should not be treated as production USB identity values.

---

## 7. Major Root Cause #1: Linux 5.10.1 FS OTG Support Was Incomplete

The first attempt used Linux `5.10.1`.

### 7.1 Board DTS enablement

The Odyssey DTS was modified so the STM32MP15 USB OTG block would run in FS peripheral mode.

Conceptually:

```dts
&usbotg_hs {
    compatible = "st,stm32mp15-fsotg", "snps,dwc2";
    pinctrl-names = "default";
    pinctrl-0 = <&usbotg_hs_pins_a &usbotg_fs_dp_dm_pins_a>;
    dr_mode = "peripheral";
    status = "okay";
};
```

### 7.2 Runtime failure

Even with the DTS enabled, Linux 5.10.1 failed during DWC2 probe:

```text
dwc2_core_reset: HANG! Soft Reset timeout GRSTCTL_CSFTRST
dwc2: probe of 49000000.usb-otg failed with error -16
```

Because DWC2 probe failed:

```text
/sys/class/udc
```

contained no usable UDC and the gadget startup script reported:

```text
ERROR: USB UDC not found
```

### 7.3 PHYSEL workaround attempt

An early FS PHY selection workaround was inserted before the first DWC2 core reset.

The patch applied successfully but did **not** fix the runtime reset timeout.

### 7.4 Deeper finding

Source inspection showed that Linux 5.10.1 lacked the later STM32MP15 FS OTG infrastructure required for a clean solution, especially:

- USBPHYC 48 MHz clock provider support
- DWC2 optional UTMI clock consumer handling
- newer STM32MP15 FS OTG integration

Conclusion:

> Linux 5.10.1 was not a good base for a maintainable Odyssey USB CDC ACM implementation.

---

## 8. Key Decision: Upgrade to Linux 6.6

The project switched the Buildroot kernel to Linux `6.6`.

### Why Linux 6.6

Linux 6.6 already contains the upstream pieces that were missing from 5.10.1:

- STM32 USBPHYC clock provider
- `ck_usbo_48m`
- USBPHYC `#clock-cells = <0>`
- DWC2 optional `utmi` clock handling
- newer STM32MP15 FS OTG support

The SoC DTS in Linux 6.6 already provides:

```dts
clocks = <&rcc USBO_K>, <&usbphyc>;
clock-names = "otg", "utmi";
```

This eliminated the need for custom DWC2 driver hacks.

---

## 9. Major Root Cause #2: Missing Odyssey Board-level USB FS DTS Overrides

A minimal board-specific DTS patch was added for Linux 6.6.

Final board logic:

```dts
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

This enabled:

- STM32MP15 integrated FS transceiver
- PA11 / PA12 USB FS D-/D+
- peripheral/gadget mode
- USBPHYC clock provider

After this change, DWC2 probe succeeded:

```text
stm32-usbphyc 5a006000.usbphyc: registered rev:1.0
dwc2 49000000.usb-otg: EPs: 9, dedicated fifos, 952 entries in SPRAM
```

The earlier soft-reset timeout disappeared.

---

## 10. Major Root Cause #3: Missing USB FS Power Dependency

After DWC2 and UDC started working, the gadget could enumerate, but the link later detached.

Observed sequence:

```text
USB UDC: 49000000.usb-otg
dwc2 49000000.usb-otg: bound driver configfs-gadget.g1
USB CDC ACM gadget started
dwc2 49000000.usb-otg: new device is full-speed
dwc2 49000000.usb-otg: new address ...
...
vdd_usb: disabling
```

At that point:

```text
cat /sys/class/udc/49000000.usb-otg/state
```

returned:

```text
not attached
```

### Root cause

The STM32MP15 internal USB FS power dependency was not fully described in the board DTS.

### Fix

Added:

```dts
&pwr_regulators {
    vdd-supply = <&vdd>;
    vdd_3v3_usbfs-supply = <&vdd_usb>;
};
```

After this change:

- `vdd_usb` was no longer disabled
- USB attachment remained stable
- Windows enumeration remained active

---

## 11. Major Root Cause #4: Linux 6.6 Changed MMC Enumeration Order

After the Linux 6.6 migration, a separate boot failure appeared.

### Symptom

Kernel command line still used:

```text
root=/dev/mmcblk0p4 rootwait
```

But Linux 6.6 enumerated:

```text
SD card  = mmcblk1
eMMC     = mmcblk0
```

The actual rootfs therefore became:

```text
/dev/mmcblk1p4
```

This caused:

```text
VFS: Cannot open root device "/dev/mmcblk0p4"
Kernel panic - not syncing
```

### Fix

The boot argument in `extlinux.conf` was changed to:

```text
append root=PARTLABEL=rootfs rootwait
```

This is robust against SD/eMMC probe-order changes.

The final boot log confirmed:

```text
Kernel command line: root=PARTLABEL=rootfs rootwait
Waiting for root device PARTLABEL=rootfs...
EXT4-fs (mmcblk1p4): mounted ...
VFS: Mounted root ...
```

---

## 12. USB CDC ACM Login Shell

Once the gadget was stable, Windows detected the board as a COM port, but `/dev/ttyGS0` initially had no login shell attached.

### Fix

A BusyBox getty was added to `/etc/inittab`:

```text
ttyGS0::respawn:/sbin/getty -L ttyGS0 115200 vt100
```

The `115200` value is only a terminal/getty setting; the physical transport remains USB Full-Speed and is not limited by UART baud rate.

Final host-side behavior:

```text
USB Serial Device (COMxx)
```

Opening the port now gives:

```text
Welcome to Buildroot
buildroot login: root
#
```

---

## 13. Final Working Architecture

```text
Windows terminal
      |
      v
USB Serial Device (COMxx)
      |
      v
USB-C
      |
      v
STM32MP15 Integrated FS OTG PHY
      |
      v
USBPHYC / UTMI 48 MHz clock
      |
      v
DWC2 UDC
      |
      v
ConfigFS gadget g1
      |
      v
CDC ACM acm.usb0
      |
      v
/dev/ttyGS0
      |
      v
BusyBox getty
      |
      v
Buildroot shell
```

---

## 14. Final Verified Status

The following items were verified:

```text
Linux 6.6 boot                PASS
rootfs via PARTLABEL          PASS
STM32 USBPHYC                 PASS
DWC2 probe                    PASS
UDC registration              PASS
ConfigFS gadget               PASS
CDC ACM                       PASS
Windows enumeration           PASS
Windows COM port              PASS
UDC state = configured        PASS
/dev/ttyGS0                   PASS
getty over ttyGS0             PASS
Buildroot shell over USB-C    PASS
```

A successful UDC state check:

```text
cat /sys/class/udc/49000000.usb-otg/state
configured
```

---

## 15. Files Modified

### 15.1 Linux board patch

```text
board/seeed/stm32mp157c-odyssey/patches/linux/9999-odyssey-enable-fs-usb-device.patch
```

Conceptually contains:

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

### 15.2 USB gadget startup script

```text
board/seeed/stm32mp157c-odyssey/overlay/etc/init.d/S50usb-acm
```

Purpose:

- create CDC ACM gadget
- expose `/dev/ttyGS0`
- bind to `49000000.usb-otg`

### 15.3 Boot configuration

```text
board/seeed/stm32mp157c-odyssey/overlay/boot/extlinux/extlinux.conf
```

Final root argument:

```text
append root=PARTLABEL=rootfs rootwait
```

### 15.4 BusyBox login console

```text
board/seeed/stm32mp157c-odyssey/overlay/etc/inittab
```

Added:

```text
ttyGS0::respawn:/sbin/getty -L ttyGS0 115200 vt100
```

### 15.5 Kernel configuration

Relevant settings retained in the Odyssey board kernel config:

```text
CONFIG_USB_DWC2_PERIPHERAL=y
CONFIG_USB_GADGET=y
CONFIG_USB_CONFIGFS=y
CONFIG_USB_CONFIGFS_ACM=y
CONFIG_USB_LIBCOMPOSITE=y
CONFIG_USB_F_ACM=y
CONFIG_USB_U_SERIAL=y
CONFIG_CONFIGFS_FS=y
CONFIG_PHY_STM32_USBPHYC=y
```

---

## 16. Buildroot / Kernel Changes

### Kernel migration

Changed from:

```text
Linux 5.10.1
```

to:

```text
Linux 6.6
```

Important Buildroot settings included:

```text
BR2_PACKAGE_HOST_LINUX_HEADERS_CUSTOM_6_6=y
BR2_LINUX_KERNEL_CUSTOM_VERSION_VALUE="6.6"
BR2_LINUX_KERNEL_INTREE_DTS_NAME="st/stm32mp157c-odyssey"
```

Old Linux 5.10-specific DWC2 workaround patches should **not** be part of the final solution.

---

## 17. Important Lessons Learned

### 17.1 Windows symptoms can be downstream effects

A Windows Code 10 / composite-device failure does not necessarily mean a Windows driver problem.

For USB gadget bring-up, always verify the device-side UDC and controller first.

### 17.2 `/dev/ttyGS0` does not prove USB is attached

`/dev/ttyGS0` only proves the ACM function exists.

The more useful UDC state check is:

```text
cat /sys/class/udc/49000000.usb-otg/state
```

Useful states include:

- `not attached`
- `powered`
- `default`
- `addressed`
- `configured`

For a working Windows COM connection, the expected steady state is:

```text
configured
```

### 17.3 DWC2 core-reset failure is below ConfigFS

If the kernel reports:

```text
dwc2_core_reset: HANG! Soft Reset timeout
```

do not debug ACM or ConfigFS first.

The failure is at the controller/clock/PHY layer.

### 17.4 Linux 6.6 is a much better STM32MP15 USB FS base

Using upstream support was simpler and more maintainable than continuing to backport missing 5.10 pieces.

### 17.5 Power dependencies in DT matter

The system may successfully enumerate and still fail later if regulator dependencies are incomplete.

The `vdd_3v3_usbfs-supply` dependency was required to keep the USB FS rail active.

### 17.6 Avoid hardcoding `/dev/mmcblkX`

Probe order changed between kernel versions.

Prefer:

```text
root=PARTLABEL=rootfs
```

instead of:

```text
root=/dev/mmcblk0p4
```

### 17.7 Gadget and shell are separate layers

USB CDC ACM provides a serial transport.

A shell requires an additional getty:

```text
ttyGS0::respawn:/sbin/getty -L ttyGS0 115200 vt100
```

---

## 18. Remaining Cleanup / Future Work

The USB CDC ACM bring-up itself is complete.

Possible follow-up items:

- replace development VID/PID with an appropriate project identity if needed
- clean up USB product/manufacturer strings
- document the final `S50usb-acm` configuration
- consider ECM/RNDIS or another USB networking function later if useful
- automate GPT repair/expansion after writing the small image to a large SD card
- move on to Linux-side sensor bring-up
- continue STM32MP157 A7/M4 integration using remoteproc/RPMsg

---

## 19. Final Status

**PASS**

The Odyssey STM32MP157C now supports:

```text
USB-C
  -> CDC ACM
  -> Windows COM port
  -> /dev/ttyGS0
  -> Buildroot login shell
```

This bring-up is considered complete and suitable as the baseline USB console implementation for the project.
