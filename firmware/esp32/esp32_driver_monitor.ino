/**
 * @file main.cpp
 * @brief Real-Time Driver Behavior Classification System
 * @author Ismail Adam - Ashesi University
 * @date 2026
 * 
 * @details
 * Embedded ML system for classifying driver behavior (aggressive/normal)
 * using CAN bus telemetry, IMU sensors, and GPS location tracking.
 * 
 * Hardware:
 * - ESP32-WROOM-32 (240MHz, 520KB SRAM, 4MB Flash)
 * - MPU6050 IMU (I2C: SDA=21, SCL=22)
 * - NEO-6M GPS (UART: RX=26, TX=27)
 * - SN65HVD230 CAN Transceiver (TX=16, RX=17)
 * - SIM7670E GSM Module
 * 
 * Features:
 * - TensorFlow Lite INT8 quantized model (6 engineered features from a 40-sample window)
 * - Standard OBD-II PID queries (Mode 01: Speed, RPM, Throttle)
 * - MQTT telemetry over WiFi/LTE
 * - BLE fallback for offline operation
 * - Deep sleep power management
 */

// ============================================================================
// INCLUDES
// ============================================================================
#include <Wire.h>
#include <WiFiClientSecure.h>
#include <PubSubClient.h>
#include <TinyGPSPlus.h>
#include <ArduinoJson.h>
#include <HTTPClient.h>
#include <math.h>
#include <string.h>
#include "driver/twai.h"
#include "esp_sleep.h"
#include "esp_wifi.h"

// TensorFlow Lite Micro
#include "tensorflow/lite/micro/micro_interpreter.h"
#include "tensorflow/lite/micro/micro_mutable_op_resolver.h"
#include "tensorflow/lite/schema/schema_generated.h"

// Project headers
#include "driver_behavior_model.h"
#include "model_settings.h"

// BLE (NimBLE stack)
#include <NimBLEDevice.h>

// ============================================================================
// CONFIGURATION
// ============================================================================

// WiFi Credentials
const char* WIFI_SSID     = "YOUR_SSID";
const char* WIFI_PASSWORD = "YOUR_PASSWORD";

// MQTT Broker (HiveMQ Cloud)
const char* MQTT_HOST     = "YOUR_BROKER.hivemq.cloud";
const int   MQTT_PORT     = 8883;
const char* MQTT_USER     = "YOUR_USERNAME";
const char* MQTT_PASSWORD = "YOUR_PASSWORD";
const char* DRIVER_ID     = "driver_001";

// Pin Definitions
#define CAN_TX_PIN          16
#define CAN_RX_PIN          17
#define GPS_RX_PIN          26
#define GPS_TX_PIN          27
#define MPU_SDA_PIN         21
#define MPU_SCL_PIN         22

// I2C Addresses
#define MPU6050_ADDR        0x68

// Timing Parameters
#define SAMPLE_RATE_HZ      20
#define SAMPLE_INTERVAL_MS  (1000 / SAMPLE_RATE_HZ)
#define WINDOW_SIZE         40      // 2 seconds @ 20Hz
#define INFERENCE_OVERLAP   20      // 50% overlap = 1Hz classification
#define OBD_QUERY_INTERVAL_MS 100   // Query OBD every 100ms

// Power Management
#define TRIP_END_TIMEOUT_MS      900000UL    // 15 minutes idle
#define SLEEP_CHECK_INTERVAL_US  30000000ULL // 30 seconds

// GPS Fallback
#define GPS_TIMEOUT_MS           20000  // 20s before IP fallback
#define IP_LOCATION_INTERVAL_MS  30000  // Update IP location every 30s

// BLE UUIDs
#define BLE_SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define BLE_CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"

// Raw signal channels retained for windowed feature extraction
#define RAW_CHANNELS        6
#define RAW_IDX_SPEED       0
#define RAW_IDX_RPM         1
#define RAW_IDX_THROTTLE    2
#define RAW_IDX_LONG_ACC    3
#define RAW_IDX_LAT_ACC     4
#define RAW_IDX_YAW_RATE    5

// ============================================================================
// GLOBAL STATE
// ============================================================================

// RTC Memory (survives deep sleep)
RTC_DATA_ATTR bool    wasAsleep      = false;
RTC_DATA_ATTR uint8_t sleepWakeCount = 0;

// Sensor Data
struct SensorData {
    float speed_kmh;
    float rpm;
    float throttle_pct;
    float long_acc;      // m/s²
    float lat_acc;       // m/s²
    float yaw_rate;      // deg/s
    float gps_lat;
    float gps_lon;
    bool  gps_valid;
    bool  using_ip_location;
};
SensorData sensors = {0};

