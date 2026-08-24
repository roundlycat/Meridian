#!/usr/bin/env python3
"""
Sensor Ecology — Parts Catalogue Ingestion Watchdog
====================================================
Watches /home/sean/parts-intake for new images dropped via the Samba share.
For each new image:
  1. Crops the bottom text panel (consistent layout from the AR scan app)
  2. Runs Tesseract OCR on the cropped panel
  3. Parses the three structured sections
  4. Generates a BAAI/bge-large-en-v1.5 embedding
  5. Inserts into the parts_catalogue table in pgvector

Usage:
    python3 parts_watchdog.py

Run as a systemd service — see parts_watchdog.service
"""

import os
import re
import sys
import time
import logging
import hashlib
from pathlib import Path

import psycopg2
import pytesseract
from PIL import Image
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler
from sentence_transformers import SentenceTransformer

# ── Config ────────────────────────────────────────────────────────────────────

INTAKE_DIR   = Path("/home/sean/parts-intake")
ARCHIVE_DIR  = Path("/home/sean/parts-archive")   # processed images move here

DB_DSN = (
    "host=localhost "
    "dbname=sensor_ecology "   # change to your actual db name
    "user=sean "               # change to your db user
    "password= ecology"               # add password if needed
)

EMBED_MODEL  = "BAAI/bge-large-en-v1.5"
IMAGE_EXTS   = {".jpg", ".jpeg", ".png", ".webp"}

# The scan app puts the text panel in the bottom ~38% of the image.
# Tweak this ratio if layout changes.
TEXT_PANEL_RATIO = 0.62

# ── Logging ───────────────────────────────────────────────────────────────────

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler("/var/log/parts_watchdog.log"),
    ]
)
log = logging.getLogger(__name__)

# ── Model (loaded once at startup) ───────────────────────────────────────────

log.info(f"Loading embedding model: {EMBED_MODEL}")
embedder = SentenceTransformer(EMBED_MODEL)
log.info("Model ready")


# ── OCR + parsing ─────────────────────────────────────────────────────────────

def crop_text_panel(image_path: Path) -> Image.Image:
    """Crop the bottom portion of the image where the dark text panel lives."""
    img = Image.open(image_path).convert("RGB")
    w, h = img.size
    top = int(h * TEXT_PANEL_RATIO)
    return img.crop((0, top, w, h))


def ocr_panel(panel: Image.Image) -> str:
    """Run Tesseract on the cropped panel. Dark background needs inversion."""
    # Invert for Tesseract — white text on dark bg → black text on white bg
    import PIL.ImageOps
    inverted = PIL.ImageOps.invert(panel)
    text = pytesseract.image_to_string(inverted, config="--psm 6")
    return text.strip()


def parse_sections(ocr_text: str) -> dict:
    """
    Parse the three numbered sections from the scan app output.
    Returns dict with keys: ocr_results, component_model, summary
    Falls back to empty strings if a section is missing.
    """
    sections = {"ocr_results": "", "component_model": "", "summary": ""}

    # Split on section headers — handles "1. OCR Results:", "1) OCR Output:", etc.
    pattern = re.split(
        r'\n?\s*[1-3][.)]\s*(?:OCR(?:\s+Results?|\s+Output)?|Component[/ ](?:Chip\s+)?Models?|Summary)\s*:?\s*\n',
        ocr_text,
        flags=re.IGNORECASE
    )

    # pattern[0] is text before section 1 (usually empty), then sections follow
    parts = [p.strip() for p in pattern if p.strip()]

    if len(parts) >= 1:
        sections["ocr_results"]    = parts[0]
    if len(parts) >= 2:
        sections["component_model"] = parts[1]
    if len(parts) >= 3:
        sections["summary"]        = parts[2]

    return sections


def make_embed_text(sections: dict, filename: str) -> str:
    """Combine the most semantically rich fields for embedding."""
    parts = []
    if sections["component_model"]:
        parts.append(sections["component_model"])
    if sections["summary"]:
        parts.append(sections["summary"])
    if not parts:
        # Fall back to raw OCR if parsing failed
        parts.append(filename)
    return " ".join(parts)


