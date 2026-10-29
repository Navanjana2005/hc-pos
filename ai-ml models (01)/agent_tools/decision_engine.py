"""
HC-POS Decision Engine
=======================
Mixed-Integer Linear Program (MILP) for smart home energy orchestration,
plus a thin AI-agent tool layer on top of it.

pip install pulp langchain-core --break-system-packages

HOW THIS FILE IS ORGANIZED (read top to bottom):
  1. CONFIG           - static fallback values, edit freely
  2. DATA MODELS       - Appliance / SystemInputs
  3. LIVE DATA LAYER    - where your ML models (solar, consumption, NILM)
                         plug in. Everything else in the file only ever
                         talks to SystemInputs, never to your models
                         directly, so new models never touch the MILP code.
  4. MILP MODEL         - the actual optimizer, rarely needs editing
  5. SOLVE + EXTRACT     - runs the solver, turns results into plain dicts
  6. ANALYSIS            - cost, savings baseline, infeasibility diagnosis
  7. AGENT PAYLOAD        - compact/labeled JSON for the LLM agent
  8. AGENT TOOLS          - @tool functions the agent actually calls

If you're adding a new feature, you almost always want section 3 (new
data source) or section 8 (new tool) — you should rarely need to touch
section 4.
"""

from dataclasses import dataclass, field, replace as dc_replace
from typing import Dict, List, Tuple, Optional
from datetime import datetime, timezone, timedelta
import os
import logging
import numpy as np
import pandas as pd
import tensorflow as tf
import joblib

from pulp import LpProblem, LpMinimize, LpVariable, lpSum, LpStatus, PULP_CBC_CMD
from langchain_core.tools import tool

logger = logging.getLogger("hc_pos.decision_engine")


# ==========================================================================
# 1. CONFIG — fallback values used whenever a live model isn't available
#    yet, fails, or returns something invalid. Edit these freely; nothing
#    below this section should need to change when you tune numbers.
# ==========================================================================

HORIZON_HOURS: int = 24

SOLAR_FORECAST_KW: List[float] = [
    0, 0, 0, 0, 0, 1, 2, 3, 4, 5, 5, 4, 4, 3, 2, 1, 0.5, 0, 0, 0, 0, 0, 0, 0,
]
CONSUMPTION_FORECAST_KW: List[float] = [0.5] * HORIZON_HOURS

TARIFF_PEAK: float = 8.0
TARIFF_OFFPEAK: float = 5.0
PEAK_HOURS: Tuple[int, int] = (8, 22)  # [start, end) — end hour is exclusive

BATTERY_SOC_NOW_KWH: float = 7.0
BATTERY_CAPACITY_KWH: float = 10.0
BATTERY_MAX_RATE_KW: float = 3.0
BATTERY_SOC_MIN_FRAC: float = 0.2
BATTERY_SOC_MAX_FRAC: float = 0.9

CURTAILMENT_PENALTY_WEIGHT: float = 1e-3


# ==========================================================================
# 2. DATA MODELS
# ==========================================================================

@dataclass
class Appliance:
    energy: float               # total kWh required to complete one run
    priority: float              # penalty weight if the run is missed
    deadline: int                 # must finish by this hour (exclusive), relative to "now"
    work_time: float = 1.0        # hours the appliance needs to run continuously


# ==========================================================================
# 2.5 DEVICE CATALOG — loaded from CSV, not hardcoded, and not a database.
#    device_catalog.csv (one directory above this file) is the single
#    source of truth for which appliances the system knows how to
#    schedule and what their MILP parameters are. Required columns:
#        device_name, energy_kwh, priority, deadline_hour, work_time_hours
#    Add/remove/edit a device by editing that CSV — no code change needed.
# ==========================================================================

DEVICE_CATALOG_CSV = os.path.join(os.path.dirname(os.path.dirname(__file__)), "device_catalog.csv")
_REQUIRED_CATALOG_COLUMNS = {"device_name", "energy_kwh", "priority", "deadline_hour", "work_time_hours"}

_device_catalog_cache: Optional[Dict[str, "Appliance"]] = None


def load_device_catalog(path: str = DEVICE_CATALOG_CSV, force_reload: bool = False) -> Dict[str, "Appliance"]:
    """Load the appliance catalog from CSV. Cached after the first
    successful load; pass force_reload=True if the CSV changes at runtime.

    Returns an empty dict — never a fabricated device list — if the file
    is missing or malformed, so callers can tell the difference between
    "no devices detected" and "no catalog available" instead of silently
    inventing appliances.
    """
    global _device_catalog_cache
    if _device_catalog_cache is not None and not force_reload:
        return _device_catalog_cache

    if not os.path.exists(path):
        logger.error(f"Device catalog CSV not found at {path}. No appliances are schedulable until it exists.")
        return {}

    try:
        df = pd.read_csv(path)
        missing_cols = _REQUIRED_CATALOG_COLUMNS - set(df.columns)
        if missing_cols:
            logger.error(f"Device catalog CSV is missing required columns: {missing_cols}")
            return {}

        catalog = {
            str(row["device_name"]): Appliance(
                energy=float(row["energy_kwh"]),
                priority=float(row["priority"]),
                deadline=int(row["deadline_hour"]),
                work_time=float(row["work_time_hours"]),
            )
            for _, row in df.iterrows()
        }
    except Exception as e:
        logger.error(f"Failed to read device catalog CSV at {path}: {e}")
        return {}

    _device_catalog_cache = catalog
    return catalog


# ==========================================================================
# 2.6 DEVICE LABEL MAP — maps the trained NILM model's output class index
#    to a device name. Generated alongside the training data by
#    generate_test_stream.py, so index order always matches what the model
#    was actually trained on.
# ==========================================================================

DEVICE_LABEL_MAP_CSV = os.path.join(os.path.dirname(os.path.dirname(__file__)), "device_label_map.csv")

