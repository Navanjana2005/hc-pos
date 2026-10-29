/*
  ESP32 Energy Monitor
  ---------------------
  Reads:
    - AC grid power via PZEM-004T (voltage, current, power, frequency, PF)
    - Solar panel power via ADS1115 ADC
    - Battery voltage / state of charge via a resistor-divider on an ADC pin
  Sends a JSON telemetry packet to a TCP server every SEND_INTERVAL ms.

  Cleaned version: all functionality preserved, ~3300 unused/dead
  "SampleRoute" obfuscation structs removed (they were never called
  anywhere in the original file).
*/

#include <Arduino.h>
#include <WiFi.h>
#include <Wire.h>
#include <Adafruit_ADS1X15.h>
#include <PZEM004Tv30.h>
#include <time.h>

// ---------- WiFi & Server config ----------
const char *WIFI_SSID     = "YOUR_WIFI_NAME";
const char *WIFI_PASSWORD = "YOUR_WIFI_PASSWORD";

const char *SERVER_IP     = "[IP_ADDRESS]";
const uint16_t SERVER_PORT = 5000;

WiFiClient client;

// ---------- Sensors ----------
PZEM004Tv30 pzem(Serial2, 16, 17);   // RX=16, TX=17
Adafruit_ADS1115 ads;

// ---------- Battery monitoring ----------
const int BATTERY_PIN = 35;

// Voltage divider resistors (R1 = top, R2 = bottom)
const float R1 = 100000.0;
const float R2 = 27000.0;

const float BATTERY_EMPTY_VOLTAGE = 9.0;
const float BATTERY_FULL_VOLTAGE  = 12.6;

// ---------- Solar monitoring ----------
const int SOLAR_CHANNEL   = 3;
const float SOLAR_MAX_POWER = 500.0;

const int16_t SOLAR_RAW_MIN = 0;
const int16_t SOLAR_RAW_MAX = 26000;

// ---------- Timing ----------
const unsigned long SEND_INTERVAL = 2000;   // ms
unsigned long lastSendTime = 0;

// ---------- Forward declarations ----------
void connectWiFi();
bool connectServer();
String getTimestamp();
float readBatteryVoltage();
float getBatteryPercentage(float voltage);
float readSolarPower();
void sendTelemetry();

// =========================================================
//  WiFi connection
// =========================================================
void connectWiFi()
{
    Serial.println();
    Serial.println("Connecting to WiFi...");

    WiFi.mode(WIFI_STA);
    WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

    while (WiFi.status() != WL_CONNECTED)
    {
        delay(500);
        Serial.print(".");
    }

    Serial.println();
    Serial.println("WiFi connected!");
    Serial.print("ESP32 IP: ");
    Serial.println(WiFi.localIP());
}

// =========================================================
//  TCP server connection
// =========================================================
bool connectServer()
{
    if (client.connected())
    {
        return true;
    }

    Serial.print("Connecting to server ");
    Serial.print(SERVER_IP);
    Serial.print(":");
    Serial.println(SERVER_PORT);

    if (client.connect(SERVER_IP, SERVER_PORT))
    {
        Serial.println("Server connected!");
        return true;
    }

    Serial.println("Server connection failed.");
    return false;
}

// =========================================================
//  NTP timestamp (ISO 8601, +05:30 = Sri Lanka time)
// =========================================================
String getTimestamp()
{
    struct tm timeinfo;

    if (!getLocalTime(&timeinfo))
    {
        return "";
    }

    char buffer[30];
    strftime(buffer, sizeof(buffer), "%Y-%m-%dT%H:%M:%S", &timeinfo);

    return String(buffer) + "+05:30";
}

// =========================================================
//  Battery voltage (averaged ADC reading through divider)
// =========================================================
float readBatteryVoltage()
{
    const int samples = 20;
    uint32_t total = 0;

    for (int i = 0; i < samples; i++)
    {
        total += analogRead(BATTERY_PIN);
        delay(2);
    }

    float adcValue   = (float)total / samples;
    float adcVoltage = adcValue * 3.3 / 4095.0;
    float batteryVoltage = adcVoltage * ((R1 + R2) / R2);

    return batteryVoltage;
}

