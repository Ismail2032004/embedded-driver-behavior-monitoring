# ESP32 Firmware – Driver Behavior Monitoring

## Overview
This firmware implements a real-time embedded driver behavior monitoring system on the ESP32. It integrates vehicle telemetry, inertial sensing, and an on-device machine learning model to classify driving behavior without cloud dependency.

The system performs continuous data acquisition, feature extraction over temporal windows, and local inference using a quantized TensorFlow Lite Micro model.

---

## System Architecture

Vehicle (OBD-II / CAN) + IMU (MPU6050)
            ↓
    Sensor Sampling (20 Hz)
            ↓
    Sliding Window Buffer (40 samples)
            ↓
    Feature Extraction (6 features)
            ↓
    Normalization + Quantization
            ↓
    TFLite Micro Inference
            ↓
    Behavior Classification (Normal / Aggressive)
            ↓
    BLE / MQTT Output

---

## Core Functionality

### 1. Data Acquisition
Vehicle telemetry via CAN/OBD-II:
- Speed
- RPM (collected but not used in final model)
- Throttle (collected but not used in final model)

IMU (MPU6050):
- Longitudinal acceleration
- Lateral acceleration
- Yaw rate (derived)

Sampling rate:
- 20 Hz (50 ms interval)

---

### 2. Windowing Strategy
- Fixed-size sliding window:
  - 40 samples (~2 seconds)
- Used to compute statistical descriptors of driving behavior

---

### 3. Feature Engineering

The deployed model uses 6 engineered features:

- accel_long_std → variability in longitudinal acceleration
- speed_std → speed fluctuation
- accel_long_min → maximum braking intensity
- accel_long_max → maximum acceleration intensity
- yaw_max → maximum turning intensity
- accel_long_p90 → high-percentile acceleration (robust to noise)

These features summarize driver behavior over the window.

---

### 4. Preprocessing

Normalization:
x_norm = (x - mean) / std

Defined in:
- model_settings.h

Quantization:
q = (x / scale) + zero_point

---

### 5. Machine Learning Model

- Model type: Feedforward Neural Network (MLP)
- Input size: 6 features

Architecture:
- Dense (16) + ReLU
- Dense (8) + ReLU
- Dense (1) + Sigmoid

Output:
- Probability of aggressive driving

Deployment:
- Quantized INT8 TensorFlow Lite model
- Stored in driver_behavior_model.h

---

### 6. Inference Pipeline

1. Collect 40 samples
2. Compute 6 features
3. Normalize features
4. Quantize to int8
5. Run inference
6. Apply threshold

label = (confidence >= 0.5) ? AGGRESSIVE : NORMAL;

---

### 7. Communication

BLE:
- Short-range communication
- Uses custom service and characteristic UUIDs

MQTT:
- Optional cloud streaming
- Used for logging and dashboard integration

---

### 8. Power and State Management

- Trip detection logic (start/stop based on movement)
- Idle timeout handling
- Designed for continuous embedded operation

---

## File Structure

esp32/
├── esp32_driver_monitor.ino
├── driver_behavior_model.h
├── model_settings.h

---

## Key Design Decisions

- Edge inference removes dependency on internet connectivity
- Feature-based model reduces computation compared to raw time-series models
- Quantized INT8 model enables real-time inference on ESP32
- Window-based analysis captures temporal driving patterns

---

## Notes

- RPM and throttle are collected but not used in the final deployed model
- Model expects engineered features, not raw sensor streams
- All credentials in the codebase are placeholders and should be configured locally

---

## Future Improvements

- Incorporate additional features such as throttle dynamics
- Extend to multi-class classification
- Adaptive thresholds based on driver profile
- OTA model updates