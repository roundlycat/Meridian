/*
 *  MERIDIAN / WRIST-PUCK ECOLOGY
 *  5-LRA Array Testing & Diagnostic Firmware
 *  
 *  Compatible Microcontroller: Seeed Studio XIAO ESP32-C3
 *  Hardware Stack: TCA9548A I2C Multiplexer + 5x Adafruit DRV2605L + 5x LRAs
 *  
 *  Pin Assignment:
 *    - SDA: GPIO6 (D4)
 *    - SCL: GPIO7 (D5)
 *    - LBO (Low Battery): GPIO2 (D0) -> Active LOW below 3.2V
 *  
 *  I2C Address Map:
 *    - TCA9548A Mux: 0x70 (Channels CH0 to CH4 active)
 *    - DRV2605L Breakouts: 0x5A (Identical, separated by Mux channels)
 *  
 *  Haptic Mapping:
 *    - CH0 -> DRV #1 -> Flat LRA A (Vibrotactile)
 *    - CH1 -> DRV #2 -> Flat LRA B (Vibrotactile)
 *    - CH2 -> DRV #3 -> Flat LRA C (Vibrotactile)
 *    - CH3 -> DRV #4 -> Flat LRA D (Vibrotactile)
 *    - CH4 -> DRV #5 -> Angled, off-center LRA (Directional-tug, bidirectional RTP)
 *  
 *  UDP Control:
 *    - Port: 9000
 *    - Input: JSON Motifs
 */

#include <WiFi.h>
#include <WiFiUdp.h>
#include <Wire.h>
#include <ArduinoJson.h>
#include <Adafruit_DRV2605.h>

// --- Configuration & Settings ---
const char* ssid     = "Meridian_2.4G";   // Replace with your 2.4GHz Wi-Fi SSID
const char* password = "your_password";   // Replace with your Wi-Fi password
const int udpPort    = 9000;              // Canonical UDP listener port

// --- Hardware Pins ---
#define SDA_PIN 6
#define SCL_PIN 7
#define LBO_PIN 2

// --- Hardware Constants ---
#define MUX_ADDR 0x70
#define DRV_ADDR 0x5A
#define NUM_CHANNELS 5

// --- Global Objects ---
WiFiUDP udpListener;
Adafruit_DRV2605 drvArray[NUM_CHANNELS];
char incomingPacket[1024];

// --- Helper: Select TCA9548A Multiplexer Channel ---
void selectMuxChannel(uint8_t channel) {
  if (channel >= 8) return;
  Wire.beginTransmission(MUX_ADDR);
  Wire.write(1 << channel);
  Wire.endTransmission();
}

// --- Helper: Scan and Verify I2C Devices ---
bool verifyDevice(uint8_t address) {
  Wire.beginTransmission(address);
  return (Wire.endTransmission() == 0);
}

// --- Execute a Rolling Phantom-Wave Sweep (CH0 -> CH3) ---
void runPhantomSweep(int stepDelayMs, uint8_t effectNum) {
  Serial.printf("[HAPTIC] Executing rolling phantom-wave sweep (%d ms steps)\n", stepDelayMs);
  
  for (int ch = 0; ch < 4; ch++) {
    selectMuxChannel(ch);
    drvArray[ch].setMode(DRV2605_MODE_INTTRIG);
    drvArray[ch].setSequence(0, effectNum);
    drvArray[ch].setSequence(1, 0); // End of sequence
    drvArray[ch].go();
    delay(stepDelayMs);
  }
}

// --- Execute a Bidirectional Directional-Tug Cue on CH4 ---
void runDirectionalTug(int force, int durationMs) {
  Serial.printf("[HAPTIC] Triggering directional-tug on CH4 (Force: %d, Duration: %d ms)\n", force, durationMs);
  
  selectMuxChannel(4);
  
  // Set to Real-Time Playback (RTP) mode
  drvArray[4].setMode(DRV2605_MODE_REALTIME);
  
  // DRV2605L RTP expects a signed 8-bit value (0 is idle, positive/negative drives LRA polarity)
  // Maps 0-255 input to -127 to +127 or uses raw register value
  drvArray[4].setRealtimeValue(force);
  
  delay(durationMs);
  
  // Decay back to neutral / rest position
  drvArray[4].setRealtimeValue(0);
  drvArray[4].setMode(DRV2605_MODE_INTTRIG); // Reset back to default
}

