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

## Test procedure

For two independent builds from the same project commit:

```bash
./scripts/clean.sh
./scripts/build.sh
./scripts/verify-image.sh
```

Record the resulting hashes and metadata, then repeat the same sequence without changing the source revision.

The two runs must use the same absolute repository/output path.

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

If an artifact still differs, identify the first nondeterministic input or metadata field before adding project-specific overrides.

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
