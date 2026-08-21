# RasPilot V1.1 Hardware Reference

## 1. Purpose

This document records the RasPilot V1.1 hardware architecture as a **historical flight-controller reference** for the STM32MP1 flight-control project.

RasPilot is not treated as the target hardware architecture and its legacy sensors are not assumed to be suitable for a new design. Its value is the way it separates a Linux-capable Raspberry Pi from a dedicated STM32 I/O/safety processor and the concrete circuits used around sensors, RC input, actuator output, power monitoring, safety indication, and external interfaces.

Primary source used for this document:

```text
RASPILOTv1_1.pdf
```

The source schematic is eight pages. The descriptions below distinguish between **schematic facts** and **project interpretation** so that historical facts are not silently turned into design requirements.

---

## 2. High-Level Architecture

RasPilot V1.1 combines two processing domains:

```text
Raspberry Pi / Linux
        |
        | Raspberry Pi 40-pin interface
        | SPI / I2C / UART / GPIO
        v
RasPilot board
        |
        +-- onboard sensors
        +-- STM32F10x I/O processor
        +-- RC input
        +-- servo outputs
        +-- serial interfaces
        +-- analog sensing
        +-- safety switch / LEDs / alarm
        +-- power-domain supervision
```

The important architectural idea is that Linux is **not the only execution domain controlling the physical vehicle interfaces**. A separate STM32F10x device owns or participates in timing-sensitive I/O and safety-related functions.

That separation is the main reason RasPilot remains relevant to this project.

---

## 3. Schematic Page Map

| Page | Main content | Relevance |
|---|---|---|
| 1 | Raspberry Pi 40-pin connection, FRAM | Host interface and shared peripheral bus |
| 2 | Serial ports, I2C, analog pressure, auxiliary ADC | External avionics connectivity |
| 3 | Gyro, accel/mag, MPU, barometer | Sensor topology and shared SPI bus |
| 4 | LEDs, piezo alarm, safety switch | Human-visible safety state and alarm path |
| 5 | STM32F10x I/O processor, SWD/JTAG, Spektrum/DSM | Deterministic I/O domain |
| 6 | S.Bus in/out, PPM, RSSI, servo outputs | RC and actuator timing path |
| 7 | I/O power supply, power sensing, reset | Power-domain design and supervision |
| 8 | Production test and interconnect signals | Manufacturing and validation access |

---

## 4. Raspberry Pi Interface

### 4.1 40-pin GPIO header

The schematic connects the RasPilot board to the Raspberry Pi 40-pin expansion interface. Signals include standard Raspberry Pi functions and RasPilot-specific assignments layered onto GPIOs.

Notable signal groups visible on the schematic include:

```text
RPI-I2C_SDA
RPI-I2C_SCL
RPI-UART_TX
RPI-UART_RX
IO-RPI-SPI_MOSI
IO-RPI-SPI_MISO
IO-RPI-SPI_SCK
IO-RPI-SPI_NSS
sensor chip-select signals
sensor data-ready signals
ALARM
LED-RESET
```

The design therefore uses the Raspberry Pi expansion connector not only for generic GPIO but as a structured host-to-flight-controller interface.

### 4.2 Shared SPI path

The Raspberry Pi-side SPI bus is reused by several peripherals. The schematic shows common SCK/MOSI/MISO nets with separate chip selects for devices such as:

```text
GYRO_CS
ACCEL_MAG_CS
MPU_CS
BARO_CS
FRAM_CS
```

This is a conventional multi-slave SPI arrangement.

### 4.3 Data-ready lines

Dedicated interrupt/data-ready lines are present for multiple inertial sensors:

```text
GYRO_DRDY
ACCEL_DRDY
MAG_DRDY
MPU_DRDY
```

This is important because it avoids relying only on software polling to determine sample timing.

### 4.4 FRAM

Page 1 includes an FM25V01 FRAM device attached to the host-visible SPI bus with a dedicated `FRAM_CS`.

This suggests nonvolatile storage was considered valuable enough to justify a dedicated robust memory device separate from SD-card storage.

For this project, the architectural lesson is broader than the specific FRAM part: critical state, counters, calibration, or last-known safety data may deserve a storage path independent of the Linux filesystem.

---

## 5. External Serial Interfaces

Page 2 provides two serial connectors:

