-- =============================================================================
-- Device Registry — Sensor Ecology
-- Run on Inferno: psql -U sean -d sensor_ecology -f device_registry.sql
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Tables
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS device_registry (
  id              TEXT PRIMARY KEY,
  display_name    TEXT NOT NULL,
  device_type     TEXT NOT NULL,
  location        TEXT,

  -- Vision recognition — Gemini matches detected labels against these
  cv_labels       TEXT[],

  -- MQTT topics for this device (null if device has no MQTT presence)
  mqtt_topics     JSONB,

  -- Anomaly thresholds — used by ws_bridge anomaly enrichment
  thresholds      JSONB,

  -- Pinout JSON — used by wiring assistant
  pinout          JSONB,

  notes           TEXT,
  created_at      TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS device_observations (
  id          SERIAL PRIMARY KEY,
  device_id   TEXT REFERENCES device_registry(id),
  observed_at TIMESTAMPTZ DEFAULT now(),
  level       TEXT CHECK (level IN ('info', 'warn', 'critical')),
  message     TEXT NOT NULL,
  source      TEXT CHECK (source IN ('threshold', 'semantic', 'manual', 'gemini', 'llama'))
);

-- Index for fast device lookup by CV label (GIN index on array)
CREATE INDEX IF NOT EXISTS idx_device_registry_cv_labels
  ON device_registry USING GIN (cv_labels);

-- Index for recent observations per device
CREATE INDEX IF NOT EXISTS idx_device_observations_device_time
  ON device_observations (device_id, observed_at DESC);


-- -----------------------------------------------------------------------------
-- Seed Data — derived from today's AR scans
-- -----------------------------------------------------------------------------

-- Raspberry Pi 5 (Inferno / sensor hub)
INSERT INTO device_registry (id, display_name, device_type, location, cv_labels, mqtt_topics, thresholds, pinout, notes)
VALUES (
  'raspberry-pi-node-1',
  'Sensor Hub Pi',
  'raspberry-pi-5',
  'workbench',
  ARRAY['Raspberry Pi', 'Main Board', 'Main Board (Raspberry Pi)', 'Raspberry Pi 5', 'SBC', 'Single Board Computer'],
  '{
    "telemetry": "sensors/pi-node-1/telemetry",
    "status":    "sensors/pi-node-1/status",
    "command":   "sensors/pi-node-1/cmd"
  }',
  '{
    "agent_temp_c": { "warn": 60, "critical": 75 },
    "cpu_load_pct": { "warn": 80, "critical": 95 }
  }',
  '{
    "GPIO_2":  "SDA (I2C1)",
    "GPIO_3":  "SCL (I2C1)",
    "GPIO_4":  "GPCLK0",
    "GPIO_14": "TXD (UART)",
    "GPIO_15": "RXD (UART)",
    "5V":      "Power input",
    "GND":     "Ground",
    "3V3":     "3.3V output"
  }',
  'Primary sensor hub. Runs Mosquitto, FastAPI dashboard, sensor ingestion pipeline.'
)
ON CONFLICT (id) DO UPDATE SET
  cv_labels = EXCLUDED.cv_labels,
  thresholds = EXCLUDED.thresholds;


-- ESP32-S3 Node
INSERT INTO device_registry (id, display_name, device_type, location, cv_labels, mqtt_topics, thresholds, pinout, notes)
VALUES (
  'esp32-node-1',
  'ESP32 Workbench Node',
  'esp32-s3',
  'workbench',
  ARRAY['ESP32', 'ESP32-S3', 'ESP32 DevKit', 'ESP32 Development Board', 'ESP32-S3-WROOM', 'ESP32 CAM', 'ESP32-CAM'],
  '{
    "telemetry": "sensors/esp32-node-1/telemetry",
    "semantic":  "sensors/esp32-node-1/semantic",
    "status":    "sensors/esp32-node-1/status",
    "command":   "sensors/esp32-node-1/cmd"
  }',
  '{
    "temperature": { "warn": 35, "critical": 45 },
    "humidity":    { "warn": 80, "critical": 90 },
    "airflow":     { "warn_low": 0.1 }
  }',
  '{
    "GPIO_21": "SDA (I2C)",
    "GPIO_22": "SCL (I2C)",
    "GPIO_1":  "TXD (UART)",
    "GPIO_3":  "RXD (UART)",
    "3V3":     "3.3V output (max 600mA)",
    "5V":      "VIN power input",
    "GND":     "Ground"
  }',
  'Primary sensor acquisition node. Publishes semantic interpretations via MQTT.'
)
ON CONFLICT (id) DO UPDATE SET
  cv_labels = EXCLUDED.cv_labels,
  thresholds = EXCLUDED.thresholds;


