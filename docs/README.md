# Documentation

This directory contains the engineering documentation for the STM32MP1 flight-control platform bring-up and implementation.

The documentation is organized by purpose rather than chronologically. Start with the build flow, then use the feature-specific bring-up and implementation documents as needed.

## Getting Started

### [ODYSSEY STM32MP157C Buildroot Build Flow](odyssey-buildroot-build-flow.md)

Use this first when rebuilding or maintaining the platform.

Covers:

- Buildroot 2026.05.1 baseline
- Linux 6.6 build flow
- WSL environment
- `output/build`, `output/target`, `output/host`, and `output/images`
- when to use `linux-dirclean`, `linux-patch`, and `linux-configure`
- rebuild decision flow
- DTB, rootfs, and image verification

### [ODYSSEY STM32MP157C Buildroot Modification Map](odyssey-buildroot-modification-map.md)

Use this when the question is:

> Which file controls this behavior, why was it modified, and what generated artifact should I verify?

It maps:

```text
Buildroot source file
    -> reason for modification
    -> generated artifact
    -> verification command
```

for the current validated Odyssey customizations.

## Platform Bring-up

### USB CDC ACM

- [USB CDC ACM Bring-up Notes](odyssey-usb-cdc-acm-bringup.md)
  - investigation history
  - Windows Code 10 symptom
  - Linux 5.10.1 DWC2 reset failure
  - Linux 6.6 migration
  - USBPHYC / UTMI / regulator root causes
  - final end-to-end result

- [USB CDC ACM — Buildroot Implementation](odyssey-usb-cdc-acm-buildroot-implementation.md)
  - concrete Buildroot implementation
  - kernel configuration
  - DTS patch
  - ConfigFS gadget startup
  - `/dev/ttyGS0`
  - BusyBox `getty`
  - runtime verification

### DEVBOOT FAT Partition

- [DEVBOOT FAT Partition Notes](odyssey-devboot-fat-partition.md)
  - rationale and design
  - GPT layout
  - Windows-readable FAT partition
  - current U-Boot boot authority
  - GPT warning on larger SD cards

- [DEVBOOT FAT — Buildroot Implementation](odyssey-devboot-fat-buildroot-implementation.md)
  - `genimage.cfg`
  - FAT image generation
  - `dosfstools` / `mtools`
  - partition verification
  - artifact inspection

## Reproducibility and Maintenance

The next documents in this area are intended to make the platform reproducible from a clean environment:

- `odyssey-known-good-baseline.md`
  - validated versions, boot expectations, and artifact hashes
- `odyssey-fresh-clone-reproduction.md`
  - clean-machine / clean-Buildroot reproduction procedure
- `odyssey-buildroot-external-migration.md`
  - migration from direct Buildroot-tree modifications to a project-owned `BR2_EXTERNAL`

These documents are part of the platform-maintenance strategy and should be kept synchronized with the actual source tree.

## Documentation Policy

The intended distinction is:

```text
Bring-up notes
    = what failed, why, and how the root cause was found

Implementation guides
    = exact Buildroot-side implementation and verification

Build flow
    = how to build and rebuild the complete platform

Modification map
    = where each persistent project change lives

Known-good baseline
    = what exact combination has been validated

Fresh-clone procedure
    = proof that the repository is reproducible
```

A generated build directory must never be treated as authoritative documentation or persistent source.

The long-term target is:

```text
clean upstream Buildroot
        +
stm32mp1-flight-control repository
        |
        v
reproducible sdcard.img
        |
        v
validated Odyssey platform
```
