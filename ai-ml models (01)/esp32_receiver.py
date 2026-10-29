"""
esp32_receiver.py
=================
Dual-protocol sensor ingestion server for HC-POS (Hardware-in-the-Loop).

Supports BOTH:
  1. ESP32 Direct TCP Socket Stream (as implemented in espcode.ino):
     - Connects via WiFiClient to SERVER_IP:5000
     - Sends newline-delimited JSON
     - Receives newline-delimited JSON status reply
  2. HTTP REST / SSE Stream (port 5000 proxied to internal Flask 5001):
     - POST /data    — JSON ingestion endpoint (for HTTP clients / simulators)
     - GET  /status  — Health check, metrics, row counts
     - GET  /stream  — Server-Sent Events (SSE) for sensor_dashboard.html
     - GET  /ping    — Quick connectivity test

Data Processing & Storage:
  - Writes raw metrics (V, I, P, Solar, SoC, PF, Freq) to live_sensor_raw.csv
  - Synthesizes 860-sample current waveforms from PZEM RMS metrics (or passes
    raw ADC samples if provided) for 1D-CNN NILM classification and writes to
    live_sensor_stream.csv
  - Throttled sync (every 3s) to Supabase table `system_state` for real-time
    Flutter mobile app monitoring
"""

import os
import sys
import csv
import json
import time
import math
import random
import socket
import queue
import logging
import threading
import numpy as np
from datetime import datetime, timezone
from logging.handlers import RotatingFileHandler
from flask import Flask, request, jsonify, Response
from flask_cors import CORS

# Force UTF-8 encoding on standard streams if available (Windows cp1252 fix)
if hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass
if hasattr(sys.stderr, "reconfigure"):
    try:
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

# ---------------------------------------------------------------------------
# Logging setup
# ---------------------------------------------------------------------------
LOG_DIR = os.path.dirname(os.path.abspath(__file__))
LOG_PATH = os.path.join(LOG_DIR, "esp32_receiver.log")

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s - %(message)s",
    handlers=[
        RotatingFileHandler(LOG_PATH, maxBytes=5 * 1024 * 1024, backupCount=3, encoding="utf-8"),
        logging.StreamHandler(sys.stdout),
    ],
)
logger = logging.getLogger("hc_pos.esp32_receiver")

# ---------------------------------------------------------------------------
# Configuration & File Paths
# ---------------------------------------------------------------------------
BASE_DIR = os.path.dirname(os.path.abspath(__file__))

TCP_PORT = 5000     # External port: ESP32 espcode.ino connects here via TCP
FLASK_PORT = 5001   # Internal Flask HTTP / SSE port (HTTP on 5000 is proxied here)

# Raw sensor CSV: consumed by LSTM solar and consumption models
RAW_CSV_PATH = os.path.join(BASE_DIR, "live_sensor_raw.csv")
RAW_CSV_HEADERS = [
    "timestamp",
    "voltage_v",
    "current_a",
    "power_w",
    "solar_power_w",
    "frequency_hz",
    "power_factor",
    "battery_soc_pct",
]

# NILM feature stream CSV: 860-feature windows for the 1D-CNN NILM model
NILM_CSV_PATH = os.path.join(BASE_DIR, "live_sensor_stream.csv")
NILM_WINDOW_SIZE = 860          # Must match 1D-CNN model input size
NILM_MAX_ROWS = 5000            # Rolling cap to prevent unbounded file growth

# Thread-safe locks
_raw_csv_lock = threading.Lock()
_nilm_csv_lock = threading.Lock()

# SSE broadcast queue
_sse_clients: list = []
_sse_lock = threading.Lock()

# Shared latest reading state
_latest: dict = {}
_latest_lock = threading.Lock()

# Supabase sync throttling
_last_supabase_sync = 0.0
_supabase_sync_lock = threading.Lock()

