// ============================================================
//  Wrist-Puck Rev 6 — Power Budget Test Harness
//  XIAO ESP32-C3 + TCA9548A mux + DRV2605L (Adafruit + generic boards)
//  July 2026 | Sean (Whitehorse, YT)
//
//  PURPOSE
//  This is not a demo — it's a bench tool. It does nothing on its
//  own. You drive every state change from the Serial Monitor, read
//  your multimeter / USB power meter after each command, then send
//  the next one. No fixed delays, because meter settling time is
//  yours to judge, not the sketch's.
//
//  WHAT YOU'RE ACTUALLY MEASURING
//  The mux only switches I2C addressing, not power. All boards wired
//  to the mux's downstream channels are powered continuously and
//  simultaneously regardless of which channel is "selected." So the
//  number that matters for your battery budget is:
//
//      (idle-but-powered draw) x (boards not currently firing)
//    + (active draw)           x (boards currently firing, usually 1)
//    + XIAO + TCA9548A quiescent draw
//
//  Run through states 'i' -> 's' -> 'w' -> 'p' -> 'q' on ONE board,
//  record each reading, then repeat for a second board of the SAME
//  type to sanity check consistency, then repeat the whole process
//  for the OTHER board type (Adafruit vs. the two smaller generic
//  DRV2605L modules) since onboard regulator/pull-up overhead may
//  differ between them.
//
//  WIRING
//  XIAO ESP32-C3 does not default its I2C pins correctly — Wire.begin()
//  with no arguments will not find the bus. SDA=D4(GPIO6), SCL=D5(GPIO7),
//  called out explicitly below (confirmed from the assembly notes).
//  XIAO -> TCA9548A (default address 0x70) -> up to 8 channels, one
//  DRV2605L board per channel. All DRV2605L boards share I2C address
//  0x5A; the mux is what makes that non-fatal.
//
//  LIBRARY
//  Requires Adafruit_DRV2605 library (Library Manager: "Adafruit DRV2605").
//  Same library/sketch works for Adafruit boards and generic DRV2605L
//  modules alike — the chip is the chip, regardless of breakout.
// ============================================================

#include <Wire.h>
#include <Adafruit_DRV2605.h>

#define SDA_PIN   6
#define SCL_PIN   7
#define TCA_ADDR  0x70

Adafruit_DRV2605 drv;
uint8_t currentChannel = 0;
bool drvReady = false;

void tcaSelect(uint8_t ch) {
  if (ch > 7) return;
  Wire.beginTransmission(TCA_ADDR);
  Wire.write(1 << ch);
  Wire.endTransmission();
  currentChannel = ch;
  drvReady = false; // force re-init before touching a newly selected channel
}

void printMenu() {
  Serial.println();
  Serial.println(F("---- Power Budget Test Harness ----"));
  Serial.print(F("Active mux channel: "));
  Serial.println(currentChannel);
  Serial.println(F("c<n>  select mux channel n (0-7), e.g. c0"));
  Serial.println(F("i     init DRV2605L on this channel (LRA mode) -> read IDLE-POWERED current"));
  Serial.println(F("s     set STANDBY on this channel               -> read STANDBY current"));
  Serial.println(F("w     wake from standby, back to idle            -> read IDLE-POWERED current"));
  Serial.println(F("p     play effect #1 (needs LRA attached)        -> read ACTIVE/peak current"));
  Serial.println(F("q     stop playback"));
  Serial.println(F("m     show this menu"));
  Serial.println(F("Read the meter BEFORE sending the next command, not after."));
}

void setup() {
  Serial.begin(115200);
  uint32_t t0 = millis();
  while (!Serial && millis() - t0 < 3000) { delay(10); } // don't hang forever if run untethered later

  Wire.begin(SDA_PIN, SCL_PIN);
  delay(200);

  printMenu();
}

void loop() {
  if (!Serial.available()) return;

  String cmd = Serial.readStringUntil('\n');
  cmd.trim();
  if (cmd.length() == 0) return;

  if (cmd[0] == 'c' && cmd.length() > 1) {
    int ch = cmd.substring(1).toInt();
    tcaSelect(ch);
    Serial.print(F("-> mux channel "));
    Serial.println(ch);
    Serial.println(F("   Send 'i' to initialize the DRV on this channel."));
  }

  else if (cmd == "i") {
    tcaSelect(currentChannel); // re-assert channel select before talking to it
    if (!drv.begin()) {
      Serial.println(F("!! DRV2605L not found on this channel. Check wiring / mux channel."));
      drvReady = false;
    } else {
      drv.selectLibrary(6);              // LRA closed-loop library
      drv.useLRA();
      drv.setMode(DRV2605_MODE_INTTRIG); // idle, ready to trigger
      drvReady = true;
      Serial.println(F("-> DRV initialized, LRA mode, idle (not standby)."));
      Serial.println(F("   READ METER NOW: this is your IDLE-POWERED current."));
    }
  }

  else if (cmd == "s") {
    if (!drvReady) { Serial.println(F("!! init with 'i' first.")); }
    else {
      // MODE register 0x01, bit 6 = STANDBY. Direct write so we know
      // exactly what's on the bus, rather than trusting an abstraction.
      drv.writeRegister8(DRV2605_REG_MODE, 0x40);
      Serial.println(F("-> STANDBY bit set."));
      Serial.println(F("   READ METER NOW: this is your STANDBY current."));
    }
  }

  else if (cmd == "w") {
    if (!drvReady) { Serial.println(F("!! init with 'i' first.")); }
    else {
      drv.setMode(DRV2605_MODE_INTTRIG); // clears standby bit, mode -> idle/trigger-ready
      Serial.println(F("-> Woken from standby, back to idle."));
      Serial.println(F("   READ METER NOW: confirm it matches your earlier IDLE reading."));
    }
  }

  else if (cmd == "p") {
    if (!drvReady) { Serial.println(F("!! init with 'i' first.")); }
    else {
      drv.setWaveform(0, 1); // effect slot 0: strong click (library 6, effect #1)
      drv.setWaveform(1, 0); // slot 1: end of sequence
      drv.go();
      Serial.println(F("-> Playing effect."));
      Serial.println(F("   READ METER NOW: this is your ACTIVE/peak current."));
    }
  }

  else if (cmd == "q") {
    if (drvReady) drv.stop();
    Serial.println(F("-> Stopped."));
  }

  else if (cmd == "m") {
    printMenu();
  }

  else {
    Serial.println(F("? unrecognized. Send 'm' for the menu."));
  }
}
