# InkyPHAT EEPROM Fix

## What Was the Problem?

**Error:** EEPROM read failure / auto-detection error

**Cause:** Your InkyPHAT's EEPROM chip (which stores display type information) isn't working or isn't present. The `auto()` function tries to read this chip to automatically detect your display model, but fails.

**Solution:** Manually specify your display type instead of using auto-detection.

## What I Fixed

### Changed in `display_manager.py`:

**Before (line 18):**
```python
from inky.auto import auto
```

**After:**
```python
from inky import InkyPHAT
```

**Before (line 131):**
```python
inky_display = auto()
```

**After:**
```python
inky_display = InkyPHAT(DISPLAY_TYPE)
```

**Added configuration (line 23-31):**
```python
# DISPLAY TYPE - Set this to match your InkyPHAT model
DISPLAY_TYPE = "red"  # Change this if needed!
```

## How to Determine Your Display Type

### Option 1: Look at Your Display
- **Red/Black/White display** → Use `DISPLAY_TYPE = "red"`
- **Black/White only** → Use `DISPLAY_TYPE = "black"`
- **Yellow/Black/White display** → Use `DISPLAY_TYPE = "yellow"`

### Option 2: Check Your Product
- **InkyPHAT Red** (most common) → `"red"`
- **InkyPHAT Black** → `"black"`
- **InkyPHAT Yellow** → `"yellow"`

### Most Common
The **red/black/white** version is the most common InkyPHAT, so `DISPLAY_TYPE = "red"` is the default.

## How to Use the Fixed Version

### Option 1: Replace File on Pi

```bash
# Download the updated display_manager.py from this conversation

# Copy it to your Pi
cd ~/poem
# Replace with the new version

# The default is set to "red" - if you have a different model:
nano display_manager.py
# Change line 31: DISPLAY_TYPE = "red"  to your model type
```

### Option 2: Manual Edit

If you want to fix your existing file:

```bash
cd ~/poem
nano display_manager.py
```

**Change line 18 from:**
```python
from inky.auto import auto
```

**To:**
```python
from inky import InkyPHAT
```

**Add after line 22 (in the CONFIGURATION section):**
```python
# DISPLAY TYPE - Set this to match your InkyPHAT model
# Options: "red" (red/black/white), "black" (black/white), "yellow" (yellow/black/white)
DISPLAY_TYPE = "red"  # Change this if you have a different model!
```

**Change line ~131 from:**
```python
inky_display = auto()
```

**To:**
```python
try:
    inky_display = InkyPHAT(DISPLAY_TYPE)
    print(f"Initialized InkyPHAT display (type: {DISPLAY_TYPE})")
except Exception as e:
    print(f"Error initializing display: {e}")
    print(f"Make sure DISPLAY_TYPE='{DISPLAY_TYPE}' is correct for your display")
    raise

# Set border color
inky_display.set_border(inky_display.WHITE)
```

## Test the Fix

```bash
cd ~/poem

# Test manually
python3 display_manager.py
```

You should see:
```
Initialized InkyPHAT display (type: red)
Display size: 212x104
Fetched poem: [poem title] by [author]
Updating display...
Display updated!
```

## If You Get an Error

### Error: "Unknown colour 'red'"

**Problem:** You specified the wrong display type.

**Solutions:**
- Try `DISPLAY_TYPE = "black"` if you have a black/white display
- Try `DISPLAY_TYPE = "yellow"` if you have a yellow display

### Error: Still getting EEPROM errors

**Problem:** The old code is still being used.

**Solution:**
```bash
# Make sure you saved the file
cd ~/poem
cat display_manager.py | head -n 35
# You should see DISPLAY_TYPE = "red" around line 31

# If not, re-edit and save properly
```

### Error: Display shows garbage or wrong colors

**Problem:** Wrong display type specified.

**Solution:** Change `DISPLAY_TYPE` to match your actual hardware:
```python
# If you have red/black/white: use "red"
# If you have black/white only: use "black"  
# If you have yellow/black/white: use "yellow"
```

## Updating the Systemd Service

The systemd service will automatically use the updated file. No changes needed!

But you can test it:

```bash
# Manually trigger an update
sudo systemctl start poetry-display.service

# Check the logs
journalctl -u poetry-display.service -n 30
```

You should see the "Initialized InkyPHAT display" message in the logs.

## Why This Happened

InkyPHAT displays have a small EEPROM chip that stores:
- Display type (red/black/yellow)
- Display size
- Other configuration

Sometimes:
- The EEPROM chip fails
- It wasn't programmed at the factory
- The connection is poor
- It got corrupted

By manually specifying the display type, we bypass the EEPROM entirely and tell the library exactly what display we have.

## Advantages of Manual Configuration

✅ **More reliable** - doesn't depend on EEPROM  
✅ **Faster startup** - no detection needed  
✅ **More explicit** - you know exactly what's configured  
✅ **Better error messages** - tells you if the type is wrong  

## Additional Display Options

Once you have the basic display working, you can experiment with:

### Using Colors (for tri-color displays)

```python
# For red/black/white displays, you can use:
draw.text((10, 10), "Title", inky_display.RED)   # Red text
draw.text((10, 30), "Body", inky_display.BLACK)  # Black text

# For yellow displays:
draw.text((10, 10), "Title", inky_display.YELLOW)
```

### Border Colors

```python
# White border (clean look)
inky_display.set_border(inky_display.WHITE)

# Black border (frame effect)
inky_display.set_border(inky_display.BLACK)

# Red/Yellow border (for tri-color displays)
inky_display.set_border(inky_display.RED)  # or .YELLOW
```

These are already configured in the updated `display_manager.py` - feel free to experiment!

## Summary

✅ **Problem:** EEPROM auto-detection failing  
✅ **Solution:** Manual display type specification  
✅ **Default:** `DISPLAY_TYPE = "red"` (most common model)  
✅ **To Change:** Edit line 31 in `display_manager.py`  
✅ **Result:** Display works reliably without EEPROM  

Your display should now work perfectly! 🎨✨
