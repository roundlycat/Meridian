import asyncio
import json
import math
import random
import time
from datetime import datetime, timezone

# Paho-MQTT 2.x imports (Ensure: pip install paho-mqtt)
import paho.mqtt.client as mqtt
from paho.mqtt.enums import CallbackAPIVersion

MQTT_BROKER = "localhost"  # Change to your local Pi/Shed IP if needed
MQTT_PORT = 1883

class GardenEnvironmentEngine:
    """Generates the underlying noumenal reality of the yard over time."""
    def __init__(self):
        self.start_time = time.time()
        
    def get_macro_states(self):
        # Accelerate time: 1 real minute = 1 simulated hour for rapid testing
        elapsed_minutes = (time.time() - self.start_time) / 60.0
        sim_hour = (elapsed_minutes * 60) % 24
        
        # Base temperature pattern (Cold Whitehorse mornings, peaking mid-afternoon)
        base_temp = 8.0 + 10.0 * math.sin((sim_hour - 8) * math.pi / 12)
        
        # Base ambient light curve (0 at night, smooth curve during daylight)
        if 5.0 <= sim_hour <= 21.0:
            base_light = 1000.0 * math.sin((sim_hour - 5) * math.pi / 16)
        else:
            base_light = 0.0
            
        return {
            "sim_hour": sim_hour,
            "base_temp": base_temp,
            "base_light": base_light,
            "is_raining": random.random() < 0.02 # 2% steady chance of a transient drizzle
        }

env_engine = GardenEnvironmentEngine()

async def simulate_node(node_id, slug, context_modifier_func):
    """Asynchronous loop simulating an individual physical Pi Pico W."""
    client = mqtt.Client(callback_api_version=CallbackAPIVersion.VERSION2, client_id=slug)
    
    try:
        client.connect(MQTT_BROKER, MQTT_PORT, 60)
        client.loop_start()
    except Exception as e:
        print(f"[{slug}] Broker connection failed (running in offline log mode): {e}")

    print(f"--> Worker initialized for node: {slug}")
    
    while True:
        macro = env_engine.get_macro_states()
        # Derive specific sensor data using the node's unique context function
        telemetry = context_modifier_func(macro)
        
        payload = {
            "node_id": node_id,
            "slug": slug,
            "timestamp": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
            "metrics": telemetry
        }
        
        topic = f"garden/ecology/{slug}/telemetry"
        json_payload = json.dumps(payload, indent=2)
        
        if client.is_connected():
            client.publish(topic, json_payload, qos=0)
        else:
            print(f"\n[OFFLINE STORAGE - {slug}] Topic: {topic}\n{json_payload}")
            
        # Push update every 5 seconds (Adjust to scale your ingestion pressure testing)
        await asyncio.sleep(5)

# --- Define Spatial & Contextual Modifiers ---

def modify_sky_reference(macro):
    """Elevated open sky view baseline."""
    return {
        "ambient_temp": round(macro["base_temp"] + random.uniform(-0.2, 0.2), 2),
        "lux": round(macro["base_light"], 1),
        "uv_index": round(max(0.0, (macro["base_light"] / 100.0) + random.uniform(-0.1, 0.1)), 2),
        "barometric_pressure_hpa": round(1013.25 + random.uniform(-0.5, 0.5), 2)
    }

def modify_bed_north(macro):
    """B1 Bed North: Close to house wall. Shaded earlier, retains soil dampness."""
    hour = macro["sim_hour"]
    # Shadow cliff: wall cuts light significantly after 14:00 (2 PM)
    shadow_factor = 0.2 if hour > 14 else 0.9
    
    return {
        "ambient_temp": round(macro["base_temp"] - 0.8 + random.uniform(-0.1, 0.1), 2),
        "lux": round(macro["base_light"] * shadow_factor, 1),
        "soil_moisture_vwc": round(42.5 - (0.1 * (hour % 24)) if not macro["is_raining"] else 45.0, 2),
        "canopy_temp": round(macro["base_temp"] - 0.4, 2)
    }

def modify_bed_south(macro):
    """B2 Bed South: Exposed open bed. Gets full afternoon heat, dries faster."""
    hour = macro["sim_hour"]
    return {
        "ambient_temp": round(macro["base_temp"] + 0.5 + random.uniform(-0.1, 0.1), 2),
        "lux": round(macro["base_light"] * 0.95, 1),
        "soil_moisture_vwc": round(31.2 - (0.25 * (hour % 24)) if not macro["is_raining"] else 38.0, 2),
        "canopy_temp": round(macro["base_temp"] + 1.1, 2)
    }

def modify_central_env(macro):
    """E1 Central: Richest sensor package."""
    # Simulate a sudden, localized rustle or transient event
    acoustic_activity = round(random.uniform(20, 35), 1)
    if random.random() < 0.05:  # 5% chance of bird or wind gust
        acoustic_activity += random.uniform(30, 45)

    return {
        "ambient_temp": round(macro["base_temp"] + random.uniform(-0.3, 0.3), 2),
        "lux": round(macro["base_light"] * 0.85, 1),
        "co2_ppm": round(415.0 + random.uniform(-10, 25)),
        "tvoc_ppb": round(12.0 + random.uniform(0, 8)),
        "acoustic_db": acoustic_activity
    }

def modify_entry_presence(macro):
    """P Entry Presence: Dual-technology radar + PIR gating."""
    # Simulate human arrival occurrences
    is_active = random.random() < 0.08  # Transient events
    return {
        "radar_target_distance_m": round(random.uniform(0.5, 4.5), 2) if is_active else 0.0,
        "pir_trigger": 1 if is_active else 0,
        "event_gated_signal": 1 if (is_active and random.random() > 0.1) else 0
    }

# --- Orchestrate Node Task Factory ---

async def main():
    # Mapping coordinates directly from your node configuration IDs
    tasks = [
        asyncio.create_task(simulate_node(1, "w-sky-reference", modify_sky_reference)),
        asyncio.create_task(simulate_node(2, "b1-bed-north", modify_bed_north)),
        asyncio.create_task(simulate_node(3, "b2-bed-south", modify_bed_south)),
        asyncio.create_task(simulate_node(4, "e1-central", modify_central_env)),
        asyncio.create_task(simulate_node(5, "p-entry-presence", modify_entry_presence)),
    ]
    await asyncio.gather(*tasks)

if __name__ == "__main__":
    print("======================================================")
    print(" STARTING SENSOR ECOLOGY PHENOMENAL FIELD SIMULATOR  ")
    print("======================================================")
    asyncio.run(main())
