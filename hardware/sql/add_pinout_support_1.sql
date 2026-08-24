-- ============================================================
-- Parts Catalogue — SVG Pinout & Pin Map Migration
-- sensor_ecology database · Inferno (192.168.0.28)
--
-- Run:
--   psql -U sean -d sensor_ecology -f add_pinout_support.sql
--
-- What this adds:
--   · svg_pinout  TEXT   — inline SVG for display in AR card
--   · pin_map     JSONB  — structured pin data for wire-drawing logic
--   · part_type   TEXT   — 'mcu' | 'sensor' | 'module' | 'shield'
--
-- pin_map shape (used by the AR wiring guide client):
--   {
--     "interface": "i2c" | "spi" | "uart" | "gpio" | "power",
--     "voltage":   "3.3v" | "5v" | "both",
--     "pins": [
--       {
--         "id":    "VCC",          -- internal reference id
--         "label": "VCC / 3.3V",  -- display label
--         "side":  "left" | "right",
--         "index": 0,              -- vertical position on card (0 = top)
--         "role":  "power" | "ground" | "i2c_clock" | "i2c_data" |
--                  "spi_mosi" | "spi_miso" | "spi_sck" | "spi_cs" |
--                  "uart_tx" | "uart_rx" | "addr" | "gpio"
--       }
--     ]
--   }
--
-- The AR client matches "role" fields between two pin_maps to
-- generate wiring steps automatically — no hardcoding per pair.
-- ============================================================

BEGIN;

-- ── Schema additions ─────────────────────────────────────────

ALTER TABLE parts_catalogue
    ADD COLUMN IF NOT EXISTS svg_pinout  TEXT,
    ADD COLUMN IF NOT EXISTS pin_map     JSONB,
    ADD COLUMN IF NOT EXISTS part_type   TEXT
        CHECK (part_type IN ('mcu', 'sensor', 'module', 'shield', 'passive', 'other'));

-- Index for role-based pairing queries
CREATE INDEX IF NOT EXISTS idx_parts_part_type
    ON parts_catalogue (part_type);

CREATE INDEX IF NOT EXISTS idx_parts_pin_map_interface
    ON parts_catalogue USING gin ((pin_map -> 'interface'));

-- ── Seed: BME280 ─────────────────────────────────────────────

INSERT INTO parts_catalogue (
    image_path,
    image_filename,
    ocr_raw,
    ocr_results,
    component_model,
    summary,
    part_type,
    pin_map,
    embedding
) VALUES (
    '/home/sean/parts-archive/bme280_reference.png',
    'bme280_reference.png',
    'BME280 reference entry',
    'VCC GND SDI SDO CSB SCK',
    'BME280 — Temperature / Humidity / Pressure sensor (Bosch)',
    'Combined digital humidity, pressure, and temperature sensor by Bosch. '
    'I2C or SPI interface. Operating voltage 1.7–3.6V. '
    'I2C address 0x76 (SDO low) or 0x77 (SDO high). '
    'Typical accuracy: ±1°C temp, ±3% RH humidity, ±1 hPa pressure.',
    'sensor',
    '{
        "interface": "i2c",
        "voltage": "3.3v",
        "i2c_addresses": ["0x76", "0x77"],
        "addr_pin": "SDO",
        "pins": [
            {
                "id":    "VCC",
                "label": "VCC / 3.3V",
                "side":  "left",
                "index": 0,
                "role":  "power"
            },
            {
                "id":    "GND",
                "label": "GND",
                "side":  "left",
                "index": 1,
                "role":  "ground"
            },
            {
                "id":    "SDI",
                "label": "SDI / SDA",
                "side":  "right",
                "index": 0,
                "role":  "i2c_data"
            },
            {
                "id":    "SCK",
                "label": "SCK / SCL",
                "side":  "right",
                "index": 1,
                "role":  "i2c_clock"
            },
            {
                "id":    "CSB",
                "label": "CSB",
                "side":  "right",
                "index": 2,
                "role":  "spi_cs"
            },
            {
                "id":    "SDO",
                "label": "SDO / ADDR",
                "side":  "right",
                "index": 3,
                "role":  "addr"
            }
        ],
        "notes": [
            "Pull SDO to GND for address 0x76 (default)",
            "Pull SDO to 3.3V for address 0x77",
            "CSB must be tied to 3.3V when using I2C mode",
            "Do not apply 5V — max 3.6V absolute"
        ]
    }'::jsonb,
    NULL   -- placeholder; run re-embed after insert (see below)
)
ON CONFLICT (image_filename) DO UPDATE SET
    component_model = EXCLUDED.component_model,
    summary         = EXCLUDED.summary,
    part_type       = EXCLUDED.part_type,
    pin_map         = EXCLUDED.pin_map;