_label_map_cache: Optional[Dict[int, str]] = None


def load_device_label_map(path: str = DEVICE_LABEL_MAP_CSV, force_reload: bool = False) -> Dict[int, str]:
    global _label_map_cache
    if _label_map_cache is not None and not force_reload:
        return _label_map_cache

    if not os.path.exists(path):
        logger.error(f"Device label map CSV not found at {path}. NILM predictions cannot be decoded.")
        return {}

    try:
        df = pd.read_csv(path)
        label_map = {int(row["label"]): str(row["device_name"]) for _, row in df.iterrows()}
    except Exception as e:
        logger.error(f"Failed to read device label map CSV at {path}: {e}")
        return {}

    _label_map_cache = label_map
    return label_map


# ==========================================================================
# 2.5 ML MODEL INTEGRATION
# ==========================================================================
_fan_model = None

def get_ml_model():
    global _fan_model
    if _fan_model is None:
        try:
            base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
            # Check 1dcnn_model.keras first, fallback to fan_1dcnn_model.keras
            model_path = os.path.join(base_dir, "1dcnn_model.keras")
            if not os.path.exists(model_path):
                model_path = os.path.join(base_dir, "fan_1dcnn_model.keras")
            _fan_model = tf.keras.models.load_model(model_path)
            logger.info("Loaded 1D-CNN model successfully from %s", model_path)
        except Exception as e:
            logger.error("Failed to load 1D-CNN model: %s", e)
    return _fan_model

LIVE_SENSOR_CSV = os.path.join(os.path.dirname(os.path.dirname(__file__)), "live_sensor_stream.csv")
SENSOR_WINDOW_SIZE = 860
RMS_IDLE_THRESHOLD = 0.25


def read_sensor_windows(path: str = LIVE_SENSOR_CSV, lookback_rows: int = 1) -> Optional[np.ndarray]:
    """Reads the last `lookback_rows` windows the real system has written to
    the live sensor CSV feed. Expects columns feature_0..feature_859 (any
    extra columns, e.g. a timestamp, are ignored). Returns an array of shape
    (rows_available, 860), or None if the file is missing/empty/malformed —
    this never fabricates a reading the way the old in-memory generator did.
    """
    if not os.path.exists(path):
        logger.warning(f"Live sensor CSV not found at {path}.")
        return None

    try:
        df = pd.read_csv(path)
        feature_cols = [c for c in df.columns if c.startswith("feature_")]
        if len(feature_cols) != SENSOR_WINDOW_SIZE:
            logger.error(
                f"Live sensor CSV has {len(feature_cols)} feature_* columns, "
                f"expected {SENSOR_WINDOW_SIZE}."
            )
            return None
        if df.empty:
            return None
        return df.tail(lookback_rows)[feature_cols].to_numpy(dtype=float)
    except Exception as e:
        logger.error(f"Failed to read live sensor CSV at {path}: {e}")
        return None


def run_nilm_inference() -> dict:
    """Runs inference on the single most recent window in the live sensor
    CSV and returns the RAW result: label, confidence, and where the data
    came from. Source of truth for "what did the NILM model just detect" —
    nothing else in this file should re-derive detection from the MILP
    schedule, which is a 24h plan, not a live reading.

    The model is expected to output a softmax over N device classes
    (see generate_test_stream.py / device_label_map.csv), not the old
    single sigmoid fan/other output.
    """
    windows = read_sensor_windows(lookback_rows=1)
    if windows is None or len(windows) == 0:
        return {"label": None, "confidence": None, "data_source": "missing_csv", "error": "no_sensor_data"}

    window = windows[-1]
    rms_current = np.sqrt(np.mean(window ** 2))
    if rms_current < RMS_IDLE_THRESHOLD:
        return {"label": "Idle / No Device", "confidence": 1.0, "data_source": "csv_file"}

    model = get_ml_model()
    if model is None:
        return {"label": None, "confidence": None, "data_source": "csv_file", "error": "model_not_loaded"}

    label_map = load_device_label_map()
    if not label_map:
        return {"label": None, "confidence": None, "data_source": "csv_file", "error": "label_map_unavailable"}

    probs = model.predict(window.reshape(1, SENSOR_WINDOW_SIZE, 1), verbose=0)[0]
    idx = int(np.argmax(probs))
    confidence = float(probs[idx])
    label = label_map.get(idx, f"class_{idx}")
    return {
        "label": label,
        "confidence": round(confidence, 3),
        "data_source": "csv_file",
        "class_probabilities": {
            label_map.get(i, f"class_{i}"): round(float(p), 3) for i, p in enumerate(probs)
        },
    }


def detect_recent_devices(path: str = LIVE_SENSOR_CSV, lookback_rows: int = 10) -> List[dict]:
    """Classifies each of the last `lookback_rows` windows in the live
    sensor CSV independently and aggregates the distinct devices seen.

    This is how a single-label-per-window classifier honestly answers
    "what devices are connected right now" for MULTIPLE devices: by looking
    across a few seconds of recent readings, not by claiming several
    simultaneous devices out of one window (the model architecturally
    can't do that — it emits exactly one label per window).
    """
    windows = read_sensor_windows(path=path, lookback_rows=lookback_rows)
    if windows is None or len(windows) == 0:
        return []

    model = get_ml_model()
    label_map = load_device_label_map()
    if model is None or not label_map:
        return []

    tallies: Dict[str, dict] = {}
    for window in windows:
        rms_current = np.sqrt(np.mean(window ** 2))
        if rms_current < RMS_IDLE_THRESHOLD:
            continue  # idle window — nothing connected in this second

        probs = model.predict(window.reshape(1, SENSOR_WINDOW_SIZE, 1), verbose=0)[0]
        idx = int(np.argmax(probs))
        confidence = float(probs[idx])
        label = label_map.get(idx, f"class_{idx}")

        entry = tallies.setdefault(label, {"device": label, "windows_seen": 0, "confidence_sum": 0.0})
        entry["windows_seen"] += 1
        entry["confidence_sum"] += confidence

    results = []
    for e in tallies.values():
        avg_conf = round(e["confidence_sum"] / e["windows_seen"], 3)
        # Suppress single-window spurious blips when multiple windows are available
        if len(windows) >= 3 and e["windows_seen"] < 2 and avg_conf < 0.85:
            continue
        results.append({
            "device": e["device"],
            "windows_seen": e["windows_seen"],
            "avg_confidence": avg_conf,
        })
    return results


