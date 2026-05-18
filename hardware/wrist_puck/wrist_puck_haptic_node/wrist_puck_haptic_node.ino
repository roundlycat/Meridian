#include <WiFi.h>
#include <WiFiUdp.h>
#include <Wire.h>
#include <ESP32Servo.h>
#include <ArduinoJson.h>
#include <Adafruit_DRV2605.h>

// ---------------------------------------------------------
// Configuration
// ---------------------------------------------------------
const char* WIFI_SSID = "YOUR_SSID";
const char* WIFI_PASS = "YOUR_PASSWORD";
const int UDP_PORT = 9000;

// Hardware Pins for XIAO ESP32-C3
#define SDA_PIN 6
#define SCL_PIN 7
#define SERVO_PIN 5
#define BAT_ADC_PIN 2

// ---------------------------------------------------------
// Globals
// ---------------------------------------------------------
Adafruit_DRV2605 drv;
Servo myServo;
WiFiUDP udp;

unsigned long lastMotifTime = 0;
const unsigned long IDLE_TIMEOUT = 5000;
bool isIdle = true;
float batVoltage = 0.0;
bool lowBatteryState = false;

// ---------------------------------------------------------
// Setup
// ---------------------------------------------------------
void setup() {
  Serial.begin(115200);
  delay(1000);
  Serial.println("\n==================================");
  Serial.println("Wrist-Puck Dual-Channel Haptic Node");
  Serial.println("==================================");
  
  pinMode(BAT_ADC_PIN, INPUT);

  // Initialize I2C
  Wire.begin(SDA_PIN, SCL_PIN);
  
  // Initialize DRV2605L
  if (!drv.begin(&Wire)) {
    Serial.println("ERROR: DRV2605L not found at 0x5A!");
  } else {
    Serial.println("DRV2605L initialized.");
    drv.selectLibrary(1); // 1 = ERM, but can be 6 for LRA. For LRA, typical setup is below:
    // Configure for LRA
    drv.setMode(DRV2605_MODE_INTTRIG); 
  }

  // Initialize Servo
  // SG51R sub-micro servo, ~500 to 2500 us pulse width mapping
  myServo.attach(SERVO_PIN, 500, 2500); 

  // Calibration Checks (from the build guide)
  calibrateMotors();

  // Connect WiFi
  WiFi.begin(WIFI_SSID, WIFI_PASS);
  Serial.print("Connecting to WiFi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nConnected!");
  Serial.print("IP Address: ");
  Serial.println(WiFi.localIP());

  // Start UDP
  udp.begin(UDP_PORT);
  Serial.printf("Listening on UDP port %d\n", UDP_PORT);
}

// ---------------------------------------------------------
// Calibration & Boot Sequence
// ---------------------------------------------------------
void calibrateMotors() {
  Serial.println("Running servo sweep test...");
  myServo.writeMicroseconds(1500);
  delay(500);
  myServo.writeMicroseconds(1000);
  delay(500);
  myServo.writeMicroseconds(2000);
  delay(500);
  myServo.writeMicroseconds(1500);
  
  Serial.println("Running LRA strong click test...");
  drv.setMode(DRV2605_MODE_INTTRIG);
  drv.setWaveform(0, 1);  // Effect 1: Strong Click
  drv.setWaveform(1, 0);  // End of sequence
  drv.go();
}

// ---------------------------------------------------------
// Main Loop
// ---------------------------------------------------------
void loop() {
  // Check battery (Voltage divider 100k/100k)
  int adcValue = analogRead(BAT_ADC_PIN);
  // ESP32-C3 ADC is 12-bit (0-4095). Max voltage is 3.3V. 
  // Divider cuts voltage in half, so we multiply by 2.
  batVoltage = (adcValue / 4095.0) * 3.3 * 2.0; 
  
  // Low battery check (Only trigger if battery is actually connected > 1.0V)
  if (batVoltage < 3.3 && batVoltage > 1.0) {
    if (!lowBatteryState) {
      Serial.printf("WARNING: Low battery! %.2fV\n", batVoltage);
      lowBatteryState = true;
    }
  } else {
    lowBatteryState = false;
  }

  // Parse UDP Motifs
  int packetSize = udp.parsePacket();
  if (packetSize) {
    char packetBuffer[2048];
    int len = udp.read(packetBuffer, sizeof(packetBuffer) - 1);
    packetBuffer[len] = 0; // null-terminate
    
    Serial.printf("Received motif (%d bytes)\n", len);
    
    lastMotifTime = millis();
    isIdle = false;

    // Do not process motifs if battery is dangerously low
    if (!lowBatteryState) {
      processMotif(packetBuffer);
    } else {
      Serial.println("Motif ignored: Low Battery");
    }
  }

  // Idle timeout: auto-center servo
  if (!isIdle && millis() - lastMotifTime > IDLE_TIMEOUT) {
    myServo.writeMicroseconds(1500);
    isIdle = true;
    Serial.println("Idle timeout. Servo centered.");
  }

  // Note: Default ESP32 Arduino Core watchdog will trigger if this loop 
  // blocks for too long without yielding. (Usually 5-8 seconds).
}

// ---------------------------------------------------------
// Process JSON Motif
// ---------------------------------------------------------
void processMotif(const char* jsonStr) {
  JsonDocument doc;
  DeserializationError error = deserializeJson(doc, jsonStr);
  
  if (error) {
    Serial.print("deserializeJson() failed: ");
    Serial.println(error.c_str());
    return;
  }

  const char* motifId = doc["id"] | "unknown";
  int repeat = doc["repeat"] | 1;
  JsonArray steps = doc["steps"];

  Serial.printf("Playing motif: %s (Repeat: %d)\n", motifId, repeat);

  for (int r = 0; r < repeat; r++) {
    for (JsonObject step : steps) {
      const char* ch = step["ch"];
      const char* type = step["type"];
      int dur_ms = step["dur_ms"] | 0;
      
      // -- LRA Channel --
      if (ch != nullptr && strcmp(ch, "lra") == 0) {
        if (strcmp(type, "effect") == 0) {
          int effect = step["effect"] | 1;
          drv.setMode(DRV2605_MODE_INTTRIG);
          drv.setWaveform(0, effect);
          drv.setWaveform(1, 0);
          drv.go();
        } 
        else if (strcmp(type, "rtp") == 0) {
          int amplitude = step["amplitude"] | 0;
          drv.setMode(DRV2605_MODE_REALTIME);
          drv.setRealtimeValue(amplitude);
        } 
        else if (strcmp(type, "stop") == 0) {
          drv.setMode(DRV2605_MODE_REALTIME);
          drv.setRealtimeValue(0);
        }
      } 
      // -- Servo Channel --
      else if (ch != nullptr && strcmp(ch, "servo") == 0) {
        if (strcmp(type, "pos") == 0) {
          int pos_us = step["pos_us"] | 1500;
          myServo.writeMicroseconds(pos_us);
        } 
        else if (strcmp(type, "center") == 0) {
          myServo.writeMicroseconds(1500);
        } 
        else if (strcmp(type, "sweep") == 0) {
          myServo.writeMicroseconds(1000);
          delay(500);
          myServo.writeMicroseconds(2000);
          delay(500);
          myServo.writeMicroseconds(1500);
        }
      }
      
      // Delay for dwell time if specified
      if (dur_ms > 0) {
        delay(dur_ms);
      }
    }
  }
}
