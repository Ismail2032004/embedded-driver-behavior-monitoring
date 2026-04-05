# Driver Dashboard – Web Monitoring Platform

## Overview
This directory contains the web-based dashboard for the Embedded Driver Behavior Monitoring System. The dashboard provides real-time visualization, historical analysis, and trip-level insights into driver behavior using telemetry streamed from the embedded device.

The system is designed as a full-stack application integrating real-time messaging, time-series storage, and interactive visualization.

---

## System Architecture

### Frontend
- React (JavaScript, JSX)
- Deployed on Vercel
- Features:
  - real-time telemetry display
  - charts and analytics
  - trip visualization with maps
  - driver behavior classification display

### Backend
- Node.js with Express
- Deployed on Railway
- Responsibilities:
  - subscribes to MQTT broker (HiveMQ Cloud)
  - receives telemetry from ESP32
  - timestamps each message (`received_at`)
  - caches latest telemetry in memory
  - exposes REST API for frontend polling
  - queries InfluxDB for historical data

### Messaging Layer
- HiveMQ Cloud (MQTT broker)
- Receives telemetry from embedded device in near real-time

### Database
- InfluxDB Cloud (time-series database)
- Stores:
  - speed
  - RPM
  - throttle
  - IMU signals
  - classification outputs
  - timestamps

---

## Data Flow

1. ESP32 publishes telemetry via MQTT
2. Backend subscribes to MQTT topic
3. Backend:
   - processes incoming data
   - adds timestamp
   - caches latest reading
   - writes to InfluxDB
4. Frontend polls backend every second (HTTP GET)
5. UI updates with live telemetry and charts

---

## Features

### Real-Time Monitoring
- Live updates (1-second polling)
- Displays:
  - speed
  - RPM
  - throttle
  - accelerometer data
  - classification output

### Trip Visualization
- Map rendering using Leaflet
- Route displayed as polyline
- Aggressive driving events highlighted

### Historical Data Analysis
- Retrieves past data from InfluxDB
- Displays time-series charts using Recharts

### Driver Behavior Classification
- Displays ML model output:
  - normal
  - weak
  - aggressive

### Authentication (Prototype)
Authentication is implemented as a frontend-only check:

username: admin  
password: driver123  

Notes:
- no backend authentication
- no sessions or JWT
- credentials are hardcoded for demonstration only

---

## Technology Stack

- React
- Node.js (Express)
- MQTT (HiveMQ Cloud)
- InfluxDB Cloud
- Recharts (charts)
- Leaflet (maps)
- Vercel (frontend hosting)
- Railway (backend hosting)

---

## Project Structure

driver_dashboard/
│
├── backend/
│   ├── src/
│   ├── scripts/
│   ├── data/
│   ├── index.js
│   └── package.json
│
├── frontend/
│   ├── src/
│   ├── public/
│   ├── index.html
│   ├── vite.config.js
│   └── package.json
│
├── .gitignore
└── README.md

---

## API Endpoint

GET /api/telemetry/latest  
Returns the latest telemetry snapshot cached by the backend.

---

## Deployment

Frontend: Vercel  
Backend: Railway  
Database: InfluxDB Cloud  
MQTT Broker: HiveMQ Cloud  

---

## Limitations

- Uses HTTP polling instead of real-time sockets
- No authentication system
- Backend stores only latest reading in memory
- Limited error handling and reconnection logic
- Not optimized for scale

---

## Future Improvements

### Architecture
- Replace polling with WebSockets or MQTT over WebSockets
- Event-driven updates instead of polling

### Security
- Implement proper authentication (JWT or OAuth)
- Secure credential handling
- Role-based access control

### Data Handling
- Batch writes to InfluxDB
- Improved query efficiency
- Data retention policies

### Frontend
- Improved UI/UX
- Filtering and search
- Advanced analytics

### Reliability
- Backend health monitoring
- MQTT reconnection handling
- Logging and alerting

### Integration
- Unified system with mobile app
- Shared API layer across clients

---

## Notes

This dashboard is a prototype developed to demonstrate an end-to-end embedded telemetry monitoring system. It is not intended for production use without further improvements in security, scalability, and reliability.