# ---------------------------------------------------------------------------
# NILM Device Profiles (Derived from training dataset generator)
# ---------------------------------------------------------------------------
DEVICE_PROFILES = {
    "HouseHold_Fan-240-150w":  {"harmonics": [(3, 0.12)],            "noise": 0.18},
    "Washing_Machine-1200w":   {"harmonics": [(3, 0.20), (5, 0.08)], "noise": 0.22},
    "Water_Heater-2000w":      {"harmonics": [],                      "noise": 0.10},
    "Refrigerator-150w":       {"harmonics": [(3, 0.15)],            "noise": 0.16},
    "Air_Conditioner-1500w":   {"harmonics": [(3, 0.18), (5, 0.06)], "noise": 0.20},
    "Microwave_Oven-1100w":    {"harmonics": [(2, 0.10), (3, 0.25)], "noise": 0.25},
    "Electric_Iron-1000w":     {"harmonics": [],                      "noise": 0.09},
    "Rice_Cooker-700w":        {"harmonics": [],                      "noise": 0.11},
    "LED_TV-90w":              {"harmonics": [(2, 0.30), (3, 0.15)], "noise": 0.14},
    "Electric_Kettle-1500w":   {"harmonics": [],                      "noise": 0.10},
}


def get_matching_device_profile(power_w: float, pf: float) -> tuple:
    """Matches measured power and power factor to the closest trained device class."""
    if power_w >= 1800:
        return "Water_Heater-2000w", DEVICE_PROFILES["Water_Heater-2000w"]
    elif power_w >= 1350:
        if pf >= 0.96:
            return "Electric_Kettle-1500w", DEVICE_PROFILES["Electric_Kettle-1500w"]
        else:
            return "Air_Conditioner-1500w", DEVICE_PROFILES["Air_Conditioner-1500w"]
    elif power_w >= 1150:
        if pf <= 0.94:
            return "Washing_Machine-1200w", DEVICE_PROFILES["Washing_Machine-1200w"]
        else:
            return "Microwave_Oven-1100w", DEVICE_PROFILES["Microwave_Oven-1100w"]
    elif power_w >= 850:
        return "Electric_Iron-1000w", DEVICE_PROFILES["Electric_Iron-1000w"]
    elif power_w >= 350:
        return "Rice_Cooker-700w", DEVICE_PROFILES["Rice_Cooker-700w"]
    elif power_w >= 110:
        if pf < 0.90:
            return "HouseHold_Fan-240-150w", DEVICE_PROFILES["HouseHold_Fan-240-150w"]
        else:
            return "Refrigerator-150w", DEVICE_PROFILES["Refrigerator-150w"]
    else:
        return "LED_TV-90w", DEVICE_PROFILES["LED_TV-90w"]


def synthesize_waveform_from_pzem(current_a: float, pf: float, power_w: float, freq_hz: float = 50.0) -> list:
    """
    Synthesizes a realistic 860-sample AC current waveform window in Amperes
    matching the physical PZEM-004T readings from the ESP32.
    """
    # If load is below idle threshold (<0.08A or <10W), produce realistic quiescent noise
    if current_a < 0.08 or power_w < 10.0:
        return np.random.normal(0.0, 0.04, NILM_WINDOW_SIZE).tolist()

    name, profile = get_matching_device_profile(power_w, pf)
    t = np.linspace(0.0, 1.0, NILM_WINDOW_SIZE, endpoint=False)
    freq = freq_hz if (45.0 <= freq_hz <= 65.0) else 50.0

    # Fundamental peak amplitude: I_peak = sqrt(2) * I_rms
    amp = max(0.1, current_a * 1.4142)

    signal = amp * np.sin(2.0 * np.pi * freq * t)
    for harmonic_mult, rel_amp in profile.get("harmonics", []):
        signal += (amp * rel_amp) * np.sin(2.0 * np.pi * (freq * harmonic_mult) * t)

    noise_amp = profile.get("noise", 0.15)
    signal += np.random.normal(0.0, noise_amp, NILM_WINDOW_SIZE)

    return signal.tolist()


