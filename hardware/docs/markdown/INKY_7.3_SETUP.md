# Inky Impression 7.3" Setup Guide

## What's Different from the InkyPHAT

**Size:** 800x480 pixels (vs 212x104) - **16x bigger!**  
**Colors:** 7 colors (Black, White, Red, Orange, Yellow, Green, Blue)  
**Refresh:** ~15 seconds (vs ~5 seconds) - more colors take longer  
**Detail:** Much sharper, can show longer poems, bigger fonts  

## Installation

### 1. Replace display_manager.py

```bash
cd ~/poem

# Backup your current version
cp display_manager.py display_manager_old.py

# Copy the new 7.3" version
# (Get display_manager_7.3.py from this conversation and save it as display_manager.py)
```

### 2. Test It

```bash
# Make sure Flask is running and you have poems
curl http://localhost:5000/api/count

# Test the new display
python3 display_manager.py
```

You should see:
```
Fetching poem from server...
Formatting poem for 7.3" display...
Title: [poem title]
Author: by [author]
Updating 7.3" Inky Impression display...
Colors: Title=ORANGE, Author=BLUE, Text=BLACK
Updating display (this takes ~15 seconds for 7-color)...
Display updated!
```

**Wait 15-20 seconds** for the display to refresh. You'll see:
- **Orange title** at the top
- **Blue author** name below it
- **Red separator line**
- **Black poem text** (most readable)
- Beautiful color-coded layout!

## Customizing Colors

Edit the configuration section in `display_manager.py`:

```python
# Color scheme - customize these to your preference!
TITLE_COLOR = "ORANGE"    # Try: BLACK, RED, ORANGE, YELLOW, GREEN, BLUE
AUTHOR_COLOR = "BLUE"     # Try: BLACK, RED, ORANGE, YELLOW, GREEN, BLUE
POEM_COLOR = "BLACK"      # Keep BLACK for best readability
ACCENT_COLOR = "RED"      # Decorative line color
```

**Color Suggestions:**

**Classic & Readable:**
```python
TITLE_COLOR = "BLACK"
AUTHOR_COLOR = "BLACK"
POEM_COLOR = "BLACK"
ACCENT_COLOR = "RED"
```

**Warm & Inviting:**
```python
TITLE_COLOR = "ORANGE"
AUTHOR_COLOR = "RED"
POEM_COLOR = "BLACK"
ACCENT_COLOR = "YELLOW"
```

**Nature Themed:**
```python
TITLE_COLOR = "GREEN"
AUTHOR_COLOR = "BLUE"
POEM_COLOR = "BLACK"
ACCENT_COLOR = "YELLOW"
```

**Bold & Dramatic:**
```python
TITLE_COLOR = "RED"
AUTHOR_COLOR = "ORANGE"
POEM_COLOR = "BLACK"
ACCENT_COLOR = "BLUE"
```

## Adjusting Font Sizes

If text is too big/small, edit these:

```python
TITLE_FONT_SIZE = 32      # Title size (try 28-40)
AUTHOR_FONT_SIZE = 24     # Author size (try 20-28)
POEM_FONT_SIZE = 20       # Poem text size (try 16-24)
WRAP_WIDTH = 70           # Characters per line (try 60-80)
```

**For longer poems:** Use smaller font and more wrap width  
**For short poems:** Use larger font for dramatic effect  

## Physical Setup

**Mounting the 7.3" Display:**
- Much heavier than the pHAT
- Needs proper case or stand
- Consider a picture frame mount
- Or a wooden stand/easel

**Power:**
- 7.3" uses more power than pHAT
- Use official Raspberry Pi power supply (5V 3A recommended)
- Consider UPS if using battery backup

## Systemd Service (Auto-Updates)

The existing systemd service will work automatically with the new display_manager.py:

```bash
# Restart the service to use new code
sudo systemctl restart poetry-display.service

# Check it worked
journalctl -u poetry-display.service -n 30
```

