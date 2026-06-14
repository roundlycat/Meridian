import sqlite3, json
conn = sqlite3.connect("meridian_ecology.db")
cur = conn.cursor()

cur.execute("""
    SELECT timestamp,
           json_extract(payload, '$.soil_moisture_vwc') as vwc,
           json_extract(payload, '$.ambient_temp') as temp
    FROM telemetry_events
    WHERE slug = 'b1-bed-north'
    ORDER BY timestamp DESC LIMIT 20
""")
for row in cur.fetchall():
    print(row)
