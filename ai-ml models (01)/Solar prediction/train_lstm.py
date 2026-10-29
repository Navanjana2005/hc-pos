import os
import joblib
import numpy as np
import pandas as pd
import tensorflow as tf
from sklearn.preprocessing import MinMaxScaler
from keras.layers import LSTM, Dense, Dropout
from keras.models import Sequential

# Configuration parameters
CSV_FILE = "solar_energy_prediction_dataset.csv"
MODEL_SAVE_PATH = "lstm_solar_model.keras"
SCALER_SAVE_PATH = "scaler.pkl"
LOOKBACK_WINDOW = 24  # Use past 24 hours to predict the next hour
EPOCHS = 25
BATCH_SIZE = 32
FEATURE_COLUMNS = [
    "Elevation",
    "Temperature",
    "Humidity",
    "Solar_Irradiance",
    "Cloud_Cover",
    "Wind_Speed",
    "Solar_Production",
]
TARGET_COLUMN = "Solar_Production"

# Reproducibility
np.random.seed(42)
tf.random.set_seed(42)



def _resolve_csv_path(file_name: str) -> str:
    # Try the provided path, then script dir, then its parent dir.
    if os.path.exists(file_name):
        return file_name
    script_dir = os.path.dirname(__file__)
    candidate = os.path.join(script_dir, file_name)
    if os.path.exists(candidate):
        return candidate
    candidate = os.path.join(script_dir, os.pardir, file_name)
    if os.path.exists(candidate):
        return os.path.abspath(candidate)
    raise FileNotFoundError(f"Could not find '{file_name}'. Checked cwd, script dir, and parent dir.")


def load_and_preprocess_data(file_path):
    # 1. Resolve and load CSV data
    resolved = _resolve_csv_path(file_path)
    df = pd.read_csv(resolved, parse_dates=["Datetime"], index_col="Datetime")

    # Ensure data is sorted chronologically
    df = df.sort_index()

    # Validate required columns exist
    missing = set(FEATURE_COLUMNS) - set(df.columns)
    if missing:
        raise ValueError(f"Missing required columns in CSV: {missing}")

    # Extract features (2D array: rows=time, cols=features)
    data = df[FEATURE_COLUMNS].values

    # 2. Fit and save the MinMaxScaler
    scaler = MinMaxScaler(feature_range=(0, 1))
    scaled_data = scaler.fit_transform(data)

    joblib.dump(scaler, SCALER_SAVE_PATH)
    print(f"Scaler successfully saved to '{SCALER_SAVE_PATH}'")

    return scaled_data, scaler

def create_sequences(data, lookback, target_index):
    """Create sliding window sequences.

    X shape -> (samples, lookback, n_features)
    y shape -> (samples,)
    """
    X, y = [], []
    n = len(data)
    for i in range(n - lookback):
        X.append(data[i : i + lookback])
        y.append(data[i + lookback, target_index])

    X = np.array(X)
    y = np.array(y)
    return X, y

def build_and_train_model():
    # Load and scale data
    scaled_data, _ = load_and_preprocess_data(CSV_FILE)

    # Determine target index (Solar_Production)
    target_index = FEATURE_COLUMNS.index(TARGET_COLUMN)

    # Create sliding window sequences (multivariate input)
    X, y = create_sequences(scaled_data, LOOKBACK_WINDOW, target_index)

    # Train/Validation split (80% train, 20% validation)
    split_idx = int(len(X) * 0.8)
    X_train, X_val = X[:split_idx], X[split_idx:]
    y_train, y_val = y[:split_idx], y[split_idx:]

    print(f"Training samples: {X_train.shape[0]} | Validation samples: {X_val.shape[0]}")

    n_features = X.shape[2]

    # Build LSTM Model Architecture
    model = Sequential(
        [
            LSTM(64, return_sequences=True, input_shape=(LOOKBACK_WINDOW, n_features)),
            Dropout(0.2),
            LSTM(32, return_sequences=False),
            Dropout(0.2),
            Dense(16, activation="relu"),
            Dense(1),  # Output layer predicting target (Solar_Production)
        ]
    )

    model.compile(optimizer="adam", loss="mean_squared_error", metrics=["mae"])
    model.summary()

    # Train the model
    print("\nStarting model training...")
    history = model.fit(
        X_train,
        y_train,
        epochs=EPOCHS,
        batch_size=BATCH_SIZE,
        validation_data=(X_val, y_val),
        verbose=1,
    )

    # Save the trained model
    model.save(MODEL_SAVE_PATH)
    print(f"\nModel successfully saved to '{MODEL_SAVE_PATH}'")


if __name__ == "__main__":
    build_and_train_model()