def detect_appliances_from_sensor() -> List[str]:
    """Thin wrapper for the MILP appliance-config path below, which only
    needs distinct device names seen recently, not confidence/source info."""
    return [d["device"] for d in detect_recent_devices()]


@dataclass
class SystemInputs:
    horizon: int = HORIZON_HOURS
    solar_forecast: List[float] = field(default_factory=lambda: list(SOLAR_FORECAST_KW))
    consumption_forecast: List[float] = field(default_factory=lambda: list(CONSUMPTION_FORECAST_KW))
    tariff_peak: float = TARIFF_PEAK
    tariff_offpeak: float = TARIFF_OFFPEAK
    peak_hours: Tuple[int, int] = PEAK_HOURS
    battery_soc_now: float = BATTERY_SOC_NOW_KWH
    battery_capacity: float = BATTERY_CAPACITY_KWH
    battery_max_rate: float = BATTERY_MAX_RATE_KW
    soc_min_frac: float = BATTERY_SOC_MIN_FRAC
    soc_max_frac: float = BATTERY_SOC_MAX_FRAC
    curtailment_weight: float = CURTAILMENT_PENALTY_WEIGHT
    appliances: Dict[str, Appliance] = field(default_factory=lambda: dict(load_device_catalog()))

    # Real-world clock hour that t=0 in this solve corresponds to. Defaults
    # to 0 (midnight) for a "plan the whole day" solve. Set this to the
    # current hour when re-solving mid-day with fresh live forecasts, so
    # peak/off-peak tariffs line up with the real clock instead of always
    # assuming t=0 is midnight.
    start_hour: int = 0

    def tariff_schedule(self) -> List[float]:
        lo, hi = self.peak_hours
        return [
            self.tariff_peak if lo <= (self.start_hour + t) % 24 < hi else self.tariff_offpeak
            for t in range(self.horizon)
        ]

    def tariff_period_at(self, t: int) -> str:
        lo, hi = self.peak_hours
        return "peak" if lo <= (self.start_hour + t) % 24 < hi else "off_peak"


def appliance_work_hours(appl: Appliance) -> int:
    """Round work_time to whole hours, since the MILP is hourly-granular.
    Always at least 1 hour."""
    return max(1, round(appl.work_time))


# ==========================================================================
# 3. LIVE DATA LAYER — plug your ML models in here.
#
# Everything below returns a SystemInputs. Nothing else in this file talks
# to your models directly — add a new model by writing one function here
# and wiring it into build_live_inputs(). The MILP and the agent tools
# never need to change.
# ==========================================================================

# ── Raw sensor CSV written by esp32_receiver.py ────────────────────────────
RAW_SENSOR_CSV = os.path.join(os.path.dirname(os.path.dirname(__file__)), "live_sensor_raw.csv")


def read_raw_sensor_data(column: str, lookback_hours: int = 24) -> Optional[List[float]]:
    """Read `lookback_hours` of hourly-averaged data from live_sensor_raw.csv.

    This is the preferred data source for seeding the Solar and Consumption
    LSTM models.  Uses real per-second V/I/Power/Solar readings written by
    the ESP32 Flask receiver and resamples them to hourly kW averages.

    Args:
        column:        One of 'power_w' or 'solar_power_w'.
        lookback_hours: How many hourly values to return (default 24).

    Returns:
        List of floats (kW, not W) or None if the file is missing / column
        is absent / not enough rows.
    """
    if not os.path.exists(RAW_SENSOR_CSV):
        logger.warning("live_sensor_raw.csv not found — falling back to NILM-RMS seed.")
        return None

    try:
        df = pd.read_csv(RAW_SENSOR_CSV)
        if df.empty or column not in df.columns or "timestamp" not in df.columns:
            return None

        # Normalize old naive rows and newer offset-aware rows to one index type.
        df["timestamp"] = pd.to_datetime(df["timestamp"], errors="coerce", utc=True)
        df = df.dropna(subset=[column, "timestamp"])
        df[column] = pd.to_numeric(df[column], errors="coerce")
        df = df.dropna(subset=[column])

        if df.empty:
            return None

        df = df.set_index("timestamp").sort_index()
        hourly = df[column].resample("1h").mean().dropna()

        if len(hourly) == 0:
            return None

        # Convert W → kW and return the last `lookback_hours` values
        values = [v / 1000.0 for v in hourly.tail(lookback_hours).tolist()]
        logger.info(
            "read_raw_sensor_data: %d hourly values from '%s' column.",
            len(values), column
        )
        return values

    except Exception as exc:
        logger.error("read_raw_sensor_data failed for column '%s': %s", column, exc)
        return None


# ── Solar LSTM model cache ──────────────────────────────────────────────────
_solar_model = None
_solar_scaler = None

SOLAR_MODEL_PATH = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "lstm_solar_model.keras")
SOLAR_SCALER_PATH = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "solar_scaler.pkl")
SOLAR_LOOKBACK = 24  # the model was trained with a 24-step lookback window


