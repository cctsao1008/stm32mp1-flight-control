# RasPilot V1.1 Reference Mapping to STM32MP1

## 1. Purpose

This document maps RasPilot V1.1 hardware functions into the STM32MP1 flight-control project.

It is intended as a working engineering reference for answering questions such as:

- which RasPilot function should be retained conceptually
- whether the function belongs on A7/Linux or M4
- which STM32MP1 peripheral class is a likely fit
- what must be revalidated on the Odyssey carrier
- which legacy RasPilot implementation details should be discarded

Primary historical source:

```text
RASPILOTv1_1.pdf
```

Target platform references:

```text
Seeed ODYSSEY STM32MP157C
STM32MP157C SoC
Cortex-A7 x2 / Linux
Cortex-M4 real-time domain
```

This document is a **reference mapping**, not a pin-finalization document. Exact GPIO alternate functions, DMA channels, interrupt routing, pin conflicts, voltage domains, and connector assignments still require board-level validation against the Odyssey/STM32MP157C schematics and device tree.

---

## 2. Mapping Rules

The following rules are used throughout this document.

### Rule 1 — Preserve function, not historical component

Example:

```text
RasPilot: L3GD20
Project:  modern SPI IMU
```

The relevant concept is high-rate SPI inertial acquisition with hardware data-ready, not the specific L3GD20.

### Rule 2 — Timing-sensitive physical interfaces default to M4

Examples:

```text
IMU DRDY
RC frame capture
PWM / DShot
watchdog
safety input
power-fault response
```

### Rule 3 — Complex policy defaults to A7/Linux

Examples:

```text
mission
navigation
parameter database
logging
MAVLink
filesystem
networking
main ArduPilot integration
```

### Rule 4 — A7 sends intent; M4 owns final hardware timing

The boundary should use semantic messages rather than exposing waveform timing to Linux.

---

## 3. Top-Level Functional Mapping

| RasPilot function | Historical implementation | STM32MP1 target owner | Target concept | Priority |
|---|---|---|---|---|
| Linux flight stack | Raspberry Pi | A7 | ArduPilot / high-level flight stack | High |
| Deterministic I/O | STM32F10x | M4 | real-time sensor/RC/actuator/safety domain | High |
| Host/I/O communication | board-level buses | A7 + M4 | RPMsg/OpenAMP, SHM if required | High |
| Primary IMU | SPI sensors | M4 | modern external SPI IMU | High |
| Sensor DRDY | dedicated GPIO | M4 | EXTI/interrupt + timestamp | High |
| Barometer | SPI | M4 or A7 | lower-rate sensor; ownership measured | Medium |
| RC input | STM32 | M4 | UART/timer capture | High |
| PWM servo outputs | STM32 timers | M4 | timer/DMA actuator engine | High |
| DShot | not represented as modern baseline | M4 | timer/DMA protocol generation | High |
| Power sensing | STM32 ADC | M4 | ADC + thresholds + telemetry | High |
| Safety switch | discrete + STM32 | M4 | local safety state | High |
| Alarm/status LEDs | local hardware | M4 | deterministic indication | Medium |
| CAN | external interface | M4 or A7 | avionics bus depending stack ownership | Medium |
| External serial | UART connectors | M4/A7 split | GPS, RC, telemetry based on timing/policy | High |
| FRAM | SPI FRAM | TBD | optional safety-state persistence | Low/Medium |
| Production test pads | explicit pads | board-level | debug/testability plan | High for custom carrier |

---

## 4. Sensor Mapping

## 4.1 Primary IMU

### RasPilot reference

RasPilot shows SPI inertial sensors with chip selects and DRDY lines.

Historical examples:

```text
L3GD20
LSM303D
MPU-9250 / MPU6500 family
```

### STM32MP1 target

Recommended functional ownership:

```text
external SPI IMU
      |
      v
M4 SPI peripheral
      |
      +-- DRDY interrupt
      +-- timestamp
      +-- DMA where useful
      +-- sample health
      +-- calibration application
      v
RPMsg / SHM
      |
      v
A7 / ArduPilot
```

### Required validation

Before freezing an interface, verify:

```text
available SPI controller for M4
pinmux availability
chip-select GPIO
DRDY GPIO/EXTI ownership
DMA availability
interrupt latency
SPI electrical voltage
maximum practical SPI clock
connector length / signal integrity
sensor power domain
```

### Carry-forward decision

```text
SPI primary IMU            KEEP
hardware DRDY              KEEP
per-sensor CS              KEEP
legacy RasPilot sensor BOM DISCARD
```

---

## 4.2 Secondary IMU / Redundancy

RasPilot includes more than one inertial sensing option.

For the project, redundancy can be preserved architecturally through:

```text
IMU0 -> SPIx -> M4
IMU1 -> SPIy or shared SPI -> M4
```

If a shared SPI bus is used, independent chip-select and DRDY lines should be retained.

Open design questions:

```text
shared bus vs independent buses
sensor orientation diversity
power-domain isolation
failure containment
hot vs cold redundancy
sample-rate matching
```

---

## 4.3 Barometer

### RasPilot

MS5611-01BA on SPI.

### STM32MP1

The barometer does not normally impose the same hard timing requirements as the primary gyro path.

Possible ownership:

```text
Option A: M4
  unified sensor timestamping
  one sensor transport path

Option B: A7/Linux
  simpler driver reuse
  lower criticality
```

Recommendation for early bring-up:

> Validate on Linux first if convenient, then move to M4 only if the architecture benefits from centralized deterministic sensor acquisition.

---

## 4.4 Magnetometer

The historical LSM303D integrated accel/mag function should not dictate the new design.

A modern external magnetometer may use I2C or SPI and often does not need to share the high-rate IMU path.

Possible ownership:

```text
A7 initially
M4 later if unified sensor timestamp/health is desired
```

---

## 5. RC Input Mapping

## 5.1 PPM

RasPilot maps PPM input to a timer-capable STM32 pin.

Project treatment:

```text
legacy compatibility only
M4 timer input capture
```

Do not make PPM the primary design target unless required.

## 5.2 S.Bus

RasPilot includes:

```text
SBUS_INPUT
SBUS_OUTPUT
SBUS_OUTPUT_EN
```

Project mapping:

```text
receiver UART
   |
   v
M4 UART
   |
   +-- decode
   +-- frame timestamp
   +-- failsafe flag
   +-- link state
   v
A7 RC state packet
```

External inverter/level-conditioning requirements depend on the selected receiver electrical interface and must be verified independently.

## 5.3 Spektrum / DSM

Treat as optional compatibility support.

Target owner:

```text
M4 UART
```

## 5.4 Modern receiver protocols

The project should evaluate modern serial protocols rather than copying RasPilot's historical priorities.

The M4 abstraction should be protocol-neutral above the driver layer:

```text
struct rc_state {
    timestamp
    sequence
    channels[]
    link_quality
    failsafe_flags
}
```

---

## 6. Actuator Mapping

## 6.1 Servo PWM

RasPilot uses eight STM32 timer channels.

Project mapping:

```text
A7 control output
      |
      v
RPMsg actuator command
      |
      v
M4 actuator arbiter
      |
      v
TIM / DMA
      |
      v
PWM servo / ESC
```

Required M4 checks before output:

```text
A7 heartbeat valid
command sequence advances
command age within limit
arm state valid
mode allows actuator output
command range valid
local failsafe not active
```

## 6.2 DShot

RasPilot V1.1 predates the modern DShot-centric design point.

The STM32MP1 project should add DShot as a native M4 actuator protocol candidate.

Likely implementation resources:

```text
hardware timers
DMA
GPIO alternate functions
precise clock source
```

The A7/M4 interface should not change when switching from PWM to DShot; protocol generation remains M4-local.

---

## 7. Safety Mapping

## 7.1 Safety switch

RasPilot provides a physical safety switch and dedicated safety LED path.

Project mapping:

```text
physical switch
      |
      v
M4 GPIO
      |
      +-- debounce
      +-- local safety state
      +-- actuator authority gate
      v
A7 receives status
```

Linux may request transitions, but final output permission should be locally enforceable.

## 7.2 Safety indication

RasPilot uses local LED indication.

Project recommendation:

```text
M4 controls minimum safety indicator
A7 may control richer UI separately
```

Useful minimum states:

```text
BOOTING
SAFE
ARMED
A7 LOST
SENSOR FAULT
ACTUATOR FAULT
POWER FAULT
```

## 7.3 Alarm output

A simple buzzer/piezo path can remain useful for fault indication independent of a display or network connection.

Target owner:

```text
M4 for critical alarms
A7 may request noncritical patterns
```

---

## 8. Watchdog Mapping

RasPilot's separate STM32 provides natural separation from Linux.

The STM32MP1 implementation should recreate that separation logically:

```text
A7 heartbeat
    |
    v
M4 supervisor
    |
    +-- stale command detection
    +-- Linux heartbeat timeout
    +-- sensor freshness
    +-- RC validity
    +-- actuator inhibit
    v
hardware watchdog / safe output state
```

Define at least these timers:

```text
A7 heartbeat timeout
actuator-command timeout
RC frame timeout
IMU sample timeout
M4 internal loop deadline
```

Thresholds should be measured and specified later rather than guessed in this reference document.

