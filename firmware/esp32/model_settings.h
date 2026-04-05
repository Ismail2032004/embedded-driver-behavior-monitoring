#ifndef MODEL_SETTINGS_H
#define MODEL_SETTINGS_H

// Model input dimensions
#define NUM_FEATURES 6
#define INPUT_SIZE NUM_FEATURES

// Windowing used to compute engineered features
#define WINDOW_SIZE 40              // 2 seconds at 20 Hz
#define SAMPLE_RATE_HZ 20
#define SAMPLE_INTERVAL_MS 50

// Feature indices
// Order must match training exactly:
// accel_long_std, speed_std, accel_long_min,
// accel_long_max, yaw_max, accel_long_p90
#define IDX_ACCEL_LONG_STD  0
#define IDX_SPEED_STD       1
#define IDX_ACCEL_LONG_MIN  2
#define IDX_ACCEL_LONG_MAX  3
#define IDX_YAW_MAX         4
#define IDX_ACCEL_LONG_P90  5

// Normalization parameters from scaler
const float FEATURE_MEANS[NUM_FEATURES] = {
  0.324765f,
  1.790878f,
 -0.629786f,
  0.626424f,
  3.074747f,
  0.406486f
};

const float FEATURE_STDS[NUM_FEATURES] = {
  0.341399f,
  2.183612f,
  0.754018f,
  0.953253f,
  5.924069f,
  0.695420f
};

// Quantization parameters
#define INPUT_SCALE       0.06603f
#define INPUT_ZERO_POINT  13
#define OUTPUT_SCALE      0.00391f
#define OUTPUT_ZERO_POINT -128

// Classification threshold
#define AGGRESSIVE_THRESHOLD 0.5f

#endif // MODEL_SETTINGS_H