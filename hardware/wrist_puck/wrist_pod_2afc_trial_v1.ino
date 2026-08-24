/*
 * wrist_pod_2afc_trial_v1.ino
 * Meridian Wrist Array — two-alternative discrimination experiment
 *
 * Hardware: XIAO ESP32-C3 -> DRV2605L (direct, NO mux) -> LRA in satellite pod
 * Wiring:   SDA = GPIO6, SCL = GPIO7, DRV at 0x5A, VIN genuinely powered
 *           (do not rely on I2C pull-up phantom power — verify VIN with meter
 *           if the DRV responds but the LRA feels weak)
 *
 * Protocol: 50 trials, balanced deck (25x Pattern A, 25x Pattern B),
 *           Fisher-Yates shuffled. Each trial: countdown buzz-free pause,
 *           stimulus plays once, you type your guess. No repeats, no
 *           per-trial feedback — results are buffered and revealed only
 *           in the end-of-session summary, so you stay blind throughout.
 *
 * Note on terminology: strictly this is a single-interval two-alternative
 * IDENTIFICATION task ("which pattern was that?"), not a classical 2AFC
 * (two intervals per trial, "which interval held the target?"). For a
 * first discriminability pass, identification is the right simplification.
 *
 * Patterns (LRA library 6):
 *   A = effect 1   (Strong Click, 100%)
 *   B = effect 15  (750 ms Alert)
 *
 * Serial commands (115200 baud):
 *   a  — practice: play Pattern A (labeled)
 *   b  — practice: play Pattern B (labeled)
 *   g  — begin the 50-trial run (practice disabled once started)
 *   1  — guess "Pattern A" for the trial just played
 *   2  — guess "Pattern B" for the trial just played
 *   r  — (before 'g' only) reshuffle the deck with a fresh seed
 *
 * Output: end-of-session CSV block (trial,actual,guess,correct) suitable
 * for copy-paste into a spreadsheet or straight into a chat for analysis,
 * plus summary stats and a 2x2 confusion matrix.
 */

#include <Wire.h>
#include <Adafruit_DRV2605.h>

// ---------- Configuration ----------
#define SDA_PIN        6
#define SCL_PIN        7
#define EFFECT_A       1     // Strong Click 100%
#define EFFECT_B       15    // 750 ms Alert
#define N_TRIALS       50    // must be even for a balanced deck
#define PRE_STIM_MS    1500  // quiet gap before each stimulus
#define POST_STIM_MS   400   // settle time after stimulus before prompt

Adafruit_DRV2605 drv;

// ---------- Trial state ----------
uint8_t deck[N_TRIALS];      // 1 = Pattern A, 2 = Pattern B
uint8_t guesses[N_TRIALS];   // recorded responses
int     trialIdx   = 0;
bool    running    = false;
bool    awaitGuess = false;
bool    finished   = false;

// ---------- Deck construction ----------
void buildDeck() {
  // Balanced: exactly N/2 of each pattern
  for (int i = 0; i < N_TRIALS; i++) {
    deck[i] = (i < N_TRIALS / 2) ? 1 : 2;
  }
  // Fisher-Yates shuffle using hardware RNG
  for (int i = N_TRIALS - 1; i > 0; i--) {
    int j = esp_random() % (i + 1);
    uint8_t tmp = deck[i];
    deck[i] = deck[j];
    deck[j] = tmp;
  }
}

// ---------- Stimulus ----------
void playEffect(uint8_t effect) {
  drv.setWaveform(0, effect);
  drv.setWaveform(1, 0);     // end of sequence
  drv.go();
}

void playPattern(uint8_t which) {
  playEffect(which == 1 ? EFFECT_A : EFFECT_B);
}

// ---------- Trial flow ----------
void runTrial() {
  Serial.print(F("\n--- Trial "));
  Serial.print(trialIdx + 1);
  Serial.print(F(" of "));
  Serial.print(N_TRIALS);
  Serial.println(F(" ---"));
  Serial.println(F("Get ready..."));
  delay(PRE_STIM_MS);

  playPattern(deck[trialIdx]);

  delay(POST_STIM_MS);
  Serial.println(F("Your guess?  1 = Pattern A (click)   2 = Pattern B (buzz)"));
  awaitGuess = true;
}

void recordGuess(uint8_t g) {
  guesses[trialIdx] = g;
  awaitGuess = false;
  trialIdx++;

  if (trialIdx >= N_TRIALS) {
    finishSession();
  } else {
    // brief pause so trials don't blur together
    delay(600);
    runTrial();
  }
}

