import asyncio
import json
import websockets
import random

MOCK_SCHEMA = {
    "interfaceType": "AR_Guidance_Overlay",
    "elements": [
        {
            "type": "Wireframe_Highlight",
            "targetObjectID": "esp32_node_01",
            "color": "#00FFCC",
            "pulseRate": 1.5
        },
        {
            "type": "Haptic_Beacon",
            "spatialPosition": {"x": 0.2, "y": 1.1, "z": -0.4},
            "frequency": 220.0,
            "amplitude": 0.8,
            "pattern": "Double_Pulse"
        },
        {
            "type": "Telemetry_Card",
            "title": "MQTT Broker Link",
            "value": "Connected - 43ms latency"
        }
    ]
}

async def schema_stream(websocket):
    print(f"Client connected: {websocket.remote_address}")
    try:
        while True:
            # Simulate a dynamic update (e.g. latency changing)
            latency = random.randint(20, 80)
            MOCK_SCHEMA["elements"][2]["value"] = f"Connected - {latency}ms latency"
            
            payload = json.dumps(MOCK_SCHEMA)
            print(f"Pushing schema update: {latency}ms")
            
            await websocket.send(payload)
            
            # Pushing updates every 2 seconds
            await asyncio.sleep(2)
            
    except websockets.exceptions.ConnectionClosed:
        print(f"Client disconnected: {websocket.remote_address}")

async def main():
    print("Starting mock Gemini schema WebSocket server on ws://localhost:8080")
    async with websockets.serve(schema_stream, "localhost", 8080):
        await asyncio.Future()  # run forever

if __name__ == "__main__":
    asyncio.run(main())