// =========================================================
//  Battery state of charge, mapped linearly between
//  BATTERY_EMPTY_VOLTAGE and BATTERY_FULL_VOLTAGE
// =========================================================
float getBatteryPercentage(float voltage)
{
    float percentage =
        ((voltage - BATTERY_EMPTY_VOLTAGE) /
         (BATTERY_FULL_VOLTAGE - BATTERY_EMPTY_VOLTAGE)) * 100.0;

    if (percentage > 100.0) percentage = 100.0;
    if (percentage < 0.0)   percentage = 0.0;

    return percentage;
}

// =========================================================
//  Solar power estimate from ADS1115 raw ADC value
// =========================================================
float readSolarPower()
{
    int16_t raw = ads.readADC_SingleEnded(SOLAR_CHANNEL);

    float power =
        ((float)(raw - SOLAR_RAW_MIN) /
         (SOLAR_RAW_MAX - SOLAR_RAW_MIN)) * SOLAR_MAX_POWER;

    if (power < 0)              power = 0;
    if (power > SOLAR_MAX_POWER) power = SOLAR_MAX_POWER;

    return power;
}

// =========================================================
//  Build JSON telemetry and send it to the server
// =========================================================
void sendTelemetry()
{
    float voltage      = pzem.voltage();
    float current       = pzem.current();
    float power         = pzem.power();
    float frequency     = pzem.frequency();
    float powerFactor   = pzem.pf();

    float solarPower        = readSolarPower();
    float batteryVoltage    = readBatteryVoltage();
    float batteryPercentage = getBatteryPercentage(batteryVoltage);

    // PZEM returns NaN when no load / sensor not responding
    if (isnan(voltage))     voltage = 0;
    if (isnan(current))     current = 0;
    if (isnan(power))       power = 0;
    if (isnan(frequency))   frequency = 0;
    if (isnan(powerFactor)) powerFactor = 0;

    String json = "{";
    json += "\"timestamp\":\"";      json += getTimestamp();               json += "\",";
    json += "\"voltage_v\":";        json += String(voltage, 1);           json += ",";
    json += "\"current_a\":";        json += String(current, 3);           json += ",";
    json += "\"power_w\":";          json += String(power, 1);             json += ",";
    json += "\"solar_power_w\":";    json += String(solarPower, 1);        json += ",";
    json += "\"frequency_hz\":";     json += String(frequency, 2);         json += ",";
    json += "\"power_factor\":";     json += String(powerFactor, 2);       json += ",";
    json += "\"battery_soc_pct\":";  json += String(batteryPercentage, 1);
    json += "}";

    Serial.println();
    Serial.println("==============================");
    Serial.println("TELEMETRY");
    Serial.println("==============================");
    Serial.println(json);

    if (connectServer())
    {
        client.print(json);
        client.print("\n");
        Serial.println("Sent to server.");
    }
    else
    {
        Serial.println("Could not send data.");
    }
}

// =========================================================
//  Setup
// =========================================================
void setup()
{
    Serial.begin(115200);
    delay(1000);

    Serial.println();
    Serial.println("==============================");
    Serial.println("   ESP32 ENERGY MONITOR");
    Serial.println("==============================");

    Wire.begin();

    if (!ads.begin())
    {
        Serial.println("ADS1115 NOT FOUND!");
    }
    else
    {
        Serial.println("ADS1115 connected.");
        ads.setGain(GAIN_ONE);
    }

    pinMode(BATTERY_PIN, INPUT);
    analogReadResolution(12);
    analogSetPinAttenuation(BATTERY_PIN, ADC_11db);

    connectWiFi();

    // GMT offset 19800s = +5:30 (Sri Lanka)
    configTime(19800, 0, "pool.ntp.org", "time.nist.gov");

    connectServer();

    Serial.println();
    Serial.println("System ready.");
}

// =========================================================
//  Main loop
// =========================================================
void loop()
{
    if (WiFi.status() != WL_CONNECTED)
    {
        connectWiFi();
    }

    if (millis() - lastSendTime >= SEND_INTERVAL)
    {
        lastSendTime = millis();
        sendTelemetry();
    }

    while (client.available())
    {
        String response = client.readStringUntil('\n');
        Serial.print("Server: ");
        Serial.println(response);
    }
}