---

## 9. Power-Sensing Mapping

RasPilot routes these classes of measurements to the STM32 I/O processor:

```text
battery voltage
battery current
5 V rail
servo rail
RSSI / analog inputs
```

Project mapping:

```text
ADC source
   |
   v
M4 ADC / external ADC
   |
   +-- filtering
   +-- plausibility
   +-- threshold state
   v
A7 telemetry/logging
```

### Recommended fault hierarchy

```text
warning threshold
critical threshold
immediate actuator-safety threshold
```

Not every analog threshold should directly trigger shutdown; the semantics must be defined per rail.

---

## 10. External Serial Mapping

RasPilot has two general serial ports, with one annotated as a default GPS port.

Suggested STM32MP1 ownership policy:

| Interface | Initial owner | Reason |
|---|---|---|
| GPS UART | A7 or M4 | depends on timestamping/PPS strategy |
| RC UART | M4 | deterministic frame/failsafe handling |
| telemetry UART | A7 | protocol complexity / MAVLink |
| debug UART | A7/Linux | system console |
| M4 debug UART | M4 if pins permit | real-time-domain diagnostics |

If GPS PPS precision matters, the PPS edge may be captured by M4 even if GPS message parsing remains on A7.

---

## 11. CAN Mapping

RasPilot exposes CAN-related signals.

For STM32MP1, CAN ownership depends on use case:

```text
DroneCAN sensor/actuator bus -> M4 may be attractive for deterministic I/O
high-level application CAN   -> A7 may be appropriate
```

Before assigning ownership, validate:

```text
STM32MP157C CAN/FDCAN peripheral availability
Odyssey pin exposure
transceiver presence
termination
voltage domain
device-tree ownership
M4 firmware support
Linux SocketCAN requirements
```

---

## 12. I2C Mapping

RasPilot uses I2C for external expansion and LED control.

Project recommendation:

```text
low-rate environmental/config sensors -> A7 acceptable
safety-critical management device      -> M4 if needed
primary high-rate IMU                   -> avoid I2C where SPI is available
```

I2C bus recovery behavior should be considered if external connectors are used.

---

## 13. FRAM / Persistent State Mapping

RasPilot includes FM25V01 SPI FRAM.

Potential project uses:

```text
M4 fault journal
watchdog reset counters
last shutdown reason
small immutable calibration record
actuator inhibit reason
```

Alternative storage options on STM32MP1 include:

```text
backup SRAM
Linux filesystem/eMMC
external FRAM
shared persistent structure with controlled handoff
```

No storage medium is selected by this mapping.

---

## 14. Production-Test Mapping

RasPilot exposes test access for boot pins, UART, CAN, analog, and power rails.

For a future custom STM32MP1 flight-control carrier, reserve test access for:

```text
SoC debug UART
M4 SWD/JTAG path
boot-mode signals
NRST
critical regulators
sensor supplies
CAN H/L
RC UART
actuator outputs
ADC measurement nodes
I2C/SPI diagnostics
```

Production-test coverage should be defined before PCB layout freeze.

---

## 15. Connector Mapping

RasPilot uses dedicated connectors for:

```text
SERIAL1
SERIAL2 / GPS
AUX ADC
PRESSURE
I2C
SAFETY
Spektrum/DSM
servo outputs
```

The new project should preserve **functional separation** but not necessarily the DF13 family or exact pin order.

Connector-selection criteria should include:

```text
locking behavior
size/weight
field serviceability
current rating
vibration resistance
keying
ESD exposure
availability
assembly process
```

---

## 16. Electrical-Protection Mapping

RasPilot repeatedly uses:

```text
series resistors
ESD diodes
ferrite/EMI components
level translators
local decoupling
separate power rails
```

These are not incidental details. A new flight-controller carrier should classify every external interface as electrically exposed and decide explicitly whether it requires:

```text
ESD protection
series damping
level conversion
common-mode/ferrite filtering
reverse protection
current limiting
hot-plug protection
```

---

## 17. A7/M4 Interface Mapping

The historical Raspberry Pi/STM32 boundary should become a structured software contract.

Recommended logical channels:

```text
sensor
rc
actuator
health
configuration
fault/event
```

### Sensor path

```text
M4 -> A7
```

Fields should include:

```text
sensor ID
sequence
sample timestamp
sample vector
status
calibration/version metadata
```

### Actuator path

```text
A7 -> M4
```

Fields should include:

```text
sequence
command timestamp
valid-until/freshness information
arm state
mode
actuator values
```

### Health path

Bidirectional:

```text
heartbeat
fault bitmap
watchdog state
power state
sensor freshness
actuator state
```

---

## 18. Peripheral Ownership Table

