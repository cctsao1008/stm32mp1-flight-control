# RasPilot V1.1 vs STM32MP1 Flight-Control Architecture

## 1. Purpose

This document compares the historical RasPilot V1.1 architecture with the intended STM32MP157C heterogeneous flight-control architecture.

The goal is not to reproduce RasPilot. The goal is to identify which architectural ideas remain useful when moving from:

```text
Raspberry Pi + external STM32F10x I/O processor
```

to:

```text
STM32MP157C
  +-- Cortex-A7 x2 / Linux
  +-- Cortex-M4 / deterministic real-time domain
```

Source-derived RasPilot facts are based primarily on `RASPILOTv1_1.pdf`. STM32MP1 capability statements are based on the STM32MP157C and Odyssey documentation already used by this project. Project recommendations are explicitly marked as design interpretation rather than historical RasPilot facts.

---

## 2. Architectural Equivalence at a Glance

The most useful conceptual mapping is:

```text
RasPilot V1.1                         STM32MP1 project
-------------------------------      -------------------------------
Raspberry Pi / Linux                 Cortex-A7 x2 / Linux
          |                                    |
          | board-level buses                   | OpenAMP / RPMsg / SHM
          v                                    v
STM32F10x I/O processor              Cortex-M4 real-time domain
          |                                    |
          v                                    v
RC / PWM / ADC / safety / I/O        sensor / actuator / safety I/O
```

The critical difference is physical integration.

RasPilot crosses a **board-level processor boundary**. The STM32MP1 project crosses an **on-chip heterogeneous-core boundary**.

This reduces some electrical complexity but does not eliminate the need to define a strict semantic boundary between Linux and the real-time domain.

---

## 3. Processing-Domain Comparison

| Function | RasPilot | STM32MP1 project direction |
|---|---|---|
| High-level flight stack | Raspberry Pi / Linux | Cortex-A7 / Linux |
| Deterministic I/O processor | STM32F10x | Integrated Cortex-M4 |
| Interprocessor boundary | board-level GPIO/SPI/UART style interfaces | OpenAMP/RPMsg plus shared memory where justified |
| Sensor timing | host SPI plus DRDY; some I/O through STM32 | M4 preferred for high-rate deterministic acquisition |
| Actuator generation | STM32 hardware timers | M4 hardware timers / DMA-capable peripherals |
| RC input | STM32 | M4 |
| Safety logic | dedicated STM32-visible signals and safety switch | M4-local safety state and watchdog boundary |
| Navigation / mission | Linux host | A7 Linux / ArduPilot |
| Logging / network | Linux host | A7 Linux |

---

## 4. The Most Important RasPilot Lesson

RasPilot demonstrates that a Linux flight stack does not need to directly own every timing-sensitive physical interface.

The useful conceptual chain is:

```text
mission / navigation / high-level control
                |
                v
        Linux flight stack
                |
        semantic command/state API
                |
                v
 deterministic I/O/control domain
                |
       hardware-timed interfaces
                |
                v
      sensors / RC / ESC / servo
```

For STM32MP1, the M4 provides a much cleaner place to implement the deterministic domain than an external STM32F1 because it is integrated into the same SoC.

---

## 5. Sensor Architecture

### 5.1 RasPilot

The RasPilot schematic shows multiple inertial sensors and a barometer on a shared SPI bus. It uses per-device chip selects and dedicated data-ready signals for several sensors.

Representative nets include:

```text
GYRO_CS
ACCEL_MAG_CS
MPU_CS
BARO_CS
GYRO_DRDY
ACCEL_DRDY
MAG_DRDY
MPU_DRDY
```

The host-facing Raspberry Pi SPI bus is therefore an important part of the original sensor path.

### 5.2 STM32MP1 direction

The STM32MP1 project should keep the **SPI + DRDY principle**, but the preferred high-rate path is:

```text
IMU
  |
  | SPI + DRDY
  v
Cortex-M4
  |
  +-- precise timestamp
  +-- sample validation
  +-- optional filtering / preprocessing
  |
  v
A7 Linux / ArduPilot
```

### 5.3 Why this is better suited to the new SoC

Moving acquisition into the M4 removes Linux scheduling jitter from the immediate sample-capture path and makes timestamps refer more directly to the physical interrupt/sample event.

This is a project design choice, not a claim about the original RasPilot firmware.

---

## 6. AHRS and Estimation Boundary

RasPilot does not imply that the entire AHRS/EKF must live in the dedicated I/O processor.

For the STM32MP1 project, a useful initial split is:

```text
M4
  - sensor acquisition
  - timestamping
  - calibration application
  - health checks
  - optional deterministic filtering

A7 / ArduPilot
  - main EKF
  - AHRS state used by the flight stack
  - navigation estimation
  - parameter management
  - logging
```

A later experiment may move selected estimation work to the M4, but that should be justified by measured latency, bandwidth, CPU load, and fault-containment benefit rather than by architectural aesthetics.

---

## 7. Actuator Output Architecture

### 7.1 RasPilot

The STM32F10x owns eight timer-mapped actuator channels:

```text
IO-CH1 .. IO-CH8
```

The schematic explicitly maps these outputs onto STM32 timer channels.

### 7.2 STM32MP1

The corresponding preferred architecture is:

```text
A7 flight-control command
        |
        v
M4 command qualification
        |
        +-- range checking
        +-- freshness checking
        +-- mode / arming check
        +-- failsafe arbitration
        |
        v
hardware timer / PWM / DShot engine
        |
        v
ESC / servo
```

The M4 should own the final timing contract to the actuator hardware.

### 7.3 Semantic interface implication

The A7/M4 API should exchange **actuator intent**, not waveform edges.

Bad boundary:

```text
A7 tells M4 every PWM transition
```

Better boundary:

```text
A7 sends normalized/qualified actuator commands + sequence/timestamp
M4 generates the physical protocol deterministically
```

---

## 8. RC Input Architecture

### 8.1 RasPilot

The historical design supports:

```text
PPM
S.Bus input
S.Bus output
Spektrum/DSM
RSSI
```

These terminate in the STM32 I/O domain.

### 8.2 STM32MP1 direction

The same architectural principle should be retained:

```text
receiver
   |
   v
M4
   |
   +-- protocol decode
   +-- frame timestamp
   +-- failsafe detection
   +-- signal-quality state
   |
   v
A7
```

A7 should receive decoded RC state, not be responsible for meeting low-level pulse/serial timing.

### 8.3 Modernization

The exact protocol priorities should be updated for current hardware. Legacy PPM and Spektrum support may be optional, while modern serial receiver protocols may deserve higher priority.

---

## 9. Safety Architecture

### 9.1 RasPilot

RasPilot includes:

```text
SAFETY
IO-LED_SAFETY
ALARM
status LEDs
power measurements
reset supervision
```

The hardware therefore gives the dedicated I/O domain access to safety-relevant physical state.

### 9.2 STM32MP1 direction

This concept should become stronger, not weaker.

The M4 safety boundary should be designed so it can make a limited set of deterministic decisions even if Linux stalls or crashes.

Candidate M4-local responsibilities:

```text
actuator command timeout
RC loss detection
A7 heartbeat timeout
sensor freshness checks
actuator inhibit / safe shutdown
watchdog servicing policy
local safety switch
local status indication
brownout / power-state response
```

The M4 should not independently invent high-level flight behavior, but it should be able to prevent stale or invalid Linux commands from reaching actuators.

---

## 10. Watchdog Philosophy

RasPilot's external MCU architecture inherently separates Linux from some physical I/O timing.

STM32MP1 provides an opportunity to formalize this into a watchdog hierarchy:

```text
hardware watchdog
      |
      v
M4 safety supervisor
      |
      +-- monitors A7 heartbeat
      +-- monitors command freshness
      +-- monitors local I/O health
      |
      v
actuator authority
```

The key principle is that the entity deciding whether an actuator command is still valid should not depend solely on the same Linux scheduling domain that produced the command.

---

## 11. A7/M4 Communication

### 11.1 RasPilot boundary

RasPilot uses physical processor-to-processor connectivity across the Raspberry Pi header and related board nets.

### 11.2 STM32MP1 boundary

The preferred baseline is:

```text
OpenAMP / RPMsg
```

for control/status messaging, with shared memory reserved for high-rate bulk data when measurements show RPMsg copies/latency to be a limitation.

### 11.3 Message classes

A practical interface should separate message semantics:

```text
CONTROL
  actuator command
  mode / arm state

SENSOR
  IMU sample blocks
  timestamps
  health flags

RC
  channel state
  frame age
  failsafe state

HEALTH
  heartbeat
  watchdog state
  fault bitmap
  power status

CONFIG
  rate configuration
  calibration data
  interface version
```

### 11.4 Required metadata

Every time-sensitive message should be designed around explicit fields such as:

```text
version
sequence number
source timestamp
receive age / freshness
validity flags
fault flags
```

The protocol should avoid loosely structured text or implicit timing assumptions.

---

## 12. Power Monitoring

### 12.1 RasPilot

The STM32 I/O processor sees battery voltage/current and supply-rail measurements.

### 12.2 STM32MP1

The M4 should similarly have direct access to the most safety-relevant power measurements where hardware permits.

Suggested priority:

```text
battery voltage
battery current
actuator/servo rail
receiver rail
critical sensor rail
board 5 V / main supply health
```

Linux may log and display these values, but local detection of catastrophic rail loss should not require Linux to be healthy.

---

## 13. Status LEDs, Alarm, and Safety Switch

RasPilot provides explicit local hardware indication.

The STM32MP1 project should preserve this concept through a minimal M4-controlled physical status interface.

Recommended state classes include:

```text
SAFE / inhibited
ARMED
M4 alive
A7 heartbeat lost
sensor fault
actuator fault
critical power fault
```

Exact colors and patterns are implementation details; the architectural requirement is independent indication from Linux UI availability.

---

## 14. Storage and FRAM

RasPilot includes SPI FRAM.

