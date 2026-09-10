import { useState, useEffect, useRef } from "react";

// ── Palette & tokens ──────────────────────────────────────────────────────────
const C = {
  ground:    "#17171c",
  surface:   "#1e1e25",
  surfaceAlt:"#22222a",
  border:    "#2e2e38",
  borderDim: "#252530",
  amber:     "#c49a3c",
  amberDim:  "#8a6b28",
  amberGlow: "#e8b84b",
  cream:     "#e8e0d0",
  creamDim:  "#a09888",
  creamFaint:"#5a5248",
  green:     "#4a7c59",
  greenBright:"#6aad7d",
  blue:      "#4a6680",
  blueBright:"#6a90b0",
  rust:      "#8a4a3a",
  rustBright:"#b06a5a",
  violet:    "#5a4a7a",
};

const FONTS = `
  @import url('https://fonts.googleapis.com/css2?family=Cormorant+Garamond:ital,wght@0,300;0,400;0,500;0,600;1,300;1,400&family=Cormorant:wght@300;400&family=JetBrains+Mono:wght@300;400&display=swap');
`;

const GLOBAL_STYLE = `
  ${FONTS}
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body { background: ${C.ground}; }
  ::-webkit-scrollbar { width: 4px; }
  ::-webkit-scrollbar-track { background: transparent; }
  ::-webkit-scrollbar-thumb { background: ${C.border}; border-radius: 2px; }
  ::-webkit-scrollbar-thumb:hover { background: ${C.amberDim}; }

  @keyframes fadeIn {
    from { opacity: 0; transform: translateY(6px); }
    to   { opacity: 1; transform: translateY(0); }
  }
  @keyframes pulse {
    0%, 100% { opacity: 1; }
    50%       { opacity: 0.4; }
  }
  @keyframes slideIn {
    from { opacity: 0; transform: translateX(-8px); }
    to   { opacity: 1; transform: translateX(0); }
  }
`;

// ── Storage helpers ───────────────────────────────────────────────────────────
const STORE_KEY_IDEAS   = "cospace:circlingIdeas";
const STORE_KEY_LOOKUP  = "cospace:toLookUp";
const STORE_KEY_KANBAN  = "cospace:kanbanSnapshot";
const STORE_KEY_READS   = "cospace:reading";
const STORE_KEY_CONTEXT = "cospace:morningContext";

async function storageGet(key, fallback) {
  try {
    const r = await window.storage.get(key);
    return r ? JSON.parse(r.value) : fallback;
  } catch { return fallback; }
}
async function storageSet(key, value) {
  try { await window.storage.set(key, JSON.stringify(value)); } catch {}
}

// ── Seed data ─────────────────────────────────────────────────────────────────
const SEED_KANBAN = [
  { id: "1772825440190", col: "research",  priority: "medium", title: "Migrate PostgreSQL from Sensor Pi to Inferno Pi", project: "infrastructure" },
  { id: "1772807737974", col: "waiting",   priority: "medium", title: "Windows startup: run sync_daemon.js before checking Kanban", project: "default" },
  { id: "1772828968362", col: "working",   priority: "medium", title: "Bread", project: "default" },
  { id: "1772829036827", col: "working",   priority: "medium", title: "Closet", project: "default" },
  { id: "1772805698073", col: "complete",  priority: "medium", title: "Motifs flowing to Unity — relay_api for live updates", project: "default" },
];

const SEED_READS = [
  { id: 1, title: "Time and Narrative, Vol. 2", author: "Paul Ricoeur",        note: "Emplotment, historicity, refiguration",  status: "active" },
  { id: 2, title: "Moralizing Technology",      author: "Peter-Paul Verbeek",  note: "Postphenomenology, moral mediation",     status: "active" },
  { id: 3, title: "A Thousand Plateaus",        author: "Deleuze & Guattari",  note: "Rhizome, plateau, assemblage",          status: "active" },
  { id: 4, title: "Journey to the West",        author: "Wu Cheng'en",         note: "Aloud with Gwen — Vol. ongoing",        status: "aloud"  },
];

