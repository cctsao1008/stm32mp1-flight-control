# Documentation

This directory contains the engineering documentation for the STM32MP1 flight-control platform bring-up, implementation, reference architecture, and reproducibility work.

The documentation is organized by purpose rather than chronologically. Start with the build flow for platform maintenance, use the feature-specific bring-up documents for implementation details, and use the RasPilot documents for historical architecture comparison and function mapping.

## Getting Started

### [ODYSSEY STM32MP157C Buildroot Build Flow](odyssey-buildroot-build-flow.md)

Use this first when rebuilding or maintaining the platform.

Covers:

- Buildroot 2026.05.1 baseline
- Linux 6.6 build flow
- WSL environment
- Buildroot output directories
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

### [ODYSSEY STM32MP157C Buildroot Submodule Workflow](odyssey-buildroot-submodule-workflow.md)

Use this for the repository-level dependency model.

Current structure:

```text
third_party/buildroot/
    pinned upstream Buildroot 2026.05.1 submodule

buildroot/
    project-owned BR2_EXTERNAL tree

output/odyssey/
    generated build output

scripts/
    build / clean / verification wrappers
```

The pinned Buildroot release commit is:

```text
cb857ba4c87a93e5265a9e4a3f32071abf39e14a
```

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

## RasPilot Historical Reference

RasPilot V1.1 is used as a **historical architecture and hardware-partitioning reference**, not as the target hardware design.

### [RasPilot V1.1 Hardware Reference](raspilot-v1.1-hardware-reference.md)

Detailed schematic-oriented reference covering:

- Raspberry Pi 40-pin host interface
- shared SPI and sensor DRDY topology
- FRAM
- serial, I2C, analog pressure, and auxiliary ADC interfaces
- L3GD20, LSM303D, MPU-9250/6500-era sensor blocks
- MS5611 barometer
- STM32F10x I/O processor
- explicit timer allocation for eight actuator channels
- PPM, S.Bus, Spektrum/DSM, and RSSI
- servo/actuator outputs
- safety switch, LEDs, and alarm
- CAN-related signals
- power rails, sensing, and reset sequencing
- production-test access
- design principles worth retaining and legacy parts that should not be copied

### [RasPilot V1.1 vs STM32MP1 Architecture](raspilot-vs-stm32mp1-architecture.md)

Architecture-level comparison covering:

```text
Raspberry Pi / Linux       -> Cortex-A7 / Linux
external STM32F10x         -> integrated Cortex-M4
board-level processor IPC  -> OpenAMP / RPMsg / shared memory
STM32 actuator timing      -> M4 timer / DMA actuator engine
STM32 RC handling          -> M4 receiver domain
local safety supervision   -> M4 safety / watchdog boundary
```

The document also discusses sensor ownership, actuator authority, RC timing, safety, power monitoring, watchdog philosophy, A7/M4 message classes, and the risks introduced by integrating both domains into one SoC.

### [RasPilot Reference Mapping to STM32MP1](raspilot-reference-mapping.md)

Function-by-function engineering mapping covering:

- primary and secondary IMU
- DRDY and timestamping
- barometer / magnetometer ownership
- PPM / S.Bus / receiver protocols
- PWM and DShot
- safety switch / indicators / alarm
- watchdogs
- ADC / power sensing
- serial / GPS
- CAN
- I2C
- FRAM / persistent fault state
- production-test access
- connector and protection philosophy
- proposed A7/M4 peripheral ownership
- Odyssey-specific validation checklist
- staged bring-up order
- RasPilot feature decision matrix

Use this document before turning the historical reference into actual STM32MP157C pin assignments.

## Reproducibility and Maintenance

The platform dependency model is now:

```text
main repository commit
        +
pinned Buildroot submodule
        +
project BR2_EXTERNAL tree
        +
build / verification scripts
        |
        v
validated sdcard.img
```

Relevant documents:

- [Buildroot Submodule Workflow](odyssey-buildroot-submodule-workflow.md)
  - pinned upstream dependency
  - clone/update workflow
  - out-of-tree output
  - controlled Buildroot upgrades
- [Known-good Baseline](odyssey-known-good-baseline.md)
  - validated versions, boot expectations, and artifact hashes
- [Fresh-clone Reproduction](odyssey-fresh-clone-reproduction.md)
  - clean-machine reproduction procedure
- [BR2_EXTERNAL Migration](odyssey-buildroot-external-migration.md)
  - migration from the currently validated local Buildroot board files to a project-owned external tree

The Buildroot submodule itself is already established. The remaining reproducibility gate is to import the exact validated Odyssey files from the current WSL Buildroot tree, create the project defconfig, and prove a clean submodule + `BR2_EXTERNAL` build on hardware.

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

Submodule workflow
    = how the exact upstream Buildroot dependency is pinned and maintained

Known-good baseline
    = what exact combination has been validated

Fresh-clone procedure
    = proof that the repository is reproducible

Historical reference
    = what an earlier design actually did

Architecture comparison
    = which historical principles still map to STM32MP1

Reference mapping
    = how those functions could map into A7/M4 ownership and future hardware
```

Generated build directories must never be treated as authoritative documentation or persistent source.

Historical reference documents must also avoid converting old component choices into new requirements. RasPilot is primarily useful for architectural intent, deterministic I/O partitioning, safety boundaries, and hardware-interface patterns.

The long-term target is now concretely represented by the repository structure:

```text
third_party/buildroot/     pinned upstream dependency
        +
buildroot/                 project-owned customization
        +
scripts/                   controlled build / verification
        |
        v
output/odyssey/images/sdcard.img
        |
        v
validated Odyssey platform
        |
        v
measured A7/M4 flight-control architecture
```