// MPU6050 Calibration
struct MPUCalibration {
    float accX_offset, accY_offset, accZ_offset;
    float gyroX_offset, gyroY_offset, gyroZ_offset;
};
MPUCalibration mpu_cal = {0};

// EMA Filter State (alpha = 0.1)
#define EMA_ALPHA 0.1f
float ema_long_acc = 0.0f;
float ema_lat_acc  = 0.0f;
float ema_yaw_rate = 0.0f;

// Sliding Window Buffer
float window_buffer[WINDOW_SIZE][RAW_CHANNELS];
int   window_index            = 0;
bool  window_full             = false;
int   samples_since_inference = 0;

// Trip State
bool     trip_active      = false;
uint32_t trip_start_ms    = 0;
uint32_t last_activity_ms = 0;
uint32_t last_sample_ms   = 0;
uint32_t last_publish_ms  = 0;
uint32_t last_obd_query_ms = 0;

// GPS State
uint32_t gps_start_time_ms = 0;
uint32_t last_ip_check_ms  = 0;

// Classification Results
int   current_label      = 0;  // 0 = Normal, 1 = Aggressive
float current_confidence = 0.0f;

// Latency Tracking (median of last 20 samples)
uint32_t latency_samples[20];
int      latency_count        = 0;
uint32_t inference_latency_ms = 0;

// TensorFlow Lite Objects
const tflite::Model*      tfl_model       = nullptr;
tflite::MicroInterpreter* tfl_interpreter = nullptr;
TfLiteTensor*             tfl_input       = nullptr;
TfLiteTensor*             tfl_output      = nullptr;

constexpr int kTensorArenaSize = 12288;  // 12KB
static uint8_t tensor_arena[kTensorArenaSize];

// Network Objects
WiFiClientSecure wifi_client;
PubSubClient     mqtt_client(wifi_client);
TinyGPSPlus      gps;

// BLE Objects
NimBLEServer*         bleServer         = nullptr;
NimBLECharacteristic* bleCharacteristic = nullptr;
bool                  bleConnected      = false;

// MQTT Topics
char MQTT_TOPIC_TELEMETRY[64];
char MQTT_TOPIC_TRIP[64];

// ============================================================================
// FUNCTION PROTOTYPES
// ============================================================================
void setupMPU6050();
void setupGPS();
void setupCAN();
void setupTFLite();
void setupWiFi();
void setupMQTT();
void setupBLE();

void updateIMU();
void updateGPS();
void updateOBD();
void runInference();
void addSampleToWindow(float spd, float r, float thr, float la, float lat, float yr);

void publishTelemetry();
void publishTripEvent(const char* event_type);
void publishBLE();

bool reconnectMQTT();
void checkTripEnd();

float computeMean(const float* data, int n);
float computeStd(const float* data, int n);
float computeMin(const float* data, int n);
float computeMax(const float* data, int n);
float computeMaxAbs(const float* data, int n);
float computePercentile(const float* data, int n, float percentile);
void  extractWindowFeatures(float features[NUM_FEATURES]);

// ============================================================================
// MPU6050 IMU
// ============================================================================

const float ACCEL_SCALE = 16384.0;  // ±2g
const float GYRO_SCALE  = 131.0;    // ±250 deg/s
const int   CALIB_SAMPLES = 500;

/**
 * @brief Write to MPU6050 register
 */
bool mpu_writeRegister(uint8_t reg, uint8_t value) {
    Wire.beginTransmission(MPU6050_ADDR);
    Wire.write(reg);
    Wire.write(value);
    return (Wire.endTransmission(true) == 0);
}

/**
 * @brief Read raw sensor data from MPU6050
 */
bool mpu_readRaw(int16_t& accX, int16_t& accY, int16_t& accZ,
                 int16_t& gyX,  int16_t& gyY,  int16_t& gyZ) {
    Wire.beginTransmission(MPU6050_ADDR);
    Wire.write(0x3B);  // ACCEL_XOUT_H register
    if (Wire.endTransmission(false) != 0) return false;
    
    Wire.requestFrom(MPU6050_ADDR, (uint8_t)14, (uint8_t)true);
    if (Wire.available() != 14) return false;
    
    accX = (Wire.read() << 8) | Wire.read();
    accY = (Wire.read() << 8) | Wire.read();
    accZ = (Wire.read() << 8) | Wire.read();
    Wire.read(); Wire.read();  // Skip temperature
    gyX  = (Wire.read() << 8) | Wire.read();
    gyY  = (Wire.read() << 8) | Wire.read();
    gyZ  = (Wire.read() << 8) | Wire.read();
    
    return true;
}