def _get_solar_model():
    global _solar_model, _solar_scaler
    if _solar_model is None:
        try:
            _solar_model = tf.keras.models.load_model(SOLAR_MODEL_PATH)
            logger.info("Loaded LSTM solar model.")
        except Exception as exc:
            logger.error("Failed to load solar LSTM model: %s", exc)
    if _solar_scaler is None:
        try:
            scaler_path = SOLAR_SCALER_PATH
            if not os.path.exists(scaler_path):
                scaler_path = os.path.join(os.path.dirname(SOLAR_SCALER_PATH), "scaler.pkl")
            _solar_scaler = joblib.load(scaler_path)
            logger.info("Loaded solar scaler from %s.", scaler_path)
        except Exception as exc:
            logger.error("Failed to load solar scaler: %s", exc)
    return _solar_model, _solar_scaler


def get_solar_forecast() -> Optional[List[float]]:
    """Call the LSTM solar model to produce a 24-hour solar generation
    forecast (kW per hour). Falls back to None on any failure so
    build_live_inputs() can substitute the static default.

    Seed priority:
      1. live_sensor_raw.csv solar_power_w column (ESP32 real data via Flask)
      2. RMS of NILM windows in live_sensor_stream.csv (legacy approximation)
      3. Diurnal solar model curve
    """
    model, scaler = _get_solar_model()
    if model is None or scaler is None:
        return None

    # Preferred: real solar readings from live_sensor_raw.csv
    seed = read_raw_sensor_data("solar_power_w", lookback_hours=SOLAR_LOOKBACK)

    if seed is None:
        windows = read_sensor_windows(lookback_rows=SOLAR_LOOKBACK)
        if windows is not None and len(windows) >= SOLAR_LOOKBACK:
            seed = [float(np.sqrt(np.mean(w ** 2))) / 1000.0 for w in windows[-SOLAR_LOOKBACK:]]
        else:
            seed = [0.0] * SOLAR_LOOKBACK

    while len(seed) < SOLAR_LOOKBACK:
        seed.insert(0, seed[0] if seed else 0.0)
    seed = seed[-SOLAR_LOOKBACK:]

    try:
        now_hour = datetime.now().hour
        predictions: List[float] = []
        recent_solar = list(seed)

        for step in range(HORIZON_HOURS):
            target_hour = (now_hour + step) % 24
            # Outside daylight hours (6am - 6pm), solar generation is 0.0
            if target_hour < 6 or target_hour > 18:
                predictions.append(0.0)
                recent_solar.append(0.0)
                continue

            # Model expects 7 features:
            # ['Elevation', 'Temperature', 'Humidity', 'Solar_Irradiance', 'Cloud_Cover', 'Wind_Speed', 'Solar_Production']
            hours = np.array([(now_hour + step - 24 + i) % 24 for i in range(24)])
            elev = np.maximum(0.0, np.sin(np.pi * (hours - 6) / 12) * 80.0)
            temp = 26.0 + 7.0 * np.sin(np.pi * (hours - 6) / 12)
            hum = 75.0 - 15.0 * np.sin(np.pi * (hours - 6) / 12)
            irr = np.maximum(0.0, elev * 10.0)
            cloud = np.full(24, 20.0)
            wind = np.full(24, 3.5)
            prod = np.array(recent_solar[-24:], dtype=float)

            feat_24 = np.column_stack([elev, temp, hum, irr, cloud, wind, prod])
            scaled_feat = scaler.transform(feat_24)
            x = scaled_feat.reshape(1, 24, 7)
            pred_scaled = model.predict(x, verbose=0)

            # Inverse transform target column (index 6)
            dummy = np.zeros((1, 7))
            dummy[0, 6] = pred_scaled[0, 0]
            pred_kw = float(scaler.inverse_transform(dummy)[0, 6])
            pred_kw = round(max(0.0, min(5.0, pred_kw)), 3)

            predictions.append(pred_kw)
            recent_solar.append(pred_kw)

        return predictions
    except Exception as exc:
        logger.error("Solar forecast inference failed: %s", exc)
        return None


# ── Consumption LSTM model (reuses power_consumption_prediction.py) ─────────

def get_consumption_forecast() -> Optional[List[float]]:
    """Call the LSTM consumption model (lstm_power_model.keras) to produce
    a 24-hour consumption forecast (kW per hour).
    Reuses _predict_next_hour from power_consumptin_prediction module.

    Seed priority:
      1. live_sensor_raw.csv  power_w column  (ESP32 real data via Flask)
      2. RMS of NILM windows in live_sensor_stream.csv  (legacy approximation)
      3. Synthetic fallback (0.5 kWh per hour)
    """
    try:
        # Import lazily to avoid circular imports
        from agent_tools.power_consumptin_prediction import _predict_next_hour, load_artifacts
        load_artifacts()  # warm up the model

        # ── Preferred: real consumption readings from live_sensor_raw.csv ──
        seed = read_raw_sensor_data("power_w", lookback_hours=24)

        if seed is None:
            # ── Fallback: RMS proxy from 860-feature NILM windows ──
            logger.warning("Consumption seed: live_sensor_raw.csv unavailable — using NILM-RMS proxy.")
            windows = read_sensor_windows(lookback_rows=24)
            if windows is None or len(windows) < 1:
                logger.warning("No sensor data for consumption forecast seed — using defaults.")
                return None
            seed = [float(np.sqrt(np.mean(w ** 2))) / 1000.0 for w in windows]

        # Pad to 24 if fewer rows available
        while len(seed) < 24:
            seed.insert(0, seed[0] if seed else 0.5)

        sequence = list(seed[-24:])
        predictions: List[float] = []
        for _ in range(HORIZON_HOURS):
            next_kwh = _predict_next_hour(sequence[-24:])
            predictions.append(round(max(0.0, next_kwh), 3))
            sequence.append(next_kwh)
        return predictions
    except Exception as exc:
        logger.error("Consumption forecast inference failed: %s", exc)
        return None


