# STM32MP1 Flight Control

Experimental flight-control platform work based on the Seeed Studio Odyssey STM32MP157C, using the STM32MP1 heterogeneous architecture:

- Cortex-A7 / Linux for platform services, configuration, logging, telemetry, and development-time sensor bring-up
- Cortex-M4 for deterministic sensor acquisition, timestamping, actuator timing, and future hard real-time control functions

## Buildroot platform

The validated Odyssey platform is built from:

```text
third_party/buildroot/     pinned upstream Buildroot 2026.05.1 submodule
buildroot_external/        project-owned BR2_EXTERNAL tree
scripts/                   build / clean / verify wrappers
output/odyssey/            generated output
```

The project-owned `buildroot_external/` tree is authoritative for Odyssey-specific Buildroot inputs. Do not maintain duplicate project changes inside the upstream Buildroot submodule.

Standard build workflow:

```bash
git clone --recursive https://github.com/cctsao1008/stm32mp1-flight-control.git
cd stm32mp1-flight-control
./scripts/build.sh
./scripts/verify-image.sh
```

The project defconfig enables Buildroot reproducible-build mode. `scripts/build.sh` derives `SOURCE_DATE_EPOCH` from the current repository commit unless explicitly supplied by the caller. See `docs/odyssey-reproducible-build.md` for the deterministic-build policy and qualification procedure.

## Validated platform baseline

Current validated functional baseline:

```text
Buildroot 2026.05.1
Linux 6.6.0
U-Boot 2021.10
TF-A v2.5
root=PARTLABEL=rootfs rootwait
```

The USB-C device path is validated through:

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

## Flight-control development direction

The near-term development sequence is:

```text
platform baseline
    -> deterministic/reproducible build
    -> Odyssey/RasPilot I/O resource mapping
    -> Cortex-A7/Linux sensor bring-up
    -> measured sample-rate / latency / jitter characterization
    -> Cortex-M4 resource ownership and deterministic acquisition
    -> A7/M4 IPC
    -> AHRS / control integration
```

RasPilot v1.1 is used as a hardware/reference architecture source; it is not assumed to define the final STM32MP1 flight-control architecture.
