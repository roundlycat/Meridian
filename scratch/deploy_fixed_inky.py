import paramiko

HOST = "192.168.0.24"
USER = "pi"
PASS = "vijwus-moJxix9"

SKY_CAM_SCRIPT = """#!/usr/bin/env python3
import json
import time
import paho.mqtt.client as mqtt
from inky import InkyPHAT
from PIL import Image, ImageFont, ImageDraw

# Initialize Inky display manually (older boards have no EEPROM for auto())
try:
    inky_display = InkyPHAT("black")
    inky_display.set_border(inky_display.WHITE)
except Exception as e:
    print(f"Failed to initialize Inky display: {e}")
    exit(1)

MQTT_BROKER = "192.168.0.28"
MQTT_TOPIC = "meridian/ecology/deltas"

def update_display(message_text):
    print(f"Updating display with: {message_text}")
    img = Image.new("P", (inky_display.WIDTH, inky_display.HEIGHT))
    draw = ImageDraw.Draw(img)
    
    # Try to load a standard font, fallback to default
    try:
        from font_source_sans_pro import SourceSansPro
        font = ImageFont.truetype(SourceSansPro, 16)
    except:
        font = ImageFont.load_default()
        
    # Split text into lines if too long (naive wrap)
    words = message_text.split()
    lines = []
    line = ""
    for word in words:
        if len(line) + len(word) < 25:
            line += word + " "
        else:
            lines.append(line)
            line = word + " "
    lines.append(line)
    
    y = 5
    for l in lines[:5]: # Max 5 lines
        draw.text((5, y), l, inky_display.BLACK, font)
        y += 20
        
    inky_display.set_image(img)
    inky_display.show()

def on_connect(client, userdata, flags, rc):
    print(f"Connected to MQTT broker with result code {rc}")
    client.subscribe(MQTT_TOPIC)

def on_message(client, userdata, msg):
    payload = msg.payload.decode('utf-8')
    print(f"Received message: {payload}")
    text_to_display = payload
    try:
        data = json.loads(payload)
        if 'delta_text' in data:
            text_to_display = data['delta_text']
        elif 'message' in data:
            text_to_display = data['message']
    except:
        pass
    
    update_display(text_to_display)

if __name__ == '__main__':
    update_display("Sky Cam Booting...\\nWaiting for deltas.")
    
    client = mqtt.Client()
    client.on_connect = on_connect
    client.on_message = on_message
    
    try:
        client.connect(MQTT_BROKER, 1883, 60)
        client.loop_forever()
    except Exception as e:
        print(f"MQTT Error: {e}")
"""

def main():
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    try:
        ssh.connect(HOST, username=USER, password=PASS, timeout=10)
        
        # Write updated file via SFTP
        sftp = ssh.open_sftp()
        with sftp.file('/home/pi/sky_cam_display.py', 'w') as f:
            f.write(SKY_CAM_SCRIPT)
        sftp.close()
        
        # Restart service
        print("Restarting service...")
        full_cmd = f"echo '{PASS}' | sudo -S systemctl restart skycam.service"
        stdin, stdout, stderr = ssh.exec_command(full_cmd)
        print(stdout.read().decode('utf-8', errors='ignore'))
        
        print("Done!")
        
    except Exception as e:
        print(f"Error: {e}")
    finally:
        ssh.close()

if __name__ == "__main__":
    main()