def get_battery_soc() -> Optional[float]:
    """Read the latest battery SOC from Supabase system_state.
    Falls back to None (uses CONFIG default) if unavailable.
    """
    try:
        from supabase_client import get_db
        db = get_db()
        if db is not None:
            res = db.table("system_state").select("battery_soc_pct").eq("id", 1).single().execute()
            if res.data and res.data.get("battery_soc_pct") is not None:
                soc_pct = float(res.data["battery_soc_pct"])
                # Convert percentage to kWh using configured battery capacity
                return round((soc_pct / 100.0) * BATTERY_CAPACITY_KWH, 2)
    except Exception as exc:
        logger.warning("Could not read battery SOC from Supabase: %s", exc)
    return None


def get_appliance_live_state() -> Dict[str, bool]:
    """Uses the NILM device-identification model to report which catalog
    devices have been detected recently."""
    return {device: True for device in detect_appliances_from_sensor()}


# ── Supabase write-back helpers ──────────────────────────────────────────────

def write_decisions_to_supabase(kpis: dict, inputs: "SystemInputs", user_id: Optional[str] = None) -> None:
    """Write optimizer decisions (postpone_load / charge_battery decisions)
    to the Supabase decisions table so the Flutter app sees them in real time.
    This is a best-effort write — failures are logged but do not raise.
    """
    try:
        from supabase_client import insert_decision
        run_times = kpis.get("appliance_run_times", {})
        for appliance_name, start_hour in run_times.items():
            if start_hour is None:
                continue  # missed appliance — skip for now
            payload = {
                "decision_type": "postpone_load",
                "reasoning": {
                    "summary": f"{appliance_name} scheduled to start at {start_hour:02d}:00 by the MILP optimizer.",
                    "confidence": 0.95,
                    "factors": [
                        f"scheduled_start: {start_hour:02d}:00",
                        f"total_cost: {kpis.get('total_cost', '?')}",
                    ],
                },
                "status": "proposed",
                "decided_by": "ai",
            }
            if user_id:
                payload["user_id"] = user_id
            insert_decision(payload)
        logger.info("Wrote %d decisions to Supabase.", len(run_times))
    except Exception as exc:
        logger.error("write_decisions_to_supabase failed: %s", exc)


def write_forecasts_to_supabase(
    solar: List[float],
    consumption: List[float],
    start_hour: int = 0,
    user_id: Optional[str] = None,
) -> None:
    """Write 24 hourly solar and consumption forecast rows to Supabase."""
    from datetime import datetime, timezone, timedelta
    try:
        from supabase_client import insert_forecast
        now = datetime.now(timezone.utc).replace(minute=0, second=0, microsecond=0)
        for i, (sol, cons) in enumerate(zip(solar, consumption)):
            t_start = now + timedelta(hours=i)
            t_end = t_start + timedelta(hours=1)
            base = {
                "model_version": "lstm_v1",
                "horizon_start": t_start.isoformat(),
                "horizon_end": t_end.isoformat(),
            }
            if user_id:
                base["user_id"] = user_id
            insert_forecast({**base, "forecast_type": "solar", "predicted_value": sol})
            insert_forecast({**base, "forecast_type": "consumption", "predicted_value": cons})
        logger.info("Wrote %d forecast pairs to Supabase.", len(solar))
    except Exception as exc:
        logger.error("write_forecasts_to_supabase failed: %s", exc)


def get_appliance_config() -> Dict[str, Appliance]:
    """Builds today's schedulable appliance set from the device catalog CSV,
    filtered to devices the NILM model actually detected in the recent
    sensor stream. No device is silently force-included anymore — if
    detection is unavailable (missing CSV, model, or nothing recognized in
    the recent window), every catalog device is scheduled as a visible,
    logged fallback, not a hardcoded 'always assumed' list.
    """
    catalog = load_device_catalog()
    if not catalog:
        return {}

    detected_names = {name for name in detect_appliances_from_sensor() if name in catalog}
    if not detected_names:
        logger.warning("No devices detected in the recent sensor stream — falling back to the full catalog.")
        return dict(catalog)

    return {name: catalog[name] for name in detected_names}


def _is_valid_forecast(values, horizon: int) -> bool:
    """Guards the MILP from NaNs, wrong-length lists, or negative values
    coming out of a live model — a bad model output should never reach the
    solver silently."""
    if not isinstance(values, list) or len(values) != horizon:
        return False
    return all(isinstance(x, (int, float)) and x >= 0 and x == x for x in values)  # x == x rejects NaN


def build_live_inputs(current_hour: int = 0) -> SystemInputs:
    """Assemble a SystemInputs from live model outputs, falling back to the
    static CONFIG defaults for anything missing or invalid. This is the one
    function the agent tools call — it's the seam between your ML models
    and the optimizer.
    """
    solar = get_solar_forecast()
    if not _is_valid_forecast(solar, HORIZON_HOURS):
        if solar is not None:
            logger.warning("Solar forecast invalid, falling back to default.")
        solar = list(SOLAR_FORECAST_KW)

    consumption = get_consumption_forecast()
    if not _is_valid_forecast(consumption, HORIZON_HOURS):
        if consumption is not None:
            logger.warning("Consumption forecast invalid, falling back to default.")
        consumption = list(CONSUMPTION_FORECAST_KW)

    soc = get_battery_soc()
    if not isinstance(soc, (int, float)) or soc < 0:
        soc = BATTERY_SOC_NOW_KWH

    appliances = get_appliance_config()
    if not isinstance(appliances, dict) or not appliances:
        appliances = load_device_catalog()

    return SystemInputs(
        solar_forecast=solar,
        consumption_forecast=consumption,
        battery_soc_now=soc,
        appliances=appliances,
        start_hour=current_hour,
    )


# ==========================================================================
# 4. MILP MODEL — the optimizer itself. Rarely needs editing; the shape of
#    the model (variables + constraints) is the "physics" of the system.
# ==========================================================================

