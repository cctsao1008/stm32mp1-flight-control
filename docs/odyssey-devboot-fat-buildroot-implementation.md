# ODYSSEY STM32MP157C DEVBOOT FAT — Buildroot Implementation

## 1. Purpose

This document is the reproducible implementation companion to `odyssey-devboot-fat-partition.md`.

It records the concrete Buildroot-side changes required to reproduce the Windows-readable `DEVBOOT` FAT partition in the Odyssey STM32MP157C SD-card image.

## 2. Files Involved

The main Buildroot file is:

```text
board/seeed/stm32mp157c-odyssey/genimage.cfg
```

The FAT image is populated from Buildroot output artifacts, primarily:

```text
output/images/zImage
output/images/stm32mp157c-odyssey.dtb
```

The generated SD-card image is:

```text
output/images/sdcard.img
```

## 3. Required FAT Image Tools

The Buildroot host must provide:

```text
dosfstools
mtools
```

These are required to create and populate the FAT filesystem image used by `genimage`.

After configuration/build, the corresponding host-side tools should be available below:

```text
output/host/bin/
```

## 4. Add a FAT Filesystem Image to `genimage.cfg`

Edit:

```text
board/seeed/stm32mp157c-odyssey/genimage.cfg
```

Add a FAT image named:

```text
devboot.vfat
```

The working design uses a 64 MiB FAT image containing:

```text
zImage
stm32mp157c-odyssey.dtb
```

A representative `genimage` structure is:

```text
image devboot.vfat {
    vfat {
        files = {
            "zImage",
            "stm32mp157c-odyssey.dtb"
        }
    }

    size = 64M
}
```

The exact surrounding syntax should follow the active Odyssey `genimage.cfg` used by the Buildroot version in the tree.

## 5. Add Partition 5 to `sdcard.img`

In the existing SD-card image definition, preserve the first four partitions and add a fifth partition for `devboot.vfat`.

Resulting logical layout:

```text
p1  fsbl1
p2  fsbl2
p3  ssbl
p4  rootfs
p5  devboot
```

The working configuration used a FAT / Microsoft basic-data-compatible partition type:

```text
partition-type-uuid = F
```

and references:

```text
image = "devboot.vfat"
```

Representative partition entry:

```text
partition devboot {
    partition-type-uuid = F
    image = "devboot.vfat"
}
```

Keep the existing Odyssey partition definitions unchanged unless the image layout is intentionally redesigned.

## 6. Build

From WSL:

```bash
cd ~/github/buildroot-2026.05.1

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

make -j8
```

Expected result:

```text
output/images/sdcard.img
```

The final image used during bring-up was approximately:

```text
125.4 MiB
```

## 7. Verify the Partition Table

Run:

```bash
fdisk -l output/images/sdcard.img
```

Verified working result:

```text
Device                     Start    End Sectors  Size Type
output/images/sdcard.img1     34    445     412  206K Linux filesystem
output/images/sdcard.img2    446    857     412  206K Linux filesystem
output/images/sdcard.img3    858   2879    2022 1011K Linux filesystem
output/images/sdcard.img4   2880 125759  122880   60M Linux filesystem
output/images/sdcard.img5 125760 256831  131072   64M Microsoft basic data
```

Then verify GPT names:

```bash
sgdisk -p output/images/sdcard.img
```

Verified working result:

```text
Number  Start (sector)    End (sector)  Size       Code  Name
   1              34             445   206.0 KiB   8300  fsbl1
   2             446             857   206.0 KiB   8300  fsbl2
   3             858            2879   1011.0 KiB  8300  ssbl
   4            2880          125759   60.0 MiB    8300  rootfs
   5          125760          256831   64.0 MiB    0700  devboot
```

## 8. Verify the FAT Image Contents Before Flashing

Use `mdir` from mtools:

```bash
mdir -i output/images/devboot.vfat ::
```

Expected files:

```text
zImage
stm32mp157c-odyssey.dtb
```

If a later Buildroot revision changes the generated FAT-image filename, first inspect:

```bash
ls -lh output/images/
```

and use the FAT image name defined by the active `genimage.cfg`.

## 9. Flash and Verify on Windows

Write:

```text
output/images/sdcard.img
```

to the SD card.

After reinserting the SD card into Windows, the FAT partition should be mountable and expose at least:

```text
zImage
stm32mp157c-odyssey.dtb
```

This provides Windows-readable access to selected boot artifacts without requiring ext4 support.

## 10. Important: `DEVBOOT` Is Not the Current Boot Source

Do not assume that a visible FAT partition means U-Boot loads the kernel from it.

The verified boot path remains:

```text
Scanning mmc 0:4...
Found /boot/extlinux/extlinux.conf
Retrieving file: /boot/extlinux/extlinux.conf
Retrieving file: /boot/zImage
Retrieving file: /boot/stm32mp157c-odyssey.dtb
```

Therefore the current authoritative boot files are still:

```text
rootfs:/boot/extlinux/extlinux.conf
rootfs:/boot/zImage
rootfs:/boot/stm32mp157c-odyssey.dtb
```

The policy is:

```text
DEVBOOT      = convenience / debug partition
ROOTFS:/boot = authoritative boot source
```

## 11. Stable Root Filesystem Boot Argument

Linux 6.6 changed the observed SD/eMMC enumeration order during testing.

Keep this in:

```text
board/seeed/stm32mp157c-odyssey/overlay/boot/extlinux/extlinux.conf
```

```text
append root=PARTLABEL=rootfs rootwait
```

Do not revert to:

```text
root=/dev/mmcblk0p4
```

The GPT label-based root argument is independent of `/dev/mmcblkX` probe order.

Verify:

```bash
grep -n 'append' \
board/seeed/stm32mp157c-odyssey/overlay/boot/extlinux/extlinux.conf

grep -n 'append' \
output/target/boot/extlinux/extlinux.conf
```

## 12. Known GPT Warning on Larger Physical SD Cards

The generated image is small compared with a typical physical SD card. Writing the image sector-for-sector to a larger card can produce:

```text
GPT: Primary header thinks Alt. header is not at the end of the disk.
GPT: Alternate GPT header not at the end of the disk.
GPT: Use GNU Parted to correct GPT errors.
```

This occurs because the backup GPT header remains at the end of the generated image rather than the end of the larger physical card.

It does not invalidate the five-partition layout and does not prevent normal boot.

GPT repair / partition expansion can be handled later as a separate first-boot or image-maintenance improvement.

## 13. Final Reproduction Checklist

```text
[ ] dosfstools available to Buildroot host
[ ] mtools available to Buildroot host
[ ] devboot.vfat defined in genimage.cfg
[ ] zImage copied into devboot.vfat
[ ] stm32mp157c-odyssey.dtb copied into devboot.vfat
[ ] p5 devboot added to sdcard.img
[ ] p5 size = 64 MiB
[ ] fdisk shows five partitions
[ ] sgdisk shows p5 name = devboot
[ ] Windows mounts the FAT partition
[ ] zImage and DTB are visible from Windows
[ ] U-Boot still boots from rootfs:/boot
```
