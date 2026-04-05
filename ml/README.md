# Machine Learning Pipeline – Driver Behavior Classification

This folder contains the complete machine learning pipeline used to train, evaluate, and export a driver behavior classification model for embedded deployment.

The workflow converts raw vehicle telemetry into a compact neural network model that can run on resource-constrained hardware such as the ESP32.

---

## Overview

The pipeline performs the following steps:

- Preprocess raw driving data
- Segment time-series data into fixed windows
- Extract statistical features from each window
- Generate labels for aggressive driving events
- Split dataset using trip-based grouping
- Train and evaluate a neural network model
- Convert the model to TensorFlow Lite
- Apply INT8 quantization for embedded use
- Export the model as a C header file

---

## Notebook
ml/notebooks/driver_behavior_training_pipeline.ipynb


This notebook contains the full end-to-end workflow, including:

- feature engineering  
- dataset construction  
- train/validation/test splitting  
- model training  
- evaluation metrics  
- TensorFlow Lite conversion  
- quantization  
- embedded export  

---

## Data Processing

### Window Segmentation

Driving data is divided into fixed-length windows:

- Window size: 100 samples (~5 seconds)
- Step size: 100 samples (non-overlapping)

Each window represents a short driving segment used for classification.

---

### Feature Extraction

Features are computed from:

- speed  
- engine RPM  
- throttle position  
- longitudinal acceleration  
- lateral acceleration  
- yaw rate  
- jerk  

Extracted statistics include:

- mean  
- standard deviation  
- minimum / maximum  
- percentiles  
- peak values  

---

### Labeling

Each window is labeled as:

- `0` → normal driving  
- `1` → aggressive driving  

A window is labeled aggressive if it contains events such as:

- harsh acceleration  
- harsh braking  
- harsh cornering  

---

## Dataset Splitting

Splitting is performed at the trip level using `GroupShuffleSplit` to avoid data leakage.

- Training set: ~60%  
- Validation set: ~20%  
- Test set: ~20%  

---

## Model Architecture

A compact neural network (MLP) is used:

- Input layer (feature vector)  
- Dense (16 units, ReLU)  
- Dropout (0.2)  
- Dense (8 units, ReLU)  
- Output (Sigmoid)  

---

## Training Configuration

- Optimizer: Adam  
- Loss: Binary cross-entropy  
- Batch size: 32  
- Early stopping enabled  
- Class weights applied to handle imbalance  

---

## Evaluation Metrics

Model performance is evaluated using:

- Accuracy  
- F1-score  
- Precision  
- Recall  
- ROC AUC  
- Average Precision  
- Confusion matrix  

---

## Exported Artifacts

After training, the following files are generated:

- `tiny_driver_mlp.keras` → trained Keras model  
- `scaler_params_small_mlp.csv` → feature scaling parameters  
- `tiny_driver_mlp_float.tflite` → float TensorFlow Lite model  
- `tiny_driver_mlp_int8.tflite` → quantized INT8 model  
- `tiny_driver_mlp_int8.h` → C header for embedded deployment  

---

## TensorFlow Lite Conversion

The trained model is converted to:

- float TFLite model  
- fully quantized INT8 model  

Quantization uses a representative dataset from the training data.

---

## Embedded Deployment

The INT8 model is converted to a C header file:

This notebook contains the full end-to-end workflow, including:

- feature engineering  
- dataset construction  
- train/validation/test splitting  
- model training  
- evaluation metrics  
- TensorFlow Lite conversion  
- quantization  
- embedded export  

---

## Data Processing

### Window Segmentation

Driving data is divided into fixed-length windows:

- Window size: 100 samples (~5 seconds)
- Step size: 100 samples (non-overlapping)

Each window represents a short driving segment used for classification.

---

### Feature Extraction

Features are computed from:

- speed  
- engine RPM  
- throttle position  
- longitudinal acceleration  
- lateral acceleration  
- yaw rate  
- jerk  

Extracted statistics include:

- mean  
- standard deviation  
- minimum / maximum  
- percentiles  
- peak values  

---

### Labeling

Each window is labeled as:

- `0` → normal driving  
- `1` → aggressive driving  

A window is labeled aggressive if it contains events such as:

- harsh acceleration  
- harsh braking  
- harsh cornering  

---

## Dataset Splitting

Splitting is performed at the trip level using `GroupShuffleSplit` to avoid data leakage.

- Training set: ~60%  
- Validation set: ~20%  
- Test set: ~20%  

---

## Model Architecture

A compact neural network (MLP) is used:

- Input layer (feature vector)  
- Dense (16 units, ReLU)  
- Dropout (0.2)  
- Dense (8 units, ReLU)  
- Output (Sigmoid)  

---

## Training Configuration

- Optimizer: Adam  
- Loss: Binary cross-entropy  
- Batch size: 32  
- Early stopping enabled  
- Class weights applied to handle imbalance  

---

## Evaluation Metrics

Model performance is evaluated using:

- Accuracy  
- F1-score  
- Precision  
- Recall  
- ROC AUC  
- Average Precision  
- Confusion matrix  

---

## Exported Artifacts

After training, the following files are generated:

- `tiny_driver_mlp.keras` → trained Keras model  
- `scaler_params_small_mlp.csv` → feature scaling parameters  
- `tiny_driver_mlp_float.tflite` → float TensorFlow Lite model  
- `tiny_driver_mlp_int8.tflite` → quantized INT8 model  
- `tiny_driver_mlp_int8.h` → C header for embedded deployment  

---

## TensorFlow Lite Conversion

The trained model is converted to:

- float TFLite model  
- fully quantized INT8 model  

Quantization uses a representative dataset from the training data.

---

## Embedded Deployment

The INT8 model is converted to a C header file:
xxd -i tiny_driver_mlp_int8.tflite > tiny_driver_mlp_int8.h


This allows the model to be:

- compiled directly into firmware  
- deployed on microcontrollers (e.g., ESP32)  
- executed using TensorFlow Lite Micro  

---

## Requirements

Install dependencies:
pip install numpy pandas scikit-learn tensorflow matplotlib seaborn


---

## How to Run

1. Open the notebook in Jupyter or Google Colab  
2. Run all cells from top to bottom  
3. Ensure dependencies are installed  
4. Exported models will be saved locally  

---

## Notes

- Feature scaling must match saved scaler parameters during deployment  
- Feature order must remain consistent between training and inference  
- Quantized models require properly scaled inputs  

---

## Purpose

This pipeline enables the development of a machine learning model that can be deployed directly on embedded systems for real-time driver behavior classification.

---