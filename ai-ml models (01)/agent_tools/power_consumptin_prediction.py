import joblib
import numpy as np
import tensorflow as tf
import pandas as pd
import os
from langchain.tools import tool

_BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODEL_SAVE_PATH = os.path.join(_BASE_DIR, "lstm_power_model.keras")
SCALER_SAVE_PATH = os.path.join(_BASE_DIR, "power_scaler.pkl")
LOOKBACK_WINDOW = 24

# Path to the raw sensor CSV written by esp32_receiver.py
_RAW_CSV_PATH = os.path.join(_BASE_DIR, "live_sensor_raw.csv")

_FALLBACK_24H = [
    0.42, 0.38, 0.35, 0.36, 0.41, 0.85, 1.45, 2.10, 1.80, 1.20,
    0.95, 0.88, 0.90, 0.92, 1.10, 1.65, 2.40, 3.10, 3.50, 2.80,
    1.90, 1.25, 0.75, 0.50
]


@tool
def get_recent_24h_usage() -> list:
    """Fetches the most recent 24 hours of power consumption data.
    Reads from live_sensor_raw.csv (written by the ESP32 Flask receiver).
    Groups per-second readings into hourly averages (kWh).
    Falls back to synthetic data if the CSV is missing or insufficient.
    """
    try:
        if not os.path.exists(_RAW_CSV_PATH):
            return _FALLBACK_24H

        df = pd.read_csv(_RAW_CSV_PATH, parse_dates=["timestamp"])
        if df.empty or "power_w" not in df.columns or "timestamp" not in df.columns:
            return _FALLBACK_24H

        df = df.dropna(subset=["power_w", "timestamp"])
        df["power_w"] = pd.to_numeric(df["power_w"], errors="coerce")
        df = df.dropna(subset=["power_w"])

        if df.empty:
            return _FALLBACK_24H

        # Resample to hourly averages, then convert W → kWh (W * 1h / 1000)
        df = df.set_index("timestamp").sort_index()
        hourly = df["power_w"].resample("1h").mean().dropna()

        if len(hourly) == 0:
            return _FALLBACK_24H

        # Take the last 24 hours, pad with the oldest value if fewer exist
        values = hourly.tail(24).tolist()
        values = [v / 1000.0 for v in values]  # W → kWh
        while len(values) < 24:
            values.insert(0, values[0] if values else 0.5)

        return values[:24]

    except Exception as exc:
        import logging
        logging.getLogger("hc_pos.power_prediction").warning(
            "get_recent_24h_usage fell back to synthetic data: %s", exc
        )
        return _FALLBACK_24H



_model = None
_scaler = None

def load_artifacts():
    """Loads (and caches) the trained LSTM model and fitted scaler."""
    global _model, _scaler
    if _model is None or _scaler is None:
        _model = tf.keras.models.load_model(MODEL_SAVE_PATH)
        _scaler = joblib.load(SCALER_SAVE_PATH)
    return _model, _scaler


def _predict_next_hour(recent_24h_usage: list) -> float:
    """Plain Python helper — not a LangChain tool — so it can be called normally."""
    model, scaler = load_artifacts()

    recent_array = np.array(recent_24h_usage).reshape(-1, 1)
    scaled_input = scaler.transform(recent_array)
    model_input = np.reshape(scaled_input, (1, LOOKBACK_WINDOW, 1))

    predicted_scaled = model.predict(model_input, verbose=0)
    predicted_kwh = scaler.inverse_transform(predicted_scaled)[0][0]
    return max(0.0, float(predicted_kwh))


@tool
def predict_next_hour(recent_24h_usage: list) -> float:
    """Predicts power consumption for the very next hour."""
    return _predict_next_hour(recent_24h_usage)


@tool
def predict_next_24_hours(recent_24h_usage: list) -> list:
    """Generates an hourly forecast for tomorrow (24 hours ahead) using an autoregressive loop."""
    current_sequence = list(recent_24h_usage)
    predictions_kwh = []

    for _ in range(24):
        input_window = current_sequence[-LOOKBACK_WINDOW:]
        next_kwh = _predict_next_hour(input_window)   # call the plain function, not the tool
        predictions_kwh.append(next_kwh)
        current_sequence.append(next_kwh)

    return [
        f"Hour {hour}: Predicted Power Consumption = {prediction:.2f} kWh"
        for hour, prediction in enumerate(predictions_kwh, start=1)
    ]