# ODYSSEY STM32MP157C USB CDC ACM — Buildroot Implementation

## 1. Purpose

This document is the reproducible implementation companion to `odyssey-usb-cdc-acm-bringup.md`.

It records the concrete Buildroot-side changes required to reproduce the working USB CDC ACM console on the Seeed Studio Odyssey STM32MP157C.

## 2. Baseline

```text
Buildroot: 2026.05.1
Board:     Seeed Studio Odyssey STM32MP157C
Kernel:    Linux 6.6
DTS:       st/stm32mp157c-odyssey
```

Important Buildroot kernel selections:

```text
BR2_PACKAGE_HOST_LINUX_HEADERS_CUSTOM_6_6=y
BR2_LINUX_KERNEL_CUSTOM_VERSION_VALUE="6.6"
BR2_LINUX_KERNEL_INTREE_DTS_NAME="st/stm32mp157c-odyssey"
```

The old Linux 5.10-specific DWC2 workaround patches are not part of the final implementation.

## 3. Kernel Configuration

Edit:

```text
board/seeed/stm32mp157c-odyssey/linux.config
```

Ensure the resulting Linux `.config` contains at least:

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

Configure and verify:

```bash
cd ~/github/buildroot-2026.05.1

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

make linux-configure

grep -E \
'CONFIG_USB_DWC2_PERIPHERAL=|CONFIG_USB_GADGET=|CONFIG_USB_CONFIGFS=|CONFIG_USB_CONFIGFS_ACM=|CONFIG_PHY_STM32_USBPHYC=' \
output/build/linux-6.6/.config
```

Expected:

```text
CONFIG_USB_DWC2_PERIPHERAL=y
CONFIG_USB_GADGET=y
CONFIG_USB_CONFIGFS=y
CONFIG_USB_CONFIGFS_ACM=y
CONFIG_PHY_STM32_USBPHYC=y
```

## 4. Board DTS Patch

Create or maintain:

```text
board/seeed/stm32mp157c-odyssey/patches/linux/9999-odyssey-enable-fs-usb-device.patch
```

The patch must add board-level overrides to:

```text
arch/arm/boot/dts/st/stm32mp157c-odyssey.dts
```

Final DTS logic:

```dts
/*
 * ODYSSEY USB-C device port
 *
 * The carrier USB-C D+/D- signals are connected to the STM32MP15
 * integrated full-speed OTG transceiver on PA11/PA12.
 */
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

Linux 6.6 already provides the OTG and UTMI clocks in the SoC DTS:

```dts
clocks = <&rcc USBO_K>, <&usbphyc>;
clock-names = "otg", "utmi";
```

Do not duplicate those clock properties in the board override unless the upstream DTS changes.

Verify patch application:

```bash
make linux-dirclean
make linux-patch
```

Inspect the patched source:

```bash
grep -A6 '^&pwr_regulators' \
output/build/linux-6.6/arch/arm/boot/dts/st/stm32mp157c-odyssey.dts

grep -A5 '^&usbphyc' \
output/build/linux-6.6/arch/arm/boot/dts/st/stm32mp157c-odyssey.dts

