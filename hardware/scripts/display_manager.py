#!/usr/bin/env python3
"""
Poetry Display Manager for InkyPHAT
====================================
This script runs on your Raspberry Pi and fetches poems from the Flask app
to display on the InkyPHAT e-ink screen.

How it works:
1. Fetches a random poem from the Flask API
2. Formats the text for the e-ink display
3. Updates the InkyPHAT with the new poem

This script should be run periodically (e.g., via cron or systemd timer).
"""

import requests
import textwrap
from inky import InkyPHAT
from PIL import Image, ImageDraw, ImageFont
import time

# ============================================================================
# CONFIGURATION
# ============================================================================

# DISPLAY TYPE - Set this to match your InkyPHAT model
# Options: "red" (red/black/white), "black" (black/white), "yellow" (yellow/black/white)
# 
# If you have a tri-color display with red or yellow, use "red" or "yellow"
# If you have a two-color black and white display, use "black"
#
# How to tell which you have:
# - Look at the display - if it shows red or yellow colors, use "red" or "yellow"
# - If it's only black and white, use "black"
# - Most common is "red" (the red/black/white model)
DISPLAY_TYPE = "red"  # Change this if needed!

# URL of your Flask app
# If running Flask on the same Pi: use 'localhost'
# If running Flask on another machine: use that machine's IP address
FLASK_API_URL = "http://localhost:5000/api/random"

# Display settings
# The InkyPHAT is 212x104 pixels (for the older model)
# or 250x122 pixels (for the newer pHAT model)
# The display type is manually configured above (DISPLAY_TYPE variable)
FONT_SIZE = 12  # Adjust this based on your preference and poem length

# Text wrapping width (characters per line)
# You'll need to adjust this based on font size and display width
WRAP_WIDTH = 30


# ============================================================================
# DISPLAY FUNCTIONS
# ============================================================================

def fetch_poem():
    """
    Fetch a random poem from the Flask API.
    
    Returns:
        dict: A dictionary containing poem data (title, author, text)
        None: If the request fails
    
    This function uses the 'requests' library to make an HTTP GET request.
    It's like typing the URL into a browser, but in Python.
    """
    try:
        # Make GET request to the Flask API
        # timeout=10 means give up after 10 seconds if no response
        response = requests.get(FLASK_API_URL, timeout=10)
        
        # Check if request was successful
        # HTTP status codes: 200 = OK, 404 = Not Found, 500 = Server Error
        response.raise_for_status()
        
        # Parse the JSON response into a Python dictionary
        poem = response.json()
        
        print(f"Fetched poem: {poem['title']} by {poem['author']}")
        return poem
        
    except requests.exceptions.RequestException as e:
        # Handle any network errors
        print(f"Error fetching poem: {e}")
        return None


def format_poem_for_display(poem):
    """
    Format the poem text to fit nicely on the e-ink display.
    
    This function:
    1. Wraps long lines to fit the display width
    2. Adds the title and author
    3. Returns a formatted string ready for display
    
    Args:
        poem (dict): Dictionary with 'title', 'author', and 'text' keys
    
    Returns:
        str: Formatted text ready for display
    """
    # Start with title and author
    formatted = f"{poem['title']}\n"
    formatted += f"by {poem['author']}\n"
    formatted += "-" * WRAP_WIDTH + "\n"  # Separator line
    
    # Wrap the poem text
    # textwrap.fill() breaks long lines into multiple lines
    poem_text = poem['text']
    
    # Handle each line of the poem separately to preserve intentional line breaks
    lines = poem_text.split('\n')
    for line in lines:
        if line.strip():  # If line is not empty
            # Wrap this line if it's too long
            wrapped = textwrap.fill(line, width=WRAP_WIDTH)
            formatted += wrapped + "\n"
        else:
            # Preserve empty lines (stanza breaks)
            formatted += "\n"
    
    return formatted


def display_poem(text):
    """
    Display the formatted poem text on the InkyPHAT.
    
    This is where the magic happens! We:
    1. Create a blank image
    2. Draw the text onto the image
    3. Send the image to the e-ink display
    
    Args:
        text (str): The formatted poem text to display
    """
    
    # Initialize InkyPHAT with manually specified type
    # This bypasses the EEPROM auto-detection which can fail
    # The display type is set in the DISPLAY_TYPE configuration variable at the top
    try:
        inky_display = InkyPHAT(DISPLAY_TYPE)
        print(f"Initialized InkyPHAT display (type: {DISPLAY_TYPE})")
    except Exception as e:
        print(f"Error initializing display: {e}")
        print(f"Make sure DISPLAY_TYPE='{DISPLAY_TYPE}' is correct for your display")
        print("Valid options: 'red' (red/black/white), 'black' (black/white), 'yellow' (yellow/black/white)")
        raise
    
    # Set border color (optional - makes it look nicer)
    # Use white border for clean look
    inky_display.set_border(inky_display.WHITE)
    
    # Get display dimensions
    width = inky_display.width
    height = inky_display.height
    
    print(f"Display size: {width}x{height}")
    
    # Create a new blank image
    # 'P' mode means 8-bit pixels (palette mode) - good for e-ink
    # We fill it with white (255)
    img = Image.new('P', (width, height), 255)
    
    # Create a drawing context
    # This lets us draw text and shapes on the image
    draw = ImageDraw.Draw(img)
    
    # Load a font
    # Try to use a nice TrueType font, fall back to default if not available
    try:
        # DejaVuSansMono is a monospace font usually available on Raspberry Pi
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf", FONT_SIZE)
    except:
        # If TrueType font not found, use default bitmap font
        font = ImageFont.load_default()
        print("Warning: Using default font. Install fonts-dejavu for better display.")
    
    # Draw the text on the image
    # Position (5, 5) gives us a small margin from the edges
    # fill=0 means black text (0 is black in our palette)
    draw.text(
        (5, 5),           # Position (x, y)
        text,             # The text to draw
        font=font,        # Font to use
        fill=0            # Color (0 = black)
    )
    
    # Set the image on the display
    # This prepares the display but doesn't update it yet
    inky_display.set_image(img)
    
    # Actually update the e-ink display
    # This is when the physical display changes
    # E-ink displays take a few seconds to refresh
    print("Updating display...")
    inky_display.show()
    print("Display updated!")


# ============================================================================
# MAIN EXECUTION
# ============================================================================

def main():
    """
    Main function that orchestrates the poem display process.
    
    This is what runs when you execute: python display_manager.py
    """
    print("=" * 50)
    print("Poetry Display Manager")
    print("=" * 50)
    
    # Step 1: Fetch a poem from the Flask API
    print("\n1. Fetching poem from server...")
    poem = fetch_poem()
    
    if poem is None:
        print("Failed to fetch poem. Is the Flask app running?")
        print(f"Check: {FLASK_API_URL}")
        return
    
    # Check for error response from API
    if 'error' in poem:
        print(f"API returned an error: {poem['error']}")
        # You might still want to display the error message on the screen
    
    # Step 2: Format the poem for display
    print("\n2. Formatting poem for display...")
    formatted_text = format_poem_for_display(poem)
    print("Preview:")
    print(formatted_text)
    
    # Step 3: Display on InkyPHAT
    print("\n3. Updating e-ink display...")
    display_poem(formatted_text)
    
    print("\n" + "=" * 50)
    print("Done! Check your InkyPHAT display.")
    print("=" * 50)


if __name__ == "__main__":
    """
    This block runs when you execute the script directly.
    It won't run if this file is imported as a module.
    """
    main()
