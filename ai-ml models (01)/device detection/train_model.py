# step2_train_model.py
import numpy as np
import pandas as pd
import tensorflow as tf
from keras import layers, models

def build_efficient_1d_cnn(input_shape=(860, 1), num_classes=10):
    inputs = layers.Input(shape=input_shape)
    
    # Block 1: Feature Extraction
    x = layers.Conv1D(filters=16, kernel_size=15, strides=2, padding='same', activation='relu')(inputs)
    x = layers.BatchNormalization()(x)
    x = layers.MaxPooling1D(pool_size=2)(x)
    
    # Block 2: Higher-level Patterns
    x = layers.Conv1D(filters=32, kernel_size=7, strides=1, padding='same', activation='relu')(x)
    x = layers.BatchNormalization()(x)
    x = layers.MaxPooling1D(pool_size=2)(x)
    
    # Block 3: Deep Representation
    x = layers.Conv1D(filters=64, kernel_size=3, strides=1, padding='same', activation='relu')(x)
    x = layers.BatchNormalization()(x)
    
    # Global Average Pooling replaces large Dense layers
    x = layers.GlobalAveragePooling1D()(x)
    x = layers.Dropout(0.3)(x)
    
    # Output Layer — one softmax probability per device class. Must match
    # the number of rows in device_label_map.csv (produced by
    # generate_test_stream.py), or decision_engine.py's argmax decoding
    # will be reading the wrong class indices.
    outputs = layers.Dense(num_classes, activation='softmax')(x)
    
    model = models.Model(inputs=inputs, outputs=outputs, name="Efficient_Device_1DCNN")
    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=0.001),
        loss='sparse_categorical_crossentropy',  # labels are plain ints, not one-hot
        metrics=['accuracy']
    )
    return model

if __name__ == "__main__":
    print("Loading device label map...")
    label_map_df = pd.read_csv("device_label_map.csv")
    num_classes = len(label_map_df)
    print(f"Training for {num_classes} device classes: {list(label_map_df['device_name'])}")

    print("Loading training data...")
    df = pd.read_csv("train_data.csv")
    
    X_train = df.drop("label", axis=1).values
    y_train = df["label"].values
    
    # Reshape for 1D CNN: (samples, features, channels)
    X_train = X_train.reshape((X_train.shape[0], X_train.shape[1], 1))
    
    print("Building and training 1D-CNN model...")
    model = build_efficient_1d_cnn(input_shape=(860, 1), num_classes=num_classes)
    
    model.fit(
        X_train, y_train,
        epochs=15,
        batch_size=32,
        validation_split=0.2,
        verbose=1
    )
    
    # Save the trained model
    model_filename = "fan_1dcnn_model.keras"
    model.save(model_filename)
    print(f"\nModel trained and saved as '{model_filename}'.")