grep -A15 '^&usbotg_hs' \
output/build/linux-6.6/arch/arm/boot/dts/st/stm32mp157c-odyssey.dts
```

## 5. ConfigFS CDC ACM Startup Script

Create:

```text
board/seeed/stm32mp157c-odyssey/overlay/etc/init.d/S50usb-acm
```

The startup script used during bring-up performs these operations:

1. mount ConfigFS if needed
2. create gadget `g1`
3. set a development VID/PID
4. create USB strings
5. create one configuration
6. create `functions/acm.usb0`
7. link the ACM function into the configuration
8. wait for an available UDC
9. bind the gadget to the first UDC
10. expose `/dev/ttyGS0`

Development USB identity used during bring-up:

```text
VID: 0525
PID: A4A7
```

These values are for development/lab use and should not be treated as production USB identity values.

The startup script must be executable:

```bash
chmod +x \
board/seeed/stm32mp157c-odyssey/overlay/etc/init.d/S50usb-acm
```

Verify after Buildroot copies the overlay:

```bash
ls -l output/target/etc/init.d/S50usb-acm
```

Expected runtime messages:

```text
Starting USB CDC ACM gadget...
USB UDC: 49000000.usb-otg
USB CDC ACM gadget started
```

## 6. Attach a Login Shell to `/dev/ttyGS0`

The CDC ACM function only provides the serial transport. To expose a login shell, add this line to:

```text
board/seeed/stm32mp157c-odyssey/overlay/etc/inittab
```

```text
ttyGS0::respawn:/sbin/getty -L ttyGS0 115200 vt100
```

Verify:

```bash
grep ttyGS0 output/target/etc/inittab
```

Expected:

```text
ttyGS0::respawn:/sbin/getty -L ttyGS0 115200 vt100
```

The `115200` value is a getty/terminal parameter; the transport itself is USB Full-Speed, not a UART limited to 115200 bit/s.

## 7. Use a Stable Root Filesystem Identifier

Linux 6.6 changed the observed SD/eMMC enumeration order during bring-up.

Do not use:

```text
root=/dev/mmcblk0p4
```

Edit:

```text
board/seeed/stm32mp157c-odyssey/overlay/boot/extlinux/extlinux.conf
```

Use:

```text
append root=PARTLABEL=rootfs rootwait
```

Verify source and generated target:

```bash
grep -n 'append' \
board/seeed/stm32mp157c-odyssey/overlay/boot/extlinux/extlinux.conf

grep -n 'append' \
output/target/boot/extlinux/extlinux.conf
```

## 8. Build

Recommended WSL build command:

```bash
cd ~/github/buildroot-2026.05.1

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

make -j8
```

Avoid relying on inherited Windows PATH entries inside WSL for the Buildroot toolchain.

## 9. Verify the Generated DTB Before Flashing

Decode the final DTB:

```bash
output/host/bin/dtc \
-I dtb -O dts \
output/images/stm32mp157c-odyssey.dtb \
2>/dev/null |
grep -A22 'usb-otg@49000000'
```

Expected properties include:

```text
compatible = "st,stm32mp15-fsotg", "snps,dwc2";
clock-names = "otg", "utmi";
dr_mode = "peripheral";
status = "okay";
```

Verify USBPHYC:

```bash
output/host/bin/dtc \
-I dtb -O dts \
output/images/stm32mp157c-odyssey.dtb \
2>/dev/null |
grep -A18 'usbphyc@5a006000'
```

Expected:

```text
#clock-cells = <0>;
status = "okay";
```

## 10. Runtime Verification

After boot:

```bash
ls -l /dev/ttyGS0

cat /sys/kernel/config/usb_gadget/g1/UDC

cat /sys/class/udc/49000000.usb-otg/state
```

Expected:

```text
/dev/ttyGS0 exists
UDC = 49000000.usb-otg
state = configured
```

Useful log check:

```bash
dmesg | grep -i -E 'usbphyc|dwc2|gadget|usb' | tail -100
```

Healthy sequence:

```text
stm32-usbphyc 5a006000.usbphyc: registered rev:1.0
dwc2 49000000.usb-otg: EPs: 9, dedicated fifos, 952 entries in SPRAM
dwc2 49000000.usb-otg: bound driver configfs-gadget.g1
dwc2 49000000.usb-otg: new device is full-speed
```

The following failure must not reappear:

```text
dwc2_core_reset: HANG! Soft Reset timeout GRSTCTL_CSFTRST
```

## 11. Windows Verification

The final gadget should enumerate as:

```text
USB Serial Device (COMxx)
```

Opening the COM port should show:

```text
Welcome to Buildroot
buildroot login:
```

After login:

```text
#
```

At that point the full path is reproduced:

```text
USB-C -> STM32MP15 FS OTG -> DWC2 -> ConfigFS CDC ACM -> ttyGS0 -> getty -> Windows COM shell
```
