import os
import joblib
import numpy as np
import pandas as pd
import tensorflow as tf
from sklearn.preprocessing import MinMaxScaler
from keras.layers import LSTM, Dense, Dropout
from keras.models import Sequential

# Configuration parameters
CSV_FILE = "synthetic_consumption_history.csv"
MODEL_SAVE_PATH = "lstm_power_model.keras"
SCALER_SAVE_PATH = "scaler.pkl"
LOOKBACK_WINDOW = 24  # Use past 24 hours to predict the next hour
EPOCHS = 25
BATCH_SIZE = 32


def load_and_preprocess_data(file_path):
    # 1. Load CSV data
    if not os.path.exists(file_path):
        raise FileNotFoundError(
            f"Could not find '{file_path}'. Please ensure the file exists."
        )

    df = pd.read_csv(
        file_path, parse_dates=["datetime"], index_col="datetime"
    )

    # Ensure data is sorted chronologically
    df = df.sort_index()

    # Extract consumption values as 2D array for scaler
    data = df[["consumption_kwh"]].values

    # 2. Fit and save the MinMaxScaler
    scaler = MinMaxScaler(feature_range=(0, 1))
    scaled_data = scaler.fit_transform(data)

    joblib.dump(scaler, SCALER_SAVE_PATH)
    print(f"Scaler successfully saved to '{SCALER_SAVE_PATH}'")

    return scaled_data, scaler


def create_sequences(data, lookback):
    X, y = [], []
    for i in range(len(data) - lookback):
        X.append(data[i : (i + lookback), 0])
        y.append(data[i + lookback, 0])

    X = np.array(X)
    y = np.array(y)

    # Reshape X to 3D Tensor: [samples, time steps, features]
    X = np.reshape(X, (X.shape[0], X.shape[1], 1))
    return X, y


def build_and_train_model():
    # Load and scale data
    scaled_data, _ = load_and_preprocess_data(CSV_FILE)

    # Create sliding window sequences
    X, y = create_sequences(scaled_data, LOOKBACK_WINDOW)

    # Train/Validation split (80% train, 20% validation)
    split_idx = int(len(X) * 0.8)
    X_train, X_val = X[:split_idx], X[split_idx:]
    y_train, y_val = y[:split_idx], y[split_idx:]

    print(f"Training samples: {X_train.shape[0]} | Validation samples: {X_val.shape[0]}")

    # Build LSTM Model Architecture
    model = Sequential(
        [
            LSTM(
                64,
                return_sequences=True,
                input_shape=(LOOKBACK_WINDOW, 1),
            ),
            Dropout(0.2),
            LSTM(32, return_sequences=False),
            Dropout(0.2),
            Dense(16, activation="relu"),
            Dense(1),  # Output layer predicting consumption kWh
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