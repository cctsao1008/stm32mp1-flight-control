# Buildroot External Tree

This directory is the project-owned Buildroot `BR2_EXTERNAL` tree for the Odyssey STM32MP157C platform.

## Ownership Boundary

The repository now deliberately separates upstream Buildroot from project customizations:

```text
third_party/buildroot/
    upstream Buildroot 2026.05.1, pinned as a Git submodule

buildroot/
    project-owned BR2_EXTERNAL source

output/odyssey/
    generated Buildroot output, ignored by Git
```

The Buildroot submodule is pinned to:

```text
cb857ba4c87a93e5265a9e4a3f32071abf39e14a
```

which is the Buildroot `2026.05.1` release commit.

## Current Status

**The submodule infrastructure is established, but the BR2_EXTERNAL migration is not yet fully authoritative.**

The currently validated working image was produced from a locally modified Buildroot 2026.05.1 tree with board-specific changes under:

```text
~/github/buildroot-2026.05.1/board/seeed/stm32mp157c-odyssey/
```

Those exact validated files still need to be imported into this directory and verified through a clean build using only:

```text
third_party/buildroot/
        +
buildroot/
        |
        v
output/odyssey/images/sdcard.img
```

Do not recreate the board files from memory. Import the exact validated files from the working WSL tree.

## Target Layout

```text
buildroot/
├── external.desc
├── external.mk
├── Config.in
├── configs/
│   └── stm32mp1_flight_odyssey_defconfig
└── board/
    └── odyssey/
        ├── linux.config
        ├── genimage.cfg
        ├── patches/
        │   └── linux/
        │       └── 9999-odyssey-enable-fs-usb-device.patch
        └── overlay/
            ├── boot/extlinux/extlinux.conf
            └── etc/
                ├── inittab
                └── init.d/S50usb-acm
```

## Intended Build Command

After the exact validated board files and project defconfig are imported:

```bash
./scripts/build.sh
```

Equivalent manual flow:

```bash
ROOT="$PWD"

make -C "$ROOT/third_party/buildroot" \
    O="$ROOT/output/odyssey" \
    BR2_EXTERNAL="$ROOT/buildroot" \
    stm32mp1_flight_odyssey_defconfig

make -C "$ROOT/third_party/buildroot" \
    O="$ROOT/output/odyssey" \
    BR2_EXTERNAL="$ROOT/buildroot" \
    -j8
```

Verify generated artifacts with:

```bash
./scripts/verify-image.sh
```

## Migration Rule

The migration is complete only when:

1. the exact validated board files are imported from the current WSL Buildroot tree,
2. `stm32mp1_flight_odyssey_defconfig` is created from the validated configuration,
3. a clean Buildroot 2026.05.1 submodule build succeeds using this external tree,
4. the generated DTB, GPT layout, rootfs overlay, and boot artifacts are verified,
5. the board boots successfully,
6. USB CDC ACM reaches `configured`,
7. Windows obtains a COM port,
8. Buildroot login works over `/dev/ttyGS0`, and
9. the known-good artifact hashes are recorded.

After that point the policy becomes:

```text
third_party/buildroot/ = pinned upstream dependency
buildroot/             = authoritative project customization
output/                = disposable generated output
```

## References

- `docs/odyssey-buildroot-submodule-workflow.md`
- `docs/odyssey-buildroot-external-migration.md`
- `docs/odyssey-fresh-clone-reproduction.md`
- `docs/odyssey-known-good-baseline.md`