The new project should not copy this automatically, but it raises a useful question: what data must survive a Linux/filesystem failure?

Possible M4-side persistent data candidates:

```text
boot/fault counters
watchdog reset reason
last critical fault bitmap
small calibration integrity data
last actuator-shutdown reason
```

Whether FRAM, backup SRAM, eMMC, or another medium is used should be decided separately.

---

## 15. Production-Test Philosophy

RasPilot exposes boot, UART, CAN, analog, and power signals for production testing.

The same philosophy should be applied to any future STM32MP1 flight-control carrier or sensor/actuator board.

Recommended test-access classes:

```text
M4 SWD
A7/SoC debug UART
boot-mode straps
critical power rails
CAN
RC UART
actuator test outputs
sensor SPI testability
reset/watchdog state
```

The exact Odyssey development board already provides some debug facilities, but a future flight-specific carrier will need its own DFT plan.

---

## 16. Integration Advantage of STM32MP1

Moving from Raspberry Pi + STM32F1 to STM32MP1 A7 + M4 has several structural advantages:

### 16.1 Lower interprocessor physical complexity

No external processor-to-processor level shifting is required for the A7/M4 boundary because both cores are inside the SoC.

### 16.2 Shared memory

High-rate data can be exchanged without external SPI/UART serialization when necessary.

### 16.3 Tighter timestamping architecture

The M4 can capture hardware events and expose timestamped state to Linux through a defined IPC path.

### 16.4 Better fault-domain design opportunity

Resource isolation and explicit peripheral ownership can make the M4 a more formal deterministic domain.

### 16.5 Lower component count

The external I/O MCU disappears as a separate component.

---

## 17. New Risks Introduced by Integration

Integration also creates risks that RasPilot's physically separate MCU naturally avoided.

### 17.1 Shared SoC failure modes

A severe SoC-level power, clock, reset, or thermal problem can affect both A7 and M4.

### 17.2 Resource ownership complexity

Peripherals must be carefully assigned to Linux or M4. Accidental dual ownership is unacceptable.

### 17.3 IPC dependency

A7/M4 correctness now depends on OpenAMP/RPMsg/shared-memory configuration and lifecycle management.

### 17.4 Reset coordination

Restarting Linux must not unintentionally leave actuators under stale authority.

These issues must be explicitly tested rather than assumed away.

---

## 18. Recommended Initial Functional Split

For the first serious STM32MP1 flight-control baseline:

### Cortex-A7 / Linux

```text
ArduPilot
main EKF / AHRS
attitude / position control initially
navigation / mission
MAVLink
logging
parameter management
network / storage
user-facing diagnostics
```

### Cortex-M4

```text
high-rate IMU acquisition
sensor DRDY handling
timestamping
sensor health / freshness
RC decoding
actuator protocol generation
actuator command freshness enforcement
watchdog / heartbeat monitoring
local safety state
critical power monitoring
local status indication
```

### Experimental migration candidates

```text
rate-loop control
selected filtering
limited AHRS preprocessing
control allocation
```

These should move only after measurement demonstrates value.

---

## 19. Suggested A7/M4 Data Contracts

### Sensor packet

```text
header
interface_version
sequence
sample_timestamp
sensor_id
accel[3]
gyro[3]
temperature
status_flags
```

### Actuator command packet

```text
header
interface_version
sequence
command_timestamp
valid_until
arm_state
mode
actuator_count
command[]
```

### RC state packet

```text
header
sequence
frame_timestamp
channel_count
channels[]
rssi/link_quality
failsafe_flags
```

### Health packet

```text
header
sequence
m4_uptime
a7_heartbeat_age
sensor_fault_bitmap
power_fault_bitmap
actuator_fault_bitmap
watchdog_state
```

These are architectural sketches, not frozen protocol definitions.

---

## 20. Comparison Summary

| Topic | RasPilot principle | STM32MP1 project decision |
|---|---|---|
| Linux host | High-level stack | Keep on A7 |
| Dedicated deterministic processor | External STM32F10x | Use integrated M4 |
| Sensor SPI | Yes | Keep, prefer M4 ownership |
| DRDY | Yes | Keep |
| Actuator timing | STM32 timers | M4 timers / DMA |
| RC timing | STM32 | M4 |
| Safety switch | Local hardware | Keep concept |
| Power sensing | STM32-visible | Keep concept on M4 |
| Status indication | Local LEDs/alarm | Keep minimal M4-controlled path |
| FRAM | Present | Evaluate, do not assume |
| IPC | board-level | RPMsg / SHM |
| Legacy sensors | Historical | Replace |
| External I/O MCU | Required | Eliminated by M4 integration |

---

## 21. Architectural Position

The project should regard RasPilot as evidence that the following pattern is practical:

> A rich Linux flight stack can coexist with a smaller deterministic domain that owns the physical timing and safety boundary.

STM32MP1 lets that idea be implemented more tightly:

```text
A7 = complexity, ecosystem, navigation, flight-stack integration
M4 = determinism, timing, actuator authority, local safety
```

The project should preserve that division of *responsibility* without preserving RasPilot's old components or exact buses.