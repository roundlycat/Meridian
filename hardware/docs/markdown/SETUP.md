# Parts Catalogue — Setup

## 1. Dependencies

```bash
pip3 install watchdog pillow pytesseract psycopg2-binary sentence-transformers --break-system-packages
sudo apt install tesseract-ocr samba
```

## 2. Database

Edit DB_DSN in parts_watchdog.py and parts_query.py to match your actual
database name, user, and password, then:

```bash
psql -U sean -d sensor_ecology -f parts_catalogue_schema.sql
```

## 3. Samba share

Add to /etc/samba/smb.conf:

```ini
[parts-intake]
path = /home/sean/parts-intake
browseable = yes
writable = yes
guest ok = yes
create mask = 0664
```

Then:
```bash
mkdir -p /home/sean/parts-intake /home/sean/parts-archive
sudo systemctl restart smbd
```

Connect from iOS Files app:
  Settings → ... → Connect to Server → smb://192.168.0.28

## 4. Watchdog script

Copy parts_watchdog.py to /home/sean/parts_watchdog.py

```bash
sudo cp parts_watchdog.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable parts_watchdog
sudo systemctl start parts_watchdog
sudo systemctl status parts_watchdog
```

Logs:
```bash
journalctl -u parts_watchdog -f
# or
tail -f /var/log/parts_watchdog.log
```

## 5. Workflow

iPhone/tablet: Save scan image → Files app → parts-intake share
Inferno watchdog picks it up automatically, OCRs, embeds, inserts, archives.

## 6. Query

```bash
python3 parts_query.py "IR sensor comparator"
python3 parts_query.py "temperature humidity I2C"
python3 parts_query.py --list
```

## Notes

- TEXT_PANEL_RATIO in parts_watchdog.py controls where the crop happens.
  0.62 means "crop from 62% down". Adjust if OCR misses text.
- The embedder loads once at service start, so ingestion is fast after warmup.
- Already-processed filenames are skipped (idempotent), so you can safely
  re-drop an image without creating duplicates.