@dataclass
class ModelVars:
    grid_import: Dict[int, LpVariable]
    batt_charge: Dict[int, LpVariable]
    batt_discharge: Dict[int, LpVariable]
    soc: Dict[int, LpVariable]
    appl_on: Dict[Tuple[int, str], LpVariable]     # 1 if appliance is mid-run at hour t
    appl_start: Dict[Tuple[int, str], LpVariable]   # 1 if appliance's run starts at hour t
    missed: Dict[str, LpVariable]
    solar_curtailed: Dict[int, LpVariable]


def _valid_start_hours(appl: Appliance, horizon: int) -> range:
    """Hours at which a run could start and still finish by the deadline."""
    w = appliance_work_hours(appl)
    deadline = min(appl.deadline, horizon)
    last_start = deadline - w
    if last_start < 0:
        raise ValueError(
            f"Appliance work_time ({appl.work_time}h -> {w}h) is longer than its "
            f"deadline ({appl.deadline}h) — increase the deadline or reduce work_time."
        )
    return range(0, last_start + 1)


def create_variables(inputs: SystemInputs) -> ModelVars:
    T = range(inputs.horizon)
    start_index = [
        (s, a) for a, appl in inputs.appliances.items()
        for s in _valid_start_hours(appl, inputs.horizon)
    ]
    return ModelVars(
        grid_import=LpVariable.dicts("GridImport", T, lowBound=0),
        batt_charge=LpVariable.dicts("BattCharge", T, lowBound=0, upBound=inputs.battery_max_rate),
        batt_discharge=LpVariable.dicts("BattDischarge", T, lowBound=0, upBound=inputs.battery_max_rate),
        soc=LpVariable.dicts(
            "SoC", T,
            lowBound=inputs.soc_min_frac * inputs.battery_capacity,
            upBound=inputs.soc_max_frac * inputs.battery_capacity,
        ),
        appl_on=LpVariable.dicts("ApplOn", [(t, a) for t in T for a in inputs.appliances], cat="Binary"),
        appl_start=LpVariable.dicts("ApplStart", start_index, cat="Binary"),
        missed=LpVariable.dicts("Missed", list(inputs.appliances), cat="Binary"),
        solar_curtailed=LpVariable.dicts("SolarCurtailed", T, lowBound=0),
    )


def add_objective(model: LpProblem, v: ModelVars, inputs: SystemInputs, tariff: List[float]) -> None:
    T = range(inputs.horizon)
    cost_term = lpSum(v.grid_import[t] * tariff[t] for t in T)
    penalty_term = lpSum(v.missed[a] * inputs.appliances[a].priority for a in inputs.appliances)
    curtailment_term = lpSum(v.solar_curtailed[t] for t in T) * inputs.curtailment_weight
    model += cost_term + penalty_term + curtailment_term


def add_energy_balance_constraints(model: LpProblem, v: ModelVars, inputs: SystemInputs) -> None:
    for t in range(inputs.horizon):
        appliance_load = lpSum(
            v.appl_on[(t, a)] * (appl.energy / appliance_work_hours(appl))
            for a, appl in inputs.appliances.items()
        )
        model += (
            inputs.solar_forecast[t] + v.batt_discharge[t] + v.grid_import[t]
            == inputs.consumption_forecast[t] + appliance_load + v.batt_charge[t] + v.solar_curtailed[t]
        ), f"EnergyBalance_t{t}"


def add_battery_dynamics_constraints(model: LpProblem, v: ModelVars, inputs: SystemInputs) -> None:
    for t in range(inputs.horizon):
        prev_soc = inputs.battery_soc_now if t == 0 else v.soc[t - 1]
        model += v.soc[t] == prev_soc + v.batt_charge[t] - v.batt_discharge[t], f"SoCDynamics_t{t}"


def add_appliance_scheduling_constraints(model: LpProblem, v: ModelVars, inputs: SystemInputs) -> None:
    """Each appliance runs at most once, as one continuous block of
    `work_time` hours, entirely inside its deadline window."""
    for name, appl in inputs.appliances.items():
        w = appliance_work_hours(appl)
        starts = list(_valid_start_hours(appl, inputs.horizon))

        model += lpSum(v.appl_start[(s, name)] for s in starts) <= 1, f"RunOnce_{name}"
        model += (
            v.missed[name] == 1 - lpSum(v.appl_start[(s, name)] for s in starts)
        ), f"MissedDef_{name}"

        for t in range(inputs.horizon):
            covering_starts = [s for s in starts if s <= t < s + w]
            model += (
                v.appl_on[(t, name)] == lpSum(v.appl_start[(s, name)] for s in covering_starts)
            ), f"OnDef_{name}_t{t}"


def build_model(inputs: SystemInputs) -> Tuple[LpProblem, ModelVars, List[float]]:
    model = LpProblem("HC_POS_Decision_Engine", LpMinimize)
    v = create_variables(inputs)
    tariff = inputs.tariff_schedule()

    add_objective(model, v, inputs, tariff)
    add_energy_balance_constraints(model, v, inputs)
    add_battery_dynamics_constraints(model, v, inputs)
    add_appliance_scheduling_constraints(model, v, inputs)

    return model, v, tariff


# ==========================================================================
# 5. SOLVE + EXTRACT
# ==========================================================================

BINARY_ON_TOLERANCE = 0.5  # CBC can return 0.999999998 instead of exactly 1.0


def solve_model(model: LpProblem, verbose: bool = False) -> str:
    # logPath is a safety net: on some platforms msg=False alone doesn't
    # fully suppress CBC's console spam, so we also redirect its log file.
    model.solve(PULP_CBC_CMD(msg=verbose, logPath=os.devnull))
    return LpStatus[model.status]