```text
SERIAL1
SERIAL2
```

The second connector is annotated as the default GPS port.

The design contains a TXS0108 level-translator block between logic domains for several UART-related signals.

External serial lines include filtering/protection components such as series resistors, ferrite/EMI components, and ESD parts.

### Architectural significance

The connector-level design is not simply MCU pins routed to headers. RasPilot explicitly treats external avionics ports as electrically exposed interfaces requiring:

- voltage-domain awareness
- ESD protection
- series impedance / EMI treatment
- connector-specific power distribution

This is directly reusable as a design principle even if all devices and connector families change.

---

## 6. I2C Interface

A dedicated external I2C connector is shown on page 2 using:

```text
RPI-I2C_SCL
RPI-I2C_SDA
```

The schematic includes series resistors and protection around this interface.

The I2C bus is also used internally for the LED driver on page 4.

### Project lesson

Shared I2C is suitable for low-rate management peripherals but should not automatically become the primary high-rate inertial sensor path in a new flight-control design. RasPilot itself already uses SPI for its primary inertial sensor set.

---

## 7. Analog Inputs

### 7.1 Auxiliary ADC

Page 2 provides two auxiliary ADC nets:

```text
IO_AUX_ADC1
IO_AUX_ADC2
```

They are routed to a dedicated external connector with filtering and protection.

### 7.2 Analog pressure input

An analog pressure connector is provided with a resistor divider. The schematic explicitly notes a divider intended to scale approximately 5 V to 3.3 V.

The analog signal appears as:

```text
PRESSURE_SENS
PRESSURE_SENS_IN
```

### 7.3 Power measurement ADCs

The STM32 I/O processor receives dedicated analog measurements including:

```text
BATT_VOLTAGE_SENS
BATT_CURRENT_SENS
VDD_5V_SENS
VDD_SERVO_SENS
RSSI_IN
```

This is an important architectural detail: the deterministic I/O controller is not limited to PWM generation. It also observes vehicle power and receiver-related analog state.

---

## 8. Onboard Sensors

Page 3 contains the main sensor subsystem.

### 8.1 L3GD20 gyro

The schematic labels the L3GD20 as a legacy gyro. It is connected to:

```text
SPI SCK
SPI MOSI
SPI MISO
GYRO_CS
GYRO_DRDY
```

The design note explicitly calls for a local 10 uF capacitor near the gyro.

### 8.2 LSM303D accel/mag

The LSM303D provides accelerometer/magnetometer functions and connects to the same host SPI bus with:

```text
ACCEL_MAG_CS
ACCEL_DRDY
MAG_DRDY
```

### 8.3 MPU-9250

The schematic includes an MPU-9250 block, noted together with MPU6500/9250 in the page annotation.

Relevant nets include:

```text
MPU_CS
MPU_DRDY
SPI SCK
SPI MOSI
SPI MISO
```

### 8.4 MS5611-01BA barometer

The MS5611-01BA barometer is also connected to the shared SPI bus through:

```text
BARO_CS
```

### 8.5 Sensor supply

The sensor devices are supplied from a dedicated rail:

```text
VDD_3V3_SENSORS
```

This separates sensor power naming and distribution from the general I/O rail.

### 8.6 What should and should not be carried forward

The exact sensors are historical parts. They should not define the new project sensor BOM.

The reusable design patterns are:

- dedicated sensor power domain
- SPI for high-rate sensors
- separate chip-select per sensor
- hardware DRDY lines
- local decoupling
- more than one inertial sensing option

---

## 9. Safety Indication and Alarm

Page 4 contains three distinct human/safety interfaces:

```text
LED subsystem
piezo alarm driver
safety switch
```

### 9.1 LEDs

The schematic contains RGB/status indication and separate I/O-driven LEDs. A TCA62724 I2C LED driver is used for one group.

Named signals include:

```text
IO-LED_AMBER
IO-LED_BLUE
IO-LED_SAFETY
LED-RESET
```

### 9.2 Piezo alarm

A dedicated LT3469-based alarm driver is controlled by:

```text
ALARM
```

The schematic note states that the alarm input should idle low to minimize power dissipation.

### 9.3 Safety switch

The external safety-switch connector includes:

```text
SAFETY
IO-LED_SAFETY
```

with resistor and ESD components.

