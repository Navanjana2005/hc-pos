"""
Generate a large, realistic hourly solar energy dataset for LSTM training.

Design notes
------------
- Hourly resolution, continuous timestamps (no gaps) across N_YEARS of data.
  Night hours are KEPT (not dropped) with Solar_Production/Irradiance = 0,
  so the LSTM learns the daily on/off cycle, not just daytime behaviour.
- No generation between SUNSET_HOUR (17:00) and SUNRISE_HOUR (07:00).
- Features are correlated with each other (not independent random noise),
  which is what makes a dataset learnable:
    Elevation -> clear-sky Irradiance -> actual Irradiance (reduced by cloud)
    -> Solar_Production (further reduced by high panel temperature)
- Cloud cover uses an AR(1) process (vectorized via scipy.signal.lfilter)
  so cloudy/clear periods persist across hours instead of flickering randomly,
  which matches real weather behaviour.
- A mild seasonal + monsoon signal is added (Sri Lanka: SW monsoon ~May-Sep,
  NE monsoon ~Oct-Jan) affecting cloud cover, humidity, and wind speed.
- Everything is fully vectorized with NumPy/pandas - no per-row Python loops -
  so generating 50k+ rows takes well under a second.
"""

import numpy as np
import pandas as pd
from scipy.signal import lfilter

# ---- Config ----
START_DATE = "2015-01-01"
END_DATE = "2026-12-31 23:00:00"   # 6 full years, hourly
SUNRISE_HOUR = 7                    # first hour with possible generation
SUNSET_HOUR = 17                    # generation stops at/after this hour
OUTPUT_FILE = "solar_energy_prediction_dataset.csv"
RANDOM_SEED = 42

np.random.seed(RANDOM_SEED)


def build_timestamps(start: str, end: str) -> pd.DatetimeIndex:
    return pd.date_range(start=start, end=end, freq="h")


def generate_dataset() -> pd.DataFrame:
    timestamps = build_timestamps(START_DATE, END_DATE)
    n = len(timestamps)

    hour = timestamps.hour.to_numpy()
    day_of_year = timestamps.dayofyear.to_numpy()
    month = timestamps.month.to_numpy()

    daylight_hours = SUNSET_HOUR - SUNRISE_HOUR
    is_daylight = (hour >= SUNRISE_HOUR) & (hour < SUNSET_HOUR)

    # ---- Solar elevation angle (degrees, 0 at night) ----
    # Rises from 0 at sunrise to a peak near solar noon, back to 0 at sunset.
    hour_frac = np.clip((hour - SUNRISE_HOUR) / daylight_hours, 0, 1)
    elevation = np.where(is_daylight, np.sin(np.pi * hour_frac) * 85.0, 0.0)
    elevation = np.clip(elevation, 0, 90)

    # ---- Seasonal factor (mild - near-equatorial location) ----
    seasonal_factor = 1 + 0.08 * np.cos(2 * np.pi * (day_of_year - 80) / 365)

    # ---- Monsoon intensity by month (rough Sri Lanka pattern) ----
    monsoon_intensity = np.select(
        [np.isin(month, [5, 6, 7, 8, 9]), np.isin(month, [10, 11, 12, 1])],
        [0.5, 0.4],
        default=0.15,
    )

    # ---- Cloud cover: AR(1) process for realistic day-to-day persistence ----
    cloud_baseline = 0.2 + monsoon_intensity
    white_noise = np.random.normal(0, 0.05, size=n)
    phi = 0.85  # persistence coefficient (higher = smoother/cloudier streaks)
    driving_signal = (1 - phi) * cloud_baseline + white_noise
    # y[t] = phi*y[t-1] + driving_signal[t]  -->  IIR filter, fully vectorized
    cloud_cover = lfilter([1.0], [1.0, -phi], driving_signal)
    cloud_cover = np.clip(cloud_cover, 0, 0.95)

    # ---- Temperature: seasonal + diurnal cycle + noise ----
    seasonal_temp = 29 + 2 * np.cos(2 * np.pi * (day_of_year - 100) / 365)
    diurnal_temp = 6 * np.cos(2 * np.pi * (hour - 14) / 24)  # peak ~14:00
    temperature = seasonal_temp + diurnal_temp + np.random.normal(0, 1.2, size=n)
    temperature = np.clip(temperature, 18, 40)

    # ---- Humidity: inversely related to temperature, higher in monsoon ----
    humidity = 85 - (temperature - 27) * 2.5 + monsoon_intensity * 20
    humidity += np.random.normal(0, 4, size=n)
    humidity = np.clip(humidity, 35, 100)

    # ---- Wind speed: gamma-distributed (always positive), monsoon boost ----
    wind_speed = np.random.gamma(shape=2.0, scale=1.4, size=n) + monsoon_intensity * 2
    wind_speed = np.clip(wind_speed, 0.2, 18)

    # ---- Solar irradiance: clear-sky curve reduced by cloud cover ----
    clear_sky_irradiance = np.where(
        is_daylight, 1000 * np.sin(np.radians(elevation)) * seasonal_factor, 0.0
    )
    solar_irradiance = clear_sky_irradiance * (1 - 0.75 * cloud_cover)
    solar_irradiance += np.where(is_daylight, np.random.normal(0, 15, size=n), 0.0)
    solar_irradiance = np.clip(solar_irradiance, 0, 1200)

    # ---- Solar production: irradiance-driven, derated by panel heat, + noise ----
    temp_derate = 1 - 0.004 * np.maximum(temperature - 25, 0)  # ~0.4%/deg C above 25C
    production_noise = np.random.normal(1.0, 0.05, size=n)
    solar_production = solar_irradiance * temp_derate * production_noise
    solar_production = np.where(is_daylight, solar_production, 0.0)
    solar_production = np.clip(solar_production, 0, None)

    df = pd.DataFrame(
        {
            "Datetime": timestamps,
            "Date": timestamps.date,
            "Time": timestamps.strftime("%H:%M:%S"),
            "Elevation": np.round(elevation, 2),
            "Temperature": np.round(temperature, 2),
            "Humidity": np.round(humidity, 2),
            "Solar_Irradiance": np.round(solar_irradiance, 2),
            "Cloud_Cover": np.round(cloud_cover, 3),
            "Wind_Speed": np.round(wind_speed, 2),
            "Solar_Production": np.round(solar_production, 2),
        }
    )
    return df


if __name__ == "__main__":
    df = generate_dataset()
    df.to_csv(OUTPUT_FILE, index=False)
    print(f"Saved {len(df):,} rows ({df['Date'].nunique():,} days) to {OUTPUT_FILE}")
    print(f"Date range: {df['Datetime'].min()} to {df['Datetime'].max()}")
    print(f"Non-zero production hours: {(df['Solar_Production'] > 0).sum():,} "
          f"/ {len(df):,} ({(df['Solar_Production'] > 0).mean():.1%})")