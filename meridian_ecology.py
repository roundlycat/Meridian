#!/usr/bin/env python3
"""
Meridian Ecology Dashboard Generator
Run from your Meridian directory: python generate_dashboard.py
Opens ecology_dashboard.html — self-contained, no server needed.
"""
import sqlite3
import json
from pathlib import Path

DB_NAME   = "meridian_ecology.db"
OUTPUT    = "ecology_dashboard.html"
MAX_PTS   = 120   # points per chart series


# ── Data Extraction ────────────────────────────────────────────────────────────

def fetch_series(conn, slug, field, max_pts=MAX_PTS):
    cur = conn.cursor()
    cur.execute(f"""
        SELECT timestamp,
               CAST(json_extract(payload, '$.{field}') AS REAL)
        FROM telemetry_events
        WHERE slug = ?
          AND json_extract(payload, '$.{field}') IS NOT NULL
        ORDER BY timestamp ASC
    """, (slug,))
    rows = cur.fetchall()
    if not rows:
        return [], []
    step   = max(1, len(rows) // max_pts)
    rows   = rows[::step]
    labels = [r[0][11:19] for r in rows]          # HH:MM:SS
    values = [round(r[1], 2) if r[1] is not None else None for r in rows]
    return labels, values


def fetch_hailo(conn, max_pts=MAX_PTS):
    cur = conn.cursor()
    cur.execute("""
        SELECT timestamp,
               CAST(json_extract(payload, '$.detection_count') AS INTEGER),
               CAST(json_extract(payload, '$.inference_ms')    AS REAL),
               CAST(json_extract(payload, '$.hailo_temp_c')    AS REAL)
        FROM telemetry_events
        WHERE slug = 'c1-hailo-camera'
        ORDER BY timestamp ASC
    """)
    rows = cur.fetchall()
    if not rows:
        return [], [], [], []
    step   = max(1, len(rows) // max_pts)
    rows   = rows[::step]
    labels  = [r[0][11:19] for r in rows]
    counts  = [r[1] or 0  for r in rows]
    ms      = [r[2]        for r in rows]
    temps   = [r[3]        for r in rows]
    return labels, counts, ms, temps


def node_summary(conn):
    cur = conn.cursor()
    cur.execute("""
        SELECT slug, COUNT(*) as n,
               MIN(timestamp) as first,
               MAX(timestamp) as last
        FROM telemetry_events
        GROUP BY slug ORDER BY slug
    """)
    return cur.fetchall()


# ── Build Chart Data ───────────────────────────────────────────────────────────

def build_data(conn):
    sm_lb_n, sm_north  = fetch_series(conn, "b1-bed-north",    "soil_moisture_vwc")
    sm_lb_s, sm_south  = fetch_series(conn, "b2-bed-south",    "soil_moisture_vwc")
    t_lb,    t_sky     = fetch_series(conn, "w-sky-reference", "ambient_temp")
    _,       t_north   = fetch_series(conn, "b1-bed-north",    "ambient_temp")
    _,       t_south   = fetch_series(conn, "b2-bed-south",    "ambient_temp")
    lux_lb,  lux_sky   = fetch_series(conn, "w-sky-reference", "lux")
    _,       lux_north = fetch_series(conn, "b1-bed-north",    "lux")
    _,       lux_south = fetch_series(conn, "b2-bed-south",    "lux")
    p_lb,    pir       = fetch_series(conn, "p-entry-presence","pir_trigger")
    h_lb, h_cnt, h_ms, h_tmp = fetch_hailo(conn)
    summary            = node_summary(conn)

    return {
        "soil": {
            "labels": sm_lb_n,
            "north":  sm_north,
            "labels_s": sm_lb_s,
            "south":  sm_south,
        },
        "temp": {
            "labels": t_lb,
            "sky":    t_sky,
            "north":  t_north,
            "south":  t_south,
        },
        "lux": {
            "labels": lux_lb,
            "sky":    lux_sky,
            "north":  lux_north,
            "south":  lux_south,
        },
        "hailo": {
            "labels":  h_lb,
            "counts":  h_cnt,
            "ms":      h_ms,
            "chip_t":  h_tmp,
        },
        "presence": {
            "labels":  p_lb,
            "pir":     pir,
        },
        "summary": [
            {"slug": r[0], "n": r[1],
             "first": r[2][11:19] if r[2] else "—",
             "last":  r[3][11:19] if r[3] else "—"}
            for r in summary
        ],
    }


# ── HTML Template ──────────────────────────────────────────────────────────────

HTML = r"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Meridian · Ecology Dashboard</title>
<script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js"></script>
<link href="https://fonts.googleapis.com/css2?family=IBM+Plex+Mono:wght@300;400;500&display=swap" rel="stylesheet">
<style>
  *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

  :root {
    --bg:        #0b0e14;
    --surface:   #13181f;
    --border:    #1f2733;
    --sky:       #4d9de0;
    --north:     #3ddc84;
    --south:     #e8a838;
    --central:   #a78bfa;
    --presence:  #f06a6a;
    --hailo:     #67d2e8;
    --muted:     #4a5568;
    --text:      #c8d0dc;
    --dim:       #6b7a8d;
    --font:      'IBM Plex Mono', monospace;
  }

  body {
    background: var(--bg);
    color: var(--text);
    font-family: var(--font);
    font-size: 12px;
    line-height: 1.5;
    padding: 24px;
    min-height: 100vh;
  }

  /* scanline overlay */
  body::before {
    content: '';
    position: fixed; inset: 0;
    background: repeating-linear-gradient(
      0deg,
      transparent,
      transparent 2px,
      rgba(0,0,0,0.04) 2px,
      rgba(0,0,0,0.04) 4px
    );
    pointer-events: none;
    z-index: 999;
  }

  header {
    display: flex;
    align-items: baseline;
    justify-content: space-between;
    margin-bottom: 24px;
    padding-bottom: 12px;
    border-bottom: 1px solid var(--border);
  }

  header h1 {
    font-size: 13px;
    font-weight: 500;
    letter-spacing: 0.12em;
    text-transform: uppercase;
    color: var(--text);
  }

  header .sub {
    font-size: 11px;
    color: var(--dim);
    letter-spacing: 0.06em;
  }

  /* Node status bar */
  .nodes {
    display: flex;
    flex-wrap: wrap;
    gap: 8px;
    margin-bottom: 24px;
  }

  .node-pill {
    display: flex;
    align-items: center;
    gap: 6px;
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: 3px;
    padding: 5px 10px;
    font-size: 10px;
    letter-spacing: 0.04em;
  }

  .node-pill .dot {
    width: 5px; height: 5px;
    border-radius: 50%;
    flex-shrink: 0;
  }

  .node-pill .count { color: var(--dim); margin-left: 4px; }

  /* Chart grid */
  .grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 16px;
  }

  .grid .wide { grid-column: 1 / -1; }

  .panel {
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: 4px;
    padding: 16px;
  }

  .panel-title {
    font-size: 10px;
    letter-spacing: 0.1em;
    text-transform: uppercase;
    color: var(--dim);
    margin-bottom: 14px;
    display: flex;
    justify-content: space-between;
    align-items: center;
  }

  .panel-title .legend {
    display: flex;
    gap: 14px;
    font-size: 10px;
    text-transform: none;
    letter-spacing: 0;
  }

  .legend-item {
    display: flex;
    align-items: center;
    gap: 5px;
    color: var(--dim);
  }

  .legend-swatch {
    width: 16px; height: 2px;
    border-radius: 1px;
  }

  .chart-wrap {
    position: relative;
    height: 180px;
  }

  .chart-wrap.tall { height: 140px; }

  footer {
    margin-top: 20px;
    font-size: 10px;
    color: var(--muted);
    letter-spacing: 0.04em;
    text-align: right;
  }
</style>
</head>
<body>

<header>
  <h1>Meridian · Sensor Ecology</h1>
  <span class="sub" id="gen-time">generated —</span>
</header>

<div class="nodes" id="node-pills"></div>

<div class="grid">

  <div class="panel wide">
    <div class="panel-title">
      soil moisture drift — vwc %
      <div class="legend">
        <div class="legend-item">
          <div class="legend-swatch" style="background:var(--north)"></div>b1-bed-north
        </div>
        <div class="legend-item">
          <div class="legend-swatch" style="background:var(--south)"></div>b2-bed-south
        </div>
      </div>
    </div>
    <div class="chart-wrap"><canvas id="soil"></canvas></div>
  </div>

  <div class="panel">
    <div class="panel-title">
      temperature — °c (diurnal wave)
      <div class="legend">
        <div class="legend-item"><div class="legend-swatch" style="background:var(--sky)"></div>sky</div>
        <div class="legend-item"><div class="legend-swatch" style="background:var(--north)"></div>north</div>
        <div class="legend-item"><div class="legend-swatch" style="background:var(--south)"></div>south</div>
      </div>
    </div>
    <div class="chart-wrap"><canvas id="temp"></canvas></div>
  </div>

  <div class="panel">
    <div class="panel-title">
      light — lux
      <div class="legend">
        <div class="legend-item"><div class="legend-swatch" style="background:var(--sky)"></div>sky ref</div>
        <div class="legend-item"><div class="legend-swatch" style="background:var(--north)"></div>north (shaded)</div>
        <div class="legend-item"><div class="legend-swatch" style="background:var(--south)"></div>south</div>
      </div>
    </div>
    <div class="chart-wrap"><canvas id="lux"></canvas></div>
  </div>

  <div class="panel">
    <div class="panel-title">
      hailo-8l — detections per frame
      <div class="legend">
        <div class="legend-item"><div class="legend-swatch" style="background:var(--hailo)"></div>count</div>
        <div class="legend-item"><div class="legend-swatch" style="background:var(--dim)"></div>infer ms</div>
      </div>
    </div>
    <div class="chart-wrap"><canvas id="hailo"></canvas></div>
  </div>

  <div class="panel">
    <div class="panel-title">entry presence — pir trigger</div>
    <div class="chart-wrap tall"><canvas id="presence"></canvas></div>
  </div>

  <div class="panel">
    <div class="panel-title">hailo chip temperature — °c</div>
    <div class="chart-wrap tall"><canvas id="hailo-temp"></canvas></div>
  </div>

</div>

<footer id="footer">meridian sensor ecology · whitehorse yk</footer>

<script>
const DATA = __DATA__;

// ── Chart defaults ─────────────────────────────────────────────────────────
Chart.defaults.font.family   = "'IBM Plex Mono', monospace";
Chart.defaults.font.size     = 10;
Chart.defaults.color         = '#4a5568';
Chart.defaults.borderColor   = '#1f2733';

const GRID = {
  color: 'rgba(31,39,51,0.8)',
  drawBorder: false,
};

const TICK = { color: '#4a5568', maxTicksLimit: 8 };

function lineDefaults(color, fill=false) {
  return {
    borderColor: color,
    backgroundColor: fill ? color + '18' : 'transparent',
    borderWidth: 1.5,
    pointRadius: 0,
    pointHoverRadius: 3,
    tension: 0.3,
    fill,
  };
}

// ── Soil Moisture ──────────────────────────────────────────────────────────
new Chart(document.getElementById('soil'), {
  type: 'line',
  data: {
    labels: DATA.soil.labels,
    datasets: [
      { label: 'north vwc', data: DATA.soil.north,
        ...lineDefaults('var(--north)', true) },
      { label: 'south vwc', data: DATA.soil.south,
        ...lineDefaults('var(--south)', true),
        labels: DATA.soil.labels_s },
    ]
  },
  options: {
    responsive: true, maintainAspectRatio: false, animation: false,
    interaction: { mode: 'index', intersect: false },
    plugins: { legend: { display: false }, tooltip: { mode: 'index' } },
    scales: {
      x: { grid: GRID, ticks: { ...TICK, maxTicksLimit: 10 } },
      y: { grid: GRID, ticks: TICK,
           title: { display: true, text: 'VWC %', color: '#4a5568', font: { size: 9 } } }
    }
  }
});

// ── Temperature ────────────────────────────────────────────────────────────
new Chart(document.getElementById('temp'), {
  type: 'line',
  data: {
    labels: DATA.temp.labels,
    datasets: [
      { label: 'sky',   data: DATA.temp.sky,   ...lineDefaults('var(--sky)') },
      { label: 'north', data: DATA.temp.north, ...lineDefaults('var(--north)') },
      { label: 'south', data: DATA.temp.south, ...lineDefaults('var(--south)') },
    ]
  },
  options: {
    responsive: true, maintainAspectRatio: false, animation: false,
    interaction: { mode: 'index', intersect: false },
    plugins: { legend: { display: false } },
    scales: {
      x: { grid: GRID, ticks: TICK },
      y: { grid: GRID, ticks: TICK,
           title: { display: true, text: '°C', color: '#4a5568', font: { size: 9 } } }
    }
  }
});

// ── Lux ────────────────────────────────────────────────────────────────────
new Chart(document.getElementById('lux'), {
  type: 'line',
  data: {
    labels: DATA.lux.labels,
    datasets: [
      { label: 'sky',   data: DATA.lux.sky,   ...lineDefaults('var(--sky)',   true) },
      { label: 'north', data: DATA.lux.north, ...lineDefaults('var(--north)') },
      { label: 'south', data: DATA.lux.south, ...lineDefaults('var(--south)') },
    ]
  },
  options: {
    responsive: true, maintainAspectRatio: false, animation: false,
    interaction: { mode: 'index', intersect: false },
    plugins: { legend: { display: false } },
    scales: {
      x: { grid: GRID, ticks: TICK },
      y: { grid: GRID, ticks: TICK,
           title: { display: true, text: 'lux', color: '#4a5568', font: { size: 9 } } }
    }
  }
});

// ── Hailo Detections ───────────────────────────────────────────────────────
new Chart(document.getElementById('hailo'), {
  type: 'bar',
  data: {
    labels: DATA.hailo.labels,
    datasets: [
      { label: 'detections', data: DATA.hailo.counts,
        backgroundColor: 'var(--hailo)' + '55',
        borderColor: 'var(--hailo)',
        borderWidth: 1,
        yAxisID: 'y',
      },
      { label: 'infer ms', data: DATA.hailo.ms,
        type: 'line',
        ...lineDefaults('#4a5568'),
        yAxisID: 'y2',
      }
    ]
  },
  options: {
    responsive: true, maintainAspectRatio: false, animation: false,
    plugins: { legend: { display: false } },
    scales: {
      x: { grid: GRID, ticks: TICK },
      y:  { grid: GRID, ticks: TICK, position: 'left',
            title: { display: true, text: 'count', color: '#4a5568', font: { size: 9 } } },
      y2: { grid: { display: false }, ticks: TICK, position: 'right',
            title: { display: true, text: 'ms', color: '#4a5568', font: { size: 9 } } },
    }
  }
});

// ── Presence ───────────────────────────────────────────────────────────────
new Chart(document.getElementById('presence'), {
  type: 'bar',
  data: {
    labels: DATA.presence.labels,
    datasets: [{
      label: 'pir', data: DATA.presence.pir,
      backgroundColor: 'var(--presence)' + '66',
      borderColor: 'var(--presence)',
      borderWidth: 1,
    }]
  },
  options: {
    responsive: true, maintainAspectRatio: false, animation: false,
    plugins: { legend: { display: false } },
    scales: {
      x: { grid: GRID, ticks: TICK },
      y: { grid: GRID, ticks: { ...TICK, stepSize: 1 }, min: 0, max: 1 }
    }
  }
});

// ── Hailo Chip Temp ────────────────────────────────────────────────────────
new Chart(document.getElementById('hailo-temp'), {
  type: 'line',
  data: {
    labels: DATA.hailo.labels,
    datasets: [{
      label: 'chip °C', data: DATA.hailo.chip_t,
      ...lineDefaults('var(--hailo)', true),
    }]
  },
  options: {
    responsive: true, maintainAspectRatio: false, animation: false,
    plugins: { legend: { display: false } },
    scales: {
      x: { grid: GRID, ticks: TICK },
      y: { grid: GRID, ticks: TICK,
           title: { display: true, text: '°C', color: '#4a5568', font: { size: 9 } } }
    }
  }
});

// ── Node pills ─────────────────────────────────────────────────────────────
const COLORS = {
  'w-sky-reference':  'var(--sky)',
  'b1-bed-north':     'var(--north)',
  'b2-bed-south':     'var(--south)',
  'e1-central':       'var(--central)',
  'p-entry-presence': 'var(--presence)',
  'c1-hailo-camera':  'var(--hailo)',
};

const pills = document.getElementById('node-pills');
DATA.summary.forEach(n => {
  const el = document.createElement('div');
  el.className = 'node-pill';
  const color = COLORS[n.slug] || '#fff';
  el.innerHTML = `
    <div class="dot" style="background:${color}"></div>
    <span>${n.slug}</span>
    <span class="count">${n.n} readings · ${n.first}–${n.last}</span>
  `;
  pills.appendChild(el);
});

document.getElementById('gen-time').textContent =
  'generated ' + new Date().toLocaleTimeString();
</script>
</body>
</html>
"""


# ── Generator ──────────────────────────────────────────────────────────────────

def main():
    if not Path(DB_NAME).exists():
        print(f"Database not found: {DB_NAME}")
        print("Run from your Meridian directory alongside meridian_ecology.db")
        return

    conn = sqlite3.connect(DB_NAME)
    data = build_data(conn)
    conn.close()

    total = sum(n["n"] for n in data["summary"])
    print(f"Loaded {total} readings across {len(data['summary'])} nodes")

    html = HTML.replace("__DATA__", json.dumps(data))

    with open(OUTPUT, "w", encoding="utf-8") as f:
        f.write(html)

    print(f"Dashboard written to {OUTPUT}")
    print("Open it in any browser — no server needed.")


if __name__ == "__main__":
    main()