### Architectural significance

RasPilot gives safety state a **physical user interface**, rather than treating arming/safety only as a software state in the Linux UI.

For an aircraft controller this is valuable: safety-critical state should have simple, deterministic, locally controlled indication.

---

## 10. STM32 I/O Processor

Page 5 centers on an STM32F10x RXT6-class device.

The schematic symbol is labeled:

```text
STM32F10XRXT6L
```

The MCU has an 8 MHz crystal, reset circuit, debug header, and a broad set of dedicated I/O assignments.

### 10.1 Main responsibilities visible from pin naming

The STM32 is connected to:

```text
8 actuator channels
PPM input
S.Bus input
S.Bus output
RSSI
battery voltage sensing
battery current sensing
5 V sensing
servo-rail sensing
pressure sensing
auxiliary ADC inputs
UART interfaces
CAN TX/RX
safety switch
status LEDs
Spektrum/DSM receiver input
Raspberry Pi SPI interface
```

This strongly establishes the STM32 as an I/O and supervision processor, not merely a bus bridge.

### 10.2 Timer allocation

The schematic explicitly documents timer allocation for actuator and RC signals:

```text
PA0  : TIM2_CH1 : IO-CH1
PA1  : TIM2_CH2 : IO-CH2
PB6  : TIM4_CH1 : IO-CH3
PB7  : TIM4_CH2 : IO-CH4
PA6  : TIM3_CH1 : IO-CH5
PA7  : TIM3_CH2 : IO-CH6
PB0  : TIM3_CH3 : IO-CH7
PB1  : TIM3_CH4 : IO-CH8
PA8  : TIM1_CH1 : PPM_IN
PA12 : TIM1_ETR : RSSI_IN
```

The exact use of `TIM1_ETR` for RSSI should be interpreted in the context of the original firmware/hardware implementation, but the timer map clearly shows deliberate hardware-resource planning.

### 10.3 Debug access

A compact ARM mini JTAG/SWD connector exposes signals including:

```text
SWDIO
SWCLK
SWO/TDO
RESET
VTREF
GND
```

Debug access is therefore part of the board architecture rather than an afterthought.

---

## 11. RC Receiver Interfaces

### 11.1 Spektrum / DSM

Page 5 has a dedicated Spektrum/DSM connector and a separately controlled 3.3 V receiver supply:

```text
VDD_3V3_SPEKTRUM
VDD_3V3_SPEKTRUM_EN
IO-USART1_RX
```

### 11.2 PPM

The schematic provides:

```text
PPM_INPUT
```

into a timer-capable STM32 pin.

### 11.3 S.Bus

Page 6 includes both:

```text
SBUS_INPUT
SBUS_OUTPUT
SBUS_OUTPUT_EN
```

A 74LVC2G240 device is used in this signal-conditioning path.

### 11.4 RSSI

Receiver signal-strength input is separately brought into the I/O processor as:

```text
RSSI_IN
```

### Architectural lesson

The RC path is owned close to the deterministic I/O domain. This avoids making Linux scheduler behavior part of the minimum viable receiver-to-actuator timing path.

---

## 12. Servo / Actuator Outputs

Page 6 provides eight output channels:

```text
IO-CH1
IO-CH2
IO-CH3
IO-CH4
IO-CH5
IO-CH6
IO-CH7
IO-CH8
```

These are generated directly from STM32 timer-capable pins according to the timer allocation on page 5.

The servo connector carries separate servo power and ground distribution. The design also senses the servo supply:

```text
VDD_SERVO
VDD_SERVO_SENS
```

### Architectural significance

This is one of the strongest RasPilot lessons for the STM32MP1 project:

```text
Linux flight stack
        |
        v
command interface
        |
        v
real-time processor
        |
        v
hardware timers
        |
        v
ESC / servo outputs
```

The Linux host does not need to bit-bang or directly schedule precise actuator pulse timing.

---

## 13. CAN

CAN-related signals appear throughout the schematic:

```text
IO-CAN_TX
IO-CAN_RX
CAN_H
CAN_L
```

The serial/GPS connector page also shows CAN-related lines routed in the external-interface area.

For the current project, CAN should be treated as an important external flight-control transport candidate, but the new board design should independently choose transceiver, termination, protection, and connector strategy.

---

