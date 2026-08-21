# ODYSSEY STM32MP157C DEVBOOT FAT Partition Notes

## 1. Purpose

This document records the rationale, image-layout changes, Buildroot modifications, and verification steps for adding a dedicated **FAT32 `DEVBOOT` partition** to the SD-card image used by the **Seeed Studio Odyssey STM32MP157C** platform.

The primary goals are:

- make selected boot artifacts directly readable from Windows
- simplify inspection and maintenance of the kernel and DTB
- provide a convenient debug / field-service partition
- preserve the existing STM32MP1 boot chain

The resulting partition is named:

```text
devboot
```

Important:

> The `DEVBOOT` FAT partition is currently a convenience/debug partition.  
> The system still boots the kernel and DTB from `/boot` on the `rootfs` partition.

---

## 2. Original Image Layout

The original Buildroot-generated SD-card image used four GPT partitions:

```text
p1  fsbl1
p2  fsbl2
p3  ssbl
p4  rootfs
```

The effective boot chain remained:

```text
TF-A
  -> U-Boot
  -> scan partition 4
  -> /boot/extlinux/extlinux.conf
  -> /boot/zImage
  -> /boot/stm32mp157c-odyssey.dtb
  -> Linux
```

The kernel and DTB were therefore stored inside the ext4 `rootfs` partition.

That is fine for Linux, but inconvenient on a Windows host because Windows does not natively mount ext4.

---

## 3. Why Add a FAT Partition?

The additional FAT32 partition was added primarily for development convenience.

### Benefits

- Windows can mount FAT32 directly
- kernel and DTB can be inspected without Linux tools
- easier artifact comparison between builds
- easier manual backup / retrieval
- useful for future maintenance workflows
- no need to expose or manipulate the rootfs partition from Windows

The initial intended contents are:

```text
zImage
stm32mp157c-odyssey.dtb
```

---

## 4. Final Partition Layout

The image was extended with a fifth GPT partition:

```text
p1  fsbl1
p2  fsbl2
p3  ssbl
p4  rootfs
p5  devboot
```

A verified image layout was:

```text
Number  Start (sector)    End (sector)  Size       Code  Name
   1              34             445   206.0 KiB   8300  fsbl1
   2             446             857   206.0 KiB   8300  fsbl2
   3             858            2879   1011.0 KiB  8300  ssbl
   4            2880          125759   60.0 MiB    8300  rootfs
   5          125760          256831   64.0 MiB    0700  devboot
```

The image size became approximately:

```text
125.4 MiB
```

---

## 5. `DEVBOOT` Filesystem

The fifth partition is a FAT32 filesystem sized at approximately:

```text
64 MiB
```

It is populated with selected boot artifacts.

Typical contents:

```text
zImage
stm32mp157c-odyssey.dtb
```

The purpose is artifact visibility and convenience, not current boot authority.

---

## 6. Buildroot / Genimage Changes

The image is generated through Buildroot's `genimage` flow.

The board-specific `genimage.cfg` was updated to define a FAT image and include it as partition 5.

Conceptually:

```text
devboot.vfat
```

contains:

```text
zImage
stm32mp157c-odyssey.dtb
```

and the SD image includes a fifth partition with a Microsoft basic-data / FAT-compatible GPT type.

The resulting partition label is:

```text
devboot
```

---

## 7. Required Host Tools

Because Buildroot must generate a FAT filesystem image, the relevant host-side tools need to be available through the Buildroot configuration.

The required utilities are:

```text
dosfstools
mtools
```

These are used to create and populate the FAT image during the build.

---

## 8. Boot Behavior After Adding `DEVBOOT`

A critical finding during validation was that adding the fifth partition **did not change the actual U-Boot boot path**.

U-Boot still reported:

```text
Scanning mmc 0:4...
Found /boot/extlinux/extlinux.conf
Retrieving file: /boot/extlinux/extlinux.conf
Retrieving file: /boot/zImage
Retrieving file: /boot/stm32mp157c-odyssey.dtb
```

Therefore:

```text
partition 4 / rootfs /boot
```

remains the authoritative source for:

- `extlinux.conf`
- `zImage`
- `stm32mp157c-odyssey.dtb`

The `DEVBOOT` partition is currently independent of that path.

---

## 9. Why Keep `DEVBOOT` Non-authoritative for Now?

Keeping the partition as a convenience layer avoids unnecessary changes to the already-working boot chain.