**Update frequency recommendations:**
- **Every 2 hours** - Good balance (battery friendly)
- **Every hour** - More variety
- **Every 30 minutes** - Maximum variety (uses more power)

```bash
# To change frequency:
sudo nano /etc/systemd/system/poetry-display.timer

# Change: OnCalendar=hourly
# To: OnCalendar=0/2:00  (every 2 hours)

# Then:
sudo systemctl daemon-reload
sudo systemctl restart poetry-display.timer
```

## Troubleshooting

### Display shows only black/white (no colors)

**Problem:** Wrong display type detected  

**Fix:** The code uses `Inky()` which auto-detects. If it fails:
```python
# Try explicit initialization:
inky_display = Inky(resolution=(800, 480))
```

### Text is cut off

**Problem:** Poem too long for display  

**Solutions:**
1. Use smaller font: `POEM_FONT_SIZE = 16`
2. Increase wrap: `WRAP_WIDTH = 80`
3. Keep poems shorter (edit in web interface)

### Colors look washed out

**Problem:** E-ink color is naturally muted  

**This is normal!** E-ink colors are pastel/muted compared to screens. For maximum contrast:
- Use BLACK for main text
- Save colors for titles/accents
- Avoid light colors (YELLOW) for small text

### Display takes forever to update

**Problem:** 7-color displays are slower  

**This is normal!** 7-color e-ink takes 15-20 seconds to refresh. If it's taking longer:
- Check power supply (needs good 5V 3A)
- Verify connections are secure
- Try rebooting the Pi

### GPIO busy error

**Fix:**
```bash
sudo systemctl stop poetry-display.timer
sudo systemctl stop poetry-display.service

sudo python3 << 'EOF'
import RPi.GPIO as GPIO
GPIO.setmode(GPIO.BCM)
GPIO.cleanup()
EOF

python3 display_manager.py
```

## Performance Notes

**7.3" Inky Impression:**
- Refresh time: ~15-20 seconds (7 colors)
- Power draw: Higher than pHAT
- Resolution: 800x480 (beautiful!)
- Viewable from across the room

**Battery Life:**
- Hourly updates: ~2-3 days on typical battery
- Every 2 hours: ~5-7 days
- E-ink only uses power during refresh
- Flask app uses continuous power

## Advanced: Using Different Fonts

The display uses DejaVu fonts by default. To try others:

```bash
# List available fonts
fc-list | grep ttf

# Install more fonts
sudo apt install fonts-liberation fonts-noto
```

Then in the code:
```python
title_font = ImageFont.truetype(
    "/usr/share/fonts/truetype/liberation/LiberationSerif-Bold.ttf",
    TITLE_FONT_SIZE
)
```

## Color Reference

Available colors on Inky Impression 7.3":

| Color | Use Case | Notes |
|-------|----------|-------|
| **BLACK** | Main text | Most readable, always use for body text |
| **WHITE** | Background | Default background color |
| **RED** | Titles, accents | Bold, attention-grabbing |
| **ORANGE** | Titles, warnings | Warm, friendly |
| **YELLOW** | Highlights | Light, use for accents only |
| **GREEN** | Positive items | Natural, calming |
| **BLUE** | Metadata, links | Cool, professional |

## Next Steps

1. **Test with different poems** - see how various lengths look
2. **Experiment with colors** - find your favorite scheme
3. **Adjust fonts** - optimize for your viewing distance
4. **Set update frequency** - balance variety vs battery life
5. **Build a nice case** - protect and display your creation!

## Web Interface Still Works!

The Flask web interface at **http://192.168.0.23:5000** still works exactly the same:
- Add/edit/delete poems
- View collection
- All the same features

The only difference is the display looks WAY better now! 🎨

---

Enjoy your beautiful 7.3" poetry display! The larger screen and colors make it a real showpiece. 📖✨
