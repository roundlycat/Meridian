/*
 * wrist_pod_2afc_trial_mux_v1.ino
 * Meridian Wrist Array — two-alternative discrimination experiment
 * Multi-pod version: routes through TCA9548A I2C mux to test each
 * physical pod in turn.
 *
 * Hardware: XIAO ESP32-C3 -> TCA9548A (0x70) -> up to 8x DRV2605L (0x5A each)
 *           -> LRA in satellite pod
 * Wiring:   SDA = GPIO6, SCL = GPIO7 (shared bus into the mux)
 *           Each DRV branches off its own mux channel — verify VIN is
 *           genuinely powered per pod, not phantom-powered through
 *           the I2C pull-ups.
 *
 * Protocol: same 50-trial balanced-deck design as the single-channel
 *           version, run once per selected pod. Select a channel with
 *           the digit keys (0-7, whichever the boot scan finds present)
 *           before starting a run. Placement isn't fixed yet, so note
 *           the sharpie mark / pod position alongside the channel
 *           number in your own session notes — the sketch only knows
 *           the mux channel, not where it sits on your arm.
 *
 * Note on terminology: strictly this is a single-interval two-alternative
 * IDENTIFICATION task ("which pattern was that?"), not a classical 2AFC
 * (two intervals per trial, "which interval held the target?"). For a
 * first discriminability pass, identification is the right simplification.
 *
 * Patterns (LRA library 6):
 *   A = effect 1   (Strong Click, 100%)
 *   B = effect 10  (Double Click, 100%)
 *   -- corrected from the single-channel file, which mislabeled B as
 *      "750 ms Alert" (effect 15) in the header comment and "buzz" in
 *      the practice prompt, while the guess prompt already said
 *      "double click." If any past session notes described Pattern B
 *      as a sustained alert rather than a double click, the label was
 *      wrong, not the firmware — effect 10 is what actually played.
 *
 * Serial commands (115200 baud):
 *   0-7 — (before 'g' only) select which mux channel/pod to test
 *   a   — practice: play Pattern A on the selected channel
 *   b   — practice: play Pattern B on the selected channel
 *   g   — begin the 50-trial run on the selected channel (auto-reshuffles)
 *   1   — guess "Pattern A" for the trial just played
 *   2   — guess "Pattern B" for the trial just played
 *   r   — (before 'g' only) manually reshuffle the deck with a fresh seed
 *
 * Output: end-of-session CSV block (trial,channel,actual,guess,correct)
 * suitable for copy-paste into a spreadsheet or straight into a chat
 * for analysis, plus summary stats and a 2x2 confusion matrix.
 *
 * After a session completes, send another channel digit to move on to
 * the next pod without resetting the board — the deck reshuffles fresh
 * for each new session.
 */

#include <Wire.h>
#include <Adafruit_DRV2605.h>

// ---------- Configuration ----------
#define SDA_PIN        6
#define SCL_PIN        7
#define MUX_ADDR       0x70
#define DRV_ADDR       0x5A
#define NUM_MUX_CH     8
#define EFFECT_A       1     // Strong Click 100%
#define EFFECT_B       10    // Double Click 100%
#define N_TRIALS       50    // must be even for a balanced deck
#define PRE_STIM_MS    1500  // quiet gap before each stimulus
#define POST_STIM_MS   400   // settle time after stimulus before prompt
#define NO_CHANNEL     0xFF  // sentinel: no channel selected yet

Adafruit_DRV2605 drv;

// ---------- Mux state ----------
bool    channelPresent[NUM_MUX_CH];
uint8_t currentChannel = NO_CHANNEL;

// ---------- Trial state ----------
uint8_t deck[N_TRIALS];      // 1 = Pattern A, 2 = Pattern B
uint8_t guesses[N_TRIALS];   // recorded responses
int     trialIdx   = 0;
bool    running    = false;
bool    awaitGuess = false;
bool    finished   = false;

// ---------- Mux ----------
void tcaSelect(uint8_t channel) {
  Wire.beginTransmission(MUX_ADDR);
  Wire.write(1 << channel);
  Wire.endTransmission();
}

void scanChannels() {
  Serial.println(F("Scanning mux channels 0-7 for DRV2605L..."));
  for (uint8_t ch = 0; ch < NUM_MUX_CH; ch++) {
    tcaSelect(ch);
    delay(5);
    Wire.beginTransmission(DRV_ADDR);
    uint8_t err = Wire.endTransmission();
    channelPresent[ch] = (err == 0);
    Serial.print(F("  channel "));
    Serial.print(ch);
    Serial.println(channelPresent[ch] ? F(": DRV2605L found") : F(": --"));
  }
}

bool initChannel(uint8_t ch) {
  tcaSelect(ch);
  if (!drv.begin(&Wire)) {
    Serial.print(F("  WARNING: begin() failed on channel "));
    Serial.println(ch);
    return false;
  }
  drv.selectLibrary(6);          // LRA library
  drv.useLRA();
  drv.setMode(DRV2605_MODE_INTTRIG);
  return true;
}

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
  tcaSelect(currentChannel);
  drv.setWaveform(0, effect);
  drv.setWaveform(1, 0);     // end of sequence
  drv.go();
}

