// Wrist-Puck — Servo + DRV2605L (I2C/LRA) Bring-up Test
// XIAO ESP32-C3
//
// Libraries needed (Library Manager):
//   "Adafruit DRV2605 Library"
//   "ESP32Servo" (by Kevin Harrington / madhephaestus)
//
// ADJUST BEFORE UPLOADING:
#define I2C_SDA   6     // established from earlier I2C testing
#define I2C_SCL   7     // established from earlier I2C testing
#define SERVO_PIN 3     // <-- CONFIRM: the GPIO you actually soldered the servo signal wire to

#include <Wire.h>
#include <Adafruit_DRV2605.h>
#include <ESP32Servo.h>

Adafruit_DRV2605 drv;
Servo servo;
bool drvReady = false;

void scanI2C() {
  Serial.println("Scanning I2C bus...");
  byte found = 0;
  for (byte addr = 1; addr < 127; addr++) {
    Wire.beginTransmission(addr);
    if (Wire.endTransmission() == 0) {
      Serial.print("  Found device at 0x");
      Serial.println(addr, HEX);
      found++;
    }
  }
  if (found == 0) {
    Serial.println("  Nothing found — check SDA/SCL solder joints before going further.");
  } else {
    Serial.println("  Scan done.");
  }
}

void setup() {
  Serial.begin(115200);
  delay(1500);  // gives the serial monitor time to connect before the first prints
  Serial.println("\n=== Wrist-Puck bring-up test ===");

  // ---- I2C / DRV2605L ----
  Wire.begin(I2C_SDA, I2C_SCL);
  scanI2C();

  if (!drv.begin()) {
    Serial.println("DRV2605L not found at its expected address (0x5A).");
    Serial.println("Check wiring before continuing — servo test will still run below.");
  } else {
    Serial.println("DRV2605L found and initialized.");
    drv.useLRA();           // LRA coin motor mode — required for this hardware
    drv.selectLibrary(6);   // library 6 = LRA effects
    drv.setMode(DRV2605_MODE_INTTRIG);
    drvReady = true;
  }

  // ---- Servo ----
  servo.setPeriodHertz(50);
  servo.attach(SERVO_PIN, 500, 2400);  // adjust pulse range if the SG51R needs different min/max
  Serial.println("Servo attached.");

  Serial.println("Starting sweep + LRA pulse loop in 2s...");
  Serial.println("(Power from battery, not just USB, if testing servo + LRA together —");
  Serial.println(" simultaneous current draw is the real-world case you actually care about.)");
  delay(2000);
}

void loop() {
  Serial.println("Servo: sweeping 0 -> 180 -> 0");
  for (int pos = 0; pos <= 180; pos += 5) {
    servo.write(pos);
    delay(20);
  }
  for (int pos = 180; pos >= 0; pos -= 5) {
    servo.write(pos);
    delay(20);
  }

  if (drvReady) {
    Serial.println("DRV2605L: firing effect #1");
    drv.setWaveform(0, 1);   // effect slot 0 = effect #1 (strong click)
    drv.setWaveform(1, 0);   // terminate sequence
    drv.go();
  }

  delay(2000);  // pause so you can watch/feel each cycle separately, not as one blur
}