const SEED_IDEAS = [
  { id: Date.now() + 1, text: "Narrative emplotment as schema for sensor ecology — time-series as plot" },
  { id: Date.now() + 2, text: "Verbeek's moral mediation ↔ MCP server as ethical infrastructure" },
  { id: Date.now() + 3, text: "Motif graph topology: are motif clusters D&G plateaus?" },
  { id: Date.now() + 4, text: "PostGIS + indigenous data sovereignty — spatial ontology question" },
];

const SEED_LOOKUP = [
  { id: Date.now() + 10, text: "Akrich de-scription framework — recent secondary literature" },
  { id: Date.now() + 11, text: "pgvector HNSW vs IVFFlat performance at 226k vectors" },
  { id: Date.now() + 12, text: "XREAL Air 2 Unity pass-through SDK docs" },
];

// ── Column metadata ───────────────────────────────────────────────────────────
const COL_META = {
  research: { label: "Research",  dot: C.blue,        abbr: "R" },
  working:  { label: "Working",   dot: C.amber,       abbr: "W" },
  waiting:  { label: "Waiting",   dot: C.rust,        abbr: "·" },
  complete: { label: "Complete",  dot: C.green,       abbr: "✓" },
};

// ── Tiny components ───────────────────────────────────────────────────────────
function RuledSection({ label, accent, children, rightSlot }) {
  return (
    <div style={{ marginBottom: 24, animation: "fadeIn 0.5s ease both" }}>
      <div style={{
        display: "flex", alignItems: "baseline", justifyContent: "space-between",
        borderBottom: `1px solid ${C.border}`, paddingBottom: 6, marginBottom: 14,
      }}>
        <span style={{
          fontFamily: "'Cormorant Garamond', serif",
          fontSize: 11, letterSpacing: "0.18em", textTransform: "uppercase",
          color: accent || C.amberDim, fontWeight: 500,
        }}>{label}</span>
        {rightSlot}
      </div>
      {children}
    </div>
  );
}

function Dot({ color, pulse }) {
  return (
    <span style={{
      display: "inline-block", width: 6, height: 6, borderRadius: "50%",
      background: color, flexShrink: 0, marginTop: 2,
      animation: pulse ? "pulse 2s ease-in-out infinite" : "none",
    }} />
  );
}

function TaskCard({ task }) {
  const meta = COL_META[task.col] || COL_META.research;
  const isComplete = task.col === "complete";
  return (
    <div style={{
      display: "flex", gap: 8, padding: "6px 0",
      borderBottom: `1px solid ${C.borderDim}`,
      opacity: isComplete ? 0.55 : 1,
      animation: "slideIn 0.3s ease both",
    }}>
      <Dot color={meta.dot} pulse={task.col === "working"} />
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{
          fontFamily: "'Cormorant Garamond', serif", fontSize: 13.5,
          color: isComplete ? C.creamDim : C.cream,
          lineHeight: 1.35, fontStyle: isComplete ? "italic" : "normal",
          textDecoration: isComplete ? "line-through" : "none",
        }}>{task.title}</div>
        {task.project && task.project !== "default" && (
          <div style={{
            fontFamily: "'JetBrains Mono', monospace", fontSize: 9,
            color: C.creamFaint, letterSpacing: "0.05em", marginTop: 2,
          }}>{task.project}</div>
        )}
      </div>
      <div style={{
        fontFamily: "'JetBrains Mono', monospace", fontSize: 9,
        color: meta.dot, opacity: 0.7, flexShrink: 0, alignSelf: "flex-start", marginTop: 3,
      }}>{meta.abbr}</div>
    </div>
  );
}