void playPattern(uint8_t which) {
  playEffect(which == 1 ? EFFECT_A : EFFECT_B);
}

// ---------- Channel selection ----------
void selectChannel(uint8_t ch) {
  if (ch >= NUM_MUX_CH || !channelPresent[ch]) {
    Serial.print(F("No DRV2605L detected on channel "));
    Serial.println(ch);
    return;
  }
  currentChannel = ch;
  Serial.print(F("Channel "));
  Serial.print(ch);
  Serial.println(F(" selected. Mark this pod's position now if it isn't fixed."));
}

// ---------- Trial flow ----------
void runTrial() {
  Serial.print(F("\n--- Trial "));
  Serial.print(trialIdx + 1);
  Serial.print(F(" of "));
  Serial.print(N_TRIALS);
  Serial.print(F(" (channel "));
  Serial.print(currentChannel);
  Serial.println(F(") ---"));
  Serial.println(F("Get ready..."));
  delay(PRE_STIM_MS);

  playPattern(deck[trialIdx]);

  delay(POST_STIM_MS);
  Serial.println(F("Your guess?  1 = Pattern A (click)   2 = Pattern B (double click)"));
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
  Serial.print(F("Channel (pod): "));
  Serial.println(currentChannel);
  Serial.println(F("\ntrial,channel,actual,guess,correct"));
  for (int i = 0; i < N_TRIALS; i++) {
    bool ok = (deck[i] == guesses[i]);
    if (ok) correct++;
    if (deck[i] == 1) { if (ok) aAsA++; else aAsB++; }
    else              { if (ok) bAsB++; else bAsA++; }

    Serial.print(i + 1);          Serial.print(',');
    Serial.print(currentChannel); Serial.print(',');
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
  Serial.println(F("Send another channel digit to test the next pod, or reset the board."));
  Serial.println(F("======================================"));
}

// ---------- Setup / loop ----------
void setup() {
  Serial.begin(115200);
  delay(2000);  // XIAO USB-CDC settle time

  Wire.begin(SDA_PIN, SCL_PIN);

  scanChannels();

  bool anyFound = false;
  for (uint8_t ch = 0; ch < NUM_MUX_CH; ch++) {
    if (channelPresent[ch]) {
      anyFound = true;
      if (!initChannel(ch)) channelPresent[ch] = false;
    }
  }

  if (!anyFound) {
    Serial.println(F("ERROR: no DRV2605L found on any mux channel."));
    Serial.println(F("Check mux wiring/address (0x70) and per-pod VIN power."));
    while (1) delay(100);
  }

  buildDeck();

  Serial.println(F("\n=== Meridian 2-Alternative Discrimination Trial — multi-pod ==="));
  Serial.println(F("Pattern A = effect 1  (Strong Click, 100%)"));
  Serial.println(F("Pattern B = effect 10 (Double Click, 100%)"));
  Serial.println(F("\nSelect a pod first: send its channel digit (see scan above)."));
  Serial.println(F("Practice:  a = play A    b = play B"));
  Serial.println(F("Reshuffle: r"));
  Serial.println(F("Begin run: g   (practice locks out once started)"));
}

void loop() {
  if (!Serial.available()) return;
  char c = Serial.read();

  // ignore whitespace/newlines from the monitor
  if (c == '\n' || c == '\r' || c == ' ') return;

  if (finished) {
    if (c >= '0' && c <= '7') {
      selectChannel(c - '0');
      finished = false;   // allow another session without a full reset
      Serial.println(F("Ready for another session. a/b to practice, g to begin."));
    } else {
      Serial.println(F("Session complete. Send a channel digit to test another pod, or reset the board."));
    }
    return;
  }

  if (!running) {
    if (c >= '0' && c <= '7') {
      selectChannel(c - '0');
      return;
    }
    switch (c) {
      case 'a':
        if (currentChannel == NO_CHANNEL) { Serial.println(F("Select a channel first.")); break; }
        Serial.println(F("[practice] Pattern A (click)"));
        playPattern(1);
        break;
      case 'b':
        if (currentChannel == NO_CHANNEL) { Serial.println(F("Select a channel first.")); break; }
        Serial.println(F("[practice] Pattern B (double click)"));
        playPattern(2);
        break;
      case 'r':
        buildDeck();
        Serial.println(F("Deck reshuffled."));
        break;
      case 'g':
        if (currentChannel == NO_CHANNEL) {
          Serial.println(F("Select a channel first (send its digit)."));
          break;
        }
        buildDeck();      // fresh shuffle for every session/pod
        running = true;
        trialIdx = 0;
        Serial.print(F("\nStarting 50 trials on channel "));
        Serial.print(currentChannel);
        Serial.println(F(". Look away from the monitor,"));
        Serial.println(F("attend to the pod, type 1 or 2 after each stimulus."));
        runTrial();
        break;
      default:
        Serial.println(F("Commands before start: 0-7 (select pod), a, b, r, g"));
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
