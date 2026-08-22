# Odyssey Reproducible Build Policy

## Purpose

This document defines the deterministic-build policy for the Odyssey STM32MP157C Buildroot platform.

This work is separate from the completed BR2_EXTERNAL migration and hardware-functional validation. The functional platform baseline remains unchanged; the objective here is byte-for-byte reproducibility of generated artifacts.

## Buildroot mode

The project defconfig enables:

```text
BR2_REPRODUCIBLE=y
```

Buildroot 2026.05.1 documents this option as experimental and notes that reproducibility is currently restricted to builds using the same output-directory path because absolute paths may be recorded in intermediate files.

For this project, reproducibility testing therefore uses repeated clean builds at the same repository and `O=` path:

```text
<repo>/output/odyssey
```

The output directory is deleted between builds, but the absolute path remains identical.

## SOURCE_DATE_EPOCH policy

The project build wrapper derives `SOURCE_DATE_EPOCH` from the timestamp of the current main-repository commit:

```bash
git log -1 --format=%ct HEAD
```

This gives a deterministic timestamp for a given project commit and makes generated timestamps track the project source revision rather than the wall-clock build time.

If `SOURCE_DATE_EPOCH` is already defined by the caller, that value is preserved. If the repository timestamp cannot be derived, Buildroot's own reproducible-build fallback remains available.

Reproducibility qualification should be performed from a clean, committed source tree. Uncommitted source changes are outside the reproducibility contract.

## First two-build comparison

After enabling `BR2_REPRODUCIBLE` and the project-derived `SOURCE_DATE_EPOCH`, two clean builds from the same commit and absolute output path were compared.

The following artifacts were identical across both runs:

```text
zImage:                  48ecc54710587621a487f5fad94af901bf240b42492c00411b5896bd3283f5d6
stm32mp157c-odyssey.dtb: 878fb69ca251bb38e9118521b3f2464276a6af408cf52688065b0251c7af2d50
TF-A:                    2a4a5ee374f0ae5519279f58a368ecb5e80267ccf88657acab053583cf891621
U-Boot:                  ba7e598d103065bdd1d6c2700c25e433316c475d1789baf7abb34abc8db3395b
```

Linux generated compile metadata was unchanged, and BusyBox no longer embedded a wall-clock build timestamp (`BusyBox v1.38.0 ()`).

The remaining differences were isolated to image/container metadata:

```text
rootfs.ext4 filesystem UUID
DEVBOOT FAT volume serial
sdcard.img GPT disk GUID
```

The ext4 creation/write times and DEVBOOT file timestamps were already identical between runs, which confirms that the reproducible timestamp policy is taking effect for those fields.

## Deterministic image identifiers

The project now assigns fixed Odyssey-specific identifiers for the remaining generated metadata:

```text
rootfs ext4 UUID: cd4c384b-40bc-5253-b967-5b0cc29a862f
DEVBOOT FAT ID:    AFFB4506
GPT disk UUID:     346cbe79-c96a-5911-8cb0-f9fa76782e5a
```

Implementation locations:

```text
buildroot_external/configs/stm32mp1_flight_odyssey_defconfig
buildroot_external/board/odyssey/genimage.cfg
```

The rootfs UUID is passed to `mke2fs -U` via `BR2_TARGET_ROOTFS_EXT2_MKFS_OPTIONS`. The DEVBOOT serial is passed to `mkdosfs -i` through genimage VFAT `extraargs`. The GPT disk UUID is set with genimage `hdimage.disk-uuid`.

These identifiers are persistent image-format identities, not timestamps. They must remain stable for a given platform image definition unless an intentional format/identity migration is made.

## Test procedure

For two independent builds from the same project commit:

```bash
./scripts/clean.sh
./scripts/build.sh
./scripts/verify-image.sh | tee repro-build-1.txt

./scripts/clean.sh
./scripts/build.sh
./scripts/verify-image.sh | tee repro-build-2.txt

diff -u repro-build-1.txt repro-build-2.txt
```

Record the resulting hashes and metadata. The two runs must use the same source revision and the same absolute repository/output path.

## Artifacts to compare

At minimum compare SHA256 for:

```text
vmlinux
Image
zImage
BusyBox
stm32mp157c-odyssey.dtb
rootfs.ext4
devboot.vfat
tf-a-stm32mp157c-odyssey.stm32
u-boot.stm32
sdcard.img
```

Also record generated metadata:

```text
kernel UTS_VERSION
BusyBox embedded build timestamp
ext4 filesystem UUID
FAT volume serial
GPT disk GUID
```

## Acceptance rule

The deterministic-build gate passes only when two independent clean builds from the same committed source revision and the same absolute output path produce byte-for-byte identical required artifacts.

If an artifact still differs, identify the first nondeterministic input or metadata field before adding further project-specific overrides.

Do not mask differences by comparing only functional behavior or selected files.

## Hardware regression

After byte-for-byte reproducibility is achieved, perform one hardware regression build and verify at least:

```text
Linux 6.6 boot
root=PARTLABEL=rootfs rootwait
rootfs read/write mount
USBPHYC / DWC2 initialization
ConfigFS CDC ACM bind
/dev/ttyGS0
UDC configured
Windows USB Serial Device
Buildroot login shell over CDC ACM
```

This confirms that deterministic-build controls did not alter the validated functional platform behavior.