/**
 * @brief Calibrate MPU6050 (device must be stationary)
 */
void mpu_calibrate() {
    Serial.println("[MPU] Calibrating (keep device still)...");
    delay(3000);
    
    long sumAX = 0, sumAY = 0, sumAZ = 0;
    long sumGX = 0, sumGY = 0, sumGZ = 0;
    int goodSamples = 0;
    
    int16_t ax, ay, az, gx, gy, gz;
    for (int i = 0; i < CALIB_SAMPLES; i++) {
        if (mpu_readRaw(ax, ay, az, gx, gy, gz)) {
            sumAX += ax; sumAY += ay; sumAZ += az;
            sumGX += gx; sumGY += gy; sumGZ += gz;
            goodSamples++;
        }
        delay(5);
    }
    
    if (goodSamples == 0) {
        Serial.println("[MPU] ERROR: Calibration failed");
        while (1) delay(1000);
    }
    
    // Expect: X=0g, Y=0g, Z=+1g (flat orientation)
    mpu_cal.accX_offset  = sumAX / (float)goodSamples;
    mpu_cal.accY_offset  = sumAY / (float)goodSamples;
    mpu_cal.accZ_offset  = (sumAZ / (float)goodSamples) - ACCEL_SCALE;
    mpu_cal.gyroX_offset = sumGX / (float)goodSamples;
    mpu_cal.gyroY_offset = sumGY / (float)goodSamples;
    mpu_cal.gyroZ_offset = sumGZ / (float)goodSamples;
    
    Serial.println("[MPU] Calibration complete");
}

/**
 * @brief Initialize MPU6050
 */
void setupMPU6050() {
    Wire.begin(MPU_SDA_PIN, MPU_SCL_PIN);
    Wire.setClock(100000);
    delay(100);
    
    // Wake up MPU6050
    if (!mpu_writeRegister(0x6B, 0x00)) {
        Serial.println("[MPU] ERROR: Wake-up failed");
        while (1) delay(1000);
    }
    delay(100);
    
    // Configure: ±2g accel, ±250 deg/s gyro
    mpu_writeRegister(0x1C, 0x00);  // Accel range
    mpu_writeRegister(0x1B, 0x00);  // Gyro range
    delay(100);
    
    Serial.println("[MPU] Initialized");
    mpu_calibrate();
}

/**
 * @brief Update IMU readings with EMA filtering
 */
void updateIMU() {
    int16_t ax, ay, az, gx, gy, gz;
    if (!mpu_readRaw(ax, ay, az, gx, gy, gz)) return;
    
    // Convert to physical units (m/s², deg/s)
    float raw_long = ((ay - mpu_cal.accY_offset) / ACCEL_SCALE) * 9.81f;
    float raw_lat  = ((ax - mpu_cal.accX_offset) / ACCEL_SCALE) * 9.81f;
    float raw_yaw  = (gz - mpu_cal.gyroZ_offset) / GYRO_SCALE;
    
    // Apply EMA low-pass filter
    ema_long_acc = EMA_ALPHA * raw_long + (1.0f - EMA_ALPHA) * ema_long_acc;
    ema_lat_acc  = EMA_ALPHA * raw_lat  + (1.0f - EMA_ALPHA) * ema_lat_acc;
    ema_yaw_rate = EMA_ALPHA * raw_yaw  + (1.0f - EMA_ALPHA) * ema_yaw_rate;
    
    sensors.long_acc = ema_long_acc;
    sensors.lat_acc  = ema_lat_acc;
    sensors.yaw_rate = ema_yaw_rate;
}

// ============================================================================
// GPS WITH IP FALLBACK
// ============================================================================

/**
 * @brief Initialize GPS module
 */
void setupGPS() {
    Serial2.begin(9600, SERIAL_8N1, GPS_RX_PIN, GPS_TX_PIN);
    Serial.println("[GPS] Initialized (searching for satellites...)");
    gps_start_time_ms = millis();
}

/**
 * @brief Get location via IP geolocation API (fallback)
 */
void getIPLocation() {
    if (WiFi.status() != WL_CONNECTED) return;
    
    HTTPClient http;
    http.begin("http://ip-api.com/json/?fields=status,lat,lon,city,country");
    
    if (http.GET() == 200) {
        StaticJsonDocument<512> doc;
        if (deserializeJson(doc, http.getString()) == DeserializationError::Ok) {
            if (strcmp(doc["status"], "success") == 0) {
                sensors.gps_lat = doc["lat"];
                sensors.gps_lon = doc["lon"];
                sensors.gps_valid = true;
                sensors.using_ip_location = true;
                
                Serial.printf("[GPS] IP Fallback: %.6f, %.6f (%s, %s)\n",
                             sensors.gps_lat, sensors.gps_lon,
                             doc["city"].as<const char*>(),
                             doc["country"].as<const char*>());
            }
        }
    }
    http.end();
}