// --- Main Setup ---
void setup() {
  Serial.begin(115200);
  delay(1000);
  Serial.println("\n=============================================");
  Serial.println("MERIDIAN SYSTEM: 5-LRA ARRAY BENCH TEST RIG");
  Serial.println("=============================================");

  // Configure Low Battery Alert (LBO) pin as pullup
  pinMode(LBO_PIN, INPUT_PULLUP);

  // Initialize I2C Bus with explicit pin definition
  Wire.begin(SDA_PIN, SCL_PIN);
  Serial.printf("[I2C] Initialized on SDA:%d, SCL:%d\n", SDA_PIN, SCL_PIN);

  // --- Bring-Up Phase 1: Mux Verification ---
  Serial.printf("[I2C] Scanning for TCA9548A Mux at 0x%02X...\n", MUX_ADDR);
  if (verifyDevice(MUX_ADDR)) {
    Serial.println("[SUCCESS] TCA9548A Multiplexer detected at 0x70.");
  } else {
    Serial.println("[CRITICAL ERROR] TCA9548A Multiplexer NOT detected. Check SDA/SCL pull-ups.");
    while (1) { delay(1000); }
  }

  // --- Bring-Up Phase 2: Sequential DRV Verification ---
  Serial.println("[I2C] Commencing sequential DRV2605L channel scans...");
  for (uint8_t ch = 0; ch < NUM_CHANNELS; ch++) {
    selectMuxChannel(ch);
    delay(10); // Small settling delay for the analog switch
    
    if (verifyDevice(DRV_ADDR)) {
      Serial.printf("  -> Channel CH%d: DRV2605L detected at 0x%02X.\n", ch, DRV_ADDR);
      
      // Initialize the DRV2605L library driver on this channel
      if (drvArray[ch].begin()) {
        drvArray[ch].selectLibrary(1); // Use standard LRA library
        drvArray[ch].setMode(DRV2605_MODE_INTTRIG); // Default to internal trigger mode
        Serial.printf("     CH%d initialized and set to LRA library.\n", ch);
      } else {
        Serial.printf("     [ERROR] Failed to initialize DRV library on CH%d.\n", ch);
      }
    } else {
      Serial.printf("  -> [WARNING] Channel CH%d: No DRV2605L detected. Check wiring/power.\n", ch);
    }
  }

  // --- Bring-Up Phase 3: Connect to Wi-Fi ---
  Serial.printf("[WIFI] Connecting to SSID: %s\n", ssid);
  WiFi.begin(ssid, password);
  
  int connectionRetries = 0;
  while (WiFi.status() != WL_CONNECTED && connectionRetries < 20) {
    delay(500);
    Serial.print(".");
    connectionRetries++;
  }
  
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\n[SUCCESS] Connected to Wi-Fi Network.");
    Serial.print("[WIFI] IP Address: ");
    Serial.println(WiFi.localIP());
    
    // Start UDP socket listener
    udpListener.begin(udpPort);
    Serial.printf("[UDP] Listening for haptic JSON datagrams on port %d\n", udpPort);
  } else {
    Serial.println("\n[WARNING] Wi-Fi Connection failed. Entering offline Serial-Diagnostics mode.");
  }
}