function BookRow({ book }) {
  const statusColor = book.status === "aloud" ? C.violet : C.greenBright;
  const statusLabel = book.status === "aloud" ? "aloud" : "reading";
  return (
    <div style={{
      padding: "7px 0", borderBottom: `1px solid ${C.borderDim}`,
      animation: "fadeIn 0.4s ease both",
    }}>
      <div style={{ display: "flex", alignItems: "flex-start", gap: 8 }}>
        <Dot color={statusColor} pulse={book.status === "active"} />
        <div style={{ flex: 1 }}>
          <div style={{
            fontFamily: "'Cormorant Garamond', serif", fontSize: 14, fontStyle: "italic",
            color: C.cream, lineHeight: 1.3,
          }}>{book.title}</div>
          <div style={{
            fontFamily: "'Cormorant Garamond', serif", fontSize: 12,
            color: C.creamDim, marginTop: 1,
          }}>{book.author}</div>
          {book.note && (
            <div style={{
              fontFamily: "'Cormorant Garamond', serif", fontSize: 11,
              color: C.creamFaint, marginTop: 3, fontStyle: "italic",
            }}>{book.note}</div>
          )}
        </div>
        <span style={{
          fontFamily: "'JetBrains Mono', monospace", fontSize: 9,
          color: statusColor, opacity: 0.8, flexShrink: 0,
        }}>{statusLabel}</span>
      </div>
    </div>
  );
}

function EditableList({ items, onAdd, onRemove, placeholder, accent }) {
  const [draft, setDraft] = useState("");
  const inputRef = useRef();

  function submit() {
    const t = draft.trim();
    if (!t) return;
    onAdd(t);
    setDraft("");
  }

  return (
    <div>
      {items.map((item, i) => (
        <div key={item.id} style={{
          display: "flex", alignItems: "flex-start", gap: 8,
          padding: "5px 0", borderBottom: `1px solid ${C.borderDim}`,
          animation: `slideIn 0.3s ease ${i * 0.04}s both`,
          group: true,
        }}>
          <span style={{
            fontFamily: "'Cormorant Garamond', serif", fontSize: 12,
            color: accent || C.amberDim, flexShrink: 0, marginTop: 2,
          }}>◦</span>
          <span style={{
            fontFamily: "'Cormorant Garamond', serif", fontSize: 13.5,
            color: C.cream, flex: 1, lineHeight: 1.4,
          }}>{item.text}</span>
          <button
            onClick={() => onRemove(item.id)}
            style={{
              background: "none", border: "none", cursor: "pointer",
              color: C.creamFaint, fontSize: 11, padding: "0 2px",
              opacity: 0.5, flexShrink: 0,
              transition: "opacity 0.2s",
            }}
            onMouseEnter={e => e.target.style.opacity = 1}
            onMouseLeave={e => e.target.style.opacity = 0.5}
          >×</button>
        </div>
      ))}
      <div style={{ display: "flex", gap: 6, marginTop: 10, alignItems: "center" }}>
        <input
          ref={inputRef}
          value={draft}
          onChange={e => setDraft(e.target.value)}
          onKeyDown={e => e.key === "Enter" && submit()}
          placeholder={placeholder}
          style={{
            flex: 1, background: "transparent",
            border: "none", borderBottom: `1px solid ${C.borderDim}`,
            color: C.cream, outline: "none", padding: "4px 0",
            fontFamily: "'Cormorant Garamond', serif", fontSize: 13,
            caretColor: accent || C.amber,
          }}
        />
        <button
          onClick={submit}
          style={{
            background: "none", border: `1px solid ${C.border}`,
            color: accent || C.amberDim, cursor: "pointer",
            fontFamily: "'Cormorant Garamond', serif", fontSize: 11,
            padding: "3px 8px", borderRadius: 2,
            transition: "all 0.2s",
          }}
          onMouseEnter={e => { e.target.style.borderColor = accent || C.amber; e.target.style.color = accent || C.amber; }}
          onMouseLeave={e => { e.target.style.borderColor = C.border; e.target.style.color = accent || C.amberDim; }}
        >add</button>
      </div>
    </div>
  );
}