def extract_schedule(v: ModelVars, inputs: SystemInputs) -> List[dict]:
    schedule = []
    for t in range(inputs.horizon):
        schedule.append({
            "hour": t,
            "grid_import_kwh": round(v.grid_import[t].varValue or 0, 3),
            "batt_charge_kwh": round(v.batt_charge[t].varValue or 0, 3),
            "batt_discharge_kwh": round(v.batt_discharge[t].varValue or 0, 3),
            "soc_kwh": round(v.soc[t].varValue or 0, 3),
            "solar_curtailed_kwh": round(v.solar_curtailed[t].varValue or 0, 3),
            "appliances_on": [
                a for a in inputs.appliances
                if (v.appl_on[(t, a)].varValue or 0) > BINARY_ON_TOLERANCE
            ],
        })
    return schedule


def compute_kpis(schedule: List[dict], inputs: SystemInputs, tariff: List[float] = None) -> dict:
    tariff = tariff if tariff is not None else inputs.tariff_schedule()

    total_cost = total_grid_import = total_batt_charge = total_curtailed = 0.0
    scheduled = set()
    run_times: Dict[str, int] = {}

    for e in schedule:
        t = e["hour"]
        total_cost += e["grid_import_kwh"] * tariff[t]
        total_grid_import += e["grid_import_kwh"]
        total_batt_charge += e["batt_charge_kwh"]
        total_curtailed += e["solar_curtailed_kwh"]
        for name in e["appliances_on"]:
            scheduled.add(name)
            run_times.setdefault(name, t)

    for name in inputs.appliances:
        run_times.setdefault(name, None)

    return {
        "total_cost": round(total_cost, 2),
        "total_grid_import_kwh": round(total_grid_import, 2),
        "total_battery_charge_kwh": round(total_batt_charge, 2),
        "total_solar_curtailed_kwh": round(total_curtailed, 2),
        "missed_appliances": [name for name in inputs.appliances if name not in scheduled],
        "appliance_run_times": run_times,
    }


def solve(inputs: SystemInputs, verbose: bool = False) -> Tuple[str, List[dict], dict]:
    """Returns (status, schedule, kpis). schedule/kpis are empty if not Optimal."""
    model, v, tariff = build_model(inputs)
    status = solve_model(model, verbose=verbose)
    if status == "Optimal":
        schedule = extract_schedule(v, inputs)
        kpis = compute_kpis(schedule, inputs, tariff=tariff)
    else:
        schedule, kpis = [], {}
    return status, schedule, kpis


# ==========================================================================
# 6. ANALYSIS — cost breakdowns, savings baseline, infeasibility diagnosis.
#    Add new analysis functions here, then expose the ones agents need as
#    tools in section 8.
# ==========================================================================

def compute_savings(inputs: SystemInputs) -> dict:
    """Compare the optimized schedule's cost against a naive baseline where
    every appliance just runs as early as possible with no battery
    scheduling intelligence — i.e. what a "dumb" system would cost.
    """
    optimized_status, _, optimized_kpis = solve(inputs)

    naive_appliances = {
        name: dc_replace(appl, deadline=appliance_work_hours(appl))
        for name, appl in inputs.appliances.items()
    }
    naive_inputs = dc_replace(inputs, appliances=naive_appliances)
    baseline_status, _, baseline_kpis = solve(naive_inputs)

    if optimized_status != "Optimal" or baseline_status != "Optimal":
        return {"status": "unavailable", "message": "Could not compute a comparable baseline."}

    savings = round(baseline_kpis["total_cost"] - optimized_kpis["total_cost"], 2)
    return {
        "status": "ok",
        "optimized_cost": optimized_kpis["total_cost"],
        "baseline_cost": baseline_kpis["total_cost"],
        "savings": savings,
    }


def diagnose_infeasibility(inputs: SystemInputs) -> dict:
    """Try relaxing constraints one at a time to find the likely cause of
    an infeasible model. Does NOT mutate the caller's inputs."""
    baseline_status, _, _ = solve(inputs)
    if baseline_status == "Optimal":
        return {"status": "Optimal", "message": "Model is already feasible."}

    findings = []

    for name in inputs.appliances:
        trial_appliances = dict(inputs.appliances)
        trial_appliances[name] = dc_replace(trial_appliances[name], deadline=inputs.horizon)
        status, _, _ = solve(dc_replace(inputs, appliances=trial_appliances))
        findings.append({
            "relaxation": f"extend '{name}' deadline to horizon ({inputs.horizon}:00)",
            "resulting_status": status,
        })

    status, _, _ = solve(dc_replace(inputs, soc_min_frac=0.0, soc_max_frac=1.0))
    findings.append({"relaxation": "widen battery SoC bounds to 0%-100%", "resulting_status": status})

    status, _, _ = solve(dc_replace(inputs, battery_max_rate=inputs.battery_max_rate * 3))
    findings.append({"relaxation": "triple battery max charge/discharge rate", "resulting_status": status})

    fixes_that_worked = [f for f in findings if f["resulting_status"] == "Optimal"]
    return {
        "status": baseline_status,
        "findings": findings,
        "likely_cause": fixes_that_worked[0]["relaxation"] if fixes_that_worked
        else "unclear — multiple constraints may be jointly infeasible",
    }


# ==========================================================================
# 7. AGENT PAYLOAD — compact, semantically-labeled schedule for the LLM.
#    Only hours with something to report are included.
# ==========================================================================

EVENT_AMOUNT_EPSILON = 0.01  # ignore solver noise below this many kWh