/**
 * @brief Update GPS fix or fallback to IP location
 */
void updateGPS() {
    while (Serial2.available() > 0) {
        gps.encode(Serial2.read());
    }
    
    if (gps.location.isValid()) {
        sensors.gps_lat = gps.location.lat();
        sensors.gps_lon = gps.location.lng();
        sensors.gps_valid = true;
        sensors.using_ip_location = false;
    } else {
        sensors.gps_valid = false;
        
        // Fallback to IP location after timeout
        if (millis() - gps_start_time_ms > GPS_TIMEOUT_MS) {
            if (millis() - last_ip_check_ms > IP_LOCATION_INTERVAL_MS) {
                last_ip_check_ms = millis();
                getIPLocation();
            }
        }
    }
}

// ============================================================================
// OBD-II CAN BUS (STANDARD PIDs)
// ============================================================================

/**
 * @brief Initialize CAN bus in listen-only mode
 */
void setupCAN() {
    twai_general_config_t g_config = TWAI_GENERAL_CONFIG_DEFAULT(
        (gpio_num_t)CAN_TX_PIN, (gpio_num_t)CAN_RX_PIN, TWAI_MODE_NORMAL
    );
    twai_timing_config_t  t_config = TWAI_TIMING_CONFIG_500KBITS();
    twai_filter_config_t  f_config = TWAI_FILTER_CONFIG_ACCEPT_ALL();
    
    if (twai_driver_install(&g_config, &t_config, &f_config) != ESP_OK) {
        Serial.println("[CAN] ERROR: Driver install failed");
        return;
    }
    
    if (twai_start() != ESP_OK) {
        Serial.println("[CAN] ERROR: Start failed");
        return;
    }
    
    Serial.println("[CAN] Initialized (500 kbps)");
}

/**
 * @brief Send OBD-II Mode 01 PID request
 * @param pid Parameter ID (e.g., 0x0D = vehicle speed)
 */
void obd_sendRequest(uint8_t pid) {
    twai_message_t request = {
        .identifier = 0x7DF,  // OBD-II functional broadcast
        .data_length_code = 8,
        .data = {0x02, 0x01, pid, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA}
    };
    request.extd = 0;
    request.rtr  = 0;
    
    twai_transmit(&request, pdMS_TO_TICKS(10));
}

/**
 * @brief Decode OBD-II PID response
 * @param msg CAN message (expected ID: 0x7E8-0x7EF)
 */
void obd_decodeResponse(const twai_message_t& msg) {
    // Format: [Length, 0x41, PID, Data...]
    if (msg.data_length_code < 3) return;
    if (msg.data[1] != 0x41) return;  // Mode 01 response
    
    uint8_t pid = msg.data[2];
    
    switch (pid) {
        case 0x0D:  // Vehicle Speed (km/h)
            sensors.speed_kmh = msg.data[3];
            break;
            
        case 0x0C:  // Engine RPM
            sensors.rpm = ((msg.data[3] << 8) | msg.data[4]) / 4.0f;
            break;
            
        case 0x11:  // Throttle Position (%)
            sensors.throttle_pct = (msg.data[3] * 100.0f) / 255.0f;
            break;
    }
}

/**
 * @brief Query OBD-II PIDs and process responses
 */
void updateOBD() {
    uint32_t now = millis();
    
    // Send PID requests at intervals
    if (now - last_obd_query_ms >= OBD_QUERY_INTERVAL_MS) {
        last_obd_query_ms = now;
        obd_sendRequest(0x0D);  // Speed
        delay(5);
        obd_sendRequest(0x0C);  // RPM
        delay(5);
        obd_sendRequest(0x11);  // Throttle
    }
    
    // Process all pending responses
    twai_message_t msg;
    while (twai_receive(&msg, pdMS_TO_TICKS(0)) == ESP_OK) {
        if (msg.identifier >= 0x7E8 && msg.identifier <= 0x7EF) {
            obd_decodeResponse(msg);
        }
    }
}

// ============================================================================
// TENSORFLOW LITE INFERENCE
// ============================================================================

/**
 * @brief Initialize TensorFlow Lite model
 */
