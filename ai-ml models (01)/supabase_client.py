"""
supabase_client.py
==================
Singleton Supabase Python client for the HC-POS AI backend.

Uses the SERVICE_ROLE key so it can write to any table, bypassing
Row-Level Security.  The Flutter app uses the anon key instead.

Usage:
    from supabase_client import get_db

    db = get_db()
    db.table("decisions").insert({...}).execute()
"""

import os
import logging
import dotenv
from supabase import create_client, Client

dotenv.load_dotenv()

logger = logging.getLogger("hc_pos.supabase_client")

from typing import Optional

_client = None


def is_supabase_configured() -> bool:
    """Check if valid Supabase credentials have been configured."""
    url = os.getenv("SUPABASE_URL")
    key = os.getenv("SUPABASE_SERVICE_KEY")
    return bool(url and key and not key.startswith("<") and "PASTE" not in key)


def get_db() -> Optional[Client]:
    """Return (and lazily create) the singleton Supabase service-role client."""
    global _client
    if _client is not None:
        return _client

    url = os.getenv("SUPABASE_URL")
    key = os.getenv("SUPABASE_SERVICE_KEY")

    if not is_supabase_configured():
        logger.warning(
            "SUPABASE_SERVICE_KEY is not configured in .env. "
            "Supabase database writes are skipped until your real service-role key is provided."
        )
        return None

    try:
        _client = create_client(url, key)
        logger.info("Supabase service-role client initialised for %s", url)
        return _client
    except Exception as exc:
        logger.error("Failed to initialise Supabase client: %s", exc)
        return None


_default_user_id: Optional[str] = None
_ingest_device_id: Optional[int] = None


def get_default_user_id() -> Optional[str]:
    """Resolve the household owner user_id from config or existing rows."""
    global _default_user_id
    if _default_user_id is not None:
        return _default_user_id

    configured_user_id = os.getenv("SUPABASE_USER_ID", "").strip()
    if configured_user_id:
        _default_user_id = configured_user_id
        return _default_user_id

    db = get_db()
    if db is None:
        return None

    try:
        res = db.table("system_state").select("user_id").limit(1).execute()
        if res.data and res.data[0].get("user_id"):
            _default_user_id = str(res.data[0]["user_id"])
            return _default_user_id

        res = db.table("devices").select("user_id").limit(1).execute()
        if res.data and res.data[0].get("user_id"):
            _default_user_id = str(res.data[0]["user_id"])
            return _default_user_id
    except Exception as exc:
        logger.debug("Could not resolve default user_id from database: %s", exc)

    logger.error(
        "No Supabase user_id is configured or stored. Set SUPABASE_USER_ID "
        "to the owning auth.users UUID in the backend .env file."
    )
    return None


def ensure_backend_registry() -> Optional[int]:
    """Ensure one owned ingestion device and the catalog appliances exist."""
    global _ingest_device_id
    if _ingest_device_id is not None:
        return _ingest_device_id

    db = get_db()
    user_id = get_default_user_id()
    if db is None or user_id is None:
        return None

    try:
        devices = (
            db.table("devices")
            .select("device_id")
            .eq("user_id", user_id)
            .eq("device_name", "HC-POS ESP32 Gateway")
            .limit(1)
            .execute()
            .data
        )
        if devices:
            _ingest_device_id = int(devices[0]["device_id"])
        else:
            device = db.table("devices").insert({
                "user_id": user_id,
                "device_name": "HC-POS ESP32 Gateway",
                "device_type": "central",
                "room_location": "Whole house",
                "firmware_version": "receiver-1.0",
                "is_active": True,
            }).execute().data
            _ingest_device_id = int(device[0]["device_id"])

        catalog = [
            ("HouseHold_Fan-240-150w", 3, 150.0),
            ("Washing_Machine-1200w", 2, 1200.0),
            ("Water_Heater-2000w", 1, 2000.0),
            ("Refrigerator-150w", 5, 150.0),
            ("Air_Conditioner-1500w", 2, 1500.0),
            ("Microwave_Oven-1100w", 1, 1100.0),
            ("Electric_Iron-1000w", 1, 1000.0),
            ("Rice_Cooker-700w", 2, 700.0),
            ("LED_TV-90w", 4, 90.0),
            ("Electric_Kettle-1500w", 1, 1500.0),
        ]
        existing = db.table("appliances").select("appliance_name").eq(
            "device_id", _ingest_device_id
        ).execute().data
        existing_names = {row["appliance_name"] for row in existing}
        missing = [
            {
                "device_id": _ingest_device_id,
                "appliance_name": name,
                "nilm_predicted_type": name,
                "rated_power_w": rated_power,
                "priority_level": priority,
                "is_controllable": True,
            }
            for name, priority, rated_power in catalog
            if name not in existing_names
        ]
        if missing:
            db.table("appliances").insert(missing).execute()
        return _ingest_device_id
    except Exception as exc:
        logger.error("Failed to ensure backend device/appliance registry: %s", exc)
        return None


# ---------------------------------------------------------------------------
# Convenience write helpers used by the decision engine and API server
# ---------------------------------------------------------------------------

def upsert_system_state(payload: dict) -> None:
    """Upsert the single system_state row (id=1)."""
    db = get_db()
    if db is None:
        return
    try:
        payload["id"] = 1
        if not payload.get("user_id"):
            uid = get_default_user_id()
            if uid:
                payload["user_id"] = uid
        db.table("system_state").upsert(payload).execute()
    except Exception as exc:
        logger.error("Failed to upsert system_state: %s", exc)


def insert_decision(payload: dict):
    """Insert a row in the decisions table and return the new row id."""
    db = get_db()
    if db is None:
        return None
    try:
        if not payload.get("user_id"):
            uid = get_default_user_id()
            if uid:
                payload["user_id"] = uid
        res = db.table("decisions").insert(payload).execute()
        rows = res.data
        if rows:
            return rows[0].get("id")
    except Exception as exc:
        logger.error("Failed to insert decision: %s", exc)
    return None


def insert_forecast(payload: dict) -> None:
    """Insert a row in the forecasts table."""
    db = get_db()
    if db is None:
        return
    try:
        if not payload.get("user_id"):
            uid = get_default_user_id()
            if uid:
                payload["user_id"] = uid
        db.table("forecasts").insert(payload).execute()
    except Exception as exc:
        logger.error("Failed to insert forecast: %s", exc)


def insert_alert(payload: dict) -> None:
    """Insert a row in the alerts table."""
    try:
        get_db().table("alerts").insert(payload).execute()
    except Exception as exc:
        logger.error("Failed to insert alert: %s", exc)


def insert_telemetry(rows: list) -> None:
    """Bulk-insert telemetry_log rows (list of dicts)."""
    if not rows:
        return
    try:
        db = get_db()
        device_id = ensure_backend_registry()
        if db is None or device_id is None:
            return
        payload = [{**row, "device_id": device_id} for row in rows]
        db.table("telemetry_log").insert(payload).execute()
    except Exception as exc:
        logger.error("Failed to insert telemetry: %s", exc)


def insert_execution_log(payload: dict) -> None:
    """Insert a row in the execution_log table."""
    try:
        get_db().table("execution_log").insert(payload).execute()
    except Exception as exc:
        logger.error("Failed to insert execution_log: %s", exc)
