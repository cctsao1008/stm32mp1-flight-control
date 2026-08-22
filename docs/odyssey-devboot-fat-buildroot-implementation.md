# Odyssey DEVBOOT FAT Buildroot Implementation

## Status

Validated through the repository-owned BR2_EXTERNAL tree.

The generated SD-card image contains a 64 MiB FAT partition named `devboot` in addition to the normal rootfs partition. `DEVBOOT` is a convenience/debug partition only; normal U-Boot boot remains from partition 4 (`rootfs`).

## Project-owned input

```text
buildroot_external/board/odyssey/genimage.cfg
```

## Validated GPT layout

```text
1  fsbl1     206 KiB
2  fsbl2     206 KiB
3  ssbl      1011 KiB
4  rootfs    60 MiB
5  devboot   64 MiB
```

## DEVBOOT contents

```text
zImage
stm32mp157c-odyssey.dtb
```

Validated with:

```bash
./scripts/verify-image.sh
```

## Boot authority

The normal boot sequence remains:

```text
Scanning mmc 0:4...
Found /boot/extlinux/extlinux.conf
Retrieving file: /boot/zImage
Retrieving file: /boot/stm32mp157c-odyssey.dtb
```

## Generated metadata

The FAT volume serial and file timestamps vary between clean builds unless deterministic-build controls are added. This affects byte-level image hashes but not the validated DEVBOOT structure or function.

## Source-of-truth rule

The authoritative genimage layout is:

```text
buildroot_external/board/odyssey/genimage.cfg
```

Do not maintain a duplicate project genimage configuration inside an upstream Buildroot checkout.