def _process_waveform_to_features(raw_waveform: list) -> list:
    """Convert raw ADC waveform samples from ESP32 into 860 features."""
    arr = np.array(raw_waveform, dtype=float)
    if np.max(np.abs(arr)) > 50.0:
        # Raw 12-bit ADC counts: centre around 2048 and scale to Amperes
        arr = (arr - 2048.0) / 100.0

    if len(arr) >= NILM_WINDOW_SIZE:
        arr = arr[-NILM_WINDOW_SIZE:]
    else:
        pad = np.zeros(NILM_WINDOW_SIZE - len(arr))
        arr = np.concatenate([pad, arr])

    return arr.tolist()


# ---------------------------------------------------------------------------
# CSV Persistence Helpers
# ---------------------------------------------------------------------------

def _ensure_raw_csv():
    """Create live_sensor_raw.csv with headers if it doesn't exist yet."""
    if not os.path.exists(RAW_CSV_PATH):
        with open(RAW_CSV_PATH, "w", newline="", encoding="utf-8") as f:
            writer = csv.writer(f)
            writer.writerow(RAW_CSV_HEADERS)
        logger.info("Created %s with headers.", RAW_CSV_PATH)


def _ensure_nilm_csv(feature_cols: list):
    """Create live_sensor_stream.csv with headers if it doesn't exist yet."""
    if not os.path.exists(NILM_CSV_PATH):
        with open(NILM_CSV_PATH, "w", newline="", encoding="utf-8") as f:
            writer = csv.writer(f)
            writer.writerow(["timestamp"] + feature_cols)
        logger.info("Created %s with headers.", NILM_CSV_PATH)


def _append_raw_row(row: dict):
    """Thread-safe append of one row to live_sensor_raw.csv."""
    _ensure_raw_csv()
    with _raw_csv_lock:
        with open(RAW_CSV_PATH, "a", newline="", encoding="utf-8") as f:
            writer = csv.DictWriter(f, fieldnames=RAW_CSV_HEADERS, extrasaction="ignore")
            writer.writerow(row)


def _append_nilm_row(timestamp: str, features: list):
    """
    Thread-safe append of one 860-feature row to live_sensor_stream.csv.
    Enforces rolling cap: keeps the last NILM_MAX_ROWS.
    """
    feature_cols = [f"feature_{i}" for i in range(len(features))]
    _ensure_nilm_csv(feature_cols)

    with _nilm_csv_lock:
        rows = []
        if os.path.exists(NILM_CSV_PATH):
            try:
                with open(NILM_CSV_PATH, "r", newline="", encoding="utf-8") as f:
                    reader = csv.reader(f)
                    rows = list(reader)
            except Exception as e:
                logger.warning("Could not read NILM CSV for trimming: %s", e)

        header = rows[0] if rows else ["timestamp"] + feature_cols
        data_rows = rows[1:] if len(rows) > 1 else []

        new_row = [timestamp] + [str(round(v, 4)) for v in features]
        data_rows.append(new_row)

        if len(data_rows) > NILM_MAX_ROWS:
            data_rows = data_rows[-NILM_MAX_ROWS:]

        with open(NILM_CSV_PATH, "w", newline="", encoding="utf-8") as f:
            writer = csv.writer(f)
            writer.writerow(header)
            writer.writerows(data_rows)


# ---------------------------------------------------------------------------
# Supabase & SSE Helpers
# ---------------------------------------------------------------------------

def _broadcast_sse(data: dict):
    """Push a reading to all connected SSE clients."""
    payload = f"data: {json.dumps(data)}\n\n"
    dead = []
    with _sse_lock:
        for q in _sse_clients:
            try:
                q.put_nowait(payload)
            except queue.Full:
                dead.append(q)
        for q in dead:
            _sse_clients.remove(q)