## 14. Power Architecture

Page 7 is especially important because it shows that the I/O processor and sensors are designed around multiple named power domains rather than one undifferentiated supply.

Visible rails include:

```text
VDD_5V_IN
VDD_5V_BRICK
VDD_5V_PERIPH
VDD_3V3_SENSORS
IO-VDD_3V3
VDD_SERVO
RX-VDD_5V5
VDD_3V3_SPEKTRUM
```

The schematic notes a **dual supply from servo rail and power module rail** in the I/O power section.

It includes MIC5332 regulators, protection devices, diodes, fuses, filtering, and a power-good/reset timing circuit.

### 14.1 Reset timing

The schematic states:

```text
Reset output 1s / uF
10n = 10ms delay from power good to reset de-asserted.
```

This is evidence that reset sequencing was deliberately tied to supply validity.

### 14.2 Vehicle power measurements

The I/O MCU receives measurements of:

```text
battery voltage
battery current
5 V rail
servo rail
```

This allows the non-Linux domain to make decisions using physical power state.

### Project significance

For an A7+M4 architecture, power supervision should not automatically live only in Linux. Brownout, actuator-rail loss, receiver-rail anomalies, and watchdog actions may need deterministic handling in the M4 domain.

---

## 15. Production Test Design

Page 8 explicitly includes production test pads and manufacturing notes.

Named test signals include:

```text
IO-BOOT1
IO-BOOT0
S1TX
S1RX
S2TX
S2RX
ADC_PR
CAN_H
CAN_L
VDD_5V_BRICK
VDD_5V_IN
VDD_SERVO
GND
```

The schematic also includes PCB production constraints such as minimum drill, trace width, copper spacing, board thickness, grid rules, and signoff checks.

### Architectural lesson

A flight-control board should be designed with test access from the start. Bringing out boot-mode, UART, CAN, ADC, and power rails makes factory test and field diagnostics substantially easier.

---

## 16. Functional Partitioning Summary

A useful abstraction of RasPilot is:

```text
Raspberry Pi / Linux
    |
    +-- high-level flight software
    +-- direct access to onboard SPI sensors
    +-- storage / networking / Linux ecosystem
    |
    v
STM32F10x I/O processor
    |
    +-- RC inputs
    +-- S.Bus / PPM
    +-- actuator timing
    +-- serial/CAN related I/O
    +-- analog power sensing
    +-- safety switch
    +-- status indication
    +-- reset / local hardware supervision
```

The exact historical firmware partition may contain details not recoverable from the schematic alone. The above summary therefore describes what the hardware wiring clearly enables, not every software responsibility of the original RasPilot firmware.

---

## 17. What RasPilot Demonstrates Well

RasPilot is especially useful as evidence for these design principles:

1. **Linux and deterministic I/O should be separated.**
2. **Actuator timing belongs close to hardware timers.**
3. **RC reception should not depend on Linux scheduling.**
4. **Power sensing and safety state deserve local deterministic access.**
5. **Primary inertial sensors benefit from SPI and DRDY lines.**
6. **External avionics ports need electrical protection and filtering.**
7. **Physical safety indication remains useful even with a rich Linux UI.**
8. **Production test points are part of the architecture, not cleanup work.**

---

## 18. What Should Not Be Copied Blindly

The following are historical implementation choices and should not become project requirements merely because RasPilot used them:

- L3GD20
- LSM303D
- MPU-9250 / MPU6500-era sensor selection
- MS5611 as the default pressure sensor
- STM32F1-class I/O processor
- Raspberry Pi-specific GPIO numbering
- DF13 connector family
- legacy PPM/Spektrum emphasis
- exact LED/alarm circuitry
- exact power-regulator parts

The new project should preserve **architectural intent** while selecting components appropriate to STM32MP157C, the target sensor rates, modern receiver protocols, and current availability.

---

## 19. Reference Status

For this project, RasPilot V1.1 is classified as:

```text
Historical architecture reference : YES
I/O/safety partitioning reference : YES
Connector/circuit pattern reference: YES
Primary sensor BOM reference       : NO
Drop-in hardware design            : NO
Target flight-control architecture : NO
```

The next documents build on this hardware reference by comparing RasPilot with the STM32MP1 A7/M4 architecture and by mapping individual RasPilot functions into project interfaces.