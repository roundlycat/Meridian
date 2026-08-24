// ============================================================
//  Wrist-Puck Rev 6 — Power Budget AUTO-CYCLE Test  (v2)
//  XIAO ESP32-C3 + TCA9548A mux (0x70) + DRV2605L on channel 0
//  July 2026 | Sean (Whitehorse, YT)
//
//  v2 CHANGE: The XIAO ESP32-C3 has NO user LED (LED_BUILTIN
//  does not exist on this board — only power + charge LEDs).
//  States are now announced by N short LRA BUZZES through the
//  DRV. An external LED on D10 (LED + ~220R to GND) is also
//  driven in parallel if present — wire one or don't, both work.
//
//  WORKFLOW
//    1. Flash over USB.
//    2. UNPLUG USB COMPLETELY (it bypasses the meter otherwise).
//    3. Power from MB102 5V rail THROUGH the meter:
//         MB102 + rail -> red probe (DC mA, 400 mA jack)
//         black probe  -> XIAO 5V pin
//         MB102 GND    -> XIAO GND
//       Note: BB830 power rails are SPLIT mid-board — jumper the
//       gap or keep everything on one half.
//    4. Each state announces itself (N buzzes / N blinks), then
//       holds ~30 s while you read the meter and note the number.
//    5. Loops forever; a missed reading comes around again.
//
//  STATE TABLE
//    1 : BASELINE — XIAO + mux, DRV not being addressed
//    2 : DRV IDLE — initialized, default state
//    3 : STANDBY  — DRV standby bit set (announce happens BEFORE
//                   entering standby, so the buzz still works)
//    4 : WAKE     — awake, silent
//    5 : ACTIVE   — continuous strong buzz for the whole window;
//                   read the AVERAGE while it pulses
//
//  BUDGET MATH (mux switches I2C only, not power):
//    5-pod total ≈ baseline + 4×(idle) + 1×(active)
// ============================================================

#include <Wire.h>
#include <Adafruit_DRV2605.h>

#define SDA_PIN   6
#define SCL_PIN   7
#define TCAADDR   0x70
#define DRV_CH    0

#define LED_PIN   D10        // OPTIONAL external LED: D10 -> LED -> 220R -> GND
#define LED_ON    HIGH       // external LED wired to GND = active HIGH
#define LED_OFF   LOW

#define HOLD_MS        30000UL
#define ANNOUNCE_MS    250     // buzz/blink length
#define ANNOUNCE_GAP   300     // gap between announce pulses
#define POST_GAP_MS    1500    // settle time after announcing

Adafruit_DRV2605 drv;
bool drvFound = false;

void tcaSelect(uint8_t ch) {
  if (ch > 7) return;
  Wire.beginTransmission(TCAADDR);
  Wire.write(1 << ch);
  Wire.endTransmission();
}

void buzzOnce() {
  if (!drvFound) return;
  tcaSelect(DRV_CH);
  drv.setWaveform(0, 1);      // short strong click
  drv.setWaveform(1, 0);
  drv.go();
}

// Announce state number N via buzzes + external LED in parallel.
void announce(uint8_t n) {
  for (uint8_t i = 0; i < n; i++) {
    digitalWrite(LED_PIN, LED_ON);
    buzzOnce();
    delay(ANNOUNCE_MS);
    digitalWrite(LED_PIN, LED_OFF);
    delay(ANNOUNCE_GAP);
  }
  delay(POST_GAP_MS);
}

void activeWindow() {
  unsigned long start = millis();
  while (millis() - start < HOLD_MS) {
    if (drvFound) {
      tcaSelect(DRV_CH);
      drv.setWaveform(0, 47);   // strong buzz
      drv.setWaveform(1, 0);
      drv.go();
    }
    digitalWrite(LED_PIN, LED_ON);  delay(400);
    digitalWrite(LED_PIN, LED_OFF); delay(400);
  }
}

// Boot error signal (no DRV found): LED flickers rapidly 3 s.
// Without an LED there is no signal — but the cycle still runs,
// so BASELINE current can be measured regardless.
void errorFlicker() {
  for (uint8_t i = 0; i < 25; i++) {
    digitalWrite(LED_PIN, LED_ON);  delay(60);
    digitalWrite(LED_PIN, LED_OFF); delay(60);
  }
}

void setup() {
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LED_OFF);

  Wire.begin(SDA_PIN, SCL_PIN);   // XIAO needs explicit pins
  delay(200);

  tcaSelect(DRV_CH);
  drvFound = drv.begin();

  if (drvFound) {
    drv.selectLibrary(1);
    drv.setMode(DRV2605_MODE_INTTRIG);
  } else {
    errorFlicker();
  }
}

void loop() {
  // 1 — BASELINE
  announce(1);
  delay(HOLD_MS);

  // 2 — DRV IDLE (re-init)
  announce(2);
  if (drvFound) {
    tcaSelect(DRV_CH);
    drv.begin();
    drv.selectLibrary(1);
    drv.setMode(DRV2605_MODE_INTTRIG);
  }
  delay(HOLD_MS);

  // 3 — STANDBY (announce first, THEN sleep it)
  announce(3);
  if (drvFound) {
    tcaSelect(DRV_CH);
    drv.writeRegister8(DRV2605_REG_MODE, 0x40);
  }
  delay(HOLD_MS);

  // 4 — WAKE (silent)
  announce(4);
  if (drvFound) {
    tcaSelect(DRV_CH);
    drv.writeRegister8(DRV2605_REG_MODE, 0x00);
  }
  delay(HOLD_MS);

  // 5 — ACTIVE (buzzing throughout)
  announce(5);
  activeWindow();
}
