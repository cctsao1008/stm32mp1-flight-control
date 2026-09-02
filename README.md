# STM32MP1 Flight Control

Experimental flight-control platform based on the Seeed Studio Odyssey STM32MP157C and the STM32MP1 heterogeneous architecture:

- Cortex-A7 / Linux for platform services, configuration, logging, telemetry, and development-time sensor bring-up
- Cortex-M4 for deterministic sensor acquisition, timestamping, actuator timing, and hard real-time control functions

## System partition

```text
Cortex-A7 / Linux
    platform services
    configuration
    logging
    telemetry
    sensor integration
          |
          | IPC / shared platform resources
          v
Cortex-M4
    deterministic acquisition
    timestamping
    actuator timing
    real-time control
          |
          v
Sensors / Actuators
```

The architecture separates Linux-side platform services from deterministic MCU-side control responsibilities while using the shared STM32MP1 device as one flight-control platform.

## Buildroot platform

The Odyssey platform is built from:

```text
third_party/buildroot/     pinned upstream Buildroot 2026.05.1 submodule
buildroot_external/        project-owned BR2_EXTERNAL tree
scripts/                   build / clean / verify wrappers
output/odyssey/            generated output
```

The project-owned `buildroot_external/` tree is authoritative for Odyssey-specific Buildroot inputs. Project changes are kept outside the upstream Buildroot submodule.

Standard build workflow:

```bash
git clone --recursive https://github.com/cctsao1008/stm32mp1-flight-control.git
cd stm32mp1-flight-control
./scripts/build.sh
./scripts/verify-image.sh
```

The project defconfig enables Buildroot reproducible-build mode. `scripts/build.sh` derives `SOURCE_DATE_EPOCH` from the repository commit unless explicitly supplied by the caller.

See `docs/odyssey-reproducible-build.md` for the deterministic-build policy and qualification procedure.

## Platform baseline

```text
Buildroot 2026.05.1
Linux 6.6.0
U-Boot 2021.10
TF-A v2.5
root=PARTLABEL=rootfs rootwait
```

The USB-C device path is:

```text
STM32MP15 USB FS PA11/PA12
    -> USBPHYC
    -> DWC2 UDC
    -> ConfigFS CDC ACM
    -> /dev/ttyGS0
    -> Buildroot getty/login shell
    -> Windows USB Serial Device
```

Detailed platform documentation is indexed under `docs/README.md`.

## Hardware reference

RasPilot v1.1 is used as a hardware and architecture reference for I/O-resource study on the STM32MP1 platform.
