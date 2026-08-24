# Hardware Registry Runbook
## *From iOS Field App to Sensor Ecology AR*

This runbook acts as the standard operating procedure for classifying a raw hardware component (like your `LSM6DS0` IMU) via the iOS ontology app and injecting it into the active `device_registry` so the Macroscopic Dashboard and the AR Computer Vision app can identify and monitor it.

### Step 1: Physical Identification (iOS App)
When you hold a raw IC board, the markings are often microscopic and visually dense.
1. Scan the board utilizing the **iOS Field App (Offline Detail Mode)**.
2. Select **OCR & Analyze IC** to hit your local semantic identification models.
3. Review the OCR output (e.g., *STMicroelectronics LSM6DS0, 6-axis IMU*).
4. Tap **Saved to Ontology DB!** (This pushes the semantic definition into your offline knowledge base).

### Step 2: Injecting into the AR Computer Vision `device_registry`
Even though the Ontology application knows what the IMU is, the AR tracking bridge running on the Pi 5 (`192.168.0.28:8766`) must be made explicitly aware of this unit so it can bind MQTT data to it when it is physically plugged in.

Instead of writing a custom Python script (like `add_bench_cam.py`) and carefully formatting SQL inserts every time, you now have a master utility script.

Execute the following on your Windows terminal:
```powershell
python register_device.py
```

**Fill out the prompts chronologically:**
* **New Device ID**: `lsm6ds0-imu-1` (Unique alphanumeric string without spaces)
* **Display Name**: `LSM6DS0 6-Axis IMU` (Human readable, appears in AR Component Library UI)
* **Device Type**: `imu-sensor`
* **Location**: `workbench`
* **AR/Gemini CV Labels**: `LSM6DS0, 6-axis IMU, Inertial Measurement Unit, STMicroelectronics IMU`
    * *CRITICAL: When the iPad AR Camera runs Gemini to identify a chip on your desk, it attempts to match the visual output directly against these comma-separated tags! Include multiple variations of names here so Gemini has a high probability of finding a match.*
* **Hardware Passport Notes**: `Marks: AH250B, E230P3`
* **MQTT Topics**: `{"telemetry": "sensors/imu-1/telemetry"}` (Format exactly as a JSON Object so `ws_bridge.py` knows which topic belongs to this specifically).

### Step 3: Reboot the Websocket Bridge Cache
Your PostgreSQL engine now contains the new registry data. However, the `ws_bridge.py` daemon explicitly caches the entire registry in RAM at start-up to avoid pounding the database at 60 frames per second.

Push a cache reload to the Pi 5:
```bash
sudo systemctl restart ws-bridge
```

Upon restart, checking the **Hardware Component Library** inside your Tablet AR Application will show the `LSM6DS0 6-Axis IMU` ready to be securely bound to an active computer-vision session!