// ── Sensor / AR status strip ──────────────────────────────────────────────────
const SENSOR_NODES = [
  { label: "ESP32-S3 (TCS34725 + MPU-6050)", status: "live",    note: "MQTT → sensor_pi" },
  { label: "MLX90640 thermal",               status: "live",    note: "I2C pipeline active" },
  { label: "Raspberry Pi 5 (sensor hub)",    status: "live",    note: "192.168.0.25" },
  { label: "Raspberry Pi 5 (Inferno)",       status: "pending", note: "PG migration target" },
  { label: "relay_api.py :8765",             status: "task",    note: "start before Unity session" },
  { label: "Unity AR motif graph",           status: "live",    note: "MotifGraphScene, ProceduralArcMesh" },
];

function SensorStrip() {
  return (
    <div style={{
      display: "flex", flexWrap: "wrap", gap: 8,
    }}>
      {SENSOR_NODES.map((n, i) => {
        const color = n.status === "live" ? C.greenBright : n.status === "pending" ? C.amber : C.rust;
        return (
          <div key={i} style={{
            display: "flex", alignItems: "center", gap: 5,
            padding: "3px 8px",
            border: `1px solid ${C.border}`, borderRadius: 2,
            animation: `fadeIn 0.4s ease ${i * 0.06}s both`,
          }}>
            <Dot color={color} pulse={n.status === "live"} />
            <div>
              <div style={{
                fontFamily: "'JetBrains Mono', monospace", fontSize: 9,
                color: C.creamDim, letterSpacing: "0.03em",
              }}>{n.label}</div>
              <div style={{
                fontFamily: "'JetBrains Mono', monospace", fontSize: 8,
                color: C.creamFaint,
              }}>{n.note}</div>
            </div>
          </div>
        );
      })}
    </div>
  );
}

// ── Morning context ───────────────────────────────────────────────────────────
async function fetchMorningContext({ tasks, reads, ideas, lookup }) {
  const activeTasks = tasks.filter(t => t.col !== "complete").map(t => `[${t.col}] ${t.title}`).join("\n");
  const reading     = reads.map(r => `${r.title} — ${r.author} (${r.note})`).join("\n");
  const ideasText   = ideas.map(i => i.text).join("\n");
  const lookupText  = lookup.map(l => l.text).join("\n");

  const today = new Date().toLocaleDateString("en-CA", { weekday: "long", month: "long", day: "numeric" });

  const prompt = `You are orienting Sean Macdonald at the start of his working day in Whitehorse, Yukon. Sean is a senior ICT developer and enterprise architect with the Yukon government, and also a committed philosophical reader. He coordinates work across sensor ecology hardware (ESP32, Raspberry Pi, MLX90640 thermal camera), a Unity AR motif graph, AAAS 2.0 asset management, an MCP-based multi-AI workflow, and sustained reading in continental philosophy (currently Ricoeur, Verbeek, Deleuze & Guattari).

Today is ${today}.

Here is the current state of his atelier:

ACTIVE WORK:
${activeTasks || "(nothing active)"}

READING ORBIT:
${reading}

CIRCLING IDEAS:
${ideasText || "(none recorded)"}

TO LOOK UP:
${lookupText || "(none)"}

Write a single, flowing paragraph — 80 to 120 words — that orients him to the day. Speak directly to Sean (use "you"). Weave together the technical and philosophical without forcing a connection. The tone should be calm, attentive, and intelligent — like a trusted colleague who has read the room. Do not use bullet points, headers, or lists. No preamble. Just the paragraph itself.`;

  const res = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      model: "claude-sonnet-4-20250514",
      max_tokens: 200,
      messages: [{ role: "user", content: prompt }],
    }),
  });
  const data = await res.json();
  return data?.content?.[0]?.text || "Context unavailable.";
}

