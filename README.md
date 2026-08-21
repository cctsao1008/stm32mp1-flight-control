# STM32MP1 Flight Control

Research and bring-up project for a flight-control platform based on the Seeed Studio Odyssey STM32MP157C.

The platform combines:

- STM32MP157C Cortex-A7 Linux domain
- STM32MP157C Cortex-M4 real-time domain
- Buildroot-based Linux image generation
- RasPilot v1.1 as a hardware/architecture reference
- future flight-control sensor, actuator, inter-processor, and safety work

## Buildroot platform

The Odyssey Buildroot platform is now reproduced from this repository using a pinned upstream Buildroot submodule plus a project-owned `BR2_EXTERNAL` tree:

```text
third_party/buildroot/     Buildroot 2026.05.1 submodule
buildroot/                 project BR2_EXTERNAL
scripts/                   build / clean / verify
output/odyssey/            generated output
```

Pinned Buildroot revision:

```text
cb857ba4c87a93e5265a9e4a3f32071abf39e14a
```

The clean repository build has passed hardware validation on the Odyssey board with Linux 6.6 and USB CDC ACM.

### Clone and build

```bash
git clone --recursive https://github.com/cctsao1008/stm32mp1-flight-control.git
cd stm32mp1-flight-control
./scripts/build.sh
./scripts/verify-image.sh
```

Validated runtime path:

```text
U-Boot 2021.10
    -> Linux 6.6.0
    -> root=PARTLABEL=rootfs rootwait
    -> rootfs
    -> STM32 USBPHYC
    -> DWC2 UDC
    -> ConfigFS CDC ACM
    -> /dev/ttyGS0
    -> Windows USB Serial Device (COM25)
    -> Buildroot login shell
```

Project-specific Buildroot changes belong under `buildroot/`; do not maintain duplicate changes inside the upstream Buildroot submodule or another upstream working tree.

## Documentation

See `docs/README.md` for the documentation index.

Key platform documents include:

- `docs/odyssey-known-good-baseline.md`
- `docs/odyssey-buildroot-submodule-workflow.md`
- `docs/odyssey-buildroot-build-flow.md`
- `docs/odyssey-buildroot-modification-map.md`
- `docs/odyssey-fresh-clone-reproduction.md`
- `docs/odyssey-usb-cdc-acm-bringup.md`
- `docs/raspilot-v1.1-hardware-reference.md`
- `docs/raspilot-vs-stm32mp1-architecture.md`
- `docs/raspilot-reference-mapping.md`

## Current platform baseline

```text
Board:          Seeed Studio Odyssey STM32MP157C
Buildroot:      2026.05.1
Linux:          6.6.0
U-Boot:         2021.10
TF-A:           v2.5
USB gadget:     CDC ACM over STM32MP15 FS OTG
Rootfs select:  PARTLABEL=rootfs
```

Byte-for-byte deterministic image generation is tracked separately from the validated functional platform baseline.
