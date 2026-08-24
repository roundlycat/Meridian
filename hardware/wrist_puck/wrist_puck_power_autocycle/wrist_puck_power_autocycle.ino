// ============================================================
//  Wrist-Puck Rev 6 — Power Budget AUTO-CYCLE Test
//  XIAO ESP32-C3 + TCA9548A mux (0x70) + DRV2605L on channel 0
//  July 2026 | Sean (Whitehorse, YT)
//
//  WHY THIS VERSION EXISTS
//  The interactive sketch needs USB serial — but USB is a second
//  power source that bypasses the meter, so battery-side current
//  can never be measured while it's plugged in. This sketch runs
//  the whole state sequence on its own. Workflow:
//
//    1. Flash over USB as usual.
//    2. UNPLUG USB completely.
//    3. Power the XIAO from the LiPo *through the meter*:
//         LiPo +  ->  red probe (meter on DC mA, 400 mA jack)
//         black probe -> XIAO BAT+ pad
//         LiPo -  ->  XIAO BAT- pad
//       (Meter in series on the + side. USB stays unplugged.)
//    4. Watch the onboard LED. Each state announces itself with
//       N blinks, then holds steady for HOLD_MS while you read
//       the meter and write the number down.
//    5. Sequence loops forever, so a missed reading just means
//       waiting one lap (~3 minutes).
//
//  STATE TABLE — what N blinks means, and what you're measuring
//    1 blink : BASELINE   — XIAO + mux idle, DRV untouched.
//    2 blinks: DRV IDLE   — DRV initialized, sitting in default state.
//    3 blinks: STANDBY    — DRV put into standby via MODE register.
//    4 blinks: WAKE       — DRV awake, no playback.
//    5 blinks: ACTIVE     — DRV firing effect 47 (strong buzz) in a
//                           repeating loop. Read the AVERAGE — the
//                           needle/number will pulse with the buzz.
//  Then back to 1. Record all five numbers = power budget row done.
//
//  MULTIPLY-OUT REMINDER
//  The mux switches I2C only, not power. Final budget for 5 pods:
//    total ≈ baseline + 4×(idle draw) + 1×(active draw)
//  assuming one pod fires at a time, which is the array's design.
//
//  WIRING (unchanged from bench setup)
//    XIAO SDA = GPIO6, SCL = GPIO7 — explicit Wire.begin(6, 7)
//    TCA9548A at 0x70, DRV2605L on mux channel 0
// ============================================================

#include <Wire.h>
#include <Adafruit_DRV2605.h>

#define SDA_PIN   6
#define SCL_PIN   7
#define TCAADDR   0x70
#define DRV_CH    0          // mux channel where the DRV lives

#define LED_PIN   LED_BUILTIN  // XIAO ESP32-C3 onboard LED (inverted)
#define LED_ON    LOW
#define LED_OFF   HIGH

#define HOLD_MS       30000UL   // how long each state holds for meter reading
#define BLINK_ON_MS   250
#define BLINK_OFF_MS  250
#define BLINK_GAP_MS  1200      // pause after announcing before hold starts

Adafruit_DRV2605 drv;
bool drvFound = false;

// ---- helpers ------------------------------------------------

void tcaSelect(uint8_t ch) {
  if (ch > 7) return;
  Wire.beginTransmission(TCAADDR);
  Wire.write(1 << ch);
  Wire.endTransmission();
}

void blinkCount(uint8_t n) {
  for (uint8_t i = 0; i < n; i++) {
    digitalWrite(LED_PIN, LED_ON);  delay(BLINK_ON_MS);
    digitalWrite(LED_PIN, LED_OFF); delay(BLINK_OFF_MS);
  }
  delay(BLINK_GAP_MS);
}

// Announce state with N blinks, then hold quietly for reading.
void announceAndHold(uint8_t n) {
  blinkCount(n);
  delay(HOLD_MS);
}

// Hold in ACTIVE while re-firing the buzz so it stays audible/felt
// and the current draw stays representative for the whole window.
void activeHold(uint8_t n) {
  blinkCount(n);
  unsigned long start = millis();
  while (millis() - start < HOLD_MS) {
    if (drvFound) {
      tcaSelect(DRV_CH);
      drv.setWaveform(0, 47);   // strong click/buzz
      drv.setWaveform(1, 0);
      drv.go();
    }
    delay(800);                 // re-trigger cadence
  }
}

// Error signal: rapid continuous flicker = DRV never found.
// Sketch still cycles so BASELINE can be measured regardless.
void errorFlicker(uint16_t ms) {
  unsigned long start = millis();
  while (millis() - start < ms) {
    digitalWrite(LED_PIN, LED_ON);  delay(60);
    digitalWrite(LED_PIN, LED_OFF); delay(60);
  }
}

// ---- setup --------------------------------------------------

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
    errorFlicker(3000);           // 3 s rapid flicker at boot = no DRV
  }
}

// ---- main cycle ---------------------------------------------

void loop() {
  // STATE 1 — BASELINE: XIAO + mux only. DRV left however it is,
  // but not being talked to. Closest thing to system floor.
  announceAndHold(1);

  // STATE 2 — DRV IDLE: (re)initialized, default post-begin state.
  if (drvFound) {
    tcaSelect(DRV_CH);
    drv.begin();
    drv.selectLibrary(1);
    drv.setMode(DRV2605_MODE_INTTRIG);
  }
  announceAndHold(2);

  // STATE 3 — STANDBY: MODE register standby bit set.
  if (drvFound) {
    tcaSelect(DRV_CH);
    drv.writeRegister8(DRV2605_REG_MODE, 0x40);  // STANDBY
  }
  announceAndHold(3);

  // STATE 4 — WAKE: out of standby, internal trigger mode, silent.
  if (drvFound) {
    tcaSelect(DRV_CH);
    drv.writeRegister8(DRV2605_REG_MODE, 0x00);  // active, int trig
  }
  announceAndHold(4);

  // STATE 5 — ACTIVE: repeating strong buzz for the whole window.
  activeHold(5);

  // Loop back to baseline. Missed a reading? It comes around again.
}
