import asyncio
import json
import math
import random
import time
from datetime import datetime, timezone

import paho.mqtt.client as mqtt
from paho.mqtt.enums import CallbackAPIVersion

MQTT_BROKER = "localhost"
MQTT_PORT = 1883


# ── Weather State Machine ──────────────────────────────────────────────────────

class WeatherStateMachine:
    """
    Persistent rain events rather than per-reading coin flips.
    Rain onset is checked once per real minute; duration is 10–90 simulated minutes.
    Intensity varies over the event lifecycle (builds, peaks, tapers).
    """
    def __init__(self):
        self.is_raining = False
        self.intensity = 0.0          # 0.0–1.0, affects sensor readings
        self._rain_end = 0.0
        self._rain_peak = 0.0
        self._next_onset_check = 0.0
        self.onset_prob_per_minute = 0.025

    def update(self) -> bool:
        now = time.time()

        if self.is_raining:
            if now >= self._rain_end:
                self.is_raining = False
                self.intensity = 0.0
                print("[WEATHER] Rain event ended")
            else:
                # Intensity arc: ramp up to peak, then taper
                elapsed = now - (self._rain_end - (self._rain_peak - self._rain_end) * 2)
                duration = self._rain_end - (self._rain_end - self._rain_peak * 2)
                self.intensity = round(
                    min(1.0, math.sin(math.pi * max(0, (now - (self._rain_end - self._rain_peak))) / self._rain_peak)),
                    2
                )
        else:
            if now >= self._next_onset_check:
                self._next_onset_check = now + 60.0
                if random.random() < self.onset_prob_per_minute:
                    duration_s = random.uniform(600, 5400)   # 10–90 min real time
                    self._rain_end = now + duration_s
                    self._rain_peak = duration_s * random.uniform(0.3, 0.6)
                    self.is_raining = True
                    self.intensity = 0.1
                    print(f"[WEATHER] Rain event started — duration {duration_s/60:.1f} min")

        return self.is_raining


# ── Soil Moisture State Registry ───────────────────────────────────────────────

class SoilStateRegistry:
    """
    Tracks soil volumetric water content (VWC %) per bed node.
    Drying is driven by temperature and light (evapotranspiration proxy).
    Wetting from rain is rapid and intensity-weighted.
    North bed dries ~30% slower due to wall shadow and lower ET.
    """
    INITIAL = {
        "b1-bed-north": 42.5,
        "b2-bed-south": 31.2,
    }
    ET_MULTIPLIER = {
        "b1-bed-north": 0.70,
        "b2-bed-south": 1.00,
    }
    WET_RATE = {
        "b1-bed-north": 1.2,
        "b2-bed-south": 0.9,
    }

    def __init__(self):
        self._vwc = dict(self.INITIAL)

    def update(self, slug: str, base_temp: float, base_light: float,
               is_raining: bool, rain_intensity: float) -> float:
        vwc = self._vwc[slug]

        if is_raining:
            wet = self.WET_RATE[slug] * rain_intensity
            vwc = min(vwc + random.uniform(wet * 0.5, wet), 60.0)
        else:
            et = (max(base_temp, 0) * 0.0010) + (max(base_light, 0) * 0.00007)
            et *= self.ET_MULTIPLIER[slug]
            vwc = max(vwc - et, 10.0)

        self._vwc[slug] = vwc
        return round(vwc + random.uniform(-0.15, 0.15), 2)


# ── Hailo-8L Synthetic Vision Node ────────────────────────────────────────────

