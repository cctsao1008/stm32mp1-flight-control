# ODYSSEY STM32MP157C Buildroot Modification Map

## 1. Purpose

This document answers one specific maintenance question:

> **Which Buildroot files were modified for the current working Odyssey STM32MP157C image, why were they modified, what artifact does each file affect, and how do we verify the result?**

It complements the general build flow and the feature-specific USB / DEVBOOT documents.

Current validated baseline:

```text
Buildroot: 2026.05.1
Linux:     6.6.0
Board:     Seeed Studio Odyssey STM32MP157C
DTS:       st/stm32mp157c-odyssey
Host:      WSL Ubuntu
```

---

## 2. High-level Dependency Map

```text
Buildroot top-level .config
        |
        +--> kernel version / headers / DTS selection
        |
        v
board/seeed/stm32mp157c-odyssey/
        |
        +-- linux.config
        |      |
        |      v
        |   output/build/linux-6.6/.config
        |      |
        |      v
        |   zImage / kernel features
        |
        +-- patches/linux/*.patch
        |      |
        |      v
        |   patched Linux source / DTS
        |      |
        |      v
        |   stm32mp157c-odyssey.dtb
        |
        +-- overlay/
        |      |
        |      v
        |   output/target/
        |      |
        |      v
        |   rootfs.ext4
        |
        +-- genimage.cfg
               |
               v
           devboot.vfat
               +
           rootfs image
               +
           TF-A / U-Boot
               |
               v
           sdcard.img
```

Persistent changes belong in the source side of this graph. `output/build`, `output/target`, and `output/images` are generated verification points, not source-of-truth locations.

---

## 3. Modification Summary

| Persistent file | Purpose | Current project change | Main generated artifact |
|---|---|---|---|
| Buildroot top-level `.config` | Buildroot-wide configuration | Linux 6.6 selection, DTS path, supporting host tools | Complete build graph |
| `board/seeed/stm32mp157c-odyssey/linux.config` | Kernel configuration source | DWC2 peripheral, USB gadget, ConfigFS ACM, USBPHYC | `output/build/linux-6.6/.config`, `zImage` |
| `board/seeed/stm32mp157c-odyssey/patches/linux/9999-odyssey-enable-fs-usb-device.patch` | Board-specific Linux/DTS change | FS OTG, USBPHYC, PA11/PA12, USB FS power dependency | final DTB |
| `board/seeed/stm32mp157c-odyssey/overlay/etc/init.d/S50usb-acm` | Runtime gadget setup | Build ConfigFS CDC ACM gadget and bind UDC | rootfs, `/dev/ttyGS0` |
| `board/seeed/stm32mp157c-odyssey/overlay/etc/inittab` | BusyBox login terminals | Attach getty to `ttyGS0` | USB serial login shell |
| `board/seeed/stm32mp157c-odyssey/overlay/boot/extlinux/extlinux.conf` | Kernel boot arguments | Use `root=PARTLABEL=rootfs rootwait` | kernel command line |
| `board/seeed/stm32mp157c-odyssey/genimage.cfg` | Final image layout | Add 64 MiB FAT `devboot` partition | `devboot.vfat`, `sdcard.img` |
| `/etc/wsl.conf` on development host | WSL environment | Disable Windows PATH injection | reliable host build environment |

---

## 4. Buildroot Top-level `.config`

### Purpose

Controls Buildroot package selection, toolchain, kernel source/version, kernel headers, board image generation, and other global build choices.

### Relevant changes

The current working build moved from Linux 5.10.1 to Linux 6.6 and uses the Linux 6.6 in-tree Odyssey DTS path.

Relevant settings include:

```text
BR2_PACKAGE_HOST_LINUX_HEADERS_CUSTOM_6_6=y
BR2_LINUX_KERNEL_CUSTOM_VERSION_VALUE="6.6"
BR2_LINUX_KERNEL_INTREE_DTS_NAME="st/stm32mp157c-odyssey"
```

Host support for FAT image generation also needs the tools required by `genimage`, notably `dosfstools` and `mtools`.

### Why it changed

Linux 5.10.1 lacked the complete upstream STM32MP15 FS-OTG / USBPHYC / UTMI clock path needed for a maintainable USB CDC ACM implementation.

### Generated artifacts affected

Potentially the entire build, especially:

```text
output/build/linux-6.6/
output/host/
output/images/zImage
output/images/stm32mp157c-odyssey.dtb
output/images/sdcard.img
```

### Verification

```bash
grep -E \
'BR2_PACKAGE_HOST_LINUX_HEADERS_CUSTOM_6_6|BR2_LINUX_KERNEL_CUSTOM_VERSION_VALUE|BR2_LINUX_KERNEL_INTREE_DTS_NAME' \
.config
```

After editing:

```bash
make olddefconfig
make -j8
```

---

## 5. `linux.config`

### Path

```text
board/seeed/stm32mp157c-odyssey/linux.config
```