Advantages:

- lower boot-risk
- no need to modify U-Boot environment or scan logic
- no dependency on Windows-side edits for normal boot
- `rootfs` continues to contain the canonical boot configuration
- `DEVBOOT` can be used for inspection without changing system behavior

This is intentionally conservative.

---

## 10. Verification

### 10.1 Inspect partition table with `fdisk`

```bash
fdisk -l output/images/sdcard.img
```

Expected structure:

```text
output/images/sdcard.img1
output/images/sdcard.img2
output/images/sdcard.img3
output/images/sdcard.img4
output/images/sdcard.img5
```

Typical final result:

```text
Device                     Start    End Sectors  Size Type
output/images/sdcard.img1     34    445     412  206K Linux filesystem
output/images/sdcard.img2    446    857     412  206K Linux filesystem
output/images/sdcard.img3    858   2879    2022 1011K Linux filesystem
output/images/sdcard.img4   2880 125759  122880   60M Linux filesystem
output/images/sdcard.img5 125760 256831  131072   64M Microsoft basic data
```

### 10.2 Inspect GPT names with `sgdisk`

```bash
sgdisk -p output/images/sdcard.img
```

Expected names:

```text
fsbl1
fsbl2
ssbl
rootfs
devboot
```

### 10.3 Verify on Windows

After writing the image to an SD card, Windows should recognize the FAT partition and allow direct access to its contents.

Expected visible files include:

```text
zImage
stm32mp157c-odyssey.dtb
```

---

## 11. Interaction with Root Filesystem Booting

After the kernel was upgraded to Linux 6.6, the SD card and eMMC enumeration order changed.

The SD card could become:

```text
mmcblk1
```

while the eMMC became:

```text
mmcblk0
```

This exposed a separate weakness in the original boot argument:

```text
root=/dev/mmcblk0p4
```

That was changed to:

```text
root=PARTLABEL=rootfs rootwait
```

This change is independent of `DEVBOOT`, but it complements the GPT-based image layout and removes dependence on `/dev/mmcblkX` probe order.

---

## 12. GPT Warning After Writing to a Larger SD Card

The generated image is only about 125 MiB, but it may be written to a much larger physical SD card, for example 16 GiB.

Linux may then report messages such as:

```text
GPT: Primary header thinks Alt. header is not at the end of the disk.
GPT: Alternate GPT header not at the end of the disk.
GPT: Use GNU Parted to correct GPT errors.
```

### Why this happens

The backup GPT header is located at the end of the generated image, not at the end of the physical SD card.

When the image is copied sector-for-sector to a larger device, the physical disk has unused space after the backup GPT header.

### Impact

This warning:

- does not prevent normal boot
- does not invalidate the existing five partitions
- is not related to USB CDC ACM
- can be handled later through GPT repair / image expansion logic

---

## 13. Future Option: Make `DEVBOOT` the Real Boot Partition

The current design deliberately does **not** boot from `DEVBOOT`.

If desired later, the architecture could be changed to:

```text
U-Boot
  -> partition 5 / DEVBOOT
  -> extlinux.conf
  -> zImage
  -> DTB
  -> root=PARTLABEL=rootfs
```

That would require additional work, such as:

- U-Boot scan / boot-target changes
- placing `extlinux.conf` on `DEVBOOT`
- deciding whether `DEVBOOT` becomes the canonical source for kernel and DTB
- preventing artifact divergence between `rootfs:/boot` and `DEVBOOT`

Until that decision is made, `rootfs:/boot` remains authoritative.

---

## 14. Recommended Usage

Use `DEVBOOT` for:

- Windows-accessible inspection
- copying kernel / DTB artifacts
- build comparison
- debugging
- future maintenance workflows

Do not assume that modifying files in `DEVBOOT` changes what the board boots.

The active files are still:

```text
rootfs:/boot/extlinux/extlinux.conf
rootfs:/boot/zImage
rootfs:/boot/stm32mp157c-odyssey.dtb
```

---

## 15. Final Status

**PASS**

The image now provides:

```text
GPT
├── fsbl1
├── fsbl2
├── ssbl
├── rootfs
└── devboot (FAT32, Windows-readable)
```

The added FAT partition provides a clean Windows-visible location for kernel and DTB artifacts while preserving the proven STM32MP1 boot path.

Current policy:

```text
DEVBOOT = convenience / debug partition
ROOTFS:/boot = authoritative boot source
```