function MorningContext({ tasks, reads, ideas, lookup }) {
  const [text,    setText]    = useState(null);
  const [loading, setLoading] = useState(false);
  const [ts,      setTs]      = useState(null);

  useEffect(() => {
    storageGet(STORE_KEY_CONTEXT, null).then(cached => {
      if (cached?.text) { setText(cached.text); setTs(cached.ts); }
    });
  }, []);

  async function generate() {
    setLoading(true);
    try {
      const result = await fetchMorningContext({ tasks, reads, ideas, lookup });
      const now = new Date().toLocaleTimeString("en-CA", { hour: "2-digit", minute: "2-digit" });
      setText(result);
      setTs(now);
      storageSet(STORE_KEY_CONTEXT, { text: result, ts: now });
    } catch (e) {
      setText("Could not reach the API — check connection.");
    } finally {
      setLoading(false);
    }
  }

  return (
    <div style={{
      borderBottom: `1px solid ${C.border}`,
      paddingBottom: 20, marginBottom: 26,
      animation: "fadeIn 0.5s ease both",
    }}>
      <div style={{
        display: "flex", alignItems: "baseline",
        justifyContent: "space-between", marginBottom: 12,
      }}>
        <span style={{
          fontFamily: "'Cormorant Garamond', serif",
          fontSize: 11, letterSpacing: "0.18em", textTransform: "uppercase",
          color: C.amberDim, fontWeight: 500,
        }}>Morning Context</span>
        <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
          {ts && (
            <span style={{
              fontFamily: "'JetBrains Mono', monospace", fontSize: 8,
              color: C.creamFaint,
            }}>{ts}</span>
          )}
          <button
            onClick={generate}
            disabled={loading}
            style={{
              background: "none",
              border: `1px solid ${loading ? C.border : C.amberDim}`,
              color: loading ? C.creamFaint : C.amberDim,
              cursor: loading ? "default" : "pointer",
              fontFamily: "'JetBrains Mono', monospace", fontSize: 9,
              padding: "3px 10px", borderRadius: 2,
              letterSpacing: "0.06em", transition: "all 0.2s",
            }}
            onMouseEnter={e => { if (!loading) { e.target.style.borderColor = C.amber; e.target.style.color = C.amber; }}}
            onMouseLeave={e => { e.target.style.borderColor = loading ? C.border : C.amberDim; e.target.style.color = loading ? C.creamFaint : C.amberDim; }}
          >
            {loading ? "thinking…" : text ? "↻ refresh" : "orient the day"}
          </button>
        </div>
      </div>

      {loading && !text && (
        <div style={{
          fontFamily: "'Cormorant Garamond', serif", fontSize: 14,
          color: C.creamFaint, fontStyle: "italic",
          animation: "pulse 1.8s ease-in-out infinite",
        }}>
          Composing…
        </div>
      )}

      {text && (
        <div style={{
          fontFamily: "'Cormorant Garamond', serif", fontSize: 15,
          color: loading ? C.creamDim : C.cream,
          lineHeight: 1.75, fontStyle: "italic",
          borderLeft: `2px solid ${C.amberDim}`,
          paddingLeft: 16,
          transition: "color 0.4s",
          animation: "fadeIn 0.6s ease both",
        }}>
          {text}
        </div>
      )}

      {!text && !loading && (
        <div style={{
          fontFamily: "'Cormorant Garamond', serif", fontSize: 13,
          color: C.creamFaint, fontStyle: "italic",
          borderLeft: `2px solid ${C.borderDim}`, paddingLeft: 16,
        }}>
          Press "orient the day" to generate a morning briefing from your current state.
        </div>
      )}
    </div>
  );
}

