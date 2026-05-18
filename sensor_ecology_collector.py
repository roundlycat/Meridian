import sqlite3
import json
import os
from datetime import datetime

import paho.mqtt.client as mqtt
from paho.mqtt.enums import CallbackAPIVersion

DB_NAME = "meridian_ecology.db"
MQTT_BROKER = "localhost"
MQTT_PORT = 1883
TOPIC = "garden/ecology/+/telemetry"

def init_db():
    conn = sqlite3.connect(DB_NAME)
    cursor = conn.cursor()
    # Create the telemetry_events table if it doesn't exist.
    # The 'payload' column stores the specific sensor metrics as JSON.
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS telemetry_events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            node_id INTEGER,
            slug TEXT,
            timestamp TEXT,
            topic TEXT,
            payload JSON
        )
    ''')
    conn.commit()
    return conn

def on_connect(client, userdata, flags, reason_code, properties):
    if reason_code == 0:
        print(f"Connected to MQTT Broker at {MQTT_BROKER}:{MQTT_PORT}")
        client.subscribe(TOPIC)
        print(f"Subscribed to topic: {TOPIC}")
    else:
        print(f"Failed to connect, return code {reason_code}")

def on_message(client, userdata, msg):
    try:
        payload_str = msg.payload.decode('utf-8')
        data = json.loads(payload_str)
        
        # Insert incoming telemetry into SQLite
        cursor = userdata['db_conn'].cursor()
        cursor.execute(
            "INSERT INTO telemetry_events (node_id, slug, timestamp, topic, payload) VALUES (?, ?, ?, ?, ?)",
            (
                data.get("node_id"), 
                data.get("slug"), 
                data.get("timestamp"), 
                msg.topic, 
                json.dumps(data.get("metrics", {}))
            )
        )
        userdata['db_conn'].commit()
        
        print(f"Stored: [{msg.topic}] from node {data.get('slug')} at {data.get('timestamp')}")
        
    except json.JSONDecodeError:
        print(f"Failed to parse JSON payload on {msg.topic}: {msg.payload}")
    except sqlite3.Error as e:
        print(f"Database error: {e}")
    except Exception as e:
        print(f"Unexpected error handling message: {e}")

def main():
    print("======================================================")
    print(" STARTING HUB GATEWAY TELEMETRY COLLECTOR             ")
    print("======================================================")
    
    db_conn = init_db()
    print(f"Initialized SQLite database at {DB_NAME}")
    
    userdata = {'db_conn': db_conn}
    
    # We use userdata to pass the db connection to the MQTT callbacks
    client = mqtt.Client(callback_api_version=CallbackAPIVersion.VERSION2, client_id="hub-gateway-collector", userdata=userdata)
    client.on_connect = on_connect
    client.on_message = on_message
    
    try:
        client.connect(MQTT_BROKER, MQTT_PORT, 60)
    except Exception as e:
        print(f"Broker connection failed: {e}")
        print("Please ensure your MQTT broker (e.g., Mosquitto) is running locally.")
        return

    try:
        client.loop_forever()
    except KeyboardInterrupt:
        print("\nCollector shutting down...")
    finally:
        client.disconnect()
        db_conn.close()
        print("Database connection closed. Goodbye.")

if __name__ == "__main__":
    main()
