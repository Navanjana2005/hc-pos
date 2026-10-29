# step1_generate_train_data.py
import numpy as np

def generate_fan_signal(num_samples=860, sampling_rate=860, noise_level=0.08):
    """
    Generates a synthetic waveform matching the HouseHold_Fan-240-150w profile:
    ~50 Hz AC fundamental wave + slight appliance harmonics + Gaussian noise.
    """
    t = np.linspace(0, num_samples / sampling_rate, num_samples, endpoint=False)
    
    # Randomize phase and slight amplitude jitter (peak around 1.35A - 1.48A)
    amplitude = np.random.uniform(1.35, 1.48)
    phase = np.random.uniform(0, 2 * np.pi)
    
    # Fundamental 50Hz AC wave + 3rd harmonic
    fundamental = amplitude * np.sin(2 * np.pi * 50 * t + phase)
    harmonic = (amplitude * 0.12) * np.sin(2 * np.pi * 150 * t + phase)
    
    noise = np.random.normal(0, noise_level, size=num_samples)
    return fundamental + harmonic + noise

def generate_other_appliance_signal(num_samples=860, sampling_rate=860, noise_level=0.08):
    """
    Generates a contrasting appliance signal.
    """
    t = np.linspace(0, num_samples / sampling_rate, num_samples, endpoint=False)
    amplitude = np.random.uniform(0.8, 1.1)
    phase = np.random.uniform(0, 2 * np.pi)
    
    signal = amplitude * np.sin(2 * np.pi * 50 * t + phase)
    noise = np.random.normal(0, noise_level, size=num_samples)
    return signal + noise

def create_training_dataset(num_windows=2000, window_size=860):
    X, y = [], []
    for _ in range(num_windows // 2):
        X.append(generate_fan_signal(num_samples=window_size))
        y.append(1)
        X.append(generate_other_appliance_signal(num_samples=window_size))
        y.append(0)
        
    X = np.array(X)  # shape (2000, 860)
    y = np.array(y).reshape(-1, 1)  # shape (2000, 1)
    
    # Shuffle dataset
    indices = np.arange(len(X))
    np.random.shuffle(indices)
    
    # Concatenate X and y and return
    return np.hstack((X[indices], y[indices]))

if __name__ == "__main__":
    import pandas as pd
    print("Generating training dataset...")
    data = create_training_dataset(num_windows=2000, window_size=860)
    
    # Create column names
    columns = [f"feature_{i}" for i in range(860)] + ["label"]
    df = pd.DataFrame(data, columns=columns)
    
    # Save to CSV
    csv_filename = "train_data.csv"
    df.to_csv(csv_filename, index=False)
    print(f"Saved dataset to {csv_filename} with shape {df.shape} successfully.")