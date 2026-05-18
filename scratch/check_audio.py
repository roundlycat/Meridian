import os
# Force load x64 PortAudio via emulation on ARM64 Windows
os.environ["SOUNDDEVICE_PORTAUDIO_LIB"] = r"C:\Users\seank\AppData\Roaming\Python\Python314\site-packages\_sounddevice_data\portaudio-binaries\libportaudio64bit.dll"
import sounddevice as sd
devs = sd.query_devices()
print("Default input:", sd.default.device[0])
print("Default output:", sd.default.device[1])
print("---")
for i, d in enumerate(devs):
    print(f"  [{i}] {d['name']} (in:{d['max_input_channels']}, out:{d['max_output_channels']})")
