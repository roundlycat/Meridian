#!/usr/bin/env python3
"""
Poetry Display Manager for Inky Impression 7.3"
===============================================
This script runs on your Raspberry Pi and fetches poems from the Flask app
to display on the Inky Impression 7.3" e-ink screen.

Enhanced for 7-color ePaper display with beautiful color-coded layout.

How it works:
1. Fetches a random poem from the Flask API
2. Formats the text with colors for the large e-ink display
3. Updates the Inky Impression with the new poem

This script should be run periodically (e.g., via systemd timer).
"""

import requests
import textwrap
from inky.inky_impression import Inky
from PIL import Image, ImageDraw, ImageFont
import time

# ============================================================================
# CONFIGURATION
# ============================================================================

# URL of your Flask app
# If running Flask on the same Pi: use 'localhost'
# If running Flask on another machine: use that machine's IP address
FLASK_API_URL = "http://localhost:5000/api/random"

# Display settings for Inky Impression 7.3" (800x480 pixels)
TITLE_FONT_SIZE = 32      # Large, bold title
AUTHOR_FONT_SIZE = 24     # Medium author name
POEM_FONT_SIZE = 20       # Readable poem text
WRAP_WIDTH = 70           # Characters per line (plenty of room!)

# Color scheme - customize these to your preference!
TITLE_COLOR = "ORANGE"    # Title color (BLACK, RED, ORANGE, YELLOW, GREEN, BLUE)
AUTHOR_COLOR = "BLUE"     # Author color
POEM_COLOR = "BLACK"      # Main poem text color
ACCENT_COLOR = "RED"      # For decorative elements


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
    Format the poem text to fit nicely on the large e-ink display.
    
    This function:
    1. Wraps long lines to fit the display width
    2. Preserves intentional line breaks in the poem
    3. Returns formatted text ready for display
    
    Args:
        poem (dict): Dictionary with 'title', 'author', and 'text' keys
    
    Returns:
        tuple: (title, author, formatted_poem_text)
    """
    title = poem['title']
    author = f"by {poem['author']}"
    
    # Format the poem text
    # Handle each line of the poem separately to preserve intentional line breaks
    poem_text = poem['text']
    formatted_lines = []
    
    for line in poem_text.split('\n'):
        if line.strip():  # If line is not empty
            # Wrap this line if it's too long
            wrapped = textwrap.fill(line, width=WRAP_WIDTH)
            formatted_lines.append(wrapped)
        else:
            # Preserve empty lines (stanza breaks)
            formatted_lines.append("")
    
    formatted_poem = "\n".join(formatted_lines)
    
    return title, author, formatted_poem


def get_color_value(inky_display, color_name):
    """
    Convert color name string to Inky display color constant.
    
    Args:
        inky_display: The Inky display object
        color_name (str): Color name (e.g., "RED", "ORANGE", "BLACK")
    
    Returns:
        int: Color constant from the Inky display
    """
    color_map = {
        "BLACK": inky_display.BLACK,
        "WHITE": inky_display.WHITE,
        "RED": inky_display.RED,
        "ORANGE": inky_display.ORANGE,
        "YELLOW": inky_display.YELLOW,
        "GREEN": inky_display.GREEN,
        "BLUE": inky_display.BLUE
    }
    return color_map.get(color_name.upper(), inky_display.BLACK)


def display_poem(title, author, poem_text):
    """
    Display the formatted poem on the Inky Impression 7.3".
    
    This creates a beautiful color-coded layout with:
    - Colored title at the top
    - Colored author name
    - Decorative separator line
    - Main poem text in readable black
    
    Args:
        title (str): The poem title
        author (str): The author name (with "by" prefix)
        poem_text (str): The formatted poem text
    """
    
    # Initialize Inky Impression 7.3"
    # This auto-detects the display model
    try:
        inky_display = Inky()
        print(f"Initialized Inky Impression 7.3\" display")
        print(f"Display size: {inky_display.width}x{inky_display.height}")
    except Exception as e:
        print(f"Error initializing display: {e}")
        raise
    
    # Set white border for clean look
    inky_display.set_border(inky_display.WHITE)
    
    # Get display dimensions
    width = inky_display.width
    height = inky_display.height
    
    # Create a new blank image with white background
    img = Image.new('P', (width, height), get_color_value(inky_display, "WHITE"))
    
    # Create a drawing context
    draw = ImageDraw.Draw(img)
    
    # Load fonts
    try:
        title_font = ImageFont.truetype(
            "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 
            TITLE_FONT_SIZE
        )
        author_font = ImageFont.truetype(
            "/usr/share/fonts/truetype/dejavu/DejaVuSans-Oblique.ttf", 
            AUTHOR_FONT_SIZE
        )
        poem_font = ImageFont.truetype(
            "/usr/share/fonts/truetype/dejavu/DejaVuSerif.ttf", 
            POEM_FONT_SIZE
        )
    except:
        # If TrueType fonts not found, use default
        print("Warning: Using default fonts. Install dejavu fonts for better display.")
        title_font = ImageFont.load_default()
        author_font = ImageFont.load_default()
        poem_font = ImageFont.load_default()
    
    # Layout configuration
    margin = 30  # Margins from edges
    y_position = margin
    
    # Draw title (colored, bold)
    draw.text(
        (margin, y_position),
        title,
        font=title_font,
        fill=get_color_value(inky_display, TITLE_COLOR)
    )
    y_position += TITLE_FONT_SIZE + 10
    
    # Draw author (colored, italic)
    draw.text(
        (margin, y_position),
        author,
        font=author_font,
        fill=get_color_value(inky_display, AUTHOR_COLOR)
    )
    y_position += AUTHOR_FONT_SIZE + 15
    
    # Draw decorative separator line
    line_width = 400
    draw.line(
        (margin, y_position, margin + line_width, y_position),
        fill=get_color_value(inky_display, ACCENT_COLOR),
        width=2
    )
    y_position += 20
    
    # Draw poem text (black for readability)
    # Handle multiline text properly
    for line in poem_text.split('\n'):
        if y_position + POEM_FONT_SIZE > height - margin:
            # Stop if we run out of space
            draw.text(
                (margin, y_position),
                "...",
                font=poem_font,
                fill=get_color_value(inky_display, POEM_COLOR)
            )
            break
        
        draw.text(
            (margin, y_position),
            line,
            font=poem_font,
            fill=get_color_value(inky_display, POEM_COLOR)
        )
        y_position += POEM_FONT_SIZE + 5
    
    # Set the image on the display
    inky_display.set_image(img)
    
    # Update the e-ink display
    # 7-color displays take longer to refresh (10-20 seconds)
    print("Updating display (this takes ~15 seconds for 7-color)...")
    inky_display.show()
    print("Display updated!")


# ============================================================================
# MAIN EXECUTION
# ============================================================================

def main():
    """
    Main function that orchestrates the poem display process.
    
    This is what runs when you execute: python3 display_manager.py
    """
    print("=" * 60)
    print("Poetry Display Manager - Inky Impression 7.3\"")
    print("=" * 60)
    
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
    
    # Step 2: Format the poem for the large display
    print("\n2. Formatting poem for 7.3\" display...")
    title, author, formatted_text = format_poem_for_display(poem)
    
    print(f"\nTitle: {title}")
    print(f"Author: {author}")
    print(f"\nFormatted poem preview:")
    print(formatted_text[:200] + "..." if len(formatted_text) > 200 else formatted_text)
    
    # Step 3: Display on Inky Impression
    print("\n3. Updating 7.3\" Inky Impression display...")
    print(f"Colors: Title={TITLE_COLOR}, Author={AUTHOR_COLOR}, Text={POEM_COLOR}")
    display_poem(title, author, formatted_text)
    
    print("\n" + "=" * 60)
    print("Done! Check your Inky Impression 7.3\" display.")
    print("=" * 60)


if __name__ == "__main__":
    """
    This block runs when you execute the script directly.
    It won't run if this file is imported as a module.
    """
    main()
