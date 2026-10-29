# step3_generate_test_data.py
"""
Generates synthetic NILM training/testing CSVs for MULTIPLE devices (not
just fan vs. "other"). Each row is one 1-second, 860-sample current window
plus an integer `label` column identifying which device produced it.

This replaces the old binary fan/other generator. Output files:
  - train_data.csv        : windows_per_device * len(DEVICE_PROFILES) rows
  - test_data.csv          : smaller, noisier hold-out set
  - device_label_map.csv    : label -> device_name, so decision_engine.py
                              (and anything else consuming the trained
                              model's output) can decode predictions using
                              the SAME index order the model was trained on.

Idle windows are deliberately NOT a class here — decision_engine.py detects
"Idle / No Device" with a cheap RMS-current threshold before ever calling
the model, so the classifier only needs to distinguish between devices that
are actually drawing power.

Add a new device by adding one entry to DEVICE_PROFILES below; everything
else (dataset size, CSV shape, label map) follows automatically.
"""

import numpy as np
import pandas as pd

WINDOW_SIZE = 860
SAMPLING_RATE_HZ = 860  # 1 second of samples

# ==========================================================================
# DEVICE PROFILES
# Each device is defined by:
#   amp_range      - fundamental current amplitude range (device "size")
#   freq_range      - 50Hz mains frequency with device-specific jitter
#   harmonics        - list of (harmonic_multiple, relative_amplitude) that
#                       give each device family its characteristic shape:
#                       motors -> odd harmonics, resistive heaters -> almost
#                       none, switch-mode electronics -> more/lower harmonics
#   noise_level       - sensor + electrical noise floor
# ==========================================================================

DEVICE_PROFILES = {
    "HouseHold_Fan-240-150w":  {"amp": (1.25, 1.50), "freq": (49.8, 50.2), "harmonics": [(3, 0.12)],            "noise": 0.18},
    "Washing_Machine-1200w":   {"amp": (3.20, 3.80), "freq": (49.7, 50.3), "harmonics": [(3, 0.20), (5, 0.08)], "noise": 0.22},
    "Water_Heater-2000w":      {"amp": (5.00, 5.60), "freq": (49.9, 50.1), "harmonics": [],                      "noise": 0.10},
    "Refrigerator-150w":       {"amp": (1.00, 1.30), "freq": (49.8, 50.2), "harmonics": [(3, 0.15)],            "noise": 0.16},
    "Air_Conditioner-1500w":   {"amp": (3.60, 4.20), "freq": (49.8, 50.2), "harmonics": [(3, 0.18), (5, 0.06)], "noise": 0.20},
    "Microwave_Oven-1100w":    {"amp": (2.60, 3.10), "freq": (49.7, 50.3), "harmonics": [(2, 0.10), (3, 0.25)], "noise": 0.25},
    "Electric_Iron-1000w":     {"amp": (2.40, 2.80), "freq": (49.9, 50.1), "harmonics": [],                      "noise": 0.09},
    "Rice_Cooker-700w":        {"amp": (1.60, 2.00), "freq": (49.9, 50.1), "harmonics": [],                      "noise": 0.11},
    "LED_TV-90w":              {"amp": (0.50, 0.70), "freq": (49.8, 50.2), "harmonics": [(2, 0.30), (3, 0.15)], "noise": 0.14},
    "Electric_Kettle-1500w":   {"amp": (3.60, 4.00), "freq": (49.9, 50.1), "harmonics": [],                      "noise": 0.10},
}

DEVICE_NAMES = sorted(DEVICE_PROFILES.keys())  # fixed order == label index order


def generate_device_window(device_name: str, window_size: int = WINDOW_SIZE) -> np.ndarray:
    """Generates one 1-second noisy AC current window for the given device."""
    profile = DEVICE_PROFILES[device_name]
    t = np.linspace(0, window_size / SAMPLING_RATE_HZ, window_size, endpoint=False)
    amp = np.random.uniform(*profile["amp"])
    freq = np.random.uniform(*profile["freq"])

    signal = amp * np.sin(2 * np.pi * freq * t)
    for harmonic_mult, rel_amp in profile["harmonics"]:
        signal += (amp * rel_amp) * np.sin(2 * np.pi * (freq * harmonic_mult) * t)
    signal += np.random.normal(0, profile["noise"], size=window_size)
    return signal


def generate_device_dataset(windows_per_device: int = 200, window_size: int = WINDOW_SIZE):
    """Returns (X, y, device_names) where X is (N, window_size), y is (N,)
    integer labels, and device_names[label] gives the device name for that
    label — the same order that gets written to device_label_map.csv."""
    X, y = [], []
    for label_idx, name in enumerate(DEVICE_NAMES):
        for _ in range(windows_per_device):
            X.append(generate_device_window(name, window_size))
            y.append(label_idx)

    X = np.array(X)
    y = np.array(y)
    shuffle_idx = np.random.permutation(len(X))
    return X[shuffle_idx], y[shuffle_idx], DEVICE_NAMES


def _save_dataset_csv(X: np.ndarray, y: np.ndarray, path: str, window_size: int = WINDOW_SIZE) -> None:
    df = pd.DataFrame(X, columns=[f"feature_{i}" for i in range(window_size)])
    df["label"] = y
    df.to_csv(path, index=False)
    print(f"Saved {path} with shape {df.shape}")


if __name__ == "__main__":
    print(f"Generating multi-device dataset for {len(DEVICE_NAMES)} devices: {DEVICE_NAMES}")

    print("\nGenerating training data...")
    X_train, y_train, device_names = generate_device_dataset(windows_per_device=300)
    _save_dataset_csv(X_train, y_train, "train_data.csv")

    print("\nGenerating noisier test/hold-out data...")
    X_test, y_test, _ = generate_device_dataset(windows_per_device=60)
    _save_dataset_csv(X_test, y_test, "test_data.csv")

    print("\nSaving device_label_map.csv (label -> device_name)...")
    label_map_df = pd.DataFrame({
        "label": list(range(len(device_names))),
        "device_name": device_names,
    })
    label_map_df.to_csv("device_label_map.csv", index=False)
    print(label_map_df.to_string(index=False))
    print(
        "\nIMPORTANT: train_model.py's output layer size must equal "
        f"len(device_names) = {len(device_names)}, and it must be trained "
        "with these exact CSVs so the label indices line up with "
        "device_label_map.csv."
    )