// ---------- Results ----------
void finishSession() {
  running  = false;
  finished = true;

  int correct = 0;
  int aAsA = 0, aAsB = 0, bAsB = 0, bAsA = 0;

  Serial.println(F("\n\n========== SESSION COMPLETE =========="));
  Serial.println(F("\ntrial,actual,guess,correct"));
  for (int i = 0; i < N_TRIALS; i++) {
    bool ok = (deck[i] == guesses[i]);
    if (ok) correct++;
    if (deck[i] == 1) { if (ok) aAsA++; else aAsB++; }
    else              { if (ok) bAsB++; else bAsA++; }

    Serial.print(i + 1);         Serial.print(',');
    Serial.print(deck[i] == 1 ? 'A' : 'B'); Serial.print(',');
    Serial.print(guesses[i] == 1 ? 'A' : 'B'); Serial.print(',');
    Serial.println(ok ? 1 : 0);
  }

  float pct = 100.0f * correct / N_TRIALS;
  Serial.println(F("\n---- Summary ----"));
  Serial.print(F("Correct: "));
  Serial.print(correct);
  Serial.print(F("/"));
  Serial.print(N_TRIALS);
  Serial.print(F("  ("));
  Serial.print(pct, 1);
  Serial.println(F("%)"));

  Serial.println(F("\nConfusion matrix (rows = actual, cols = guessed):"));
  Serial.println(F("        guess A   guess B"));
  Serial.print(F("  A     "));  Serial.print(aAsA); Serial.print(F("         ")); Serial.println(aAsB);
  Serial.print(F("  B     "));  Serial.print(bAsA); Serial.print(F("         ")); Serial.println(bAsB);

  Serial.println(F("\nChance = 50%. For 50 trials, ~32+ correct (64%) clears"));
  Serial.println(F("p < .05 by binomial test; near-100% expected for this easy pair."));
  Serial.println(F("Copy the CSV block above into your notes before power-off."));
  Serial.println(F("======================================"));
}

// ---------- Setup / loop ----------
void setup() {
  Serial.begin(115200);
  delay(2000);  // XIAO USB-CDC settle time

  Wire.begin(SDA_PIN, SCL_PIN);

  if (!drv.begin(&Wire)) {
    Serial.println(F("ERROR: DRV2605L not found at 0x5A."));
    Serial.println(F("Check wiring — and check VIN is truly powered,"));
    Serial.println(F("not phantom-powered through the I2C pull-ups."));
    while (1) delay(100);
  }

  drv.selectLibrary(6);            // LRA library
  drv.useLRA();
  drv.setMode(DRV2605_MODE_INTTRIG);

  buildDeck();

  Serial.println(F("\n=== Meridian 2-Alternative Discrimination Trial v1 ==="));
  Serial.println(F("Pattern A = effect 1  (Strong Click 100%)"));
  Serial.println(F("Pattern B = effect 15 (750 ms Alert)"));
  Serial.println(F("\nPractice:  a = play A    b = play B"));
  Serial.println(F("Reshuffle: r"));
  Serial.println(F("Begin run: g   (practice locks out once started)"));
}

void loop() {
  if (!Serial.available()) return;
  char c = Serial.read();

  // ignore whitespace/newlines from the monitor
  if (c == '\n' || c == '\r' || c == ' ') return;

  if (finished) {
    Serial.println(F("Session complete. Reset the board to run again."));
    return;
  }

  if (!running) {
    switch (c) {
      case 'a':
        Serial.println(F("[practice] Pattern A (click)"));
        playPattern(1);
        break;
      case 'b':
        Serial.println(F("[practice] Pattern B (buzz)"));
        playPattern(2);
        break;
      case 'r':
        buildDeck();
        Serial.println(F("Deck reshuffled."));
        break;
      case 'g':
        running = true;
        trialIdx = 0;
        Serial.println(F("\nStarting 50 trials. Look away from the monitor,"));
        Serial.println(F("attend to the pod, type 1 or 2 after each stimulus."));
        runTrial();
        break;
      default:
        Serial.println(F("Commands before start: a, b, r, g"));
    }
    return;
  }

  // running: only guesses are valid
  if (awaitGuess && (c == '1' || c == '2')) {
    recordGuess(c - '0');
  } else if (awaitGuess) {
    Serial.println(F("Type 1 (Pattern A) or 2 (Pattern B)."));
  }
  // input during stimulus playback is ignored
}