// ── Header ────────────────────────────────────────────────────────────────────
function Header({ lastSync, onSync }) {
  const now = new Date();
  const dateStr = now.toLocaleDateString("en-CA", { weekday: "long", year: "numeric", month: "long", day: "numeric" });
  const timeStr = now.toLocaleTimeString("en-CA", { hour: "2-digit", minute: "2-digit" });

  return (
    <div style={{
      borderBottom: `1px solid ${C.border}`,
      paddingBottom: 16, marginBottom: 28,
      display: "flex", alignItems: "flex-end", justifyContent: "space-between",
    }}>
      <div>
        <div style={{
          fontFamily: "'Cormorant', serif",
          fontSize: 28, fontWeight: 300,
          color: C.cream, letterSpacing: "0.04em",
          lineHeight: 1,
        }}>
          Atelier
        </div>
        <div style={{
          fontFamily: "'Cormorant Garamond', serif",
          fontSize: 13, color: C.creamDim, marginTop: 5,
          letterSpacing: "0.06em",
        }}>
          {dateStr} · {timeStr}
        </div>
      </div>
      <div style={{ textAlign: "right" }}>
        <div style={{
          fontFamily: "'JetBrains Mono', monospace",
          fontSize: 9, color: C.creamFaint, letterSpacing: "0.08em",
          textTransform: "uppercase", marginBottom: 6,
        }}>
          Whitehorse, YT
        </div>
        <button
          onClick={onSync}
          style={{
            background: "none", border: `1px solid ${C.border}`,
            color: C.amberDim, cursor: "pointer",
            fontFamily: "'JetBrains Mono', monospace", fontSize: 9,
            padding: "3px 10px", borderRadius: 2, letterSpacing: "0.06em",
            transition: "all 0.2s",
          }}
          onMouseEnter={e => { e.target.style.borderColor = C.amber; e.target.style.color = C.amber; }}
          onMouseLeave={e => { e.target.style.borderColor = C.border; e.target.style.color = C.amberDim; }}
        >
          ↻ sync
        </button>
        {lastSync && (
          <div style={{
            fontFamily: "'JetBrains Mono', monospace",
            fontSize: 8, color: C.creamFaint, marginTop: 4,
          }}>last sync {lastSync}</div>
        )}
      </div>
    </div>
  );
}

// ── Sync modal ────────────────────────────────────────────────────────────────
function SyncModal({ onClose, onApply }) {
  const [json, setJson] = useState("");
  const [err, setErr] = useState("");

  function apply() {
    try {
      const data = JSON.parse(json);
      onApply(data);
      onClose();
    } catch {
      setErr("Invalid JSON — paste the object from Claude's kanban pull");
    }
  }

  return (
    <div style={{
      position: "fixed", inset: 0, background: "rgba(0,0,0,0.7)",
      display: "flex", alignItems: "center", justifyContent: "center",
      zIndex: 100, animation: "fadeIn 0.2s ease both",
    }}>
      <div style={{
        background: C.surface, border: `1px solid ${C.border}`,
        borderRadius: 4, padding: 24, width: 480, maxWidth: "90vw",
      }}>
        <div style={{
          fontFamily: "'Cormorant Garamond', serif", fontSize: 16,
          color: C.cream, marginBottom: 12,
        }}>Sync kanban from Claude</div>
        <div style={{
          fontFamily: "'Cormorant Garamond', serif", fontSize: 12,
          color: C.creamDim, marginBottom: 12, lineHeight: 1.5,
        }}>
          Ask Claude: <em>"Pull my hedgehogger tasks and give me the JSON for Atelier sync."</em><br />
          Paste the result below.
        </div>
        <textarea
          value={json}
          onChange={e => setJson(e.target.value)}
          placeholder='[{ "id": "...", "col": "working", "title": "...", "project": "..." }]'
          style={{
            width: "100%", height: 120, background: C.ground,
            border: `1px solid ${C.border}`, color: C.cream,
            fontFamily: "'JetBrains Mono', monospace", fontSize: 10,
            padding: 8, borderRadius: 2, outline: "none", resize: "vertical",
          }}
        />
        {err && <div style={{ color: C.rust, fontSize: 11, marginTop: 6 }}>{err}</div>}
        <div style={{ display: "flex", gap: 8, marginTop: 12, justifyContent: "flex-end" }}>
          <button onClick={onClose} style={{
            background: "none", border: `1px solid ${C.border}`, color: C.creamDim,
            cursor: "pointer", fontFamily: "'Cormorant Garamond', serif",
            fontSize: 12, padding: "4px 14px", borderRadius: 2,
          }}>cancel</button>
          <button onClick={apply} style={{
            background: "none", border: `1px solid ${C.amber}`, color: C.amber,
            cursor: "pointer", fontFamily: "'Cormorant Garamond', serif",
            fontSize: 12, padding: "4px 14px", borderRadius: 2,
          }}>apply</button>
        </div>
      </div>
    </div>
  );
}

