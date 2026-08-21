# ODYSSEY STM32MP157C Buildroot Submodule Workflow

## 1. Purpose

This document defines how the project pins and uses upstream Buildroot as a Git submodule while keeping all project-owned Odyssey customizations in the main repository through `BR2_EXTERNAL`.

The intended ownership boundary is:

```text
third_party/buildroot/
    upstream Buildroot source, pinned as a Git submodule

buildroot/
    project-owned BR2_EXTERNAL tree

output/
    generated Buildroot output, never committed

scripts/
    project build and verification wrappers
```

This separation is deliberate. Upstream Buildroot must remain disposable and unmodified; persistent board changes belong in the project repository.

---

## 2. Pinned Buildroot Revision

The submodule currently points to the Buildroot `2026.05.1` release commit:

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

Buildroot documents that this GitHub repository is a mirror; the official upstream repository is hosted by the Buildroot project on GitLab. The pinned Git commit is what matters for reproducibility.

---

## 3. Repository Layout

```text
stm32mp1-flight-control/
├── .gitmodules
├── .gitignore
├── README.md
├── buildroot/
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

The board/config files shown under `buildroot/` are the target authoritative layout. Until the exact validated files are imported from the current WSL Buildroot tree and a fresh reproduction passes, the external-tree migration remains incomplete.

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

Verify the release version:

```bash
grep '^export BR2_VERSION' third_party/buildroot/Makefile
```

Expected:

```text
export BR2_VERSION := 2026.05.1
```

---

## 5. Build Invocation

Once the project-owned defconfig and exact validated board files have been imported, the normal manual Buildroot invocation is:

```bash
ROOT="$PWD"

make -C "$ROOT/third_party/buildroot" \
    O="$ROOT/output/odyssey" \
    BR2_EXTERNAL="$ROOT/buildroot" \
    stm32mp1_flight_odyssey_defconfig
```

Then build:

```bash
make -C "$ROOT/third_party/buildroot" \
    O="$ROOT/output/odyssey" \
    BR2_EXTERNAL="$ROOT/buildroot" \
    -j8
```

The project wrapper is:

```bash
./scripts/build.sh
```

The wrapper intentionally fails if the Buildroot submodule is not initialized or if the project defconfig has not yet been imported.

---

## 6. Generated Output

All generated Buildroot state is kept outside the submodule under:

```text
output/odyssey/
```

Important directories are expected to be:

```text
output/odyssey/build/
output/odyssey/host/
output/odyssey/target/
output/odyssey/images/
```

Important final artifacts include:

```text
output/odyssey/images/sdcard.img
output/odyssey/images/zImage
output/odyssey/images/stm32mp157c-odyssey.dtb
output/odyssey/images/rootfs.ext4
output/odyssey/images/devboot.vfat
```

`output/` is ignored by Git and must never become a persistent source of truth.

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

Runtime verification remains mandatory because static image inspection cannot prove that the board actually boots or that USB CDC ACM reaches the configured state.

The final runtime gate remains:

```text
Linux 6.6 boot
    -> root=PARTLABEL=rootfs
    -> rootfs mounted
    -> USBPHYC active
    -> DWC2 UDC registered
    -> ConfigFS gadget bound
    -> /dev/ttyGS0 present
    -> UDC state configured
    -> Windows USB Serial Device (COMxx)
    -> Buildroot login shell
```

---

## 8. Cleaning

To remove the out-of-tree Buildroot output:

```bash
./scripts/clean.sh
```

This removes:

```text
output/odyssey/
```

It does not modify:

- the Buildroot submodule
- the project `BR2_EXTERNAL` source
- documentation
- Git history

---

## 9. Updating the Buildroot Submodule

A Buildroot version change must be treated as a controlled platform migration, not as a casual dependency update.

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
[ ] project defconfig migration / olddefconfig review
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

Temporary source inspection or experiments are acceptable, but any required persistent customization must be represented in one of these forms:

```text
buildroot/configs/
buildroot/board/odyssey/linux.config
buildroot/board/odyssey/patches/
buildroot/board/odyssey/overlay/
buildroot/board/odyssey/genimage.cfg
buildroot/package/               # if custom packages are added later
```

If `git status` inside the submodule shows local modifications after development, treat them as uncommitted upstream-tree experiments that must either be discarded or converted into project-owned patches/configuration.

---

## 11. Submodule State Verification

From the project root:

```bash
git submodule status
```

A healthy initialized state should show the pinned Buildroot commit for:

```text
third_party/buildroot
```

Also check:

```bash
git status
```

The main repository should not report a modified submodule unless the Buildroot revision was intentionally changed or the submodule contains local edits.

---

## 12. Reproducibility Definition

For this project, the Buildroot platform is reproducible only when all of the following are version-controlled together:

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
validated image
```

The submodule solves only the upstream dependency pinning problem. It does not replace the need to import and validate the exact project-owned board files.

---

## 13. Current Status

Completed:

```text
[PASS] .gitmodules created
[PASS] Buildroot submodule path established
[PASS] Buildroot 2026.05.1 release commit pinned
[PASS] generated output moved conceptually to output/odyssey
[PASS] output/ ignored by Git
[PASS] build wrapper added
[PASS] clean wrapper added
[PASS] image verification wrapper added
```

Still required before declaring the Buildroot platform fully reproducible:

```text
[ ] import exact validated Odyssey board files from WSL
[ ] create project-owned defconfig
[ ] perform clean build using submodule + BR2_EXTERNAL only
[ ] compare final static artifacts
[ ] perform runtime regression on hardware
[ ] record known-good SHA256 values
[ ] declare BR2_EXTERNAL tree authoritative
```
