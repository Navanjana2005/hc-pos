import pandas as pd
import numpy as np

def generate_synthetic_power_data(start_date='2026-01-01', days=365):
    """Generates realistic hourly power consumption data."""
    
    print(f"Generating {days} days of synthetic hourly power data...")
    
    # 1. Create the hourly timestamp index
    date_rng = pd.date_range(start=start_date, periods=days*24, freq='H')
    df = pd.DataFrame(index=date_rng)
    
    # Extract time features to build patterns
    df['hour'] = df.index.hour
    df['day_of_week'] = df.index.dayofweek
    
    # 2. Define the Base Load (Always-on appliances)
    # Let's assume a baseline of 0.4 kWh
    base_load = 0.4 
    
    # 3. Simulate Daily Seasonality (Human routines)
    # We use a mathematical curve to create a small morning peak and a large evening peak.
    # We'll use Gaussian curves (bell curves) to simulate when people are most active.
    
    # Morning peak around 7:00 AM (Hour 7)
    morning_peak = 0.8 * np.exp(-((df['hour'] - 7) ** 2) / (2 * 2**2)) 
    
    # Evening peak around 7:00 PM (Hour 19), usually larger
    evening_peak = 1.5 * np.exp(-((df['hour'] - 19) ** 2) / (2 * 3**2))
    
    daily_pattern = morning_peak + evening_peak
    
    # 4. Simulate Weekend Effects
    # People are home more during the day on weekends (Saturday=5, Sunday=6)
    # We apply a multiplier to increase midday usage on weekends
    weekend_mask = df['day_of_week'] >= 5
    midday_mask = (df['hour'] >= 10) & (df['hour'] <= 16)
    df['weekend_boost'] = np.where(weekend_mask & midday_mask, 0.6, 0.0)
    
    # 5. Add Random Noise (Unpredictable usage)
    # Standard deviation of 0.15 adds a realistic level of jitter
    noise = np.random.normal(0, 0.15, len(df))
    
    # 6. Combine all components together
    df['consumption_kwh'] = base_load + daily_pattern + df['weekend_boost'] + noise
    
    # 7. Final Cleanup
    # Power consumption cannot be negative. If noise pushes it below 0, clip it to a minimum value.
    df['consumption_kwh'] = df['consumption_kwh'].clip(lower=0.1)
    
    # Keep only the required column for the LSTM
    final_df = df[['consumption_kwh']]
    
    return final_df

# Generate 365 days (a full year) of data
year_data = generate_synthetic_power_data(start_date='2026-01-01', days=365)

# Save to CSV
filename = 'synthetic_consumption_history.csv'
year_data.to_csv(filename, index_label='datetime')

print(f"Success! Saved {len(year_data)} hourly records to {filename}")
print("\nFirst 10 rows:")
print(year_data.head(10))