def _sync_supabase_system_state(reading: dict):
    """Sync latest telemetry to Supabase system_state in a daemon thread.
    Throttled to once every 3 seconds.
    """
    global _last_supabase_sync
    now = time.time()
    with _supabase_sync_lock:
        if now - _last_supabase_sync < 3.0:
            return
        _last_supabase_sync = now

    def _worker():
        try:
            from supabase_client import (
                insert_telemetry,
                upsert_system_state,
                is_supabase_configured,
            )
            if not is_supabase_configured():
                return

            solar = float(reading.get("solar_power_w") or 0.0)
            load = float(reading.get("power_w") or 0.0)
            soc = float(reading.get("battery_soc_pct") or 50.0)

            if solar > load and solar > 10.0:
                source = "solar"
            elif soc > 20.0 and load > 0.0:
                source = "battery"
            else:
                source = "grid"

            upsert_system_state({
                "solar_generation_w": round(solar, 2),
                "whole_house_power_w": round(load, 2),
                "battery_soc_pct": round(soc, 2),
                "battery_health_pct": 100.0,
                "current_power_source": source,
                "automation_mode": "auto",
                "emergency_stop_active": False,
            })
            recorded_at = reading.get("timestamp") or datetime.now(timezone.utc).isoformat()
            insert_telemetry([
                {
                    "metric_type": "solar_generation_w",
                    "value": round(solar, 2),
                    "recorded_at": recorded_at,
                },
                {
                    "metric_type": "whole_house_power_w",
                    "value": round(load, 2),
                    "recorded_at": recorded_at,
                },
            ])
        except Exception as exc:
            logger.debug("Supabase system_state sync error: %s", exc)

    threading.Thread(target=_worker, daemon=True).start()


# ---------------------------------------------------------------------------
# Core Telemetry Ingestion Logic
# ---------------------------------------------------------------------------

def process_telemetry_reading(payload: dict) -> dict:
    """
    Core function called by both the TCP socket server and HTTP POST /data.
    Writes raw CSV, updates NILM features, updates latest state, and syncs Supabase.
    """
    ts = payload.get("timestamp") or datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S")

    v = float(payload.get("voltage_v") or 0.0)
    i = float(payload.get("current_a") or 0.0)
    p = float(payload.get("power_w") or 0.0)
    solar = float(payload.get("solar_power_w") or 0.0)
    freq = float(payload.get("frequency_hz") or 50.0)
    pf = float(payload.get("power_factor") or 1.0)
    soc = float(payload.get("battery_soc_pct") or 50.0)

    # 1. Append to raw sensor CSV
    raw_row = {
        "timestamp":       ts,
        "voltage_v":       round(v, 2),
        "current_a":       round(i, 3),
        "power_w":         round(p, 2),
        "solar_power_w":   round(solar, 2),
        "frequency_hz":    round(freq, 2),
        "power_factor":    round(pf, 3),
        "battery_soc_pct": round(soc, 1),
    }
    _append_raw_row(raw_row)

    # 2. Append to NILM feature stream CSV
    raw_waveform = payload.get("raw_waveform")
    if raw_waveform and isinstance(raw_waveform, list) and len(raw_waveform) > 0:
        features = _process_waveform_to_features(raw_waveform)
        nilm_mode = "waveform"
    else:
        features = synthesize_waveform_from_pzem(current_a=i, pf=pf, power_w=p, freq_hz=freq)
        nilm_mode = "synthesized"

    _append_nilm_row(ts, features)

    # 3. Update cached state & broadcast
    reading = {
        "timestamp":           ts,
        "voltage_v":           v,
        "current_a":           i,
        "power_w":             p,
        "solar_power_w":       solar,
        "frequency_hz":        freq,
        "power_factor":        pf,
        "battery_soc_pct":     soc,
        "nilm_window_written": True,
        "nilm_mode":           nilm_mode,
    }
    with _latest_lock:
        _latest.update(reading)

    _broadcast_sse(reading)
    _sync_supabase_system_state(reading)

    logger.info(
        "[OK] Telemetry | V=%.1fV | I=%.3fA | P=%.1fW | Solar=%.1fW | SoC=%.1f%% | NILM=%s",
        v, i, p, solar, soc, nilm_mode,
    )

    return {
        "status": "ok",
        "timestamp": ts,
        "raw_csv": "written",
        "nilm_csv": nilm_mode,
    }