void setupTFLite() {
    Serial.println("[TFLite] Loading model...");
    
    tfl_model = tflite::GetModel(driver_behavior_model_data);
    if (tfl_model->version() != TFLITE_SCHEMA_VERSION) {
        Serial.printf("[TFLite] ERROR: Schema mismatch (%d vs %d)\n",
                     tfl_model->version(), TFLITE_SCHEMA_VERSION);
        while (1) delay(1000);
    }
    
    // Register only required ops
    static tflite::MicroMutableOpResolver<8> resolver;
    resolver.AddFullyConnected();
    resolver.AddReshape();
    resolver.AddLogistic();
    resolver.AddQuantize();
    resolver.AddDequantize();
    resolver.AddMul();
    resolver.AddAdd();
    resolver.AddSub();
    
    static tflite::MicroInterpreter static_interpreter(
        tfl_model, resolver, tensor_arena, kTensorArenaSize
    );
    tfl_interpreter = &static_interpreter;
    
    if (tfl_interpreter->AllocateTensors() != kTfLiteOk) {
        Serial.println("[TFLite] ERROR: Tensor allocation failed");
        while (1) delay(1000);
    }
    
    tfl_input  = tfl_interpreter->input(0);
    tfl_output = tfl_interpreter->output(0);
    
    Serial.printf("[TFLite] Model loaded (arena: %d bytes)\n",
                 tfl_interpreter->arena_used_bytes());
}

/**
 * @brief Normalize and quantize features to INT8
 */
void normalizeAndQuantize(float features[NUM_FEATURES], int8_t* out) {
    for (int i = 0; i < NUM_FEATURES; i++) {
        // StandardScaler normalization
        float norm = (features[i] - FEATURE_MEANS[i]) / FEATURE_STDS[i];
        
        // Quantize to INT8
        float q = (norm / INPUT_SCALE) + INPUT_ZERO_POINT;
        out[i] = (int8_t)constrain(q, -128.0f, 127.0f);
    }
}

/**
 * @brief Compute arithmetic mean for a fixed-size float array
 */
float computeMean(const float* data, int n) {
    if (n <= 0) return 0.0f;
    float sum = 0.0f;
    for (int i = 0; i < n; i++) sum += data[i];
    return sum / (float)n;
}

/**
 * @brief Compute population standard deviation for a fixed-size float array
 */
float computeStd(const float* data, int n) {
    if (n <= 0) return 0.0f;
    float mean = computeMean(data, n);
    float sum_sq = 0.0f;
    for (int i = 0; i < n; i++) {
        float d = data[i] - mean;
        sum_sq += d * d;
    }
    return sqrtf(sum_sq / (float)n);
}

/**
 * @brief Compute minimum value in a fixed-size float array
 */
float computeMin(const float* data, int n) {
    if (n <= 0) return 0.0f;
    float vmin = data[0];
    for (int i = 1; i < n; i++) {
        if (data[i] < vmin) vmin = data[i];
    }
    return vmin;
}

/**
 * @brief Compute maximum value in a fixed-size float array
 */
float computeMax(const float* data, int n) {
    if (n <= 0) return 0.0f;
    float vmax = data[0];
    for (int i = 1; i < n; i++) {
        if (data[i] > vmax) vmax = data[i];
    }
    return vmax;
}

/**
 * @brief Compute maximum absolute value in a fixed-size float array
 */
float computeMaxAbs(const float* data, int n) {
    if (n <= 0) return 0.0f;
    float vmax = fabsf(data[0]);
    for (int i = 1; i < n; i++) {
        float a = fabsf(data[i]);
        if (a > vmax) vmax = a;
    }
    return vmax;
}

/**
 * @brief Compute percentile using linear interpolation
 */
float computePercentile(const float* data, int n, float percentile) {
    if (n <= 0) return 0.0f;
    
    float sorted[WINDOW_SIZE];
    memcpy(sorted, data, n * sizeof(float));
    
    for (int i = 0; i < n - 1; i++) {
        for (int j = i + 1; j < n; j++) {
            if (sorted[i] > sorted[j]) {
                float tmp = sorted[i];
                sorted[i] = sorted[j];
                sorted[j] = tmp;
            }
        }
    }
    
    if (percentile <= 0.0f) return sorted[0];
    if (percentile >= 100.0f) return sorted[n - 1];
    
    float position = (percentile / 100.0f) * (float)(n - 1);
    int lower = (int)floorf(position);
    int upper = (int)ceilf(position);
    
    if (lower == upper) return sorted[lower];
    
    float weight = position - (float)lower;
    return sorted[lower] * (1.0f - weight) + sorted[upper] * weight;
}

/**
 * @brief Extract model features from the current 40-sample circular buffer
 */
