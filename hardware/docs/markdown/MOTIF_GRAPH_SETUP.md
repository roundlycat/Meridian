# Motif Graph Dynamic Loader — Setup Notes

## 1. Unity Package Manifest

In `ar_client/Packages/manifest.json`, add to the `"dependencies"` block:

```json
"com.unity.cloud.gltfast": "6.9.0"
```

Full example:
```json
{
  "dependencies": {
    "com.unity.cloud.gltfast": "6.9.0",
    "com.unity.xr.arfoundation": "...",
    "com.unity.xr.oculus": "..."
  }
}
```

Unity will pull the package on next editor launch. If the registry lookup
fails, add the Unity registry explicitly:

```json
"scopedRegistries": [
  {
    "name": "Unity",
    "url": "https://packages.unity.com",
    "scopes": ["com.unity"]
  }
]
```

---

## 2. Inferno — Install Python deps

```bash
pip install trimesh psycopg2-binary scikit-learn numpy --break-system-packages
```

---

## 3. Inferno — Place the generator

```bash
mkdir -p /home/sean/meridian/gltf
cp motif_gltf_generator.py /home/sean/meridian/
python3 /home/sean/meridian/motif_gltf_generator.py
# Should print: Exported N motifs, M edges → /home/sean/meridian/gltf/MotifGraph.gltf
```

---

## 4. Inferno — Wire routes into relay-api

Edit `/home/sean/relay-api/main.py` (or wherever your FastAPI app lives):

```python
from relay_api_gltf_routes import gltf_router
app.include_router(gltf_router)
```

Copy the routes file:
```bash
cp relay_api_gltf_routes.py /home/sean/relay-api/
sudo systemctl restart relay-api
```

Test from any machine on the LAN:
```bash
curl http://192.168.0.28:8765/motif-graph/meta
# → {"generated_at": "...", "motif_count": 17, "edge_count": 42}
```

---

## 5. Unity — Add DynamicMotifLoader to scene

1. Create an empty GameObject in your AR scene, name it `MotifAnchor`
2. Position it where you want the graph to float (e.g. 1.2m in front of origin, 0m height)
3. Attach `DynamicMotifLoader.cs` to it
4. In Inspector, set **Inferno Base URL** to `http://192.168.0.28:8765`
5. Set **Poll Interval** to 30 (seconds)
6. Build and sideload to Quest 3

---

## 6. Optional — Auto-regenerate on a schedule

On Inferno, add to crontab (`crontab -e`):

```cron
*/15 * * * * python3 /home/sean/meridian/motif_gltf_generator.py >> /home/sean/meridian/gltf/generator.log 2>&1
```

This regenerates the graph every 15 minutes from live motif data.

---

## How the full loop works

```
[sensor nodes] → MQTT → [Inferno: sensor_ingestion_layer]
    → PostgreSQL (motif_resonance updated)
    → cron / POST /regenerate triggers motif_gltf_generator.py
    → writes MotifGraph.gltf + .meta to /home/sean/meridian/gltf/

[Quest 3: DynamicMotifLoader]
    → every 30s: GET /motif-graph/meta
    → if generated_at changed: GET /motif-graph/file
    → glTFast parses bytes → instantiates in AR scene
    → hot-swaps old graph → ambient float + rotation begins
```

---

## Troubleshooting

**Graph doesn't appear:**
- Check `curl http://192.168.0.28:8765/motif-graph/meta` from Quest (via browser or adb)
- Check Unity logcat: `adb logcat -s Unity` — look for `[MotifLoader]` lines
- Confirm Quest and Inferno are on the same WiFi network

**glTFast compile error:**
- Ensure `com.unity.cloud.gltfast` (not the old `com.atteneder.gltfast`) is in manifest
- Minimum Unity version: 2021.3 LTS

**Empty graph / only a few nodes:**
- Run generator manually and check output count
- Confirm `motifs.embedding IS NOT NULL` — run reembedding if needed
- Lower `EDGE_THRESHOLD` in generator (default 0.25) if graph looks sparse