### Purpose

Persistent Linux kernel configuration for the Odyssey board.

### Required USB-related configuration

The working kernel configuration includes:

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

### Why it changed

The project requires the STM32MP15 DWC2 controller in peripheral mode and a ConfigFS CDC ACM gadget, with STM32 USBPHYC support enabled.

### Generated artifact affected

```text
board/.../linux.config
        -> output/build/linux-6.6/.config
        -> kernel objects
        -> output/images/zImage
```

### Verification

```bash
make linux-configure

grep -E \
'CONFIG_USB_DWC2_PERIPHERAL=|CONFIG_USB_GADGET=|CONFIG_USB_CONFIGFS=|CONFIG_USB_CONFIGFS_ACM=|CONFIG_USB_LIBCOMPOSITE=|CONFIG_USB_F_ACM=|CONFIG_USB_U_SERIAL=|CONFIG_CONFIGFS_FS=|CONFIG_PHY_STM32_USBPHYC=' \
output/build/linux-6.6/.config
```

For a persistent config change, a clean Linux package rebuild is the safest path:

```bash
make linux-dirclean
make -j8
```

---

## 6. Linux/DTS Patch

### Path

```text
board/seeed/stm32mp157c-odyssey/patches/linux/9999-odyssey-enable-fs-usb-device.patch
```

### Purpose

Carry the board-specific Device Tree changes that are not present in the upstream Odyssey DTS used by Linux 6.6.

### Required logical changes

The final board DTS needs the equivalent of:

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

### Why each part exists

- `&usbphyc { status = "okay"; };`
  - enables the STM32 USBPHYC block that provides the required USB clock path
- `stm32mp15-fsotg`
  - selects the integrated full-speed transceiver behavior
- `usbotg_fs_dp_dm_pins_a`
  - maps the device port to PA11/PA12 D-/D+
- `dr_mode = "peripheral"`
  - forces gadget/peripheral operation for the USB-C device port
- `vdd_3v3_usbfs-supply = <&vdd_usb>`
  - keeps the USB FS supply referenced and prevents the late regulator cleanup from disabling it

### Generated artifact affected

```text
patch
  -> output/build/linux-6.6/arch/arm/boot/dts/st/stm32mp157c-odyssey.dts
  -> compiled DTB
  -> output/images/stm32mp157c-odyssey.dtb
```

### Verification

Reapply from a clean Linux tree:

```bash
make linux-dirclean
make linux-patch
```

Inspect patched source:

```bash
grep -A6 '^&pwr_regulators' output/build/linux-6.6/arch/arm/boot/dts/st/stm32mp157c-odyssey.dts
grep -A5 '^&usbphyc' output/build/linux-6.6/arch/arm/boot/dts/st/stm32mp157c-odyssey.dts
grep -A15 '^&usbotg_hs' output/build/linux-6.6/arch/arm/boot/dts/st/stm32mp157c-odyssey.dts
```

After building, verify the final binary artifact rather than only the source:

```bash
output/host/bin/dtc -I dtb -O dts output/images/stm32mp157c-odyssey.dtb 2>/dev/null |
grep -A22 'usb-otg@49000000'
```

Expected properties include:

```text
compatible = "st,stm32mp15-fsotg", "snps,dwc2";
clock-names = "otg", "utmi";
dr_mode = "peripheral";
status = "okay";
```

---

## 7. `S50usb-acm`

### Path

```text
board/seeed/stm32mp157c-odyssey/overlay/etc/init.d/S50usb-acm
```

### Purpose

Automatically configure the Linux USB gadget during boot.

### Runtime responsibilities

The working script performs the following logical sequence:

```text
mount configfs
    -> create usb_gadget/g1
    -> configure VID/PID and USB strings
    -> create configuration
    -> create functions/acm.usb0
    -> link ACM function into configuration
    -> wait for /sys/class/udc
    -> bind first UDC
    -> /dev/ttyGS0 becomes available
```

Development VID/PID used during bring-up:

```text
0525:A4A7
```

These are development values, not a production USB identity.

### Generated artifact affected

```text
overlay/etc/init.d/S50usb-acm
    -> output/target/etc/init.d/S50usb-acm
    -> rootfs
    -> runtime ConfigFS gadget
```

### Verification

Before flashing:

```bash
ls -l output/target/etc/init.d/S50usb-acm
```

It must be executable.

At runtime:

```bash
cat /sys/kernel/config/usb_gadget/g1/UDC
ls -l /dev/ttyGS0
cat /sys/class/udc/49000000.usb-otg/state
```

Healthy final state:

```text
UDC:   49000000.usb-otg
state: configured
```

---

## 8. BusyBox `inittab`

### Path

```text
board/seeed/stm32mp157c-odyssey/overlay/etc/inittab
```

### Purpose

Attach a login process to the CDC ACM device node.

### Change

Add:

```text
ttyGS0::respawn:/sbin/getty -L ttyGS0 115200 vt100
```

### Why it changed

Creating `/dev/ttyGS0` only provides a serial transport. It does not automatically create a shell or login console.

### Generated artifact affected

```text
overlay/etc/inittab
    -> output/target/etc/inittab
    -> rootfs
    -> BusyBox init
    -> getty on ttyGS0
```

### Verification

```bash
grep ttyGS0 output/target/etc/inittab
```

Runtime result on Windows COM port:

```text
Welcome to Buildroot
buildroot login:
```

---

## 9. `extlinux.conf`

### Path

```text
board/seeed/stm32mp157c-odyssey/overlay/boot/extlinux/extlinux.conf
```

### Purpose

Defines the U-Boot extlinux kernel/DTB selection and Linux kernel command line.

### Change

Old:

```text
append root=/dev/mmcblk0p4 rootwait
```

Final:

```text
append root=PARTLABEL=rootfs rootwait
```

### Why it changed

Linux 6.6 changed the observed MMC probe order during bring-up:

```text
eMMC -> mmcblk0
SD   -> mmcblk1
```

Hardcoding `mmcblk0p4` therefore caused a kernel panic even though the SD-card rootfs was valid.

Using the GPT partition name decouples boot from probe order.

### Generated artifact affected

```text
overlay/boot/extlinux/extlinux.conf
    -> output/target/boot/extlinux/extlinux.conf
    -> rootfs:/boot/extlinux/extlinux.conf
    -> U-Boot kernel command line
```

### Verification

```bash
grep -n 'append' board/seeed/stm32mp157c-odyssey/overlay/boot/extlinux/extlinux.conf
grep -n 'append' output/target/boot/extlinux/extlinux.conf
```

Boot log must show:

```text
Kernel command line: root=PARTLABEL=rootfs rootwait
```

---

## 10. `genimage.cfg`

### Path

```text
board/seeed/stm32mp157c-odyssey/genimage.cfg
```

### Purpose

Controls the generated SD-card image layout.

### Change

A fifth, Windows-readable FAT partition was added:

```text
p5 = devboot
size = 64 MiB
filesystem = FAT
```

The FAT image contains:

```text
zImage
stm32mp157c-odyssey.dtb
```

The working partition entry uses a FAT / Microsoft-basic-data-compatible partition type and the generated `devboot.vfat` image.

### Important design rule

`DEVBOOT` is **not currently the authoritative boot partition**.

U-Boot still boots from:

```text
partition 4 / rootfs /boot
```

The FAT partition exists for inspection/debug/maintenance convenience.

### Generated artifact affected

```text
genimage.cfg
   -> devboot.vfat
   -> sdcard.img
```

### Verification

```bash
fdisk -l output/images/sdcard.img
sgdisk -p output/images/sdcard.img
mdir -i output/images/devboot.vfat ::
```

Expected GPT names:

```text
fsbl1
fsbl2
ssbl
rootfs
devboot
```

Expected DEVBOOT files:

```text
zImage
stm32mp157c-odyssey.dtb
```

---

## 11. WSL Host Configuration

### Path

```text
/etc/wsl.conf
```

### Change

```ini
[interop]
appendWindowsPath=false
```

### Why it changed

Windows PATH injection into the WSL environment caused Buildroot host-tool lookup problems. A Linux-only PATH provides a much more deterministic build environment.

Recommended shell PATH:

```bash
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
```

After editing `/etc/wsl.conf`, restart WSL from Windows:

```powershell
wsl --shutdown
```

This file is host configuration and is not part of the target image.

---

## 12. Change-to-Rebuild Matrix

| Changed file | Minimum normal action | Conservative / bring-up action |
|---|---|---|
| top-level `.config` | `make olddefconfig && make -j8` | same |
| `linux.config` | Linux reconfigure/rebuild | `make linux-dirclean && make -j8` |
| Linux/DTS patch | reapply Linux patches | `make linux-dirclean && make linux-patch && make linux-configure && make -j8` |
| `S50usb-acm` | `make -j8` | verify `output/target`, then build |
| `inittab` | `make -j8` | verify `output/target`, then build |
| `extlinux.conf` | `make -j8` | verify `output/target`, then build |
| `genimage.cfg` | `make -j8` | verify `fdisk`, `sgdisk`, FAT contents |
| `/etc/wsl.conf` | restart WSL | `wsl --shutdown`, reopen shell |

---

## 13. Source-of-Truth Policy

The long-term repository policy should be:

```text
Git repository
    -> Buildroot external tree / board files
    -> generated Buildroot tree
    -> generated output
    -> flashed image
```

Do not maintain important changes only in:

```text
output/build/
output/target/
output/images/
```

Those locations are disposable build products.

The next infrastructure step is to move the validated Odyssey customizations into a project-owned `BR2_EXTERNAL` tree so a clean upstream Buildroot checkout plus this repository is sufficient to reproduce the image.