void extractWindowFeatures(float features[NUM_FEATURES]) {
    float speed_window[WINDOW_SIZE];
    float long_acc_window[WINDOW_SIZE];
    float yaw_window[WINDOW_SIZE];
    
    // Reconstruct window in chronological order (oldest to newest)
    for (int i = 0; i < WINDOW_SIZE; i++) {
        int src_idx = window_full ? ((window_index + i) % WINDOW_SIZE) : i;
        speed_window[i]    = window_buffer[src_idx][RAW_IDX_SPEED];
        long_acc_window[i] = window_buffer[src_idx][RAW_IDX_LONG_ACC];
        yaw_window[i]      = window_buffer[src_idx][RAW_IDX_YAW_RATE];
    }
    
    features[IDX_ACCEL_LONG_STD] = computeStd(long_acc_window, WINDOW_SIZE);
    features[IDX_SPEED_STD]      = computeStd(speed_window, WINDOW_SIZE);
    features[IDX_ACCEL_LONG_MIN] = computeMin(long_acc_window, WINDOW_SIZE);
    features[IDX_ACCEL_LONG_MAX] = computeMax(long_acc_window, WINDOW_SIZE);
    features[IDX_YAW_MAX]        = computeMaxAbs(yaw_window, WINDOW_SIZE);
    features[IDX_ACCEL_LONG_P90] = computePercentile(long_acc_window, WINDOW_SIZE, 90.0f);
}

/**
 * @brief Run TFLite inference on current window
 */
void runInference() {
    float features[NUM_FEATURES];
    extractWindowFeatures(features);
    
    // Outlier clipping (±4σ)
    for (int f = 0; f < NUM_FEATURES; f++) {
        float clip_min = FEATURE_MEANS[f] - 4.0f * FEATURE_STDS[f];
        float clip_max = FEATURE_MEANS[f] + 4.0f * FEATURE_STDS[f];
        features[f] = constrain(features[f], clip_min, clip_max);
    }
    
    // Fill input tensor
    int8_t* input_data = tfl_input->data.int8;
    normalizeAndQuantize(features, input_data);
    
    // Run inference
    if (tfl_interpreter->Invoke() != kTfLiteOk) {
        Serial.println("[TFLite] ERROR: Inference failed");
        return;
    }
    
    // Dequantize output
    int8_t raw_output = tfl_output->data.int8[0];
    current_confidence = (raw_output - OUTPUT_ZERO_POINT) * OUTPUT_SCALE;
    current_confidence = constrain(current_confidence, 0.0f, 1.0f);
    current_label = (current_confidence >= AGGRESSIVE_THRESHOLD) ? 1 : 0;
}

/**
 * @brief Add sample to sliding window and trigger inference
 */
void addSampleToWindow(float spd, float r, float thr, float la, float lat, float yr) {
    // Store in circular buffer
    window_buffer[window_index][RAW_IDX_SPEED]    = spd;
    window_buffer[window_index][RAW_IDX_RPM]      = r;
    window_buffer[window_index][RAW_IDX_THROTTLE] = thr;
    window_buffer[window_index][RAW_IDX_LONG_ACC] = la;
    window_buffer[window_index][RAW_IDX_LAT_ACC]  = lat;
    window_buffer[window_index][RAW_IDX_YAW_RATE] = yr;
    
    window_index = (window_index + 1) % WINDOW_SIZE;
    if (window_index == 0) window_full = true;
    
    samples_since_inference++;
    
    // Run inference every 20 samples (50% overlap)
    if (window_full && samples_since_inference >= INFERENCE_OVERLAP) {
        uint32_t t_start = millis();
        runInference();
        uint32_t t_end = millis();
        
        // Track latency (median of last 20)
        latency_samples[latency_count % 20] = t_end - t_start;
        latency_count++;
        
        int n = min(latency_count, 20);
        uint32_t temp[20];
        memcpy(temp, latency_samples, n * sizeof(uint32_t));
        
        // Simple bubble sort for median
        for (int i = 0; i < n - 1; i++) {
            for (int j = i + 1; j < n; j++) {
                if (temp[i] > temp[j]) {
                    uint32_t x = temp[i];
                    temp[i] = temp[j];
                    temp[j] = x;
                }
            }
        }
        inference_latency_ms = temp[n / 2];
        samples_since_inference = 0;
        
        Serial.printf("[ML] Label=%d Conf=%.2f | Spd=%.1f RPM=%.0f Thr=%.1f | "
                     "LongAcc=%.3f LatAcc=%.3f Yaw=%.2f | Lat=%.6f Lon=%.6f\n",
                     current_label, current_confidence,
                     spd, r, thr, la, lat, yr,
                     sensors.gps_lat, sensors.gps_lon);
    }
}

// ============================================================================
// WIFI & MQTT
// ============================================================================

