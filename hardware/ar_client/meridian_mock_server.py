import asyncio
import websockets
import json
import random
import time

async def send_telemetry(websocket):
    print("Client connected!")
    try:
        while True:
            # Generate a mock telemetry payload matching the Gemini schema
            payload = {
                "interfaceType": "Dashboard",
                "elements": [
                    {
                        "type": "Telemetry_Card",
                        "targetObjectID": "system_status",
                        "title": "System Status",
                        "value": f"Online - {random.randint(20, 100)}ms",
                        "color": "#00FFCC" if random.random() > 0.1 else "#FF4444"
                    },
                    {
                        "type": "Haptic_Beacon",
                        "targetObjectID": "wrist_puck",
                        "frequency": random.uniform(100.0, 250.0),
                        "amplitude": random.uniform(0.1, 0.8),
                        "pattern": "Pulse"
                    }
                ]
            }
            
            await websocket.send(json.dumps(payload))
            print(f"Sent payload: {payload['elements'][0]['value']}")
            await asyncio.sleep(2)  # Update every 2 seconds
            
    except websockets.ConnectionClosed:
        print("Client disconnected.")

async def main():
    print("Starting Mock WebSocket server on ws://localhost:8080...")
    # Change host to '0.0.0.0' if testing from Quest headset rather than Unity Editor on same machine
    async with websockets.serve(send_telemetry, "localhost", 8080):
        await asyncio.Future()  # run forever

if __name__ == "__main__":
    asyncio.run(main())
