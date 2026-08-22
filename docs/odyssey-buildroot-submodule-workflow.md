# ODYSSEY STM32MP157C Buildroot Submodule Workflow

## 1. Purpose

This document defines how the project pins and uses upstream Buildroot as a Git submodule while keeping all project-owned Odyssey customizations in the main repository through `BR2_EXTERNAL`.

The ownership boundary is:

```text
third_party/buildroot/
    upstream Buildroot source, pinned as a Git submodule

buildroot_external/
    project-owned BR2_EXTERNAL tree

output/
    generated Buildroot output, never committed

scripts/
    project build and verification wrappers
```

This separation is deliberate. Upstream Buildroot must remain disposable and unmodified; persistent board changes belong in the project repository.

---

## 2. Pinned Buildroot Revision

The submodule points to the Buildroot `2026.05.1` release commit:

```text
cb857ba4c87a93e5265a9e4a3f32071abf39e14a
```

The corresponding upstream commit is:

```text
Makefile: Update for 2026.05.1
```

The submodule source is the GitHub mirror:

```text
https://github.com/buildroot/buildroot.git
```

The pinned Git commit is the dependency identity used by this project.

---

## 3. Repository Layout

```text
stm32mp1-flight-control/
├── .gitmodules
├── .gitignore
├── README.md
├── buildroot_external/
│   ├── external.desc
│   ├── external.mk
│   ├── Config.in
│   ├── configs/
│   │   └── stm32mp1_flight_odyssey_defconfig
│   └── board/
│       └── odyssey/
│           ├── linux.config
│           ├── genimage.cfg
│           ├── patches/
│           │   └── linux/
│           │       └── 9999-odyssey-enable-fs-usb-device.patch
│           └── overlay/
│               ├── boot/extlinux/extlinux.conf
│               └── etc/
│                   ├── inittab
│                   └── init.d/S50usb-acm
├── third_party/
│   └── buildroot/             # Git submodule
├── scripts/
│   ├── build.sh
│   ├── clean.sh
│   └── verify-image.sh
└── output/                    # generated and ignored
```

The project-owned files under `buildroot_external/` are authoritative.

---

## 4. Clone Workflow

Preferred clone command:

```bash
git clone --recursive https://github.com/cctsao1008/stm32mp1-flight-control.git
cd stm32mp1-flight-control
```

If the repository was cloned without `--recursive`:

```bash
git submodule update --init --recursive
```

Verify the pinned revision:

```bash
git -C third_party/buildroot rev-parse HEAD
```

Expected:

```text
cb857ba4c87a93e5265a9e4a3f32071abf39e14a
```

---

## 5. Build Invocation

Normal manual Buildroot invocation:

```bash
ROOT="$PWD"

make -C "$ROOT/third_party/buildroot" \
    O="$ROOT/output/odyssey" \
    BR2_EXTERNAL="$ROOT/buildroot_external" \
    stm32mp1_flight_odyssey_defconfig

make -C "$ROOT/third_party/buildroot" \
    O="$ROOT/output/odyssey" \
    BR2_EXTERNAL="$ROOT/buildroot_external" \
    -j8
```

The preferred project wrapper is:

```bash
./scripts/build.sh
```

The wrapper uses:

```text
DEFCONFIG=stm32mp1_flight_odyssey_defconfig
BR2_EXTERNAL=<repo>/buildroot_external
O=<repo>/output/odyssey
```

The generated symbol `BR2_EXTERNAL_STM32MP1_FLIGHT_PATH` comes from `external.desc` and therefore does not change when the external-tree directory is renamed.

---

## 6. Generated Output

All generated Buildroot state is kept under:

```text
output/odyssey/
```

Important final artifacts include:

```text
output/odyssey/images/sdcard.img
output/odyssey/images/zImage
output/odyssey/images/stm32mp157c-odyssey.dtb
output/odyssey/images/rootfs.ext4
output/odyssey/images/devboot.vfat
```

`output/` is ignored by Git and is not a source of truth.

---

## 7. Verification Workflow

