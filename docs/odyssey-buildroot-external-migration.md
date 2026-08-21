# ODYSSEY STM32MP157C BR2_EXTERNAL Migration Plan

## 1. Purpose

This document defines how the validated Odyssey STM32MP157C Buildroot customizations should be moved out of a locally modified upstream Buildroot checkout and into this repository as a project-owned `BR2_EXTERNAL` tree.

The goal is to make the platform reproducible from:

```text
clean Buildroot 2026.05.1
        +
stm32mp1-flight-control repository
        |
        v
validated sdcard.img
```

without manually editing files inside the upstream Buildroot source tree.

---

## 2. Why Migrate

The current working implementation was developed under:

```text
~/github/buildroot-2026.05.1/
```

with persistent customizations stored under the Odyssey board directory in that Buildroot tree.

That is acceptable during bring-up, but it has several maintenance risks:

- a fresh Buildroot checkout does not contain project modifications
- a future Buildroot upgrade can overwrite or obscure local board changes
- Git history for the flight-control project does not automatically capture the exact build inputs
- another developer cannot reproduce the image from this repository alone
- generated and persistent files can become mixed during debugging

A project-owned external tree removes this ambiguity.

---

## 3. Target Repository Layout

Recommended target structure:

```text
stm32mp1-flight-control/
├── buildroot/
│   ├── external.desc
│   ├── external.mk
│   ├── Config.in
│   ├── configs/
│   │   └── stm32mp157c_odyssey_flight_defconfig
│   └── board/
│       └── odyssey/
│           ├── linux.config
│           ├── genimage.cfg
│           ├── patches/
│           │   └── linux/
│           │       └── 9999-odyssey-enable-fs-usb-device.patch
│           └── overlay/
│               ├── boot/
│               │   └── extlinux/
│               │       └── extlinux.conf
│               └── etc/
│                   ├── inittab
│                   └── init.d/
│                       └── S50usb-acm
├── docs/
└── README.md
```

The exact final defconfig name may be adjusted, but it should be project-specific rather than silently modifying the upstream Odyssey defconfig in place.

---

## 4. External-tree Metadata

A normal external tree contains:

```text
buildroot/external.desc
buildroot/external.mk
buildroot/Config.in
```

Representative `external.desc`:

```text
name: STM32MP1_FLIGHT
 desc: STM32MP1 flight-control Buildroot external tree
```

Representative `external.mk`:

```make
include $(sort $(wildcard $(BR2_EXTERNAL_STM32MP1_FLIGHT_PATH)/package/*/*.mk))
```

If the project has no custom Buildroot packages yet, this file can remain minimal.

Representative `Config.in`:

```text
# Project-specific packages may be sourced here later.
```

Do not add unnecessary custom packages merely to justify the external tree. The initial value is ownership of board configuration and reproducibility.

---

## 5. Files to Migrate

The following working files should be copied from the validated local Buildroot tree into the repository-owned external tree.

### Kernel config

Current source:

```text
buildroot-2026.05.1/board/seeed/stm32mp157c-odyssey/linux.config
```

Target:

```text
stm32mp1-flight-control/buildroot/board/odyssey/linux.config
```

### Image layout

Current source:

```text
buildroot-2026.05.1/board/seeed/stm32mp157c-odyssey/genimage.cfg
```

Target:

```text
stm32mp1-flight-control/buildroot/board/odyssey/genimage.cfg
```

### Linux patch

Current source:

```text
buildroot-2026.05.1/board/seeed/stm32mp157c-odyssey/patches/linux/9999-odyssey-enable-fs-usb-device.patch
```

Target:

```text
stm32mp1-flight-control/buildroot/board/odyssey/patches/linux/9999-odyssey-enable-fs-usb-device.patch
```

### Rootfs overlay

Current source:

```text
buildroot-2026.05.1/board/seeed/stm32mp157c-odyssey/overlay/
```

Target:

```text
stm32mp1-flight-control/buildroot/board/odyssey/overlay/
```

This includes at least:

```text
boot/extlinux/extlinux.conf
etc/inittab
etc/init.d/S50usb-acm
```

---

## 6. Project Defconfig Strategy

The project should own a defconfig that starts from the validated Odyssey baseline but explicitly records project choices.

The defconfig must capture at least:

```text
Linux 6.6 selection
Linux 6.6 headers selection
DTS name: st/stm32mp157c-odyssey
board-specific kernel config path
board-specific Linux patch path
rootfs overlay path
genimage configuration / post-image flow
host tools needed for FAT generation
```

