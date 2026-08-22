# Documentation Index

## Odyssey STM32MP157C Buildroot Platform

The repository-owned Buildroot platform uses a pinned Buildroot 2026.05.1 submodule under `third_party/buildroot/` plus the validated project `BR2_EXTERNAL` tree under `buildroot_external/`. The migration from the former modified upstream working tree is complete and hardware-validated.

Primary documents:

- `odyssey-known-good-baseline.md` — authoritative hardware-validated baseline, hashes, runtime acceptance, and change-control rule
- `odyssey-buildroot-submodule-workflow.md` — clone, build, verify, clean, update, and source-ownership workflow
- `odyssey-buildroot-build-flow.md` — Buildroot platform build flow and component relationships
- `odyssey-buildroot-modification-map.md` — mapping from project-owned files to generated artifacts and verification
- `odyssey-buildroot-external-migration.md` — completed migration from modified upstream working tree to BR2_EXTERNAL
- `odyssey-fresh-clone-reproduction.md` — clean-clone reproduction and hardware validation result
- `odyssey-usb-cdc-acm-bringup.md` — USB CDC ACM bring-up history and runtime path
- `odyssey-usb-cdc-acm-buildroot-implementation.md` — persistent Buildroot USB gadget implementation
- `odyssey-devboot-fat-partition.md` — DEVBOOT FAT partition design and use
- `odyssey-devboot-fat-buildroot-implementation.md` — Buildroot implementation for DEVBOOT

Validated end-to-end platform path:

```text
clean recursive clone
    -> pinned Buildroot 2026.05.1
    -> buildroot_external/ BR2_EXTERNAL
    -> Linux 6.6 image
    -> Odyssey boot from PARTLABEL=rootfs
    -> USBPHYC / DWC2 peripheral
    -> ConfigFS CDC ACM
    -> /dev/ttyGS0
    -> UDC configured
    -> Windows USB Serial Device (COM25)
    -> Buildroot login shell
```

Byte-for-byte deterministic image generation is separate follow-up work.

## RasPilot / Flight-control Reference

- `raspilot-v1.1-hardware-reference.md` — source-grounded RasPilot v1.1 hardware architecture reference
- `raspilot-vs-stm32mp1-architecture.md` — RasPilot reference architecture compared with STM32MP1 A7/M4 partitioning
- `raspilot-reference-mapping.md` — reference mapping and resource-allocation framework for the STM32MP1 flight-control design