This is the recommended **initial** ownership model, subject to actual STM32MP157C/Odyssey pin availability.

| Peripheral class | A7 | M4 | Notes |
|---|---:|---:|---|
| Primary IMU SPI |  | X | deterministic acquisition |
| IMU DRDY GPIO |  | X | timestamp at interrupt |
| Secondary IMU |  | X | preferred if resources permit |
| Barometer | possible | possible | bring-up on Linux acceptable |
| Magnetometer | possible | possible | low rate |
| RC UART |  | X | failsafe/timing |
| PWM/DShot timer |  | X | actuator timing |
| Power ADC |  | X | local fault handling |
| Safety switch |  | X | actuator authority |
| Safety LED/buzzer |  | X | independent indication |
| MAVLink telemetry | X |  | high-level protocol |
| Storage/eMMC | X |  | Linux ownership |
| Ethernet/Wi-Fi | X |  | Linux |
| USB gadget | X |  | Linux console/debug |
| Main flight stack | X |  | ArduPilot |
| M4 debug SWD |  | X | development path |

---

## 19. Odyssey-Specific Validation Checklist

Before converting this reference mapping into actual pin assignments, verify the Odyssey board for each candidate interface.

### For every signal

```text
Is the STM32MP157 pin exposed on the carrier?
What voltage domain is it in?
Is the pin already used by eMMC, Ethernet, Wi-Fi, audio, display, camera, USB, or boot logic?
Which alternate functions are available?
Can the peripheral be assigned to M4?
Does Linux currently claim it in DT?
Is there a level shifter on the carrier?
Is the connector physically accessible?
```

### For M4-owned peripherals

```text
remove/disable Linux DT ownership
configure pinctrl/resource ownership
verify clocks/resets
verify interrupt routing
verify DMA if used
validate remoteproc startup
validate behavior when A7 restarts
```

---

## 20. Bring-Up Order Suggested by the Mapping

A practical sequence is:

```text
1. Linux validates each external sensor/interface individually
2. Establish M4 remoteproc/OpenAMP baseline
3. Move one IMU to M4
4. Verify DRDY timestamp and sustained sample rate
5. Stream samples to A7
6. Add RC input on M4
7. Add one actuator output on M4
8. Add actuator freshness timeout
9. Add power sensing
10. Add safety switch / local indication
11. Expand actuator channels
12. Measure latency/jitter/fault behavior
13. Only then consider moving control loops
```

This sequence uses Linux for fast hardware discovery while gradually establishing the deterministic M4 boundary.

---

## 21. RasPilot Feature Decision Matrix

| RasPilot feature | Decision | Reason |
|---|---|---|
| Linux + RT processor split | Keep | core architectural value |
| SPI IMUs | Keep | bandwidth/determinism |
| DRDY lines | Keep | precise sampling |
| STM32-timed actuators | Keep concept | move to M4 |
| STM32 RC handling | Keep concept | move to M4 |
| power monitoring in RT domain | Keep | safety relevance |
| physical safety switch | Keep concept | independent actuator authority |
| local safety LED/alarm | Keep minimal form | visible fault state |
| FRAM | Evaluate | useful but not automatically required |
| L3GD20 | Replace | obsolete/legacy |
| LSM303D | Replace | obsolete/legacy |
| MPU-9250 | Replace | historical sensor generation |
| STM32F1 | Replace | integrated M4 available |
| Raspberry Pi header as IPC | Replace | use on-chip IPC |
| PPM-first RC design | Deprioritize | legacy protocol |
| exact RasPilot connectors | Replace | new mechanical/electrical constraints |

---

## 22. Definition of Done for Hardware Mapping

This reference mapping becomes an actionable hardware design only after the following are complete:

```text
[ ] Odyssey exposed-pin inventory
[ ] M4-capable peripheral inventory
[ ] SPI/DRDY pin assignment
[ ] RC UART assignment
[ ] actuator timer/DMA assignment
[ ] ADC/power-sense assignment
[ ] safety GPIO assignment
[ ] CAN ownership decision
[ ] A7/M4 resource-ownership DT plan
[ ] connector/electrical protection plan
[ ] power-domain plan
[ ] latency and sample-rate budgets
[ ] failure-state definitions
```

Until then, this document intentionally remains at the functional-reference layer.

---

## 23. Final Position

RasPilot should influence this project primarily through these abstractions:

```text
Linux domain
  = rich flight stack and system services

real-time domain
  = precise physical I/O and safety boundary

inter-domain API
  = explicit, versioned, timestamped semantic contract
```

Everything below that abstraction — sensor model, connector family, external STM32, Raspberry Pi GPIO mapping, and legacy RC protocols — should be independently redesigned for STM32MP1.