// ── Main app ──────────────────────────────────────────────────────────────────
export default function Atelier() {
  const [tasks,   setTasks]   = useState(SEED_KANBAN);
  const [reads,   setReads]   = useState(SEED_READS);
  const [ideas,   setIdeas]   = useState(SEED_IDEAS);
  const [lookup,  setLookup]  = useState(SEED_LOOKUP);
  const [lastSync, setLastSync] = useState(null);
  const [showSync, setShowSync] = useState(false);
  const [loaded,  setLoaded]  = useState(false);

  // Load from storage on mount
  useEffect(() => {
    (async () => {
      const [storedTasks, storedReads, storedIdeas, storedLookup] = await Promise.all([
        storageGet(STORE_KEY_KANBAN, null),
        storageGet(STORE_KEY_READS,  null),
        storageGet(STORE_KEY_IDEAS,  null),
        storageGet(STORE_KEY_LOOKUP, null),
      ]);
      if (storedTasks)  setTasks(storedTasks);
      if (storedReads)  setReads(storedReads);
      if (storedIdeas)  setIdeas(storedIdeas);
      if (storedLookup) setLookup(storedLookup);
      setLoaded(true);
    })();
  }, []);

  // Persist ideas
  useEffect(() => { if (loaded) storageSet(STORE_KEY_IDEAS, ideas); }, [ideas, loaded]);
  useEffect(() => { if (loaded) storageSet(STORE_KEY_LOOKUP, lookup); }, [lookup, loaded]);
  useEffect(() => { if (loaded) storageSet(STORE_KEY_KANBAN, tasks); }, [tasks, loaded]);
  useEffect(() => { if (loaded) storageSet(STORE_KEY_READS, reads); }, [reads, loaded]);

  function addIdea(text) {
    setIdeas(prev => [...prev, { id: Date.now(), text }]);
  }
  function removeIdea(id) {
    setIdeas(prev => prev.filter(i => i.id !== id));
  }
  function addLookup(text) {
    setLookup(prev => [...prev, { id: Date.now(), text }]);
  }
  function removeLookup(id) {
    setLookup(prev => prev.filter(i => i.id !== id));
  }

  function applySync(data) {
    if (Array.isArray(data)) {
      setTasks(data);
      setLastSync(new Date().toLocaleTimeString("en-CA", { hour: "2-digit", minute: "2-digit" }));
    }
  }

  // Group tasks
  const byCol = { research: [], working: [], waiting: [], complete: [] };
  tasks.forEach(t => { if (byCol[t.col]) byCol[t.col].push(t); });
  const activeTasks = [...byCol.research, ...byCol.working, ...byCol.waiting];
  const doneTasks   = byCol.complete;

  return (
    <>
      <style>{GLOBAL_STYLE}</style>

      {/* Grain overlay */}
      <div style={{
        position: "fixed", inset: 0, pointerEvents: "none", zIndex: 0,
        backgroundImage: `url("data:image/svg+xml,%3Csvg viewBox='0 0 256 256' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='noise'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.9' numOctaves='4' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23noise)' opacity='0.03'/%3E%3C/svg%3E")`,
        backgroundRepeat: "repeat", opacity: 0.6,
      }} />

      <div style={{
        minHeight: "100vh", background: C.ground,
        padding: "28px 32px 48px",
        position: "relative", zIndex: 1,
        maxWidth: 1200, margin: "0 auto",
      }}>
        <Header lastSync={lastSync} onSync={() => setShowSync(true)} />

        <MorningContext tasks={tasks} reads={reads} ideas={ideas} lookup={lookup} />
        <div style={{
          display: "grid",
          gridTemplateColumns: "1fr 1fr 1fr",
          gridTemplateRows: "auto auto",
          gap: "0 32px",
        }}>

          {/* ── Col 1: Work ── */}
          <div style={{ gridColumn: 1, gridRow: "1 / 3" }}>
            <RuledSection label="Active Work" accent={C.amber}>
              {activeTasks.length === 0
                ? <div style={{ fontFamily: "'Cormorant Garamond', serif", fontSize: 13, color: C.creamFaint, fontStyle: "italic" }}>— clear desk —</div>
                : activeTasks.map(t => <TaskCard key={t.id} task={t} />)
              }
            </RuledSection>

            {doneTasks.length > 0 && (
              <RuledSection label="Recently Completed" accent={C.green}>
                {doneTasks.map(t => <TaskCard key={t.id} task={t} />)}
              </RuledSection>
            )}

            {/* Amber margin rule */}
            <div style={{ borderLeft: `2px solid ${C.amberDim}`, paddingLeft: 14, marginTop: 24, opacity: 0.6 }}>
              <div style={{
                fontFamily: "'Cormorant Garamond', serif", fontSize: 12,
                color: C.creamDim, lineHeight: 1.7, fontStyle: "italic",
              }}>
                Add tasks via hedgehogger kanban<br />
                or ask Claude to update this surface.
              </div>
            </div>
          </div>

          {/* ── Col 2: Reading + AR ── */}
          <div style={{ gridColumn: 2, gridRow: 1 }}>
            <RuledSection label="Reading Orbit" accent={C.blueBright}>
              {reads.map(b => <BookRow key={b.id} book={b} />)}
            </RuledSection>
          </div>

          <div style={{ gridColumn: 2, gridRow: 2, paddingTop: 0 }}>
            <RuledSection label="Sensor & AR Ecology" accent={C.greenBright}>
              <SensorStrip />
            </RuledSection>
          </div>

          {/* ── Col 3: Ideas + Lookup ── */}
          <div style={{ gridColumn: 3, gridRow: 1 }}>
            <RuledSection
              label="Circling Ideas"
              accent={C.amberGlow}
              rightSlot={
                <span style={{
                  fontFamily: "'JetBrains Mono', monospace", fontSize: 9,
                  color: C.creamFaint,
                }}>{ideas.length}</span>
              }
            >
              <EditableList
                items={ideas}
                onAdd={addIdea}
                onRemove={removeIdea}
                placeholder="add a circling thought…"
                accent={C.amberGlow}
              />
            </RuledSection>
          </div>

          <div style={{ gridColumn: 3, gridRow: 2, paddingTop: 0 }}>
            <RuledSection
              label="To Look Up"
              accent={C.blueBright}
              rightSlot={
                <span style={{
                  fontFamily: "'JetBrains Mono', monospace", fontSize: 9,
                  color: C.creamFaint,
                }}>{lookup.length}</span>
              }
            >
              <EditableList
                items={lookup}
                onAdd={addLookup}
                onRemove={removeLookup}
                placeholder="add something to research…"
                accent={C.blueBright}
              />
            </RuledSection>
          </div>
        </div>

        {/* Footer */}
        <div style={{
          marginTop: 40, paddingTop: 16,
          borderTop: `1px solid ${C.borderDim}`,
          display: "flex", justifyContent: "space-between",
          alignItems: "center",
        }}>
          <div style={{
            fontFamily: "'JetBrains Mono', monospace", fontSize: 8,
            color: C.creamFaint, letterSpacing: "0.1em",
          }}>
            AAAS 2.0 · SENSOR ECOLOGY · AR MOTIF GRAPH · HEDGEHOG LIBRARY · SEMANTIC TWIN VAULT
          </div>
          <div style={{
            fontFamily: "'Cormorant Garamond', serif", fontSize: 11,
            color: C.creamFaint, fontStyle: "italic",
          }}>
            — the workshop persists —
          </div>
        </div>
      </div>

      {showSync && (
        <SyncModal
          onClose={() => setShowSync(false)}
          onApply={applySync}
        />
      )}
    </>
  );
}