Do not rely on a manually edited top-level `.config` as the only record of these choices.

The normal workflow should eventually be:

```bash
make BR2_EXTERNAL=/path/to/stm32mp1-flight-control/buildroot \
     stm32mp157c_odyssey_flight_defconfig
```

followed by:

```bash
make BR2_EXTERNAL=/path/to/stm32mp1-flight-control/buildroot -j8
```

---

## 7. Path Conversion

Paths that currently point into:

```text
board/seeed/stm32mp157c-odyssey/
```

must be converted to paths rooted in the external tree.

The external-tree path variable will be based on the `name` in `external.desc`.

For the proposed name:

```text
STM32MP1_FLIGHT
```

the generated variable is conceptually:

```text
BR2_EXTERNAL_STM32MP1_FLIGHT_PATH
```

Project-owned paths can then reference:

```text
$(BR2_EXTERNAL_STM32MP1_FLIGHT_PATH)/board/odyssey/...
```

The exact Buildroot configuration symbols used for kernel custom config, rootfs overlay, patches, and image-generation hooks should be validated against Buildroot 2026.05.1 when the migration is implemented.

---

## 8. Migration Procedure

Recommended migration sequence:

```text
1. Freeze current working Buildroot tree
2. Record SHA256 hashes of current artifacts
3. Copy persistent board files into repository
4. Create external.desc / external.mk / Config.in
5. Create project defconfig
6. Point all board paths to BR2_EXTERNAL locations
7. Start from a fresh Buildroot 2026.05.1 checkout
8. Build using only BR2_EXTERNAL + project defconfig
9. Compare generated DTB / GPT / rootfs content
10. Flash and perform runtime validation
11. Compare artifact hashes where reproducibility permits
12. Declare BR2_EXTERNAL tree authoritative
13. Stop maintaining duplicate project files in upstream Buildroot tree
```

---

## 9. Pre-migration Freeze

Before copying files, record the current source and artifacts.

Recommended commands in the working Buildroot tree:

```bash
cd ~/github/buildroot-2026.05.1

sha256sum \
  output/images/sdcard.img \
  output/images/zImage \
  output/images/stm32mp157c-odyssey.dtb \
  output/images/rootfs.ext4
```

Also preserve:

```bash
cp .config /tmp/odyssey-buildroot-known-good.config
cp output/build/linux-6.6/.config /tmp/odyssey-linux-known-good.config
```

And capture the persistent board files:

```bash
find board/seeed/stm32mp157c-odyssey -maxdepth 5 -type f -print | sort
```

This provides an audit reference for the migration.

---

## 10. Fresh-build Validation

The migration is not complete merely because Buildroot compiles.

The new external-tree build must pass the same validation as the current working image.

Required checks:

```text
[ ] Linux 6.6.0 boots
[ ] root=PARTLABEL=rootfs rootwait
[ ] rootfs mounts successfully
[ ] final DTB contains USBPHYC + FS OTG + power dependency
[ ] no DWC2 Soft Reset timeout
[ ] ConfigFS gadget starts automatically
[ ] /dev/ttyGS0 exists
[ ] UDC reaches configured
[ ] Windows enumerates USB Serial Device
[ ] Buildroot login works over USB CDC ACM
[ ] GPT contains devboot
[ ] DEVBOOT contains zImage + DTB
[ ] U-Boot still loads authoritative boot files from rootfs:/boot
```

---

## 11. Avoid Duplicate Sources of Truth

During migration there will temporarily be two copies of the same board files:

```text
upstream Buildroot working tree
project BR2_EXTERNAL tree
```

That state must be temporary.

After the external-tree build is validated, the policy should be:

```text
project repository = authoritative
upstream Buildroot checkout = disposable dependency
output/* = disposable generated artifacts
```

Do not continue editing both locations in parallel.

---

## 12. Version Upgrade Policy

Once the external tree is authoritative, future Buildroot upgrades should follow this pattern:

```text
existing BR2_EXTERNAL
       +
new clean Buildroot version
       |
       v
configuration migration
       |
       v
build
       |
       v
artifact + runtime regression validation
```

This makes a Buildroot version upgrade explicit and reviewable rather than mixing it with board-specific source changes.

---

## 13. Current Status

The `BR2_EXTERNAL` layout is the **target architecture**, but the migration must not be declared complete until the exact validated files from the current WSL Buildroot tree are copied into this repository and a fresh Buildroot checkout reproduces the working image.

This distinction is intentional: documentation and scaffolding can be prepared in advance, but only a fresh-build runtime validation can establish the external tree as the new source of truth.