# ── Database ──────────────────────────────────────────────────────────────────

def get_conn():
    return psycopg2.connect(DB_DSN)


def already_ingested(conn, filename: str) -> bool:
    with conn.cursor() as cur:
        cur.execute(
            "SELECT 1 FROM parts_catalogue WHERE image_filename = %s",
            (filename,)
        )
        return cur.fetchone() is not None


def insert_part(conn, image_path: Path, ocr_raw: str, sections: dict, embedding: list):
    with conn.cursor() as cur:
        cur.execute(
            """
            INSERT INTO parts_catalogue
                (image_path, image_filename, ocr_raw,
                 ocr_results, component_model, summary, embedding)
            VALUES (%s, %s, %s, %s, %s, %s, %s)
            ON CONFLICT (image_filename) DO NOTHING
            """,
            (
                str(image_path),
                image_path.name,
                ocr_raw,
                sections["ocr_results"],
                sections["component_model"],
                sections["summary"],
                embedding,
            )
        )
    conn.commit()


# ── Core processing ───────────────────────────────────────────────────────────

def process_image(image_path: Path):
    log.info(f"Processing: {image_path.name}")

    conn = get_conn()
    try:
        if already_ingested(conn, image_path.name):
            log.info(f"  Already in catalogue, skipping: {image_path.name}")
            return

        # OCR
        panel    = crop_text_panel(image_path)
        ocr_raw  = ocr_panel(panel)
        log.info(f"  OCR complete ({len(ocr_raw)} chars)")

        # Parse
        sections = parse_sections(ocr_raw)
        log.info(f"  Component: {sections['component_model'][:80] if sections['component_model'] else 'unparsed'}")

        # Embed
        embed_text = make_embed_text(sections, image_path.name)
        embedding  = embedder.encode(embed_text, normalize_embeddings=True).tolist()

        # Insert
        insert_part(conn, image_path, ocr_raw, sections, embedding)
        log.info(f"  Inserted into parts_catalogue ✓")

        # Archive
        ARCHIVE_DIR.mkdir(parents=True, exist_ok=True)
        dest = ARCHIVE_DIR / image_path.name
        image_path.rename(dest)
        log.info(f"  Archived to {dest}")

    except Exception as e:
        log.error(f"  Failed to process {image_path.name}: {e}", exc_info=True)
    finally:
        conn.close()


# ── Watchdog handler ──────────────────────────────────────────────────────────

class IntakeHandler(FileSystemEventHandler):
    def on_created(self, event):
        if event.is_directory:
            return
        path = Path(event.src_path)
        if path.suffix.lower() not in IMAGE_EXTS:
            return
        # Small delay — let the file finish copying before we read it
        time.sleep(1.5)
        process_image(path)

    def on_moved(self, event):
        # Handles iOS Files app which sometimes moves files into the share
        if event.is_directory:
            return
        path = Path(event.dest_path)
        if path.suffix.lower() not in IMAGE_EXTS:
            return
        time.sleep(1.5)
        process_image(path)


# ── Startup: process anything already waiting in intake ──────────────────────

def process_existing():
    existing = [p for p in INTAKE_DIR.iterdir()
                if p.is_file() and p.suffix.lower() in IMAGE_EXTS]
    if existing:
        log.info(f"Found {len(existing)} existing image(s) in intake — processing")
        for p in sorted(existing):
            process_image(p)


# ── Main ──────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    INTAKE_DIR.mkdir(parents=True, exist_ok=True)
    log.info(f"Parts Catalogue Watchdog starting")
    log.info(f"Watching: {INTAKE_DIR}")

    process_existing()

    observer = Observer()
    observer.schedule(IntakeHandler(), str(INTAKE_DIR), recursive=False)
    observer.start()
    log.info("Observer running — waiting for images")

    try:
        while True:
            time.sleep(5)
    except KeyboardInterrupt:
        observer.stop()
    observer.join()
    log.info("Watchdog stopped")
