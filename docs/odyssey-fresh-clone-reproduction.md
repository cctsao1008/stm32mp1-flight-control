# ODYSSEY STM32MP157C Fresh-clone Reproduction

## 1. Purpose

This document defines the target procedure for reproducing the validated Odyssey STM32MP157C image from a clean development environment.

The long-term reproducibility target is:

```text
clean host
  + clean Buildroot 2026.05.1
  + stm32mp1-flight-control repository
  -> reproducible sdcard.img
  -> validated Odyssey boot
```

At the current project stage, some validated Buildroot custom files still live in the working Buildroot tree and are being migrated into this repository. Therefore this document contains both the **current manual reproduction path** and the **target BR2_EXTERNAL path**.

---

## 2. Host Prerequisites

Validated host environment:

```text
Windows 11
WSL Ubuntu
```

Recommended WSL configuration:

```ini
[interop]
appendWindowsPath=false
```

File:

```text
/etc/wsl.conf
```

Restart WSL from Windows after changing it:

```powershell
wsl --shutdown
```

Inside WSL, use a Linux-only PATH:

```bash
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
```

Use Bash for all Buildroot commands. Do not paste these commands into PowerShell.

Recommended build parallelism:

```bash
make -j8
```

---

## 3. Obtain Buildroot

Use exactly:

```text
Buildroot 2026.05.1
```

Example working location:

```text
~/github/buildroot-2026.05.1
```

The baseline Odyssey board configuration is:

```text
stm32mp157c_odyssey_defconfig
```

Initialize it:

```bash
cd ~/github/buildroot-2026.05.1
make stm32mp157c_odyssey_defconfig
```

---

## 4. Apply Project Buildroot Changes

Until the `BR2_EXTERNAL` migration is complete, the validated customizations need to exist under:

```text
board/seeed/stm32mp157c-odyssey/
```

Required persistent files include:

```text
linux.config
genimage.cfg
patches/linux/9999-odyssey-enable-fs-usb-device.patch
overlay/etc/init.d/S50usb-acm
overlay/etc/inittab
overlay/boot/extlinux/extlinux.conf
```

The exact responsibilities and required content are documented in:

```text
docs/odyssey-buildroot-modification-map.md
docs/odyssey-usb-cdc-acm-buildroot-implementation.md
docs/odyssey-devboot-fat-buildroot-implementation.md
```

Do not copy generated files from `output/build` or `output/target` as a substitute for these persistent source files.

---

## 5. Configure Linux 6.6

The current baseline uses Linux 6.6 rather than the original 5.10.1 configuration.

Relevant Buildroot settings:

```text
BR2_PACKAGE_HOST_LINUX_HEADERS_CUSTOM_6_6=y
BR2_LINUX_KERNEL_CUSTOM_VERSION_VALUE="6.6"
BR2_LINUX_KERNEL_INTREE_DTS_NAME="st/stm32mp157c-odyssey"
```

After modifying Buildroot `.config`:

```bash
make olddefconfig
```

Verify:

```bash
grep -E \
'BR2_PACKAGE_HOST_LINUX_HEADERS_CUSTOM_6_6|BR2_LINUX_KERNEL_CUSTOM_VERSION_VALUE|BR2_LINUX_KERNEL_INTREE_DTS_NAME' \
.config
```

---

## 6. Validate Linux Patch Application

Use a clean Linux package source tree:

```bash
make linux-dirclean
make linux-patch
```

Verify board DTS changes:

```bash
grep -A6 '^&pwr_regulators' output/build/linux-6.6/arch/arm/boot/dts/st/stm32mp157c-odyssey.dts
grep -A5 '^&usbphyc' output/build/linux-6.6/arch/arm/boot/dts/st/stm32mp157c-odyssey.dts
grep -A15 '^&usbotg_hs' output/build/linux-6.6/arch/arm/boot/dts/st/stm32mp157c-odyssey.dts
```

Required behavior:

```text
USBPHYC enabled
FS OTG compatible selected
PA11/PA12 FS D-/D+ pins selected
dr_mode = peripheral
USB FS power dependency connected to vdd_usb
```

---

## 7. Validate Kernel Configuration

Generate kernel configuration:

```bash
make linux-configure
```

Check:

```bash
grep -E \
'CONFIG_USB_DWC2_PERIPHERAL=|CONFIG_USB_GADGET=|CONFIG_USB_CONFIGFS=|CONFIG_USB_CONFIGFS_ACM=|CONFIG_USB_LIBCOMPOSITE=|CONFIG_USB_F_ACM=|CONFIG_USB_U_SERIAL=|CONFIG_CONFIGFS_FS=|CONFIG_PHY_STM32_USBPHYC=' \
output/build/linux-6.6/.config
```

Expected enabled items:

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

## 8. Build

Build the full image:

```bash
make -j8
```

Expected key outputs:

```text
output/images/sdcard.img
output/images/zImage
output/images/stm32mp157c-odyssey.dtb
output/images/rootfs.ext4
output/images/devboot.vfat
```

Exact filenames may vary slightly with Buildroot internals, but the deployable SD-card image is expected to be:

```text
output/images/sdcard.img
```

---