void setupWiFi() {
    Serial.printf("[WiFi] Connecting to %s...\n", WIFI_SSID);
    WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
    
    int attempts = 0;
    while (WiFi.status() != WL_CONNECTED && attempts < 40) {
        delay(500);
        Serial.print(".");
        attempts++;
    }
    
    if (WiFi.status() == WL_CONNECTED) {
        Serial.printf("\n[WiFi] Connected (IP: %s)\n", WiFi.localIP().toString().c_str());
        
        // NTP time sync
        configTime(0, 0, "pool.ntp.org");
        
        // Disable power save for BLE coexistence
        esp_wifi_set_ps(WIFI_PS_NONE);
        WiFi.setTxPower(WIFI_POWER_19_5dBm);
    } else {
        Serial.println("\n[WiFi] Connection failed (continuing offline)");
    }
}

void setupMQTT() {
    wifi_client.setInsecure();  // Skip TLS verification (dev only)
    mqtt_client.setServer(MQTT_HOST, MQTT_PORT);
    mqtt_client.setBufferSize(512);
    
    snprintf(MQTT_TOPIC_TELEMETRY, sizeof(MQTT_TOPIC_TELEMETRY),
             "drivers/%s/telemetry", DRIVER_ID);
    snprintf(MQTT_TOPIC_TRIP, sizeof(MQTT_TOPIC_TRIP),
             "drivers/%s/trip", DRIVER_ID);
    
    Serial.println("[MQTT] Configured");
}

bool reconnectMQTT() {
    if (mqtt_client.connected()) return true;
    if (WiFi.status() != WL_CONNECTED) return false;
    
    static uint32_t lastAttempt = 0;
    if (millis() - lastAttempt < 5000) return false;
    lastAttempt = millis();
    
    char client_id[32];
    snprintf(client_id, sizeof(client_id), "esp32_%s", DRIVER_ID);
    
    if (mqtt_client.connect(client_id, MQTT_USER, MQTT_PASSWORD)) {
        Serial.println("[MQTT] Connected");
        return true;
    }
    return false;
}

void publishTelemetry() {
    if (!reconnectMQTT()) return;
    
    StaticJsonDocument<304> doc;
    doc["driver_id"]  = DRIVER_ID;
    doc["timestamp"]  = (unsigned long)time(nullptr);
    doc["label"]      = current_label;
    doc["confidence"] = current_confidence * 100.0f;
    doc["speed"]      = round(sensors.speed_kmh * 10) / 10;
    doc["rpm"]        = (int)sensors.rpm;
    doc["throttle"]   = round(sensors.throttle_pct * 100) / 100;
    doc["long_acc"]   = round(sensors.long_acc * 1000) / 1000;
    doc["lat_acc"]    = round(sensors.lat_acc * 1000) / 1000;
    doc["yaw_rate"]   = round(sensors.yaw_rate * 100) / 100;
    doc["lat"]        = sensors.gps_lat;
    doc["lon"]        = sensors.gps_lon;
    doc["location_source"] = sensors.using_ip_location ? "ip" : "gps";
    doc["inference_latency_ms"] = inference_latency_ms;
    
    char payload[304];
    serializeJson(doc, payload);
    mqtt_client.publish(MQTT_TOPIC_TELEMETRY, payload);
}

void publishTripEvent(const char* event_type) {
    if (!reconnectMQTT()) return;
    
    StaticJsonDocument<128> doc;
    doc["driver_id"] = DRIVER_ID;
    doc["event"]     = event_type;
    doc["timestamp"] = millis() / 1000;
    
    char payload[128];
    serializeJson(doc, payload);
    mqtt_client.publish(MQTT_TOPIC_TRIP, payload);
}

// ============================================================================
// BLE
// ============================================================================

class MyServerCallbacks : public NimBLEServerCallbacks {
    void onConnect(NimBLEServer* pServer) {
        bleConnected = true;
        Serial.println("[BLE] Client connected");
    }
    void onDisconnect(NimBLEServer* pServer) {
        bleConnected = false;
        NimBLEDevice::getAdvertising()->start();
        Serial.println("[BLE] Client disconnected");
    }
};

void setupBLE() {
    NimBLEDevice::init("DriverMonitor");
    NimBLEDevice::setPower(ESP_PWR_LVL_P9);
    
    bleServer = NimBLEDevice::createServer();
    bleServer->setCallbacks(new MyServerCallbacks());
    
    NimBLEService* service = bleServer->createService(BLE_SERVICE_UUID);
    bleCharacteristic = service->createCharacteristic(
        BLE_CHARACTERISTIC_UUID,
        NIMBLE_PROPERTY::READ | NIMBLE_PROPERTY::NOTIFY
    );
    
    service->start();
    NimBLEDevice::getAdvertising()->addServiceUUID(BLE_SERVICE_UUID);
    NimBLEDevice::getAdvertising()->start();
    
    Serial.println("[BLE] Advertising started");
}