# ---------------------------------------------------------------------------
# Flask App (Routes)
# ---------------------------------------------------------------------------
app = Flask(__name__)
CORS(app)


@app.route("/", methods=["GET"])
def home():
    return jsonify({
        "status": "online",
        "service": "HC-POS ESP32 Ingestion Receiver",
        "tcp_port": TCP_PORT,
        "http_port": FLASK_PORT,
        "endpoints": ["POST /data", "GET /status", "GET /stream", "GET /ping"],
    })


@app.route("/data", methods=["POST"])
def ingest_data():
    """HTTP POST ingestion endpoint (fallback for HTTP ESP32 / simulators)."""
    if not request.is_json:
        return jsonify({"error": "Content-Type must be application/json"}), 400

    payload = request.get_json(silent=True)
    if not payload:
        return jsonify({"error": "Empty or malformed JSON body"}), 400

    res = process_telemetry_reading(payload)
    return jsonify(res), 200


@app.route("/status", methods=["GET"])
def status():
    """Health check and latest reading summary."""
    with _latest_lock:
        latest_copy = dict(_latest)

    raw_rows = 0
    nilm_rows = 0
    try:
        if os.path.exists(RAW_CSV_PATH):
            with open(RAW_CSV_PATH, "r", encoding="utf-8") as f:
                raw_rows = max(0, sum(1 for _ in f) - 1)
        if os.path.exists(NILM_CSV_PATH):
            with open(NILM_CSV_PATH, "r", encoding="utf-8") as f:
                nilm_rows = max(0, sum(1 for _ in f) - 1)
    except Exception:
        pass

    return jsonify({
        "status": "ok",
        "service": "HC-POS ESP32 Receiver",
        "tcp_port": TCP_PORT,
        "http_port": FLASK_PORT,
        "raw_csv_rows": raw_rows,
        "nilm_csv_rows": nilm_rows,
        "latest_reading": latest_copy or "no data yet",
        "server_time": datetime.now(timezone.utc).isoformat(),
    })


@app.route("/stream", methods=["GET"])
def stream():
    """Server-Sent Events endpoint for sensor_dashboard.html."""
    client_queue: queue.Queue = queue.Queue(maxsize=50)
    with _sse_lock:
        _sse_clients.append(client_queue)

    def event_generator():
        yield "data: {\"event\": \"connected\"}\n\n"
        try:
            while True:
                try:
                    msg = client_queue.get(timeout=30)
                    yield msg
                except queue.Empty:
                    yield ": keepalive\n\n"
        except GeneratorExit:
            pass
        finally:
            with _sse_lock:
                if client_queue in _sse_clients:
                    _sse_clients.remove(client_queue)

    return Response(
        event_generator(),
        mimetype="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "X-Accel-Buffering": "no",
        },
    )


@app.route("/ping", methods=["GET"])
def ping():
    return jsonify({"pong": True, "server_time": datetime.now(timezone.utc).isoformat()})


# ---------------------------------------------------------------------------
# Port 5000 Dual TCP Socket & HTTP Proxy Handler
# ---------------------------------------------------------------------------

def _proxy_http_to_flask(conn: socket.socket, initial_chunk: bytes):
    """Proxies an incoming HTTP request on port 5000 to internal Flask on port 5001."""
    flask_sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    try:
        flask_sock.connect(("127.0.0.1", FLASK_PORT))
        flask_sock.sendall(initial_chunk)

        def pipe(src, dst):
            try:
                while True:
                    data = src.recv(4096)
                    if not data:
                        break
                    dst.sendall(data)
            except Exception:
                pass
            finally:
                try:
                    dst.shutdown(socket.SHUT_WR)
                except Exception:
                    pass

        t1 = threading.Thread(target=pipe, args=(conn, flask_sock), daemon=True)
        t2 = threading.Thread(target=pipe, args=(flask_sock, conn), daemon=True)
        t1.start()
        t2.start()
        t1.join()
        t2.join()
    except Exception as exc:
        logger.debug("HTTP proxy error: %s", exc)
    finally:
        try:
            flask_sock.close()
        except Exception:
            pass


