# Odyssey DEVBOOT FAT Partition

## Purpose

`DEVBOOT` is a 64 MiB FAT partition included in the generated Odyssey SD-card image as a convenience/debug surface for Windows or other hosts that can read FAT directly.

It is not the normal boot authority.

## Validated partition layout

```text
1  fsbl1     206 KiB
2  fsbl2     206 KiB
3  ssbl      1011 KiB
4  rootfs    60 MiB
5  devboot   64 MiB
```

## Contents

The validated partition contains:

```text
zImage
stm32mp157c-odyssey.dtb
```

## Normal boot path

U-Boot continues to load kernel and DTB from partition 4:

```text
Scanning mmc 0:4...
Found /boot/extlinux/extlinux.conf
Retrieving file: /boot/zImage
Retrieving file: /boot/stm32mp157c-odyssey.dtb
```

Therefore `DEVBOOT` is not authoritative for the running image.

## Buildroot ownership

The partition is generated from:

```text
buildroot/board/odyssey/genimage.cfg
```

through the project BR2_EXTERNAL build.

## Verification

```bash
./scripts/verify-image.sh
```

The verification output must show the `devboot` GPT label and the two expected files.

## Reproducibility note

FAT volume serial numbers and file timestamps are generated metadata and currently vary between clean builds. This affects exact image hashes but does not change the partition's validated structure or role.