void publishBLE() {
    if (!bleConnected) return;
    
    StaticJsonDocument<352> doc;
    doc["driver_id"]  = DRIVER_ID;
    doc["timestamp"]  = (unsigned long)time(nullptr);
    doc["label"]      = current_label;
    doc["label_text"] = (current_label == 1) ? "Aggressive" : "Normal";
    doc["confidence"] = current_confidence * 100.0f;
    doc["speed"]      = sensors.speed_kmh;
    doc["rpm"]        = (int)sensors.rpm;
    doc["throttle"]   = sensors.throttle_pct;
    doc["long_acc"]   = sensors.long_acc;
    doc["lat_acc"]    = sensors.lat_acc;
    doc["yaw_rate"]   = sensors.yaw_rate;
    doc["lat"]        = sensors.gps_lat;
    doc["lon"]        = sensors.gps_lon;
    doc["gps_valid"]  = sensors.gps_valid;
    doc["location_source"] = sensors.using_ip_location ? "ip" : "gps";
    doc["inference_latency_ms"] = inference_latency_ms;
    
    char payload[352];
    serializeJson(doc, payload);
    bleCharacteristic->setValue(payload);
    bleCharacteristic->notify();
}

// ============================================================================
// TRIP MANAGEMENT & POWER
// ============================================================================

void checkTripEnd() {
    bool engine_running = (sensors.rpm > 100.0f || sensors.speed_kmh > 2.0f);
    
    if (engine_running) {
        last_activity_ms = millis();
        
        if (!trip_active) {
            trip_active   = true;
            trip_start_ms = millis();
            publishTripEvent("trip_start");
            Serial.println("[TRIP] Started");
        }
    } else if (trip_active) {
        uint32_t idle_duration = millis() - last_activity_ms;
        
        if (idle_duration >= TRIP_END_TIMEOUT_MS) {
            trip_active = false;
            publishTripEvent("trip_end");
            Serial.println("[TRIP] Ended (entering deep sleep)");
            
            mqtt_client.disconnect();
            WiFi.disconnect(true);
            delay(500);
            
            esp_sleep_enable_timer_wakeup(SLEEP_CHECK_INTERVAL_US);
            esp_deep_sleep_start();
        }
    }
}

// ============================================================================
// SETUP & MAIN LOOP
// ============================================================================

void setup() {
    Serial.begin(115200);
    delay(1000);
    
    Serial.println("========================================");
    Serial.println("  Driver Behavior Monitor - Starting");
    Serial.println("========================================");
    
    // Check deep sleep wake reason
    if (esp_sleep_get_wakeup_cause() == ESP_SLEEP_WAKEUP_TIMER) {
        wasAsleep = true;
        sleepWakeCount++;
        Serial.printf("[POWER] Wake #%d (checking engine...)\n", sleepWakeCount);
    }
    
    // Initialize peripherals
    setupMPU6050();
    setupGPS();
    setupCAN();
    setupWiFi();
    setupMQTT();
    setupTFLite();
    
    // Connect MQTT before BLE to avoid interference
    Serial.println("[MQTT] Initial connection...");
    for (int i = 0; i < 10 && !mqtt_client.connected(); i++) {
        char client_id[32];
        snprintf(client_id, sizeof(client_id), "esp32_%s", DRIVER_ID);
        mqtt_client.connect(client_id, MQTT_USER, MQTT_PASSWORD);
        delay(2000);
    }
    
    setupBLE();
    
    last_sample_ms   = millis();
    last_activity_ms = millis();
    
    Serial.println("[SYSTEM] Ready\n========================================");
}

void loop() {
    uint32_t now = millis();
    
    // Continuous CAN monitoring
    updateOBD();
    
    // 20Hz sensor sampling
    if (now - last_sample_ms >= SAMPLE_INTERVAL_MS) {
        last_sample_ms = now;
        
        updateIMU();
        updateGPS();
        
        addSampleToWindow(sensors.speed_kmh, sensors.rpm, sensors.throttle_pct,
                         sensors.long_acc, sensors.lat_acc, sensors.yaw_rate);
        
        checkTripEnd();
    }
    
    // 1Hz telemetry publishing
    if (now - last_publish_ms >= 1000 && trip_active && window_full) {
        last_publish_ms = now;
        publishTelemetry();
        publishBLE();
    }
    
    mqtt_client.loop();
    yield();
}