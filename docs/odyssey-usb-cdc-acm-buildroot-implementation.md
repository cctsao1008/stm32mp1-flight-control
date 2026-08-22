# Odyssey USB CDC ACM Buildroot Implementation

## Status

Validated and authoritative through the project BR2_EXTERNAL tree.

## Project-owned inputs

```text
buildroot_external/board/odyssey/linux.config
buildroot_external/board/odyssey/patches/linux/9999-odyssey-enable-fs-usb-device.patch
buildroot_external/board/odyssey/overlay/etc/init.d/S50usb-acm
buildroot_external/board/odyssey/overlay/etc/inittab
buildroot_external/configs/stm32mp1_flight_odyssey_defconfig
```

## Kernel / Device Tree path

```text
PA11/PA12 USB FS D-/D+
    -> STM32 USBPHYC
    -> UTMI clock
    -> DWC2 at 0x49000000
```

Validated final DTB:

```text
compatible = "st,stm32mp15-fsotg", "snps,dwc2"
clock-names = "otg", "utmi"
dr_mode = "peripheral"
status = "okay"
```

## ConfigFS gadget

Validated runtime output:

```text
Starting USB CDC ACM gadget...
USB UDC: 49000000.usb-otg
dwc2 49000000.usb-otg: bound driver configfs-gadget.g1
USB CDC ACM gadget started
```

Explicit checks:

```text
/dev/ttyGS0
/sys/class/udc/49000000.usb-otg/state = configured
/sys/kernel/config/usb_gadget/g1/UDC = 49000000.usb-otg
Windows = USB Serial Device (COM25)
```

The rootfs `inittab` starts a getty on `ttyGS0`, providing the Buildroot login shell over CDC ACM.

## Build and verify

```bash
./scripts/build.sh
./scripts/verify-image.sh
```

## Source-of-truth rule

Persistent Odyssey USB changes belong in `buildroot_external/board/odyssey/`. Do not maintain parallel versions inside an upstream Buildroot checkout.
