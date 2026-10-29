import joblib
import numpy as np
import tensorflow as tf

MODEL_SAVE_PATH = "lstm_power_model.keras"
SCALER_SAVE_PATH = "scaler.pkl"
LOOKBACK_WINDOW = 24


def load_artifacts():
    """Loads the trained LSTM model and fitted scaler."""
    model = tf.keras.models.load_model(MODEL_SAVE_PATH)
    scaler = joblib.load(SCALER_SAVE_PATH)
    return model, scaler


def predict_next_hour(recent_24h_usage, model, scaler):
    """Predicts power consumption for the very next hour."""
    recent_array = np.array(recent_24h_usage).reshape(-1, 1)

    # Scale the input using the saved scaler bounds
    scaled_input = scaler.transform(recent_array)

    # Reshape input to 3D Tensor: [1 sample, 24 time steps, 1 feature]
    model_input = np.reshape(scaled_input, (1, LOOKBACK_WINDOW, 1))

    # Predict scaled value
    predicted_scaled = model.predict(model_input, verbose=0)

    # Convert back to original kWh scale
    predicted_kwh = scaler.inverse_transform(predicted_scaled)[0][0]
    return max(0.0, float(predicted_kwh))


def predict_next_24_hours(recent_24h_usage, model, scaler):
    """Generates an hourly forecast for tomorrow (24 hours ahead)

    using an autoregressive loop.
    """
    current_sequence = list(recent_24h_usage)
    predictions_kwh = []

    for hour in range(24):
        # Take the most recent 24 hours from our rolling list
        input_window = current_sequence[-LOOKBACK_WINDOW:]

        # Predict next 1 hour
        next_kwh = predict_next_hour(input_window, model, scaler)
        predictions_kwh.append(next_kwh)

        # Append prediction to current sequence for recursive forecasting
        current_sequence.append(next_kwh)

    return predictions_kwh


if __name__ == "__main__":
    # Load model and scaler artifacts
    model, scaler = load_artifacts()

    # Example test input: 24 hourly readings from yesterday (kWh)
    sample_yesterday_data = [
        0.42, 0.38, 0.35, 0.36, 0.41, 0.85, 1.45, 2.10, 1.80, 1.20,
        0.95, 0.88, 0.90, 0.92, 1.10, 1.65, 2.40, 3.10, 3.50, 2.80,
        1.90, 1.25, 0.75, 0.50
    ]

    print("--- Single Hour Test ---")
    next_hour_pred = predict_next_hour(sample_yesterday_data, model, scaler)
    print(f"Predicted Consumption for Next Hour: {next_hour_pred:.3f} kWh")

    print("\n--- 24-Hour Tomorrow Forecast Test ---")
    tomorrow_forecast = predict_next_24_hours(sample_yesterday_data, model, scaler)

    for hr, val in enumerate(tomorrow_forecast, 1):
        print(f"Hour {hr:02d}: {val:.3f} kWh")