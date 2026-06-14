import sqlite3, json

conn = sqlite3.connect("meridian_ecology.db")
cur = conn.cursor()

# Readings per node
cur.execute("""
    SELECT slug, COUNT(*) as readings,
           MIN(timestamp) as first,
           MAX(timestamp) as last
    FROM telemetry_events
    GROUP BY slug
    ORDER BY slug
""")
print("=== Node summary ===")
for row in cur.fetchall():
    print(row)

# One sample payload per node
print("\n=== Sample payloads ===")
cur.execute("""
    SELECT slug, payload FROM telemetry_events
    WHERE id IN (SELECT MAX(id) FROM telemetry_events GROUP BY slug)
    ORDER BY slug
""")
for slug, payload in cur.fetchall():
    print(f"\n{slug}:")
    print(json.dumps(json.loads(payload), indent=2))

conn.close()
