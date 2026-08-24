# Zen Kiosk — Setup Notes (Waveshare 4" / 4.3" 800×480, Pi 3B)

## What this is
A fullscreen poetry kiosk page for a Raspberry Pi 3B + display hat.
It fetches a random poem from your Flask app and cycles every 5 minutes
with a fade transition. A thin progress bar at the bottom shows when the
next poem is coming.

---

## Option A — Serve it from Flask (recommended)

Drop `zen_kiosk.html` into `~/poetry_display/templates/zen.html`
and add this route to `app.py`:

```python
@app.route('/zen')
def zen():
    """Kiosk display page for the Pi 3B."""
    return render_template('zen.html')
```

Then the Pi just opens `http://192.168.0.22:5000/zen`
(the `/api/random` call is relative, so it works automatically).

---

## Option B — Standalone file

Edit the `POETRY_URL` line in the HTML to the full address:

```javascript
const POETRY_URL = 'http://192.168.0.22:5000/api/random';
```

Then copy the file to the Pi and open it directly in Chromium.

---

## Kiosk mode on the Pi 3B

### Install Chromium (if not present)
```bash
sudo apt install chromium-browser
```

### Launch in kiosk mode (run manually first to test)
```bash
chromium-browser \
  --kiosk \
  --noerrdialogs \
  --disable-infobars \
  --disable-session-crashed-bubble \
  --no-first-run \
  http://192.168.0.22:5000/zen
```

### Auto-launch on boot with a systemd service
Create `/etc/systemd/system/poetry-kiosk.service`:

```ini
[Unit]
Description=Poetry Kiosk Display
After=network.target graphical.target

[Service]
User=pi
Environment=DISPLAY=:0
Environment=XAUTHORITY=/home/pi/.Xauthority
ExecStartPre=/bin/sleep 5
ExecStart=/usr/bin/chromium-browser \
  --kiosk \
  --noerrdialogs \
  --disable-infobars \
  --disable-session-crashed-bubble \
  --no-first-run \
  http://192.168.0.22:5000/zen
Restart=on-failure
RestartSec=10

[Install]
WantedBy=graphical.target
```

Then enable it:
```bash
sudo systemctl daemon-reload
sudo systemctl enable poetry-kiosk
sudo systemctl start poetry-kiosk
```

### Disable screen blanking (so it never sleeps)
Add to `/etc/xdg/lxsession/LXDE-pi/autostart`:
```
@xset s off
@xset -dpms
@xset s noblank
```

Or add to the service before Chromium starts:
```ini
ExecStartPre=/usr/bin/xset s off
ExecStartPre=/usr/bin/xset -dpms
```

---

## Adjustments

| What                  | Where in zen_kiosk.html          |
|-----------------------|----------------------------------|
| Change refresh time   | `const REFRESH_MS = 5 * 60 * 1000` (ms) |
| Point to different IP | `const POETRY_URL = '...'`       |
| Font size             | `font-size: clamp(...)` on `#poem-text` |
| Background colour     | `--bg` CSS variable              |

---

## Waveshare 4" / 4.3" framebuffer setup

The Waveshare hat uses SPI and creates `/dev/fb1`.

### Easiest: use Waveshare's LCD-show script
```bash
git clone https://github.com/waveshare/LCD-show.git
cd LCD-show
chmod +x LCD4-show        # or LCD43-show for the 4.3"
sudo ./LCD4-show 0        # 0 = no rotation
```
This edits `/boot/config.txt` and `/etc/X11/xorg.conf` automatically.

### Manual `/boot/config.txt` additions (if needed)
```
dtparam=spi=on
dtoverlay=waveshare-4inch-rpi-lcd-waveshare,speed=80000000,rotate=0
```

### Verify
```bash
ls /dev/fb*   # should show /dev/fb0 and /dev/fb1
```

---

## Kiosk mode launch

```bash
DISPLAY=:0 chromium-browser \
  --kiosk \
  --noerrdialogs \
  --disable-infobars \
  --disable-session-crashed-bubble \
  --no-first-run \
  --window-size=800,480 \
  --window-position=0,0 \
  http://192.168.0.22:5000/zen
```

---

## Autostart service

Create `/etc/systemd/system/poetry-kiosk.service`:

```ini
[Unit]
Description=Poetry Zen Kiosk
After=network.target graphical.target

[Service]
User=pi
Environment=DISPLAY=:0
Environment=XAUTHORITY=/home/pi/.Xauthority
ExecStartPre=/bin/sleep 8
ExecStartPre=/usr/bin/xset s off
ExecStartPre=/usr/bin/xset -dpms
ExecStartPre=/usr/bin/xset s noblank
ExecStart=/usr/bin/chromium-browser \
  --kiosk \
  --noerrdialogs \
  --disable-infobars \
  --no-first-run \
  --window-size=800,480 \
  --window-position=0,0 \
  http://192.168.0.22:5000/zen
Restart=on-failure
RestartSec=10

[Install]
WantedBy=graphical.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable poetry-kiosk
sudo systemctl start poetry-kiosk
```

---

## Adjustments

| What               | Where in zen.html                     |
|--------------------|---------------------------------------|
| Refresh interval   | `const REFRESH_MS = 5 * 60 * 1000`   |
| Font size          | `#poem-text { font-size: 1.0rem; }`  |
| Background colour  | `--bg: #f5f0e8;` CSS variable         |
| Server address     | `const POETRY_URL = '/api/random';`  |

---

## Troubleshooting

**Black screen after boot** → increase `ExecStartPre=/bin/sleep` to 12–15s  
**Poem not loading** → `curl http://localhost:5000/api/random` on the Pi  
**Screen blanks** → add to `/etc/xdg/lxsession/LXDE-pi/autostart`:
```
@xset s off
@xset -dpms
@xset s noblank
```
