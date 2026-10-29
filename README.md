<div align="center">

# ⚡ HC-POS
### Human-Centric Power Orchestration System

*An intelligent cyber-physical home energy management system that pairs deep-learning AI, mathematical optimization, and a trilingual conversational assistant — while keeping humans in full control.*

<br/>

[![Python](https://img.shields.io/badge/Python-3.10%2B-3776AB?style=for-the-badge&logo=python&logoColor=white)](https://python.org)
[![Flutter](https://img.shields.io/badge/Flutter-3.5%2B-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![ESP32](https://img.shields.io/badge/ESP32-Arduino-E7352C?style=for-the-badge&logo=arduino&logoColor=white)](https://www.arduino.cc)
[![TensorFlow](https://img.shields.io/badge/TensorFlow-2.16%2B-FF6F00?style=for-the-badge&logo=tensorflow&logoColor=white)](https://tensorflow.org)
[![Supabase](https://img.shields.io/badge/Supabase-PostgreSQL-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)](https://supabase.com)
[![Research Paper](https://img.shields.io/badge/Research%20Paper-PDF%20%7C%20Markdown-red?style=for-the-badge&logo=adobeacrobatreader&logoColor=white)](./Project_Showcase_Symposium_Paper_Title.pdf)
[![License: MIT](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)](LICENSE)

<br/>

[![NILM Accuracy](https://img.shields.io/badge/NILM%20Accuracy-94.2%25-brightgreen?style=flat-square)](/)
[![Cost Reduction](https://img.shields.io/badge/Cost%20Reduction-36.96%25-blue?style=flat-square)](/)
[![MILP Solve Time](https://img.shields.io/badge/MILP%20Solve-0.45s-purple?style=flat-square)](/)
[![Latency](https://img.shields.io/badge/E2E%20Latency-%3C180ms-orange?style=flat-square)](/)

</div>

---

## 📋 Table of Contents

- [Why HC-POS?](#-why-hc-pos)
- [System Architecture](#-system-architecture)
- [Key Features](#-key-features)
- [Tech Stack](#-tech-stack)
- [Verified Performance Results](#-verified-performance-results)
- [Repository Structure](#-repository-structure)
- [Hardware Requirements](#-hardware-requirements)
- [Getting Started](#-getting-started)
  - [1. ESP32 Firmware](#1-esp32-firmware-setup)
  - [2. Python AI Backend](#2-python-ai-backend-setup)
  - [3. Flutter Mobile App](#3-flutter-mobile-app-setup)
- [Configuration Reference](#-configuration-reference)
- [How It Works — Deep Dive](#-how-it-works--deep-dive)
- [API Reference](#-api-reference)
- [Roadmap](#-roadmap)
- [Research Paper & Publications](#-research-paper--publications)
- [Contributing](#-contributing)
- [License](#-license)

---

## 🎯 Why HC-POS?

Modern Home Energy Management Systems (HEMS) operate as **autonomous black boxes** — they schedule your appliances and switch your relays without ever explaining *why*, and with no easy way for the occupant to question or override their decisions.

**HC-POS solves this with a human-centric design philosophy:**

| Traditional HEMS | HC-POS |
|:---|:---|
| 🔲 Black-box automation | ✅ Every decision explained in plain language |
| 🌐 English-only interfaces | ✅ Sinhala 🇱🇰, Singlish & English |
| ❌ Users cannot interrogate the AI | ✅ Conversational advisor you can question |
| 🔒 Overrides are clunky or impossible | ✅ One-tap "Run Now / Reschedule" on every decision |
| 💰 No financial transparency | ✅ Per-decision savings displayed in LKR |
| 💥 Single point of failure | ✅ Microservice fault isolation — edge runs if cloud fails |
| 🕶 No appliance visibility | ✅ Non-Intrusive Load Monitoring identifies devices |

HC-POS was built for Sri Lankan residential microgrids under the **Ceylon Electricity Board (CEB) Time-of-Use (TOU) tariff**, but its architecture is adaptable to any country's pricing regime.

---

## 🏗 System Architecture

HC-POS is organized into **five decoupled functional layers**:

```
┌───────────────────────────────────────────────────────────────────┐
│  Layer 1 — Edge Sensing & Actuation                               │
│  ESP32 · PZEM-004T AC Meter · ADS1115 ADC · 4-Channel Relays     │
│  → 1-second JSON telemetry over raw TCP socket                    │
└──────────────────────────────┬────────────────────────────────────┘
                               │ TCP / HTTP
┌──────────────────────────────▼────────────────────────────────────┐
│  Layer 2 — Dual-Protocol Ingestion Gateway  (esp32_receiver.py)   │
│  TCP parser · HTTP/SSE proxy · Physics-informed waveform synth    │
│  → live_sensor_raw.csv  |  live_sensor_stream.csv                 │
└──────────────────────────────┬────────────────────────────────────┘
                               │ CSV data
┌──────────────────────────────▼────────────────────────────────────┐
│  Layer 3 — AI & Optimization Server            (api_server.py)    │
│  ┌────────────────┐  ┌──────────────┐  ┌──────────────────────┐  │
│  │  1D-CNN NILM   │  │  Solar LSTM  │  │  Consumption LSTM    │  │
│  │   94.2% acc    │  │  R²=0.892    │  │  R²=0.865            │  │
│  └───────┬────────┘  └──────┬───────┘  └──────────┬───────────┘  │
│          └──────────────────▼──────────────────────┘             │
│                      ┌─────────────────┐                          │
│                      │ MILP Optimizer  │ ← PuLP / CBC solver      │
│                      │  0.45s solve    │   36.96% savings proven  │
│                      └────────┬────────┘                          │
│                               │                                   │
│                 ┌─────────────▼─────────────┐                    │
│                 │  Genesis AI Agent (LLM)   │ ← Trilingual XAI   │
│                 │  LangChain ReAct + 8 tools│   Sinhala / Eng    │
│                 └─────────────┬─────────────┘                    │
└───────────────────────────────┼───────────────────────────────────┘
                                │ HTTPS / WebSocket
┌───────────────────────────────▼───────────────────────────────────┐
│  Layer 4 — Cloud Database                   (Supabase / Postgres) │
│  system_state | decisions | forecasts | appliances | alerts        │
│  → Row-Level Security · Realtime WebSocket push · Multi-tenant     │
└───────────────────────────────┬───────────────────────────────────┘
                                │ WebSocket Realtime
┌───────────────────────────────▼───────────────────────────────────┐
│  Layer 5 — Flutter Mobile App          (Flutter 3.5 + Riverpod)   │
│  Dashboard · Decisions Feed · Genesis AI Chat · Sockets · Alerts  │
└───────────────────────────────────────────────────────────────────┘
```

---

## ✨ Key Features

### 🤖 AI & Machine Learning

- **Non-Intrusive Load Monitoring (NILM)** — A 3-block 1D Convolutional Neural Network classifies **10 household appliance types** from AC current waveform harmonics with **94.2% categorical accuracy** at just 17.9 ms per inference window. No per-socket sensors required.

- **24-Hour Solar Generation Forecaster** — Multi-layer LSTM neural network predicts photovoltaic output using 7 meteorological features with **R² = 0.892**, hard-bounded to zero during nighttime hours.

- **24-Hour Consumption Forecaster** — Autoregressive LSTM predicts household demand with **R² = 0.865**, accurately capturing morning kitchen preparation and evening entertainment peaks.

- **Physics-Informed Waveform Reconstruction** — Synthesizes 860-sample, 860 Hz AC current waveforms from scalar PZEM meter readings, enabling NILM inference without oscilloscope hardware.

### ⚡ Mathematical Optimization

- **MILP Energy Scheduler** — Mixed-Integer Linear Program solved via PuLP + CBC Branch-and-Cut algorithm minimizes daily electricity cost across a 24-hour scheduling horizon.
- **Sri Lanka TOU Tariff Awareness** — Off-Peak Rs. 13/kWh → Day Rs. 25/kWh → Peak Rs. 54/kWh
- **Proven 36.96% cost reduction** — Rs. 191.60 saved per day vs. unmanaged baseline in controlled study
- **Sub-second convergence** — Global optimal 24-hour schedule solved in ≈ **0.45 seconds**
- **100% Peak Grid Independence** — Zero grid imports during expensive peak tariff hours when battery is available

### 💬 Explainable AI (XAI)

- **Genesis AI Agent** — LangChain ReAct framework powered by NVIDIA Nemotron LLM with 8 specialized energy management tools
- **Trilingual** — Full natural language reasoning in **Sinhala** (සිංහල), **Singlish**, and **English** — replies in whichever language the user writes in
- **Tool-augmented reasoning** — Agent queries live NILM detections, optimizer schedules, and financial metrics before answering; never invents numbers
- **Human-in-the-loop protocol** — The agent can only *propose* overrides via `request_manual_approval`; users always confirm before any relay command executes

### 📱 Flutter Mobile App (6 Screens)

| Screen | Description |
|:---|:---|
| **Home Dashboard** | Animated energy flow canvas (Solar → Inverter → Battery/Load/Grid) with live kW readings |
| **Decisions Feed** | Every AI scheduling decision with LKR savings and Approve / Reschedule / Run Now actions |
| **Genesis AI Chat** | Trilingual conversational assistant with typing indicator and suggested prompts |
| **Appliances & Sockets** | Real-time NILM recognition tags on each relay branch with manual toggle |
| **Energy History** | Multi-curve chart: 24h solar generation vs. household demand vs. battery SoC |
| **Alerts** | Safety notifications (low battery, over-voltage) and emergency relay cutoff |

### 🔌 Edge Hardware Integration

- ESP32 firmware in C++/Arduino with 1-second sensor polling loop
- PZEM-004T AC power analyzer over Modbus-RTU (V, I, P, Hz, PF)
- ADS1115 16-bit ADC for solar PV and battery voltage
- 4-channel optocoupler relay matrix: Grid / Inverter / Critical loads / Deferrable loads
- **< 210 ms** emergency relay cutoff from mobile tap to hardware click

---

## 🛠 Tech Stack

| Component | Technology |
|:---|:---|
| **Edge Firmware** | C++ / Arduino (ESP32), PZEM004Tv30, Adafruit ADS1X15 |
| **Ingestion Gateway** | Python 3.10+, Flask, raw TCP sockets |
| **AI Backend API** | Python, FastAPI, Uvicorn |
| **NILM Model** | TensorFlow / Keras — 1D-CNN (3 conv blocks + GAP head) |
| **Solar Forecaster** | TensorFlow / Keras — Multi-layer LSTM, 7 meteorological features |
| **Consumption Forecaster** | TensorFlow / Keras — Autoregressive LSTM |
| **MILP Optimizer** | PuLP + CBC Branch-and-Cut solver |
| **AI Agent Framework** | LangChain (ReAct pattern), NVIDIA Nemotron LLM |
| **Cloud Database** | Supabase (PostgreSQL + Realtime WebSocket + Row-Level Security) |
| **Mobile App** | Flutter 3.5+, Dart, Riverpod state management, go_router |
| **UI Charts** | fl_chart |
| **Typography** | Manrope variable-weight font |

---

## 📊 Verified Performance Results

### Machine Learning Model Accuracy

| Model | Metric | Empirical Result |
|:---|:---|:---|
| **1D-CNN NILM** | Overall Categorical Accuracy | **94.2%** |
| **1D-CNN NILM** | Macro Average F1-Score | **0.942** |
| **1D-CNN NILM** | Inference Latency per Window | **17.9 ms** |
| **1D-CNN NILM** | Idle State Precision (`RMS < 0.25A`) | **100.0%** |
| **Solar LSTM** | R² Score | **0.892** |
| **Solar LSTM** | Mean Absolute Error | **0.124 kW** |
| **Solar LSTM** | Root Mean Squared Error | **0.198 kW** |
| **Consumption LSTM** | R² Score | **0.865** |
| **Consumption LSTM** | Mean Absolute Error | **0.162 kWh** |

### NILM Per-Appliance Results (600 independent test windows)

| Appliance | Rated Power | Precision | Recall | F1-Score |
|:---|:---|:---|:---|:---|
| Water Heater | 2000 W | 0.985 | 0.980 | **0.982** |
| Electric Iron | 1000 W | 0.981 | 0.975 | **0.978** |
| Rice Cooker | 700 W | 0.970 | 0.965 | **0.967** |
| Electric Kettle | 1500 W | 0.965 | 0.950 | **0.957** |
| Air Conditioner | 1500 W | 0.942 | 0.920 | **0.931** |
| Household Fan | 150 W | 0.935 | 0.940 | **0.937** |
| Refrigerator | 150 W | 0.925 | 0.930 | **0.927** |
| LED Television | 90 W | 0.928 | 0.915 | **0.921** |
| Washing Machine | 1200 W | 0.918 | 0.910 | **0.914** |
| Microwave Oven | 1100 W | 0.912 | 0.905 | **0.908** |
| **Macro Average** | — | **0.946** | **0.939** | **0.942** |

### System End-to-End Latency

| Operation | Target | Measured | Status |
|:---|:---|:---|:---|
| ESP32 sensor sampling loop | 1000 ms ± 50 ms | **1000.4 ms** avg | ✅ Pass |
| TCP microcontroller → gateway | < 50 ms | **8.2–14.6 ms** over Wi-Fi | ✅ Pass |
| Waveform synthesis | < 10 ms | **1.85 ms** / window | ✅ Pass |
| 1D-CNN NILM inference | < 50 ms | **17.9 ms** on CPU | ✅ Pass |
| MILP 24-hour schedule solve | < 2000 ms | **428 ms** (PuLP/CBC) | ✅ Pass |
| Gateway → Supabase cloud sync | < 500 ms | **142 ms** HTTPS write | ✅ Pass |
| Cloud WebSocket → mobile UI | < 300 ms | **165 ms** end-to-end | ✅ Pass |
| Emergency relay cutoff | < 500 ms | **210 ms** tap-to-relay | ✅ Pass |

### Economic Impact (24-Hour Comparative Study)

**Test Conditions:** Washing Machine (1.2 kW × 2h) + Water Heater (2.0 kW × 1.5h) + Water Pump (0.75 kW × 2h) | Battery: 4.8 kWh @ 50% SoC | Solar: 3.0 kWp (14.2 kWh/day)

| Metric | Unmanaged Baseline | HC-POS Optimized | Improvement |
|:---|:---|:---|:---|
| Peak window grid import | 5.40 kWh | **0.00 kWh** | **−100% (Peak Independence)** |
| Total grid import (24h) | 14.80 kWh | **10.20 kWh** | **−31.1%** |
| Solar self-consumption ratio | 62.5% | **93.8%** | **+31.3%** |
| **Daily electricity cost** | **Rs. 518.40** | **Rs. 326.80** | **−Rs. 191.60 (−36.96%)** |
| **Monthly savings** | — | — | **Rs. 5,748 / month** |

---

## 📁 Repository Structure

```
hc-pos/
│
├── .gitignore                          # Excludes .env, build artifacts, logs
│
├── ESP32 backend/
│   └── espcode.ino                     # Arduino firmware — PZEM + ADS1115 + TCP
│
├── ai-ml models (01)/
│   ├── esp32_receiver.py               # Dual-protocol ingestion gateway (TCP + HTTP/SSE)
│   ├── api_server.py                   # FastAPI server — AI agent + MILP optimizer REST API
│   ├── agent.py                        # Standalone CLI mode agent (local testing)
│   ├── supabase_client.py              # Supabase singleton client (service-role)
│   ├── sensor_dashboard.html           # Browser live telemetry SSE dashboard
│   ├── requirements.txt                # Python dependencies
│   ├── .env.example                    # Environment variable template → copy to .env
│   │
│   ├── agent_tools/
│   │   ├── __init__.py                 # Auto-exports all @tool-decorated functions
│   │   ├── decision_engine.py          # MILP optimizer · NILM · LSTM forecasters · 8 agent tools
│   │   └── power_consumptin_prediction.py  # LSTM consumption model inference module
│   │
│   ├── device detection/               # NILM model training pipeline
│   │   ├── generate_training_data.py   # Synthesize labeled 860-sample waveform dataset
│   │   ├── generate_test_stream.py     # Generate NILM test windows & label map CSV
│   │   └── train_model.py              # Train the 1D-CNN NILM classifier
│   │
│   ├── Solar prediction/               # Solar LSTM training pipeline
│   │   ├── generate_train_dataset.py   # Build solar irradiance training dataset
│   │   ├── train_lstm.py               # Train the 24-hour solar LSTM
│   │   └── test_lstm.py                # Evaluate solar LSTM (R², MAE, RMSE)
│   │
│   ├── Future power consumption prediction/   # Consumption LSTM training pipeline
│   │   ├── generate_training_data.py   # Generate residential load sequences
│   │   ├── train_lstm.py               # Train the autoregressive consumption LSTM
│   │   └── test_lstm.py                # Evaluate consumption LSTM
│   │
│   ├── 1dcnn_model.keras               # Trained NILM 1D-CNN model (10 appliance classes)
│   ├── lstm_solar_model.keras          # Trained 24-hour solar generation LSTM
│   ├── lstm_power_model.keras          # Trained 24-hour consumption LSTM
│   ├── solar_scaler.pkl                # MinMaxScaler fitted to solar LSTM features
│   ├── power_scaler.pkl                # MinMaxScaler fitted to consumption LSTM features
│   ├── device_catalog.csv              # Schedulable appliance registry (MILP parameters)
│   └── device_label_map.csv            # NILM class index → device name mapping
│
└── Mobile app/
    └── project1/                       # Flutter project root
        ├── pubspec.yaml                # Dependencies declaration
        └── lib/
            ├── main.dart               # App entry point, Supabase init, Riverpod scope
            ├── core/
            │   ├── constants.dart      # ⚠️ FILL IN before build (Supabase URL, API URL)
            │   ├── router.dart         # go_router navigation graph
            │   └── theme/              # AppColors, AppTextStyles, AppTheme (dark)
            ├── models/                 # Dart data classes (SystemState, Decision, Alert…)
            ├── providers/              # Riverpod providers — Supabase realtime streams
            ├── screens/                # 6 app screens (dashboard, chat, decisions, …)
            ├── services/               # AgentService (HTTP client), SupabaseService
            └── shared/                 # Reusable widgets: GlassCard, BottomNav, dialogs
```

---

## 🔧 Hardware Requirements

| Component | Specification | Role |
|:---|:---|:---|
| Microcontroller | **ESP32 Dev Board** (any 38-pin) | Central edge controller |
| AC Power Meter | **PZEM-004T v3.0** | Grid V, I, P, Hz, PF measurement |
| ADC | **ADS1115** 16-bit I2C | Solar PV + battery DC voltage |
| Relay Module | **4-channel 5V optocoupler relay** | Load switching |
| Voltage Divider | 100 kΩ + 27 kΩ resistors | 12V battery → 3.3V safe range |
| Battery Bank | 12V Li-ion (e.g., 48V 100Ah system) | BESS energy storage |
| Solar Array | ≥ 1 kWp PV panels | Renewable generation source |
| Hybrid Inverter | Any grid-tie or hybrid inverter | DC ↔ AC conversion |

### Wiring Summary

```
ESP32 GPIO16 (RX2) ←─→ PZEM-004T TX   │  Modbus-RTU UART
ESP32 GPIO17 (TX2) ←─→ PZEM-004T RX   │

ESP32 GPIO21 (SDA) ←─→ ADS1115 SDA    │  I2C @ 100–400 kHz
ESP32 GPIO22 (SCL) ←─→ ADS1115 SCL    │

ADS1115 Channel 0  ←── Battery divider output  (12V → ~0.9V)
ADS1115 Channel 3  ←── Solar panel divider output

ESP32 GPIO35        ←── Battery voltage (alternative ADC path)
ESP32 GPIO26–29    ──→ Relay IN1–IN4  (active LOW, optocoupler-isolated)
```

---

## 🚀 Getting Started

> **Prerequisites:**
> - Python 3.10+, pip, and virtualenv
> - Flutter SDK 3.5+ (`flutter doctor` should show no critical errors)
> - Arduino IDE 2.x with ESP32 board support package
> - A free [Supabase](https://supabase.com) project
> - A free [NVIDIA API key](https://build.nvidia.com/) for the Genesis AI LLM

---

### 1. ESP32 Firmware Setup

**Install Arduino libraries** (via IDE Library Manager or `.zip`):
- `PZEM004Tv30` by Olehs
- `Adafruit ADS1X15`

**Open and configure** `ESP32 backend/espcode.ino`:

```cpp
// ── Edit these four lines before flashing ─────────────────────────
const char *WIFI_SSID     = "YOUR_WIFI_SSID";
const char *WIFI_PASSWORD = "YOUR_WIFI_PASSWORD";
const char *SERVER_IP     = "192.168.1.100"; // PC/server LAN IP (ipconfig / ip addr)
const uint16_t SERVER_PORT = 5000;
// ──────────────────────────────────────────────────────────────────
```

**Flash** → Select your board & COM port → Upload (Ctrl+U) → Open Serial Monitor at **115200 baud** to confirm the connection.

---

### 2. Python AI Backend Setup

```bash
# 1. Clone the repository
git clone https://github.com/Navanjana2005/hc-pos.git
cd "hc-pos/ai-ml models (01)"

# 2. Create and activate a virtual environment
python -m venv .venv
# Windows:  .venv\Scripts\activate
# Mac/Linux: source .venv/bin/activate

# 3. Install dependencies
pip install -r requirements.txt

# 4. Configure environment variables
cp .env.example .env
# Open .env in a text editor and fill in your credentials
```

**Supabase database setup** — run these in the [Supabase SQL Editor](https://supabase.com/dashboard):

```sql
-- Core system state table (single row, updated in real time)
CREATE TABLE system_state (
  id BIGINT PRIMARY KEY DEFAULT 1,
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  solar_generation_w FLOAT DEFAULT 0,
  whole_house_power_w FLOAT DEFAULT 0,
  battery_soc_pct FLOAT DEFAULT 50,
  battery_health_pct FLOAT DEFAULT 100,
  current_power_source TEXT DEFAULT 'grid',
  automation_mode TEXT DEFAULT 'auto',
  emergency_stop_active BOOLEAN DEFAULT FALSE,
  user_id UUID REFERENCES auth.users(id)
);

-- Optimizer decisions (one row per scheduled appliance action)
CREATE TABLE decisions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  decision_type TEXT,
  reasoning JSONB,
  status TEXT DEFAULT 'proposed',
  decided_by TEXT DEFAULT 'ai',
  user_id UUID REFERENCES auth.users(id)
);

-- 24-hour solar and consumption forecasts
CREATE TABLE forecasts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  model_version TEXT DEFAULT 'lstm_v1',
  forecast_type TEXT,     -- 'solar' | 'consumption'
  horizon_start TIMESTAMPTZ,
  horizon_end TIMESTAMPTZ,
  predicted_value FLOAT,
  user_id UUID REFERENCES auth.users(id)
);

-- Safety alerts and notifications
CREATE TABLE alerts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  alert_type TEXT,
  message TEXT,
  severity TEXT,          -- 'info' | 'warning' | 'critical'
  is_resolved BOOLEAN DEFAULT FALSE,
  user_id UUID REFERENCES auth.users(id)
);

-- Enable Row Level Security (recommended)
ALTER TABLE system_state ENABLE ROW LEVEL SECURITY;
ALTER TABLE decisions ENABLE ROW LEVEL SECURITY;
ALTER TABLE forecasts ENABLE ROW LEVEL SECURITY;
ALTER TABLE alerts ENABLE ROW LEVEL SECURITY;
```

**Start the backend servers** (two separate terminals):

```bash
# Terminal 1 — ESP32 ingestion gateway (port 5000)
python esp32_receiver.py

# Terminal 2 — AI API server (port 8000)
uvicorn api_server:app --host 0.0.0.0 --port 8000 --reload
```

**Verify everything is running:**

```bash
# Health check
curl http://localhost:8000/health
# → {"status":"ok","service":"HC-POS Genesis AI"}

# Sensor gateway status
curl http://localhost:5000/status
# → {"status":"ok","raw_csv_rows":...,"nilm_csv_rows":...}

# Trigger a manual optimizer run
curl -X POST http://localhost:8000/run-optimizer

# Chat with Genesis AI
curl -X POST http://localhost:8000/chat \
  -H "Content-Type: application/json" \
  -d '{"message":"What appliances are running right now?","history":[]}'
```

> **Interactive API docs:** Open `http://localhost:8000/docs` in your browser (Swagger UI auto-generated by FastAPI).

> **Live sensor dashboard:** Open `sensor_dashboard.html` in your browser — it auto-connects to the SSE stream at `http://localhost:5000/stream`.

---

### 3. Flutter Mobile App Setup

```bash
cd "hc-pos/Mobile app/project1"

# Install Dart/Flutter dependencies
flutter pub get
```

**Configure credentials** in [`lib/core/constants.dart`](Mobile%20app/project1/lib/core/constants.dart):

```dart
class AppConstants {
  // ── Supabase ───────────────────────────────────────────────────────────
  // From: supabase.com → Your Project → Settings → API
  static const String supabaseUrl = 'https://YOUR_PROJECT_REF.supabase.co';
  static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY'; // anon key, not service_role

  // ── Python Backend ────────────────────────────────────────────────────
  // LAN IP for local dev, cloud URL for deployment
  static const String apiBaseUrl = 'http://192.168.1.100:8000';
  // ...
}
```

**Run the app:**

```bash
# Run on connected Android device or emulator
flutter run

# Build release APK
flutter build apk --release

# Build for iOS (requires macOS + Xcode)
flutter build ios --release
```

---

## ⚙️ Configuration Reference

### `device_catalog.csv` — Schedulable Appliance Registry

Add, remove, or tune appliances by editing this CSV — no code changes needed:

| Column | Type | Description |
|:---|:---|:---|
| `device_name` | string | Must match a NILM class label in `device_label_map.csv` |
| `energy_kwh` | float | Total kWh required to complete one run cycle |
| `priority` | float | Inconvenience penalty if the run is missed (higher = more urgent) |
| `deadline_hour` | int | Must finish by this hour relative to solve start (0–24) |
| `work_time_hours` | float | Minimum continuous hours the appliance needs to run |

### `device_label_map.csv` — NILM Class Index Map

Maps the 1D-CNN model's output class indices to human-readable device names. Generated by `device detection/generate_test_stream.py` alongside the training data. **Do not edit manually unless retraining the model.**

### Python Backend `.env` Variables

| Variable | Required | Description |
|:---|:---|:---|
| `NVIDIAGS_API_KEY` | ✅ Required | NVIDIA API key for the Genesis AI LLM |
| `SUPABASE_URL` | ✅ Required | Your Supabase project URL |
| `SUPABASE_SERVICE_KEY` | ✅ Required | Service-role key (bypasses RLS for backend writes) |
| `SUPABASE_USER_ID` | ⚠️ Recommended | UUID of the household's Supabase auth user |
| `MISTRAL_API_KEY` | ❌ Optional | Alternative LLM (Mistral AI) — commented out by default |

> ⚠️ **Security Note:** The `SUPABASE_SERVICE_KEY` is a privileged secret — never expose it in client-side code. Only the Python backend uses it. The Flutter app uses the `supabaseAnonKey`.

---

## 🔬 How It Works — Deep Dive

### Physics-Informed Waveform Reconstruction

Standard AC meters output only scalar RMS values. HC-POS's ingestion gateway **synthesizes** realistic 860-sample current waveforms from these scalars by:

1. **Archetype matching** — maps measured power and power factor to the closest trained device class (e.g., resistive heater vs. induction motor)
2. **Fundamental synthesis** — builds the 50 Hz base waveform: $i(t) = I_{peak} \sin(2\pi f t)$ where $I_{peak} = \sqrt{2} \cdot I_{RMS}$
3. **Harmonic injection** — adds empirically-calibrated harmonic distortion components for the matched archetype (3rd harmonic for motors, 2nd/3rd for SMPS electronics)
4. **Noise injection** — adds Gaussian sensor noise calibrated per device class

This enables NILM inference **without oscilloscope hardware**, making the system practical for real-world deployments.

### MILP Cost Minimization Formulation

The optimizer solves a **Mixed-Integer Linear Program** every 5 minutes:

$$\min \sum_{t=1}^{24} \left[ C_{grid}(t) \cdot P_{grid}(t) + C_{deg} \cdot P_{dis}(t) + \sum_{a \in \mathcal{A}} C_{delay}(a) \cdot (1 - u_a(t)) \right]$$

**Subject to:**

| Constraint | Description |
|:---|:---|
| Energy balance | $P_{solar}(t) + P_{dis}(t) + P_{grid}(t) = P_{load}(t) + P_{chg}(t) + P_{curtailed}(t)$ |
| Battery SoC dynamics | $SoC(t) = SoC(t-1) + \eta_{chg} P_{chg}(t) - \frac{1}{\eta_{dis}} P_{dis}(t)$ |
| SoC bounds | $0.20 \leq SoC(t) \leq 1.00$ |
| Inverter limits | $P_{chg}(t) + P_{dis}(t) \leq 3.0 \text{ kW}$ |
| Appliance scheduling | Each appliance runs exactly once as a continuous block before its deadline |
| TOU tariff | Off-Peak Rs. 13 | Day Rs. 25 | Peak Rs. 54 per kWh |

### Genesis AI Agent Tools

The Genesis agent calls 8 real-time tools to answer questions — it never invents numbers:

| Tool | What It Does |
|:---|:---|
| `get_detected_devices` | Runs NILM on last N sensor windows; reports detected appliances with confidence |
| `get_current_decision` | Fetches the latest 24-hour MILP schedule and KPIs from Supabase |
| `explain_decision` | Explains why a specific appliance was scheduled at a given hour (tariff/deadline/SoC) |
| `diagnose_why_infeasible` | Analyzes constraint violations when the optimizer returns no valid schedule |
| `simulate_scenario` | Re-runs optimizer with hypothetical parameters for "what if" queries |
| `request_manual_approval` | Proposes an override for human confirmation — never auto-executes |
| `predict_next_24_hours` | Returns LSTM solar generation and household consumption forecasts |
| `generate_pdf_report` | Compiles a daily energy audit summary document |

---

## 📡 API Reference

### ESP32 Ingestion Gateway (Port 5000)

| Method | Endpoint | Description |
|:---|:---|:---|
| `GET` | `/` | Service info and endpoint list |
| `POST` | `/data` | Ingest a JSON telemetry reading (HTTP fallback for simulators) |
| `GET` | `/status` | Health check, CSV row counts, latest reading |
| `GET` | `/stream` | Server-Sent Events stream for live browser dashboard |
| `GET` | `/ping` | Connectivity test |

**Telemetry JSON format** (sent by ESP32 firmware every 2 seconds):
```json
{
  "timestamp": "2026-10-29T15:30:00+05:30",
  "voltage_v": 230.1,
  "current_a": 3.500,
  "power_w": 800.0,
  "solar_power_w": 1450.0,
  "frequency_hz": 50.00,
  "power_factor": 0.95,
  "battery_soc_pct": 75.0
}
```

### AI API Server (Port 8000)

| Method | Endpoint | Description |
|:---|:---|:---|
| `GET` | `/health` | Liveness check |
| `POST` | `/chat` | Send a message to the Genesis AI agent |
| `POST` | `/run-optimizer` | Trigger a MILP optimization cycle |

**`POST /chat` request body:**
```json
{
  "message": "Why was the water heater shifted to 11 PM?",
  "history": [
    {"role": "user", "content": "What's today's schedule?"},
    {"role": "assistant", "content": "The optimizer has scheduled..."}
  ]
}
```

> Full interactive API docs at `http://localhost:8000/docs` (FastAPI auto-generated Swagger UI)

---

## 🗺 Roadmap

### ✅ Completed
- [x] ESP32 hardware-in-the-loop sensing and TCP streaming
- [x] Dual-protocol (TCP + HTTP/SSE) ingestion gateway
- [x] Physics-informed waveform reconstruction engine
- [x] 1D-CNN NILM classifier — 10 appliances, 94.2% accuracy
- [x] 24-hour Solar LSTM forecaster — R² = 0.892
- [x] 24-hour Consumption LSTM forecaster — R² = 0.865
- [x] MILP cost optimizer — 36.96% savings verified
- [x] Genesis AI agent with 8 tool-augmented capabilities
- [x] Trilingual support (Sinhala / Singlish / English)
- [x] Supabase cloud database with Row-Level Security
- [x] Flutter mobile app (6 screens, Riverpod, Realtime WebSocket)
- [x] Master emergency relay cutoff (< 210 ms latency)

### 🔜 Planned
- [ ] Custom PCB integrating ESP32 + PZEM + ADS1115 in DIN-rail form factor
- [ ] ESP-NOW / MQTT mesh for decentralized per-socket sub-metering
- [ ] Local SQLite caching for offline operation during broadband outages
- [ ] TensorFlow Lite on-chip quantized NILM inference (no server dependency)
- [ ] Online model fine-tuning from real household sensor data
- [ ] Multi-objective MILP with real-time carbon intensity factors
- [ ] Firebase Cloud Messaging push notifications for upcoming peak tariff windows
- [ ] On-device Sinhala TTS/ASR for hands-free voice control
- [ ] WearOS / Apple Watch companion app for quick emergency shutoff
- [ ] Stochastic MILP with probabilistic solar generation uncertainty

---

## 🎓 Research Paper & Publications

HC-POS was engineered as an academic research and engineering platform at the **Sri Lanka Institute of Information Technology (SLIIT)**, Department of Computer Systems Engineering.

### 📄 Access the Research Paper
* **Full Academic Paper (PDF):** [`Project_Showcase_Symposium_Paper_Title.pdf`](./Project_Showcase_Symposium_Paper_Title.pdf) — Complete compiled symposium research paper ready for reading and citation.
* **Comprehensive Technical Specification (Markdown):** [`HC_POS_Research_Paper.md`](./HC_POS_Research_Paper.md) — Unified thesis document combining the complete software architecture, mathematical optimization proofs, 1D-CNN & LSTM empirical evaluation tables, and comparative economic case studies.

**Key Research Contributions:**
1. **Physics-Informed Waveform Reconstruction:** Bridges the gap between cheap scalar AC meters and high-frequency NILM classifiers without requiring dedicated oscilloscope hardware.
2. **Sri Lanka Time-of-Use (TOU) Mathematical Optimization:** A Mixed-Integer Linear Program formulated under CEB tariffs achieving a verified **36.96% daily electricity cost reduction** and **100% peak grid independence**.
3. **Trilingual Explainable AI (XAI):** A LangChain ReAct agent executing 8 diagnostic tools to explain complex optimization vectors in **Sinhala, Singlish, and English** with strict human-in-the-loop authorization.

```bibtex
@inproceedings{hcpos2026,
  title={HC-POS: A Human-Centric AI and IoT Platform for Residential Energy Orchestration},
  author={Navanjana and Collaborators},
  booktitle={SLIIT Project Showcase & Symposium},
  year={2026},
  organization={Sri Lanka Institute of Information Technology (SLIIT)}
}
```

---

## 🤝 Contributing

Contributions are very welcome! Please follow these steps:

1. **Fork** this repository
2. Create a **feature branch**: `git checkout -b feature/your-awesome-feature`
3. **Make your changes** with descriptive commit messages
4. **Push** to your fork: `git push origin feature/your-awesome-feature`
5. Open a **Pull Request** against `main`

### Code Style Guidelines

| Component | Standard |
|:---|:---|
| Python | PEP 8; docstrings on all public functions; type hints on function signatures |
| Dart/Flutter | [Official Flutter style guide](https://docs.flutter.dev/development/tools/formatting); `flutter analyze` must pass |
| Arduino/C++ | Function-per-concern; comment all pin and register configurations |
| Commits | [Conventional Commits](https://www.conventionalcommits.org/) preferred (`feat:`, `fix:`, `docs:`, etc.) |
| **Secrets** | **ZERO tolerance for credentials in code** — all keys via `.env` only |

---

## 📜 License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- [PuLP](https://coin-or.github.io/pulp/) — Python Linear Programming library
- [LangChain](https://www.langchain.com/) — AI agent orchestration framework
- [NVIDIA NIM](https://build.nvidia.com/) — Nemotron LLM inference API
- [Supabase](https://supabase.com/) — Open-source Firebase alternative with realtime PostgreSQL
- [Flutter](https://flutter.dev/) — Cross-platform UI framework by Google
- [TensorFlow/Keras](https://www.tensorflow.org/) — Deep learning framework
- [PZEM-004T Library](https://github.com/olehs/PZEM004Tv30) — Arduino library by Olehs
- [Adafruit ADS1X15](https://github.com/adafruit/Adafruit_ADS1X15) — Arduino ADC library

---

<div align="center">

**Built with ❤️ at SLIIT, Sri Lanka 🇱🇰**

<br/>

[⭐ Star this repo](https://github.com/Navanjana2005/hc-pos) &nbsp;·&nbsp; [🐛 Report a Bug](https://github.com/Navanjana2005/hc-pos/issues/new?template=bug_report.md) &nbsp;·&nbsp; [💡 Request a Feature](https://github.com/Navanjana2005/hc-pos/issues/new?template=feature_request.md)

<br/>

*If this project helped your research or saved you some time, please consider giving it a ⭐ — it really helps!*

</div>