-- ── Seed: D1 Mini (ESP8266) ──────────────────────────────────

INSERT INTO parts_catalogue (
    image_path,
    image_filename,
    ocr_raw,
    ocr_results,
    component_model,
    summary,
    part_type,
    pin_map,
    embedding
) VALUES (
    '/home/sean/parts-archive/d1mini_reference.png',
    'd1mini_reference.png',
    'D1 Mini reference entry',
    'RST TX RX D8 D7 D6 D5 GND 3V3 A0 D0 D1 D2 D3 D4 5V',
    'Wemos D1 Mini — ESP8266 development board',
    'ESP8266-based WiFi development board. 11 digital I/O pins, 1 analog pin. '
    'I2C on D1 (GPIO5, SCL) / D2 (GPIO4, SDA) by default. '
    '3.3V logic; 5V tolerant power input via USB or 5V pin. '
    'Flash via USB-C. Built-in WiFi 802.11 b/g/n.',
    'mcu',
    '{
        "interface": "i2c",
        "voltage": "3.3v",
        "chip": "ESP8266",
        "pins": [
            {
                "id":    "3V3",
                "label": "3.3V out",
                "side":  "left",
                "index": 0,
                "role":  "power"
            },
            {
                "id":    "GND",
                "label": "GND",
                "side":  "left",
                "index": 1,
                "role":  "ground"
            },
            {
                "id":    "D1",
                "label": "D1 / GPIO5 / SCL",
                "side":  "right",
                "index": 0,
                "role":  "i2c_clock"
            },
            {
                "id":    "D2",
                "label": "D2 / GPIO4 / SDA",
                "side":  "right",
                "index": 1,
                "role":  "i2c_data"
            },
            {
                "id":    "D5",
                "label": "D5 / GPIO14 / SCK",
                "side":  "right",
                "index": 2,
                "role":  "spi_sck"
            },
            {
                "id":    "D6",
                "label": "D6 / GPIO12 / MISO",
                "side":  "right",
                "index": 3,
                "role":  "spi_miso"
            },
            {
                "id":    "D7",
                "label": "D7 / GPIO13 / MOSI",
                "side":  "right",
                "index": 4,
                "role":  "spi_mosi"
            },
            {
                "id":    "D8",
                "label": "D8 / GPIO15 / CS",
                "side":  "right",
                "index": 5,
                "role":  "spi_cs"
            },
            {
                "id":    "5V",
                "label": "5V in",
                "side":  "left",
                "index": 2,
                "role":  "power"
            }
        ],
        "notes": [
            "I2C default: Wire.begin() uses D2=SDA, D1=SCL",
            "3.3V output current limited — avoid powering multiple sensors directly",
            "D8 (GPIO15) must be LOW at boot; avoid pull-up on this pin",
            "A0 is the only ADC pin; max 1.0V input (not 3.3V)"
        ]
    }'::jsonb,
    NULL
)
ON CONFLICT (image_filename) DO UPDATE SET
    component_model = EXCLUDED.component_model,
    summary         = EXCLUDED.summary,
    part_type       = EXCLUDED.part_type,
    pin_map         = EXCLUDED.pin_map;

-- ── Seed: SHT31 ──────────────────────────────────────────────
-- (already deployed on env-node-05; added here for completeness)

