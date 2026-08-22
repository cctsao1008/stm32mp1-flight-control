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

## 2. Pinned Buildroot Revision

```text
Buildroot: 2026.05.1
commit:    cb857ba4c87a93e5265a9e4a3f32071abf39e14a
source:    https://github.com/buildroot/buildroot.git
```

## 3. Repository Layout

```text
stm32mp1-flight-control/
├── buildroot_external/
│   ├── external.desc
│   ├── external.mk
│   ├── Config.in
│   ├── configs/
│   │   └── stm32mp1_flight_odyssey_defconfig
│   └── board/odyssey/
│       ├── linux.config
│       ├── genimage.cfg
│       ├── patches/linux/9999-odyssey-enable-fs-usb-device.patch
│       └── overlay/
├── third_party/
│   └── buildroot/             # Git submodule
├── scripts/
│   ├── build.sh
│   ├── clean.sh
│   └── verify-image.sh
└── output/                    # generated and ignored
```

The project-owned files under `buildroot_external/` are authoritative.

## 4. Clone Workflow

```bash
git clone --recursive https://github.com/cctsao1008/stm32mp1-flight-control.git
cd stm32mp1-flight-control
```

If cloned without `--recursive`:

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

## 5. Build Invocation

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

Preferred wrapper:

```bash
./scripts/build.sh
```

The wrapper uses:

```text
DEFCONFIG=stm32mp1_flight_odyssey_defconfig
BR2_EXTERNAL=<repo>/buildroot_external
O=<repo>/output/odyssey
```

## 6. Generated Output

Generated Buildroot state remains under `output/odyssey/` and is not a source of truth.

## 7. Verification Workflow

```bash
./scripts/verify-image.sh
```

Validated runtime path:

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

## 8. Cleaning

```bash
./scripts/clean.sh
```

## 9. Project-owned Customization

Persistent customization belongs under:

```text
buildroot_external/configs/
buildroot_external/board/odyssey/linux.config
buildroot_external/board/odyssey/patches/
buildroot_external/board/odyssey/overlay/
buildroot_external/board/odyssey/genimage.cfg
buildroot_external/package/               # if custom packages are added later
```

Do not make persistent project edits under `third_party/buildroot/`.

## 10. Reproducibility Definition

Functional platform reproduction is defined by the main repository commit, pinned Buildroot submodule, BR2_EXTERNAL project files, build scripts, generated image verification, and hardware behavior.

Byte-for-byte deterministic image generation is tracked separately.