After building:

```bash
./scripts/verify-image.sh
```

The verification script checks or prints:

- SHA256 of generated artifacts
- GPT partition table
- DEVBOOT FAT contents
- final DTB USB OTG node
- final DTB USBPHYC node

Static verification is followed by hardware runtime validation.

The validated runtime path is:

```text
Linux 6.6 boot
    -> root=PARTLABEL=rootfs rootwait
    -> rootfs mounted
    -> USBPHYC active
    -> DWC2 UDC registered
    -> ConfigFS gadget bound
    -> /dev/ttyGS0 present
    -> UDC state configured
    -> Windows USB Serial Device (COM25)
    -> Buildroot login shell
```

This complete path has passed on the Seeed Odyssey STM32MP157C.

---

## 8. Cleaning

To remove the out-of-tree Buildroot output:

```bash
./scripts/clean.sh
```

This removes generated output without modifying the Buildroot submodule or project-owned BR2_EXTERNAL source.

---

## 9. Updating the Buildroot Submodule

A Buildroot version change must be treated as a controlled platform migration.

Example workflow:

```bash
cd third_party/buildroot

git fetch --tags
git checkout <new-buildroot-tag-or-commit>

cd ../..
git add third_party/buildroot
git commit -m "build: update Buildroot submodule to <version>"
```

After changing the submodule revision, perform at least:

```text
[ ] clean output build
[ ] project defconfig / olddefconfig review
[ ] Linux patch application check
[ ] kernel configuration check
[ ] DTB inspection
[ ] GPT inspection
[ ] DEVBOOT inspection
[ ] full board boot
[ ] rootfs mount check
[ ] USB CDC ACM regression
[ ] A7/M4 related regression tests as they become available
[ ] artifact hash / baseline update
```

Do not update the submodule pointer merely because a newer Buildroot release exists.

---

## 10. Do Not Modify the Submodule In Place

Do not make persistent project edits under:

```text
third_party/buildroot/
```

Persistent customization belongs under:

```text
buildroot_external/configs/
buildroot_external/board/odyssey/linux.config
buildroot_external/board/odyssey/patches/
buildroot_external/board/odyssey/overlay/
buildroot_external/board/odyssey/genimage.cfg
buildroot_external/package/               # if custom packages are added later
```

The former modified `~/github/buildroot-2026.05.1` checkout is historical/debug evidence only. Do not maintain it in parallel as a project source tree.

---

## 11. Reproducibility Definition

Functional platform reproduction is defined by version-controlling and validating:

```text
main repository commit
        +
Buildroot submodule commit
        +
BR2_EXTERNAL project defconfig
        +
kernel config
        +
Linux patches
        +
rootfs overlay
        +
genimage layout
        +
build/verification scripts
        |
        v
validated image and hardware behavior
```

The submodule solves upstream dependency pinning; the BR2_EXTERNAL tree owns project-specific changes.

Byte-for-byte deterministic image generation is a separate objective because current generated artifacts include build timestamps, filesystem UUID/time metadata, FAT metadata, and GPT GUIDs.

---

## 12. Validated Status

```text
[PASS] .gitmodules created
[PASS] Buildroot 2026.05.1 pinned as a submodule
[PASS] exact active Odyssey board files imported
[PASS] project-owned defconfig created
[PASS] project paths use BR2_EXTERNAL
[PASS] output redirected to output/odyssey
[PASS] build / clean / verification wrappers present
[PASS] clean recursive clone build completed
[PASS] final DTB reproduced byte-for-byte
[PASS] GPT and DEVBOOT layout validated
[PASS] Linux 6.6 boots from PARTLABEL=rootfs
[PASS] DWC2 initializes without historical reset timeout
[PASS] ConfigFS CDC ACM binds automatically
[PASS] /dev/ttyGS0 present
[PASS] UDC state configured
[PASS] Windows USB Serial Device enumerates as COM25
[PASS] Buildroot login shell works over CDC ACM
[PASS] buildroot_external/ BR2_EXTERNAL tree declared authoritative
```