## 9. Verify Rootfs Overlay Results

Before flashing, verify that persistent overlay changes reached `output/target`.

USB gadget script:

```bash
ls -l output/target/etc/init.d/S50usb-acm
```

It must be executable.

USB login shell:

```bash
grep ttyGS0 output/target/etc/inittab
```

Expected:

```text
ttyGS0::respawn:/sbin/getty -L ttyGS0 115200 vt100
```

Boot argument:

```bash
grep -n 'append' output/target/boot/extlinux/extlinux.conf
```

Expected:

```text
append root=PARTLABEL=rootfs rootwait
```

---

## 10. Verify Final DTB

Always inspect the final binary DTB, not only the patched source.

```bash
output/host/bin/dtc \
-I dtb -O dts \
output/images/stm32mp157c-odyssey.dtb \
2>/dev/null |
grep -A22 'usb-otg@49000000'
```

Expected key properties:

```text
compatible = "st,stm32mp15-fsotg", "snps,dwc2";
clock-names = "otg", "utmi";
dr_mode = "peripheral";
status = "okay";
```

USBPHYC:

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

---

## 11. Verify Final GPT Layout

```bash
fdisk -l output/images/sdcard.img
sgdisk -p output/images/sdcard.img
```

Expected GPT names:

```text
fsbl1
fsbl2
ssbl
rootfs
devboot
```

The fifth partition is expected to be approximately 64 MiB and Windows-readable.

Verify FAT image contents:

```bash
mdir -i output/images/devboot.vfat ::
```

Expected:

```text
zImage
stm32mp157c-odyssey.dtb
```

---

## 12. Record Artifact Hashes

Before flashing a candidate baseline:

```bash
sha256sum \
  output/images/sdcard.img \
  output/images/zImage \
  output/images/stm32mp157c-odyssey.dtb \
  output/images/rootfs.ext4
```

Keep these values with the corresponding Git commit and validation log.

This prevents ambiguity about which image was actually tested.

---

## 13. Flash the SD Card

Flash:

```text
output/images/sdcard.img
```

Use the preferred SD-card imaging tool on Windows or Linux.

Because the generated image is much smaller than a typical physical SD card, a backup-GPT-not-at-end warning may appear after boot. This is currently non-blocking and should be treated separately from rootfs and USB validation.

---

## 14. Boot Validation

Expected U-Boot sequence includes:

```text
Scanning mmc 0:4...
Found /boot/extlinux/extlinux.conf
Retrieving file: /boot/zImage
Retrieving file: /boot/stm32mp157c-odyssey.dtb
append: root=PARTLABEL=rootfs rootwait
```

Expected Linux command line:

```text
Kernel command line: root=PARTLABEL=rootfs rootwait
```

Expected rootfs mount:

```text
Waiting for root device PARTLABEL=rootfs...
EXT4-fs (...p4): mounted ...
VFS: Mounted root ...
```

The SD card may appear as `mmcblk1`; that is normal with the current Linux 6.6 probe order.

---

## 15. USB CDC ACM Validation

Expected boot/runtime sequence:

```text
stm32-usbphyc 5a006000.usbphyc: registered rev:1.0
dwc2 49000000.usb-otg: EPs: 9, dedicated fifos, 952 entries in SPRAM
Starting USB CDC ACM gadget...
USB UDC: 49000000.usb-otg
dwc2 49000000.usb-otg: bound driver configfs-gadget.g1
USB CDC ACM gadget started
```

Check:

```bash
ls -l /dev/ttyGS0
cat /sys/kernel/config/usb_gadget/g1/UDC
cat /sys/class/udc/49000000.usb-otg/state
```

Expected final state with Windows connected:

```text
configured
```

Windows should enumerate:

```text
USB Serial Device (COMxx)
```

Opening the COM port should produce:

```text
Welcome to Buildroot
buildroot login:
```

---

## 16. Fresh-clone Acceptance Criteria

A reproduction is considered successful only if all of the following are true:

```text
[ ] clean Buildroot 2026.05.1 tree used
[ ] project persistent modifications applied from source-of-truth files
[ ] Linux 6.6 selected
[ ] build completes with make -j8
[ ] final DTB verification passes
[ ] GPT contains rootfs + devboot with expected labels
[ ] rootfs mounts through PARTLABEL=rootfs
[ ] USBPHYC and DWC2 probe successfully
[ ] no DWC2 Soft Reset timeout appears
[ ] CDC ACM gadget binds automatically
[ ] /dev/ttyGS0 exists
[ ] UDC reaches configured
[ ] Windows COM port appears
[ ] Buildroot shell works over USB-C
[ ] artifact SHA256 values are recorded
```

---

## 17. Target Procedure After BR2_EXTERNAL Migration

Once the repository-owned external tree is complete, the preferred workflow should become conceptually:

```bash
cd ~/github/buildroot-2026.05.1

make BR2_EXTERNAL=~/github/stm32mp1-flight-control/buildroot \
     <project_defconfig>

make BR2_EXTERNAL=~/github/stm32mp1-flight-control/buildroot -j8
```

At that point no manual edits inside the upstream Buildroot checkout should be required.

That is the reproducibility target for the platform.