INSERT INTO parts_catalogue (
    image_path,
    image_filename,
    ocr_raw,
    ocr_results,
    component_model,
    summary,
    part_type,
    pin_map,
    embedding
) VALUES (
    '/home/sean/parts-archive/sht31_reference.png',
    'sht31_reference.png',
    'SHT31 reference entry',
    'VCC GND SDA SCL ADDR ALERT',
    'SHT31 — Temperature / Humidity sensor (Sensirion)',
    'High-accuracy digital temperature and humidity sensor. '
    'I2C interface. Operating voltage 2.4–5.5V. '
    'I2C address 0x44 (ADDR low) or 0x45 (ADDR high). '
    'Typical accuracy: ±0.2°C temp, ±2% RH. '
    'Paired with BME688 on env-node-05 for thermal cross-reference.',
    'sensor',
    '{
        "interface": "i2c",
        "voltage": "both",
        "i2c_addresses": ["0x44", "0x45"],
        "addr_pin": "ADDR",
        "pins": [
            {
                "id":    "VCC",
                "label": "VCC",
                "side":  "left",
                "index": 0,
                "role":  "power"
            },
            {
                "id":    "GND",
                "label": "GND",
                "side":  "left",
                "index": 1,
                "role":  "ground"
            },
            {
                "id":    "SDA",
                "label": "SDA",
                "side":  "right",
                "index": 0,
                "role":  "i2c_data"
            },
            {
                "id":    "SCL",
                "label": "SCL",
                "side":  "right",
                "index": 1,
                "role":  "i2c_clock"
            },
            {
                "id":    "ADDR",
                "label": "ADDR",
                "side":  "right",
                "index": 2,
                "role":  "addr"
            },
            {
                "id":    "ALERT",
                "label": "ALERT",
                "side":  "right",
                "index": 3,
                "role":  "gpio"
            }
        ],
        "notes": [
            "Pull ADDR to GND for address 0x44 (default)",
            "Pull ADDR to VCC for address 0x45",
            "Accepts 3.3V or 5V — level-shift not required with D1 Mini",
            "ALERT pin is open-drain; pull up to VCC if using threshold alerts"
        ]
    }'::jsonb,
    NULL
)
ON CONFLICT (image_filename) DO UPDATE SET
    component_model = EXCLUDED.component_model,
    summary         = EXCLUDED.summary,
    part_type       = EXCLUDED.part_type,
    pin_map         = EXCLUDED.pin_map;

-- ── Seed: BME688 ─────────────────────────────────────────────
-- (env-node-05 primary sensor)

INSERT INTO parts_catalogue (
    image_path,
    image_filename,
    ocr_raw,
    ocr_results,
    component_model,
    summary,
    part_type,
    pin_map,
    embedding
) VALUES (
    '/home/sean/parts-archive/bme688_reference.png',
    'bme688_reference.png',
    'BME688 reference entry',
    'VCC GND SDA SCL SDO CS',
    'BME688 — Gas / Temperature / Humidity / Pressure sensor (Bosch)',
    'Multi-sensor with VOC gas detection, temperature, humidity, and pressure. '
    'I2C or SPI interface. Operating voltage 1.71–3.6V. '
    'I2C address 0x76 (SDO low) or 0x77 (SDO high). '
    'AI gas sensing via BSEC library. Deployed on env-node-05.',
    'sensor',
    '{
        "interface": "i2c",
        "voltage": "3.3v",
        "i2c_addresses": ["0x76", "0x77"],
        "addr_pin": "SDO",
        "pins": [
            {
                "id":    "VCC",
                "label": "VCC / 3.3V",
                "side":  "left",
                "index": 0,
                "role":  "power"
            },
            {
                "id":    "GND",
                "label": "GND",
                "side":  "left",
                "index": 1,
                "role":  "ground"
            },
            {
                "id":    "SDA",
                "label": "SDA / SDI",
                "side":  "right",
                "index": 0,
                "role":  "i2c_data"
            },
            {
                "id":    "SCL",
                "label": "SCL / SCK",
                "side":  "right",
                "index": 1,
                "role":  "i2c_clock"
            },
            {
                "id":    "SDO",
                "label": "SDO / ADDR",
                "side":  "right",
                "index": 2,
                "role":  "addr"
            },
            {
                "id":    "CS",
                "label": "CS",
                "side":  "right",
                "index": 3,
                "role":  "spi_cs"
            }
        ],
        "notes": [
            "Pull SDO to GND for address 0x76 (default)",
            "CS must be tied HIGH for I2C mode",
            "Do not exceed 3.6V — no 5V operation",
            "Gas sensor requires heater warm-up; use BSEC library for calibrated IAQ output",
            "Paired with SHT31 on env-node-05 for thermal cross-reference"
        ]
    }'::jsonb,
    NULL
)
ON CONFLICT (image_filename) DO UPDATE SET
    component_model = EXCLUDED.component_model,
    summary         = EXCLUDED.summary,
    part_type       = EXCLUDED.part_type,
    pin_map         = EXCLUDED.pin_map;

COMMIT;

-- ============================================================
-- Re-embed after seeding
-- Run this separately once the transaction above is committed:
--
--   python3 /home/sean/sensor-ecology/scripts/embed_parts_catalogue.py \
--       --filter "embedding = '[0]'"
--
-- Or from psql to verify the new rows landed:
--
--   SELECT image_filename, part_type,
--          jsonb_array_length(pin_map->'pins') AS pin_count,
--          LEFT(summary, 60) AS summary_preview
--   FROM parts_catalogue
--   WHERE part_type IS NOT NULL
--   ORDER BY part_type, image_filename;
-- ============================================================
