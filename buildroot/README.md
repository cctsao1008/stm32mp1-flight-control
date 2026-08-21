# Buildroot External Tree

This directory is reserved for the project-owned Buildroot `BR2_EXTERNAL` tree for the Odyssey STM32MP157C platform.

## Status

**Scaffold only — not yet the authoritative build source.**

The current validated image was produced from a working Buildroot 2026.05.1 tree with board-specific changes under:

```text
board/seeed/stm32mp157c-odyssey/
```

Those exact validated files still need to be copied into this repository and verified through a fresh Buildroot build before this external tree is declared authoritative.

Do not assume that the presence of this directory means the external-tree migration is complete.

## Target Layout

```text
buildroot/
├── external.desc
├── external.mk
├── Config.in
├── configs/
│   └── stm32mp157c_odyssey_flight_defconfig
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

## Migration Rule

The migration is complete only when:

1. the exact validated board files are imported from the current WSL Buildroot tree,
2. a clean Buildroot 2026.05.1 checkout builds using this external tree,
3. the generated DTB, GPT layout, rootfs overlay, and boot artifacts are verified,
4. the board boots successfully,
5. USB CDC ACM reaches `configured`,
6. Windows obtains a COM port,
7. Buildroot login works over `/dev/ttyGS0`, and
8. the known-good artifact hashes are recorded.

See:

- `docs/odyssey-buildroot-external-migration.md`
- `docs/odyssey-fresh-clone-reproduction.md`
- `docs/odyssey-known-good-baseline.md`
