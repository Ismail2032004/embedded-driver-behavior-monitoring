# Hardware Design – Embedded Driver Behavior Monitoring System

## Overview
This directory contains the complete hardware design package for the embedded driver behavior monitoring system. The PCB is designed to acquire vehicle telemetry, inertial data, and positioning information, and to support real-time embedded machine learning inference on an ESP32.

The system integrates automotive interfacing, sensing, communication, and power management into a compact embedded platform suitable for in-vehicle deployment.

---

## System Architecture

The hardware is organized into the following functional subsystems:

- Power Input and Protection (12V automotive input)
- Power Regulation (5V and 3.3V rails)
- Microcontroller (ESP32-WROOM-32E)
- CAN Interface (vehicle communication)
- IMU (motion sensing)
- GPS module (location tracking)
- GSM module (optional remote communication)
- USB interface (programming and debugging)

---

## Key Components

### Microcontroller
- ESP32-WROOM-32E
- Provides:
  - Wi-Fi and BLE connectivity
  - Processing for real-time inference
  - Peripheral interfacing (UART, I2C, SPI, GPIO)

---

### CAN Interface
- SN65HVD232 CAN transceiver
- Enables communication with vehicle ECUs via CAN bus
- Supports OBD-II data acquisition

---

### IMU
- MPU6050 (accelerometer + gyroscope)
- Used to derive:
  - Longitudinal acceleration
  - Lateral acceleration
  - Yaw rate

---

### GPS
- NEO-6M module
- Provides:
  - Position
  - Speed (fallback/validation)
  - Time synchronization

---

### GSM Module
- SIM7670E
- Enables:
  - Remote telemetry transmission
  - Cloud connectivity (optional)

---

### Power System

#### 12V Input with Protection
- Automotive battery input
- Includes:
  - Reverse polarity protection
  - Transient suppression
  - Filtering

#### 5V Regulation
- Buck converter (LM2596)
- Steps down 12V → 5V

#### 3.3V Regulation
- LDO regulator (AMS1117-3.3)
- Supplies ESP32 and logic components

---

### USB and Programming
- USB-to-UART bridge (CP2102)
- Supports:
  - Firmware upload
  - Serial debugging
- Auto-reset and boot circuitry included

---

## Directory Structure
hardware/
├── schematics/
│ └── esp32_driver_monitor_schematic.pdf
│
├── pcb/
│ ├── gerbers/
│ │ └── esp32_driver_monitor_gerbers.zip
│ ├── pick_and_place/
│ │ └── pick_and_place.csv
│ └── project_files/
│ └── *.json (EasyEDA design files)
│
├── bom/
│ └── bill_of_materials.csv
│
├── renders/
│ ├── 2d_layout.png
│ └── 3d_view.png
│
└── README.md

---

## Manufacturing

The PCB can be fabricated and assembled using standard PCB services such as:

- JLCPCB  
- PCBWay  

### Required Files
- Gerber files → for PCB fabrication  
- Pick-and-place file → for automated assembly  
- BOM → for component sourcing  

---

## Assembly Notes

- Ensure correct polarity for:
  - Electrolytic capacitors
  - Diodes
  - Voltage regulators
- Verify orientation of:
  - ESP32 module
  - IMU (MPU6050)
  - CAN transceiver
- USB and power sections should be tested independently before full system bring-up

---

## Design Considerations

- Designed for automotive voltage conditions (12V input variability)
- Modular subsystem layout for easier debugging
- Separation of analog (power) and digital sections
- Compact footprint for in-vehicle installation
- Supports both local (BLE) and remote (MQTT via GSM/Wi-Fi) communication

---

## Limitations

- GSM module increases power consumption significantly
- GPS accuracy depends on antenna placement
- No hardware-level isolation on CAN interface
- Thermal performance depends on enclosure design

---

## Future Improvements

- Add CAN isolation for improved robustness
- Integrate more efficient DC-DC converter
- Reduce board size through component optimization
- Add onboard storage (e.g., SD card)
- Improve EMI shielding for automotive environments

---

## Notes

- Design files were created using EasyEDA
- All files required for fabrication and assembly are included
- The hardware is tightly coupled with the firmware and ML pipeline in this repository