def _hour_events(entry: dict) -> List[dict]:
    actions = []
    for appliance in entry["appliances_on"]:
        actions.append({"type": "appliance_run", "appliance": appliance})
    if entry["batt_charge_kwh"] > EVENT_AMOUNT_EPSILON:
        actions.append({"type": "battery_charge", "amount_kwh": entry["batt_charge_kwh"]})
    if entry["batt_discharge_kwh"] > EVENT_AMOUNT_EPSILON:
        actions.append({"type": "battery_discharge", "amount_kwh": entry["batt_discharge_kwh"]})
    if entry["grid_import_kwh"] > EVENT_AMOUNT_EPSILON:
        actions.append({"type": "grid_import", "amount_kwh": entry["grid_import_kwh"]})
    if entry["solar_curtailed_kwh"] > EVENT_AMOUNT_EPSILON:
        actions.append({"type": "solar_curtailed", "amount_kwh": entry["solar_curtailed_kwh"]})
    return actions


def build_agent_payload(status: str, schedule: List[dict], kpis: dict, inputs: SystemInputs) -> dict:
    events = []
    for entry in schedule:
        actions = _hour_events(entry)
        if not actions:
            continue
        t = entry["hour"]
        events.append({
            "hour": t,
            "time": f"{(inputs.start_hour + t) % 24:02d}:00",
            "tariff_period": inputs.tariff_period_at(t),
            "battery_soc_kwh": entry["soc_kwh"],
            "actions": actions,
        })

    return {
        "status": status,
        "horizon_hours": inputs.horizon,
        "summary": kpis,
        "battery": {
            "start_soc_kwh": inputs.battery_soc_now,
            "end_soc_kwh": schedule[-1]["soc_kwh"] if schedule else None,
            "capacity_kwh": inputs.battery_capacity,
        },
        "events": events,
    }


# ==========================================================================
# 8. AGENT TOOLS — what the LLM agent can actually call.
#
# Rules kept from earlier fixes, keep following them for new tools:
#   - No tool takes `verbose` or a raw SystemInputs/dataclass as an LLM-set
#     argument. Solver internals are never LLM-controlled.
#   - Tools return facts computed here, never ask the LLM to compute a
#     number itself (e.g. cost) from data it wasn't actually given.
#   - Tools that could change real-world state (none currently) must be
#     request/approve, never direct-execute.
# ==========================================================================

@tool
def get_current_decision() -> dict:
    """Run the optimizer with the latest live data and return the current
    power schedule and KPIs."""
    inputs = build_live_inputs()
    status, schedule, kpis = solve(inputs, verbose=False)
    if status != "Optimal":
        return {"status": status, "message": "Solver did not find an optimal schedule."}
    return build_agent_payload(status, schedule, kpis, inputs)


@tool
def calculate_power_cost() -> dict:
    """Return today's actual grid cost and per-appliance energy usage,
    computed from the optimizer's schedule."""
    inputs = build_live_inputs()
    status, schedule, kpis = solve(inputs, verbose=False)
    if status != "Optimal":
        return {"status": status, "message": "No optimal schedule available."}

    appliance_usage_kwh = {
        name: inputs.appliances[name].energy
        for name, run_hour in kpis["appliance_run_times"].items()
        if run_hour is not None
    }
    return {
        "total_cost": kpis["total_cost"],
        "appliance_usage_kwh": appliance_usage_kwh,
        "tariff_peak": inputs.tariff_peak,
        "tariff_offpeak": inputs.tariff_offpeak,
    }


@tool
def get_savings() -> dict:
    """Return how much the optimizer saved today compared to a naive
    baseline with no smart scheduling."""
    inputs = build_live_inputs()
    return compute_savings(inputs)


@tool
def diagnose_why_infeasible() -> dict:
    """Explain why the optimizer failed to find a feasible schedule, if it did."""
    inputs = build_live_inputs()
    return diagnose_infeasibility(inputs)


@tool
def get_detected_devices() -> dict:
    """Return which devices the NILM model has actually detected recently on
    the power line, read live from the sensor CSV feed. Use THIS tool — not
    get_current_decision — to answer "what devices are connected/detected
    right now". get_current_decision returns a 24-hour optimizer PLAN, not a
    live connection status, and must never be presented to the user as one.
    """
    recent = detect_recent_devices()
    catalog = load_device_catalog()
    seen_names = {d["device"] for d in recent}
    catalog_not_seen = sorted(name for name in catalog if name not in seen_names)

    return {
        "detected_devices": recent,  # [{device, windows_seen, avg_confidence}, ...]
        "data_source": "live_sensor_csv",
        "model_limitation": (
            "Each 1-second sensor window yields exactly one device label, so "
            "multiple simultaneous devices are inferred by aggregating "
            "several recent windows, not confirmed within a single reading."
        ),
        "catalog_devices_not_recently_detected": catalog_not_seen,
        "note": (
            "Devices in 'catalog_devices_not_recently_detected' are known to "
            "the system (device_catalog.csv) but were not seen in the "
            "recent sensor stream, so they're excluded from today's "
            "schedule unless detected."
        ),
    }


# --- TODO stubs: implement when needed, keep the same "no LLM-controlled
# internals, return facts not raw objects" pattern used above. ---
#
# @tool
# def simulate_scenario(change_description: str) -> dict:
#     """Re-run the optimizer with a hypothetical change (e.g. 'what if
#     solar is 20% lower tomorrow') and return the resulting schedule.
#     Parse `change_description` into a bounded set of known overrides —
#     never let the LLM inject arbitrary SystemInputs fields directly."""
#
# @tool
# def generate_pdf_report() -> dict:
#     """Generate the Sinhala summary report via ReportLab and return its
#     file path."""
#
# @tool
# def request_manual_approval(action: str) -> dict:
#     """Surface a proposed override to the Flutter app for a human to
#     approve. Never executes anything itself."""


# ==========================================================================
# Local test entry point
# ==========================================================================

# if __name__ == "__main__":
#     logging.basicConfig(level=logging.INFO)
#     demo_inputs = build_live_inputs()
#     status, schedule, kpis = solve(demo_inputs)
#     print("Status:", status)
#     print("KPIs:", kpis)
#     print("Savings:", compute_savings(demo_inputs))