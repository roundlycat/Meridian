# Motif Graph Unity Integration

To seamlessly load the Blender-generated `.gltf` sculpture into your AR headset dynamically (so it updates whenever the ecology simulator changes, without needing to rebuild the Unity APK), we need to set up runtime glTF loading.

## Proposed Changes

Currently, Unity only natively processes `.gltf` files at *edit-time* on your desktop. To load them at *runtime* on the Quest 3, we will use the industry-standard `glTFast` package.

### 1. Update Package Manifest
I will add the `glTFast` dependency to your `ar_client/Packages/manifest.json`. This will allow your compiled Quest 3 app to parse `.gltf` files on the fly.

### 2. Create `DynamicMotifLoader.cs`
I will write a new Unity script in `ar_client/Scripts/DynamicMotifLoader.cs`. This script will:
- Act as the anchor for the motif graph in AR space.
- Fetch the `MotifGraph.gltf` file.
- Instantiate it in the scene.
- Apply a slow, ambient rotation/bobbing animation to give it that floating sculptural presence.
- Periodically check for a new version of the file and hot-swap it.

> [!IMPORTANT]
> **Hosting the GLTF for the Quest 3**
> Because the Quest 3 is a separate Android device, it cannot read `C:\Users\seank\...` from your Windows PC at runtime. 
> To load the `.gltf` dynamically over the air, the file needs to be hosted on a local web server.
> 
> **Options:**
> 1. We spin up a simple `python -m http.server 8080` background task in the `ar_client/Assets/Models` folder on your PC. The Unity script will just fetch `http://<YOUR_PC_IP>:8080/MotifGraph.gltf`.
> 2. Alternatively, if you just want to bake this initial `.gltf` directly into the Unity build statically (no dynamic updates), we don't need `glTFast` at all. We just drag the prefab into the scene.
> 
> Assuming you want the "dynamic runtime updates" (Option 1), does that sound good?

## Verification Plan

1. Modify `manifest.json` to include glTFast.
2. Write `DynamicMotifLoader.cs`.
3. Provide instructions to start the local python server.
4. You will attach the script to your AR anchor, build to the Quest, and see the mesh load dynamically!