-- BME280 Environmental Sensor
INSERT INTO device_registry (id, display_name, device_type, location, cv_labels, mqtt_topics, thresholds, pinout, notes)
VALUES (
  'bme280-breakout-1',
  'BME280 Environmental Sensor',
  'bme280',
  'workbench',
  ARRAY['BME280', 'BME280 Environmental Sensor Module', 'BME280 Breakout', 'Environmental Sensor'],
  NULL,
  '{
    "temperature": { "warn": 35, "critical": 45 },
    "humidity":    { "warn": 80, "critical": 90 },
    "pressure":    { "warn_low": 950, "warn_high": 1050 }
  }',
  '{
    "VCC": "3.3V (do NOT connect to 5V)",
    "GND": "Ground",
    "SDA": "I2C data — connect to ESP32 GPIO_21",
    "SCL": "I2C clock — connect to ESP32 GPIO_22",
    "SDO": "I2C address select (GND = 0x76, VCC = 0x77)",
    "CSB": "Tie to VCC for I2C mode"
  }',
  'Temperature, humidity, pressure sensor. I2C interface. Default address 0x76.'
)
ON CONFLICT (id) DO UPDATE SET
  cv_labels = EXCLUDED.cv_labels,
  thresholds = EXCLUDED.thresholds;


-- Camera Module (Pi Camera / ESP-CAM)
INSERT INTO device_registry (id, display_name, device_type, location, cv_labels, mqtt_topics, thresholds, pinout, notes)
VALUES (
  'cam-module-1',
  'Camera Module',
  'pi-camera',
  'workbench',
  ARRAY['Camera Module', 'Camera Module (Raspberry Pi)', 'Pi Camera', 'ESP32-CAM', 'Camera'],
  '{
    "frames":   "vision/cam-module-1/frame",
    "detected": "bench/detected_components"
  }',
  NULL,
  '{
    "FFC":  "Ribbon cable to CSI port",
    "VCC":  "3.3V",
    "GND":  "Ground"
  }',
  'Primary vision node. Posts component detection results to bench/detected_components.'
)
ON CONFLICT (id) DO UPDATE SET cv_labels = EXCLUDED.cv_labels;


-- MLX90640 Thermal Camera
INSERT INTO device_registry (id, display_name, device_type, location, cv_labels, mqtt_topics, thresholds, pinout, notes)
VALUES (
  'mlx90640-thermal-1',
  'MLX90640 Thermal Camera',
  'mlx90640',
  'workbench',
  ARRAY['MLX90640', 'Thermal Camera', 'Thermal Sensor', 'IR Camera'],
  '{
    "frames": "thermal/pi5-thermal/frame"
  }',
  '{
    "max_temp_c": { "warn": 40, "critical": 60 },
    "presence_score": { "warn_low": 0.0 }
  }',
  '{
    "VCC": "3.3V",
    "GND": "Ground",
    "SDA": "I2C data",
    "SCL": "I2C clock",
    "address": "0x33 (default)"
  }',
  'Wide-angle thermal imaging. 32x24 pixel array. Publishes frames via MQTT.'
)
ON CONFLICT (id) DO UPDATE SET cv_labels = EXCLUDED.cv_labels;


-- Breadboard
INSERT INTO device_registry (id, display_name, device_type, location, cv_labels, mqtt_topics, thresholds, pinout, notes)
VALUES (
  'breadboard-1',
  'Half-size Breadboard',
  'breadboard',
  'workbench',
  ARRAY['Breadboard', 'Prototyping Board', 'Half-size Breadboard'],
  NULL, NULL, NULL,
  'Half-size solderless breadboard. Blue cutting mat surface.'
)
ON CONFLICT (id) DO UPDATE SET cv_labels = EXCLUDED.cv_labels;


-- Multi-channel Sensor Hub / Breakout Board
INSERT INTO device_registry (id, display_name, device_type, location, cv_labels, mqtt_topics, thresholds, pinout, notes)
VALUES (
  'sensor-hub-1',
  'Multi-channel Sensor Hub',
  'breakout-board',
  'workbench',
  ARRAY['Multi-channel Sensor/Breakout Board', 'Sensor Hub', 'Breakout Board', 'Jumper Wire Breakout Board'],
  NULL, NULL, NULL,
  'Blue PCB with WiFi symbol. Central connection point for jumper wires.'
)
ON CONFLICT (id) DO UPDATE SET cv_labels = EXCLUDED.cv_labels;


-- LCD/OLED Display
INSERT INTO device_registry (id, display_name, device_type, location, cv_labels, mqtt_topics, thresholds, pinout, notes)
VALUES (
  'display-1',
  'LCD/OLED Display Panel',
  'display',
  'workbench',
  ARRAY['LCD/OLED Display Panel', 'Display', 'OLED Display', 'LCD Display', 'Screen'],
  NULL, NULL,
  '{
    "VCC": "3.3V or 5V (check module)",
    "GND": "Ground",
    "SDA": "I2C data",
    "SCL": "I2C clock"
  }',
  'Small display panel. Partially obscured. Likely I2C OLED.'
)
ON CONFLICT (id) DO UPDATE SET cv_labels = EXCLUDED.cv_labels;


-- =============================================================================
-- Verify
-- =============================================================================
SELECT id, display_name, device_type, array_length(cv_labels, 1) AS label_count
FROM device_registry
ORDER BY device_type;
