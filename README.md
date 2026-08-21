# STM32MP1 Flight Control

Heterogeneous flight-control architecture on STM32MP1, using Cortex-A7/Linux for ArduPilot and Cortex-M4 for deterministic sensing, inner-loop control, actuator I/O, and safety.

## Overview

This project explores how flight-control responsibilities can be partitioned across the heterogeneous processing domains of the STM32MP1 family.

The Cortex-A7 domain runs Linux and hosts the high-level ArduPilot flight stack. The Cortex-M4 domain provides the deterministic real-time path for time-critical sensing, control, actuator output, and safety functions.

The goal is not simply to run ArduPilot on another board. The project focuses on the boundary between a feature-rich Linux flight stack and a deterministic real-time execution domain.

## Architecture

```text
                         STM32MP157C

        +-------------------------------------------+
        |            Cortex-A7 x2 / Linux           |
        |                                           |
        |  ArduPilot                                |
        |  - EKF / AHRS                             |
        |  - attitude / position control            |
        |  - navigation / mission                   |
        |  - MAVLink / logging / parameters         |
        +---------------------+---------------------+
                              |
                     A7 <-> M4 interface
                     OpenAMP / RPMsg
                              |
        +---------------------v---------------------+
        |              Cortex-M4 / RT               |
        |                                           |
        |  - high-rate IMU acquisition              |
        |  - precise sensor timestamping            |
        |  - filtering / inertial preprocessing     |
        |  - deterministic inner-loop control       |
        |  - PWM / DShot / actuator I/O             |
        |  - watchdog / safety handling             |
        +---------------------+---------------------+
                              |
                  +-----------+-----------+
                  |           |           |
                 IMU         RC        ESC / Servo
```

## Processing Boundary

| Domain | Primary responsibilities |
| --- | --- |
| Cortex-A7 / Linux | ArduPilot, EKF/AHRS, attitude and position control, navigation, mission logic, MAVLink, logging, parameter management |
| Cortex-M4 / real-time | Sensor acquisition and timestamping, high-rate preprocessing, deterministic inner-loop execution, actuator timing, watchdog and safety functions |

The exact boundary is intentionally measurable rather than assumed. Functions may move between A7 and M4 when timing, latency, control-bandwidth, or maintainability measurements justify the change.

## Design Goals

- Keep the fast sensor-to-actuator path deterministic.
- Use the M4 domain for work with hard timing requirements.
- Keep complex and rapidly evolving flight-stack functionality on Linux where practical.
- Maintain a small, explicit semantic interface between A7 and M4.
- Measure end-to-end latency, jitter, deadline margin, and fault behavior instead of relying on nominal timing alone.
- Preserve compatibility with upstream ArduPilot wherever the architecture allows it.
- Support modern external SPI IMUs instead of depending on legacy onboard sensors.

## Initial Platform

- **SoC:** STM32MP157C
- **Development board:** Seeed Studio ODYSSEY-STM32MP157C
- **Application domain:** Cortex-A7 x2 running Linux
- **Real-time domain:** Cortex-M4
- **Flight stack:** ArduPilot
- **Inter-processor communication:** OpenAMP / RPMsg, with shared memory where appropriate
- **Primary sensing:** modern external SPI IMU

## Buildroot Platform Structure

Upstream Buildroot is pinned as a Git submodule while Odyssey-specific changes remain project-owned through `BR2_EXTERNAL`:

```text
third_party/buildroot/     upstream Buildroot submodule
buildroot/                 project BR2_EXTERNAL tree
scripts/                   build / clean / verification wrappers
output/                    generated output, ignored by Git
```

The current submodule is pinned to Buildroot `2026.05.1`:

```text
cb857ba4c87a93e5265a9e4a3f32071abf39e14a
```

Clone with the dependency initialized:

```bash
git clone --recursive https://github.com/cctsao1008/stm32mp1-flight-control.git
```

or initialize it later with:

```bash
git submodule update --init --recursive
```

The exact validated Odyssey board files still need to be imported from the current WSL Buildroot working tree before `BR2_EXTERNAL` is declared authoritative.

## RasPilot Reference

RasPilot V1.1 is used as a historical and optional hardware reference.

Its original architecture combined a Raspberry Pi/Linux flight stack with an STM32F103 I/O and failsafe processor. This project revisits the same Linux/real-time partitioning problem using the heterogeneous A7 + M4 architecture of STM32MP1.

The original RasPilot sensors are treated as legacy reference devices rather than the primary sensor set for this project.

## Engineering Focus

The most important questions are architectural rather than computational:

- What is the minimum useful A7/M4 interface?
- Which control functions actually benefit from deterministic M4 execution?
- How much latency and jitter are removed by moving physical I/O out of Linux?
- Where is the practical knee point for IMU, control-loop, and actuator update rates?
- Can the M4 domain maintain deterministic safety behavior when the Linux domain stalls, restarts, or fails?

## Documentation

Platform bring-up and Buildroot documentation is maintained under [`docs/`](docs/README.md).

Recommended starting points:

- [Buildroot Build Flow](docs/odyssey-buildroot-build-flow.md)
- [Buildroot Modification Map](docs/odyssey-buildroot-modification-map.md)
- [Buildroot Submodule Workflow](docs/odyssey-buildroot-submodule-workflow.md)
- [Known-good Baseline](docs/odyssey-known-good-baseline.md)
- [Fresh-clone Reproduction](docs/odyssey-fresh-clone-reproduction.md)
- [BR2_EXTERNAL Migration Plan](docs/odyssey-buildroot-external-migration.md)
- [USB CDC ACM Bring-up](docs/odyssey-usb-cdc-acm-bringup.md)
- [DEVBOOT FAT Partition](docs/odyssey-devboot-fat-partition.md)
- [RasPilot V1.1 Hardware Reference](docs/raspilot-v1.1-hardware-reference.md)
- [RasPilot vs STM32MP1 Architecture](docs/raspilot-vs-stm32mp1-architecture.md)
- [RasPilot Reference Mapping](docs/raspilot-reference-mapping.md)

## References

- [Seeed Studio ODYSSEY-STM32MP157C](https://wiki.seeedstudio.com/ODYSSEY-STM32MP157C/)
- [STM32MP157C](https://www.st.com/en/microcontrollers-microprocessors/stm32mp157c.html)
- [STM32CubeMP1](https://github.com/STMicroelectronics/STM32CubeMP1)
- [ArduPilot](https://github.com/ArduPilot/ardupilot)
- [Buildroot](https://github.com/buildroot/buildroot)
- [RasPilot Hardware](https://github.com/raspilot/Hardware/tree/RASPILOT_V1)
- [RasPilot Documentation](https://github.com/raspilot/docs)