class HailoVisionSynth:
    """
    Generates synthetic YOLOv8s detections matching the output schema
    of the Freenove camera node + Hailo-8L on Sensor Pi.

    Rates are diurnal and class-realistic for a Whitehorse residential yard.
    Inference latency (7–14ms) matches observed Hailo-8L performance.
    """
    # (class_label, daytime_prob_per_5s, night_multiplier)
    CLASSES = [
        ("person",   0.06, 0.04),
        ("bird",     0.05, 0.01),
        ("cat",      0.02, 0.20),   # cats more active at night
        ("vehicle",  0.03, 0.02),
        ("squirrel", 0.04, 0.00),   # diurnal only
        ("raven",    0.02, 0.00),   # Whitehorse-specific
    ]

    def generate(self, sim_hour: float) -> dict:
        is_day = 6.0 <= sim_hour <= 21.0
        detections = []

        for cls, day_rate, night_mult in self.CLASSES:
            rate = day_rate if is_day else day_rate * night_mult
            if random.random() < rate:
                detections.append({
                    "class": cls,
                    "confidence": round(random.uniform(0.62, 0.97), 3),
                    "bbox_xywh": [          # normalised [x, y, w, h]
                        round(random.uniform(0.05, 0.70), 3),
                        round(random.uniform(0.05, 0.70), 3),
                        round(random.uniform(0.08, 0.35), 3),
                        round(random.uniform(0.08, 0.35), 3),
                    ]
                })

        return {
            "frame_detections": detections,
            "detection_count": len(detections),
            "inference_ms": round(random.uniform(7.5, 14.0), 1),
            "model": "yolov8s",
            "hailo_temp_c": round(random.uniform(42.0, 58.0), 1),
        }


# ── Garden Environment Engine ──────────────────────────────────────────────────

class GardenEnvironmentEngine:
    """
    Generates the underlying noumenal reality of the yard.
    Weather and soil are now stateful singletons shared across all nodes.
    """
    def __init__(self):
        self.start_time = time.time()
        self.weather = WeatherStateMachine()
        self.soil = SoilStateRegistry()

    def get_macro_states(self) -> dict:
        elapsed_minutes = (time.time() - self.start_time) / 60.0
        sim_hour = (elapsed_minutes * 60) % 24          # 1 real min = 1 sim hour

        base_temp = 8.0 + 10.0 * math.sin((sim_hour - 8) * math.pi / 12)

        base_light = (
            1000.0 * math.sin((sim_hour - 5) * math.pi / 16)
            if 5.0 <= sim_hour <= 21.0
            else 0.0
        )

        is_raining = self.weather.update()

        return {
            "sim_hour":       sim_hour,
            "base_temp":      base_temp,
            "base_light":     base_light,
            "is_raining":     is_raining,
            "rain_intensity": self.weather.intensity,
        }


# ── Singletons ─────────────────────────────────────────────────────────────────

env_engine  = GardenEnvironmentEngine()
hailo_synth = HailoVisionSynth()


# ── Node Context Modifiers ─────────────────────────────────────────────────────

def modify_sky_reference(macro: dict) -> dict:
    """W Sky Reference — elevated open-sky baseline, weather-aware."""
    return {
        "ambient_temp":          round(macro["base_temp"] + random.uniform(-0.2, 0.2), 2),
        "lux":                   round(macro["base_light"], 1),
        "uv_index":              round(max(0.0, macro["base_light"] / 100.0 + random.uniform(-0.1, 0.1)), 2),
        "barometric_pressure_hpa": round(1013.25 + random.uniform(-0.5, 0.5), 2),
        "is_raining":            macro["is_raining"],
        "rain_intensity":        macro["rain_intensity"],
    }


def modify_bed_north(macro: dict) -> dict:
    """B1 Bed North — wall shadow cliff at 14:00, persistent soil moisture."""
    hour = macro["sim_hour"]
    shadow_factor = 0.2 if hour > 14 else 0.9
    vwc = env_engine.soil.update(
        "b1-bed-north", macro["base_temp"], macro["base_light"],
        macro["is_raining"], macro["rain_intensity"]
    )
    return {
        "ambient_temp":    round(macro["base_temp"] - 0.8 + random.uniform(-0.1, 0.1), 2),
        "lux":             round(macro["base_light"] * shadow_factor, 1),
        "soil_moisture_vwc": vwc,
        "canopy_temp":     round(macro["base_temp"] - 0.4, 2),
    }


def modify_bed_south(macro: dict) -> dict:
    """B2 Bed South — full afternoon exposure, dries faster."""
    vwc = env_engine.soil.update(
        "b2-bed-south", macro["base_temp"], macro["base_light"],
        macro["is_raining"], macro["rain_intensity"]
    )
    return {
        "ambient_temp":    round(macro["base_temp"] + 0.5 + random.uniform(-0.1, 0.1), 2),
        "lux":             round(macro["base_light"] * 0.95, 1),
        "soil_moisture_vwc": vwc,
        "canopy_temp":     round(macro["base_temp"] + 1.1, 2),
    }


