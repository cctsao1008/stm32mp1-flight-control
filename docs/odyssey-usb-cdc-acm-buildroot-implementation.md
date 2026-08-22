# Odyssey USB CDC ACM Buildroot Implementation

## Status

Validated and authoritative through the project BR2_EXTERNAL tree.

The Odyssey USB-C device port is exposed as a Linux USB CDC ACM gadget and has been validated end-to-end against a Windows host.

## Project-owned inputs

```text
buildroot_external/board/odyssey/linux.config
buildroot_external/board/odyssey/patches/linux/9999-odyssey-enable-fs-usb-device.patch
buildroot_external/board/odyssey/overlay/etc/init.d/S50usb-acm
buildroot_external/board/odyssey/overlay/etc/inittab
```

These files are referenced by:

```text
buildroot_external/configs/stm32mp1_flight_odyssey_defconfig
```

## Kernel configuration

Persistent project kernel configuration includes:

```text
CONFIG_USB_GADGET=y
CONFIG_USB_DWC2_PERIPHERAL=y
# CONFIG_USB_DWC2_HOST is not set
# CONFIG_USB_DWC2_DUAL_ROLE is not set
CONFIG_USB_CONFIGFS=y
CONFIG_USB_CONFIGFS_ACM=y
CONFIG_PHY_STM32_USBPHYC=y
```

Generated dependencies additionally include:

```text
CONFIG_USB_LIBCOMPOSITE=y
CONFIG_USB_F_ACM=y
CONFIG_USB_U_SERIAL=y
CONFIG_CONFIGFS_FS=y
```

## Device Tree

The project patch configures the STM32MP15 integrated FS device path:

```text
PA11/PA12 USB FS D-/D+
    -> STM32 USBPHYC
    -> UTMI clock
    -> DWC2 at 0x49000000
```

The final validated DTB contains:

```text
compatible = "st,stm32mp15-fsotg", "snps,dwc2"
clock-names = "otg", "utmi"
dr_mode = "peripheral"
status = "okay"
```

USBPHYC is also enabled.

The historical Linux 5.10 workaround that attempted to change DWC2 reset ordering is not part of the active implementation.

## ConfigFS gadget

`S50usb-acm` runs during boot and creates ConfigFS gadget `g1` with one ACM function.

Validated runtime output:

```text
Starting USB CDC ACM gadget...
USB UDC: 49000000.usb-otg
dwc2 49000000.usb-otg: bound driver configfs-gadget.g1
USB CDC ACM gadget started
```

Explicit runtime checks:

```text
/dev/ttyGS0
/sys/class/udc/49000000.usb-otg/state = configured
/sys/kernel/config/usb_gadget/g1/UDC = 49000000.usb-otg
```

## Getty

The rootfs `inittab` starts a getty on:

```text
ttyGS0
```

This provides the Buildroot login shell over USB CDC ACM.

## Windows host result

Validated Windows enumeration:

```text
COM25    USB Serial Device (COM25)
```

No vendor-specific serial driver is required for the class-compliant CDC ACM interface.

## Build and verify

```bash
./scripts/build.sh
./scripts/verify-image.sh
```

Then flash `output/odyssey/images/sdcard.img` and perform the runtime USB checks.

## Source-of-truth rule

Do not maintain parallel versions of these files inside an upstream Buildroot checkout. Persistent Odyssey USB changes belong in `buildroot_external/board/odyssey/`.