def _handle_client_connection(conn: socket.socket, addr):
    """
    Inspects the incoming connection on port 5000:
    - If HTTP (GET, POST, OPTIONS, HEAD), forwards to Flask on port 5001.
    - If raw ESP32 JSON TCP socket (from espcode.ino), ingests telemetry and
      responds with newline-delimited JSON.
    """
    try:
        conn.settimeout(15.0)
        initial_chunk = conn.recv(1024)
        if not initial_chunk:
            return

        is_http = any(
            initial_chunk.startswith(m)
            for m in [b"GET ", b"POST ", b"PUT ", b"HEAD ", b"OPTIONS ", b"DELETE "]
        )

        if is_http:
            _proxy_http_to_flask(conn, initial_chunk)
        else:
            # Raw TCP newline-delimited JSON from espcode.ino
            buffer = initial_chunk
            while b"\n" not in buffer:
                chunk = conn.recv(1024)
                if not chunk:
                    break
                buffer += chunk

            line = buffer.decode("utf-8", errors="replace").strip()
            if line:
                try:
                    payload = json.loads(line)
                    result = process_telemetry_reading(payload)
                    reply = (json.dumps(result) + "\n").encode("utf-8")
                    conn.sendall(reply)
                except json.JSONDecodeError as err:
                    logger.warning("Invalid JSON from %s: %s", addr, err)
                    conn.sendall(b'{"status":"error","message":"invalid json"}\n')
    except Exception as exc:
        logger.debug("Connection handling exception from %s: %s", addr, exc)
    finally:
        try:
            conn.close()
        except Exception:
            pass


def _start_tcp_server():
    """Starts the TCP listener on 0.0.0.0:5000."""
    server_sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server_sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server_sock.bind(("0.0.0.0", TCP_PORT))
    server_sock.listen(128)
    logger.info("TCP socket listener active on 0.0.0.0:%d (ESP32 hardware target)", TCP_PORT)

    while True:
        try:
            conn, addr = server_sock.accept()
            client_thread = threading.Thread(
                target=_handle_client_connection,
                args=(conn, addr),
                daemon=True,
            )
            client_thread.start()
        except Exception as exc:
            logger.error("Error accepting TCP connection: %s", exc)
            time.sleep(0.5)


# ---------------------------------------------------------------------------
# Entry Point
# ---------------------------------------------------------------------------
if __name__ == "__main__":
    logger.info("=" * 60)
    logger.info("HC-POS Dual-Protocol ESP32 Receiver starting...")
    logger.info("Raw CSV  -> %s", RAW_CSV_PATH)
    logger.info("NILM CSV -> %s", NILM_CSV_PATH)
    logger.info("=" * 60)
    logger.info("Port 5000: Dual TCP + HTTP Listener (matches espcode.ino)")
    logger.info("Port 5001: Internal / Direct Flask HTTP Server")
    logger.info("Endpoints:")
    logger.info("  TCP  0.0.0.0:5000       - espcode.ino WiFiClient sends JSON here")
    logger.info("  POST http://localhost:5000/data   - HTTP JSON ingestion")
    logger.info("  GET  http://localhost:5000/status - Health check & stats")
    logger.info("  GET  http://localhost:5000/stream - SSE for sensor_dashboard.html")
    logger.info("  GET  http://localhost:5000/ping   - Quick connectivity test")
    logger.info("=" * 60)

    _ensure_raw_csv()

    # 1. Start background Flask server on port 5001
    flask_thread = threading.Thread(
        target=lambda: app.run(
            host="0.0.0.0",
            port=FLASK_PORT,
            debug=False,
            threaded=True,
            use_reloader=False,
        ),
        daemon=True,
    )
    flask_thread.start()

    # Small sleep to let Flask bind port 5001 before TCP listener starts proxying
    time.sleep(0.5)

    # 2. Start main TCP socket server on port 5000 (blocks main thread)
    _start_tcp_server()