// --- Main Processing Loop ---
void loop() {
  // 1. Check Low Battery Indicator
  if (digitalRead(LBO_PIN) == LOW) {
    Serial.println("[ALERT] LBO Pin is LOW! LiPo battery is critically low (<3.2V). Pausing haptics.");
    delay(2000);
    return;
  }

  // 2. Process Wi-Fi UDP Packets
  int packetSize = udpListener.parsePacket();
  if (packetSize > 0) {
    int len = udpListener.read(incomingPacket, sizeof(incomingPacket) - 1);
    if (len > 0) {
      incomingPacket[len] = 0; // Null-terminate string
    }
    
    Serial.printf("\n[UDP] Packet Received (%d bytes):\n%s\n", packetSize, incomingPacket);
    
    // Parse JSON motif schema
    JsonDocument doc;
    DeserializationError error = deserializeJson(doc, incomingPacket);
    
    if (error) {
      Serial.print("[JSON ERROR] Parsing failed: ");
      Serial.println(error.c_str());
    } else {
      const char* motifId = doc["id"] | "unknown";
      Serial.printf("[JSON] Valid Motif ID: '%s'\n", motifId);
      
      // Check for Sweep Motif Command
      if (doc.containsKey("type") && strcmp(doc["type"], "sweep") == 0) {
        int stepDelay = doc["step_ms"] | 150;
        uint8_t effect = doc["effect"] | 47; // Default 47 is Sharp Click
        runPhantomSweep(stepDelay, effect);
      } 
      // Check for Directional-Tug Command (Targeting CH4)
      else if (doc.containsKey("type") && strcmp(doc["type"], "tug") == 0) {
        int force = doc["amplitude"] | 127; // Signed RTP value
        int duration = doc["dur_ms"] | 200;
        runDirectionalTug(force, duration);
      } 
      // Fallback: Parse steps array
      else if (doc.containsKey("steps")) {
        JsonArray steps = doc["steps"].as<JsonArray>();
        for (JsonObject step : steps) {
          int ch = step["ch"] | 0;
          const char* type = step["type"] | "effect";
          int dur = step["dur_ms"] | 100;
          
          if (ch >= 0 && ch < NUM_CHANNELS) {
            selectMuxChannel(ch);
            
            if (strcmp(type, "effect") == 0) {
              uint8_t effect = step["effect"] | 47;
              drvArray[ch].setMode(DRV2605_MODE_INTTRIG);
              drvArray[ch].setSequence(0, effect);
              drvArray[ch].setSequence(1, 0);
              drvArray[ch].go();
            } else if (strcmp(type, "rtp") == 0) {
              uint8_t amp = step["amplitude"] | 0;
              drvArray[ch].setMode(DRV2605_MODE_REALTIME);
              drvArray[ch].setRealtimeValue(amp);
            }
            delay(dur);
            
            // Clean up RTP state if used
            if (strcmp(type, "rtp") == 0) {
              drvArray[ch].setRealtimeValue(0);
              drvArray[ch].setMode(DRV2605_MODE_INTTRIG);
            }
          }
        }
      }
    }
  }

  // 3. Process Serial Diagnostic Diagnostics (Manual Laptop Tests)
  if (Serial.available() > 0) {
    char cmd = Serial.read();
    
    // Command Menu
    if (cmd == 's') {
      runPhantomSweep(150, 47); // sharp click phantom-wave
    } else if (cmd == 't') {
      runDirectionalTug(127, 250);  // CW positive push tug
      delay(500);
      runDirectionalTug(-127, 250); // CCW negative pull tug
    } else if (cmd >= '0' && cmd <= '4') {
      uint8_t targetCh = cmd - '0';
      Serial.printf("[DIAGNOSTIC] Pulsing Channel CH%d individually...\n", targetCh);
      selectMuxChannel(targetCh);
      drvArray[targetCh].setMode(DRV2605_MODE_INTTRIG);
      drvArray[targetCh].setSequence(0, 47); // Pulse sharp click
      drvArray[targetCh].setSequence(1, 0);
      drvArray[targetCh].go();
    } else {
      Serial.println("\n--- DIAGNOSTICS MENU ---");
      Serial.println("  's' : Trigger Rolling Phantom-Wave Sweep (CH0 -> CH3)");
      Serial.println("  't' : Trigger Bidirectional Directional-Tug on CH4");
      Serial.println("  '0'-'4' : Pulse individual LRA channels directly");
    }
  }

  delay(10); // Standard background polling relaxation
}
