# Embedded Driver Behavior Monitoring System

An end-to-end embedded system for detecting aggressive driving behavior using vehicle telemetry, IMU sensing, and edge machine learning inference on the ESP32.

The system integrates embedded firmware, machine learning, a mobile application, and a dashboard to provide real-time feedback and analysis of driving patterns.

---

## Overview

This project combines:

- Embedded systems (ESP32 + sensors)
- Signal processing and feature engineering
- Machine learning for behavior classification
- Edge deployment using TensorFlow Lite
- Mobile and dashboard interfaces for visualization

The goal is to build a complete pipeline from raw sensor data to real-time driver behavior insights.

---

## Repository Structure

embedded-driver-behavior-monitoring/

│
├── driver_app/ # Flutter mobile application

├── driver_dashboard/ # Dashboard for visualization and analytics

├── firmware/

│ └── esp32/ # ESP32 firmware for data collection and inference

├── hardware/ # Hardware design files and documentation

├── ml/ # Machine learning pipeline and model training

│ ├── notebooks/

│ └── README.md

---

## System Architecture

1. Sensors (IMU, vehicle telemetry) collect driving data  
2. ESP32 processes signals and extracts features  
3. Embedded ML model performs real-time inference  
4. Results are transmitted to:
   - mobile app (real-time feedback)
   - dashboard (analytics and visualization)

---

## Machine Learning Pipeline (ml/)

The ML module includes:

- Window-based segmentation of time-series data
- Feature extraction from vehicle signals
- Label generation for aggressive driving events
- Neural network training and evaluation
- TensorFlow Lite conversion
- INT8 quantization for embedded deployment
- Export to C header for firmware integration

Main notebook:
ml/notebooks/driver_behavior_training_pipeline.ipynb

---

## Firmware (firmware/esp32/)

The firmware handles:

- Sensor data acquisition (IMU, telemetry)
- Signal preprocessing
- Feature computation
- Running the TensorFlow Lite Micro model
- Communication with external interfaces

Designed for real-time inference on constrained hardware.

---

## Mobile Application (driver_app/)

Flutter-based mobile app that:

- Displays real-time driving feedback
- Shows alerts for aggressive behavior
- Provides user interaction and monitoring

---

## Dashboard (driver_dashboard/)

Dashboard for:

- Visualizing driving sessions
- Analyzing behavior trends
- Reviewing performance metrics

---

## Hardware (hardware/)

Contains:

- Sensor integration design
- Circuit and hardware setup documentation
- System assembly details

---

## Key Features

- Real-time aggressive driving detection  
- Edge ML inference on ESP32  
- Lightweight neural network model  
- TensorFlow Lite Micro deployment  
- Cross-platform interface (mobile + dashboard)  
- End-to-end pipeline from data to deployment  

---

## Technologies Used

- Python (NumPy, Pandas, Scikit-learn)
- TensorFlow / Keras
- TensorFlow Lite / TFLite Micro
- C/C++ (ESP32 firmware)
- Flutter (mobile app)
- Embedded systems + IMU sensors

---

## How to Use

### Machine Learning

1. Open the notebook:
   ml/notebooks/driver_behavior_training_pipeline.ipynb  
2. Run all cells sequentially  
3. Generate model artifacts for deployment  

---

### Firmware

1. Navigate to:
   firmware/esp32/  
2. Build and flash to ESP32  
3. Ensure model header file is included  

---

### Mobile App

1. Navigate to:
   driver_app/  
2. Run using Flutter:
   flutter run  

---

## Deployment Flow

1. Train model in Python (ml/)
2. Export TensorFlow Lite model
3. Quantize to INT8
4. Convert to C header
5. Integrate into ESP32 firmware
6. Run real-time inference on device

---

## Notes

- Feature preprocessing must match between training and firmware  
- Model input format must remain consistent  
- Quantized models require properly scaled inputs  

---

## Future Improvements

- Model optimization for lower latency  
- Improved feature engineering  
- Enhanced UI/UX for mobile and dashboard  
- Expanded dataset for better generalization  

---

## Author

Developed as an embedded + machine learning system integrating real-time sensing and edge inference.