def modify_central_env(macro: dict) -> dict:
    """E1 Central — richest package: CO2, TVOC, acoustic."""
    acoustic_db = round(random.uniform(20, 35), 1)
    if random.random() < 0.05:                          # transient gust / bird
        acoustic_db += random.uniform(30, 45)
    # Rain adds broadband noise floor
    if macro["is_raining"]:
        acoustic_db += round(macro["rain_intensity"] * 12.0, 1)
    return {
        "ambient_temp": round(macro["base_temp"] + random.uniform(-0.3, 0.3), 2),
        "lux":          round(macro["base_light"] * 0.85, 1),
        "co2_ppm":      round(415.0 + random.uniform(-10, 25)),
        "tvoc_ppb":     round(12.0 + random.uniform(0, 8)),
        "acoustic_db":  round(min(acoustic_db, 95.0), 1),
        "is_raining":   macro["is_raining"],
    }


def modify_entry_presence(macro: dict) -> dict:
    """P Entry Presence — radar + PIR dual-technology gating."""
    # Rain causes spurious PIR triggers
    spurious_rate = 0.08 + (0.06 * macro["rain_intensity"])
    is_active = random.random() < spurious_rate
    is_real   = is_active and random.random() > (0.1 + 0.3 * macro["rain_intensity"])
    return {
        "radar_target_distance_m": round(random.uniform(0.5, 4.5), 2) if is_active else 0.0,
        "pir_trigger":             1 if is_active else 0,
        "event_gated_signal":      1 if is_real else 0,
    }


def modify_hailo_camera(macro: dict) -> dict:
    """C1 Hailo Camera — synthetic YOLOv8s detections from Hailo-8L."""
    return hailo_synth.generate(macro["sim_hour"])


# ── Node Task Runner ───────────────────────────────────────────────────────────

async def simulate_node(node_id: int, slug: str, context_modifier_func):
    """Asynchronous loop for one simulated physical node."""
    client = mqtt.Client(
        callback_api_version=CallbackAPIVersion.VERSION2,
        client_id=slug
    )
    try:
        client.connect(MQTT_BROKER, MQTT_PORT, 60)
        client.loop_start()
    except Exception as e:
        print(f"[{slug}] Broker unavailable — offline log mode: {e}")

    print(f"--> Worker initialised: {slug}")

    while True:
        macro    = env_engine.get_macro_states()
        telemetry = context_modifier_func(macro)

        payload = {
            "node_id":   node_id,
            "slug":      slug,
            "timestamp": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
            "metrics":   telemetry,
        }

        topic        = f"garden/ecology/{slug}/telemetry"
        json_payload = json.dumps(payload, indent=2)

        if client.is_connected():
            client.publish(topic, json_payload, qos=0)
        else:
            print(f"\n[OFFLINE — {slug}] {topic}\n{json_payload}")

        await asyncio.sleep(5)


# ── Main ───────────────────────────────────────────────────────────────────────

async def main():
    tasks = [
        asyncio.create_task(simulate_node(1, "w-sky-reference",  modify_sky_reference)),
        asyncio.create_task(simulate_node(2, "b1-bed-north",     modify_bed_north)),
        asyncio.create_task(simulate_node(3, "b2-bed-south",     modify_bed_south)),
        asyncio.create_task(simulate_node(4, "e1-central",       modify_central_env)),
        asyncio.create_task(simulate_node(5, "p-entry-presence", modify_entry_presence)),
        asyncio.create_task(simulate_node(6, "c1-hailo-camera",  modify_hailo_camera)),
    ]
    await asyncio.gather(*tasks)


if __name__ == "__main__":
    print("==========================================================")
    print("  MERIDIAN SENSOR ECOLOGY SIMULATOR  v2                   ")
    print("  nodes: sky · bed-N · bed-S · central · presence · hailo ")
    print("==========================================================")
    asyncio.run(main())
