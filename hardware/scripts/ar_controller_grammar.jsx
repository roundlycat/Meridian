import { useState } from "react";

const MODES = [
  {
    id: "ID", paddle: "P1", name: "ID Mode",
    bg: "#E6F1FB", text: "#0C447C", border: "#185FA5",
    assignments: [
      { key: "LS",  action: "Cycle detected objects (spatial)" },
      { key: "RS",  action: "Pan HUD overlay" },
      { key: "DP",  action: "Cycle ID candidates" },
      { key: "LT",  action: "Confidence vote — pull depth = certainty" },
      { key: "RT",  action: "Commit action" },
      { key: "LB",  action: "Zoom HUD out" },
      { key: "RB",  action: "Zoom HUD in" },
      { key: "A",   action: "Confirm identification" },
      { key: "B",   action: "Reject / skip" },
      { key: "X",   action: "Parts catalogue lookup" },
      { key: "Y",   action: "Flag as unknown" },
      { key: "P1",  action: "▶ ID Mode (active)" },
      { key: "P2",  action: "Switch to Measure" },
      { key: "P3",  action: "Switch to Wiring" },
      { key: "P4",  action: "Switch to Telemetry" },
    ]
  },
  {
    id: "MEASURE", paddle: "P2", name: "Measure Mode",
    bg: "#EAF3DE", text: "#27500A", border: "#639922",
    assignments: [
      { key: "LS",  action: "Move measurement cursor" },
      { key: "RS",  action: "Fine adjust" },
      { key: "DP",  action: "Unit / precision toggle" },
      { key: "LT",  action: "Zoom anchor" },
      { key: "RT",  action: "Capture measurement" },
      { key: "LB",  action: "Scale −" },
      { key: "RB",  action: "Scale +" },
      { key: "A",   action: "Set point 1" },
      { key: "B",   action: "Clear / reset" },
      { key: "X",   action: "Pin count mode" },
      { key: "Y",   action: "Capture to record" },
      { key: "P1",  action: "Switch to ID" },
      { key: "P2",  action: "▶ Measure Mode (active)" },
      { key: "P3",  action: "Switch to Wiring" },
      { key: "P4",  action: "Switch to Telemetry" },
    ]
  },
  {
    id: "WIRING", paddle: "P3", name: "Wiring Mode",
    bg: "#FAEEDA", text: "#412402", border: "#854F0B",
    assignments: [
      { key: "LS",  action: "Trace connection path" },
      { key: "RS",  action: "Rotate view" },
      { key: "DP",  action: "Step through net" },
      { key: "LT",  action: "Highlight net" },
      { key: "RT",  action: "Follow trace" },
      { key: "LB",  action: "Previous net" },
      { key: "RB",  action: "Next net" },
      { key: "A",   action: "Confirm connection" },
      { key: "B",   action: "Break / ignore trace" },
      { key: "X",   action: "Show full pinout" },
      { key: "Y",   action: "Flag connection issue" },
      { key: "P1",  action: "Switch to ID" },
      { key: "P2",  action: "Switch to Measure" },
      { key: "P3",  action: "▶ Wiring Mode (active)" },
      { key: "P4",  action: "Switch to Telemetry" },
    ]
  },
  {
    id: "TELEMETRY", paddle: "P4", name: "Telemetry Mode",
    bg: "#EEEDFE", text: "#26215C", border: "#534AB7",
    assignments: [
      { key: "LS",  action: "Select sensor node" },
      { key: "RS",  action: "Scrub timeline" },
      { key: "DP",  action: "Navigate readings" },
      { key: "LT",  action: "Rewind timeline" },
      { key: "RT",  action: "Fast-forward / commit" },
      { key: "LB",  action: "Previous sensor" },
      { key: "RB",  action: "Next sensor" },
      { key: "A",   action: "Drill into reading" },
      { key: "B",   action: "Dismiss / collapse" },
      { key: "X",   action: "Set alert threshold" },
      { key: "Y",   action: "Log reading to pgvector" },
      { key: "P1",  action: "Switch to ID" },
      { key: "P2",  action: "Switch to Measure" },
      { key: "P3",  action: "Switch to Wiring" },
      { key: "P4",  action: "▶ Telemetry Mode (active)" },
    ]
  },
];

const HAPTIC_STATES = [
  {
    id: "IDLE", label: "Idle",
    leftI: 0, leftP: "—",
    rightI: 0, rightP: "—",
    trigger: "Normal travel",
    color: "#888780", bg: "#F1EFE8",
    desc: "No objects in frame"
  },
  {
    id: "SCANNING", label: "Scanning",
    leftI: 0, leftP: "—",
    rightI: 1, rightP: "Slow pulse · 1 Hz",
    trigger: "Normal",
    color: "#185FA5", bg: "#E6F1FB",
    desc: "Camera active, searching"
  },
  {
    id: "CANDIDATE", label: "Candidate detected",
    leftI: 0, leftP: "—",
    rightI: 2, rightP: "Single buzz",
    trigger: "Normal",
    color: "#3B6D11", bg: "#EAF3DE",
    desc: "Object in bounding box, ID pending"
  },
  {
    id: "AMBIGUOUS", label: "Ambiguous",
    leftI: 0, leftP: "—",
    rightI: 3, rightP: "Irregular flutter",
    trigger: "Long pull required",
    color: "#BA7517", bg: "#FAEEDA",
    desc: "Multiple candidates · model uncertain"
  },
  {
    id: "CONFIDENT", label: "Confident lock",
    leftI: 0, leftP: "—",
    rightI: 4, rightP: "Sharp double buzz",
    trigger: "Short pull to confirm",
    color: "#639922", bg: "#EAF3DE",
    desc: "High confidence identification"
  },
  {
    id: "CONFIRMING", label: "Confirming",
    leftI: 3, leftP: "Scales with uncertainty",
    rightI: 3, rightP: "Steady hum",
    trigger: "Trigger held — active",
    color: "#534AB7", bg: "#EEEDFE",
    desc: "RT held · committing · both motors active"
  },
  {
    id: "CONFIRMED", label: "Confirmed",
    leftI: 4, leftP: "Single strong pulse",
    rightI: 4, rightP: "Single sharp pulse",
    trigger: "Release",
    color: "#1D9E75", bg: "#E1F5EE",
    desc: "Locked · registry updated"
  },
  {
    id: "LINK_SEVERED", label: "Link severed",
    leftI: 2, leftP: "Slow pulse · 1 Hz",
    rightI: 0, rightP: "—",
    trigger: "Normal",
    color: "#D85A30", bg: "#FAECE7",
    desc: "Sensor telemetry lost · background signal"
  },
  {
    id: "SERVICE_ERROR", label: "Service error",
    leftI: 4, leftP: "Fast pulse · 3 Hz",
    rightI: 0, rightP: "—",
    trigger: "Reduced haptic response",
    color: "#E24B4A", bg: "#FCEBEB",
    desc: "Backend unavailable · triggers feel loose"
  },
];

function MotorBar({ intensity, color }) {
  return (
    <div style={{ display: "flex", gap: 2, alignItems: "flex-end" }}>
      {[1,2,3,4].map(i => (
        <div key={i} style={{
          width: 7,
          height: 6 + i * 3,
          borderRadius: 2,
          background: i <= intensity ? color : "var(--color-border-tertiary)",
          transition: "background 0.15s",
        }} />
      ))}
    </div>
  );
}

function ControllerSVG({ mode }) {
  const h = mode.border;
  const fill = mode.bg;
  const txt = mode.text;
  const paddles = ["P1","P2","P3","P4"];

  const Btn = ({ x, y, r=13, label }) => (
    <g>
      <circle cx={x} cy={y} r={r} fill={fill} stroke={h} strokeWidth={0.8}/>
      <text x={x} y={y+4} textAnchor="middle" fontSize={10} fontWeight="500" fill={txt}>{label}</text>
    </g>
  );

  const Pill = ({ x, y, w=38, label }) => (
    <g>
      <rect x={x-w/2} y={y-9} width={w} height={18} rx={5} fill={fill} stroke={h} strokeWidth={0.8}/>
      <text x={x} y={y+4} textAnchor="middle" fontSize={10} fontWeight="500" fill={txt}>{label}</text>
    </g>
  );

  const Paddle = ({ x, y, label }) => {
    const active = mode.paddle === label;
    return (
      <g>
        <rect x={x-20} y={y-9} width={40} height={18} rx={4}
          fill={active ? h : "var(--color-background-secondary)"}
          stroke={active ? h : "var(--color-border-tertiary)"}
          strokeWidth={active ? 1.5 : 0.5}/>
        <text x={x} y={y+4} textAnchor="middle" fontSize={10} fontWeight={active?"500":"400"}
          fill={active ? "#fff" : "var(--color-text-tertiary)"}>{label}</text>
      </g>
    );
  };

  const Stick = ({ cx, cy, label }) => (
    <g>
      <circle cx={cx} cy={cy} r={20} fill={fill} stroke={h} strokeWidth={0.8}/>
      <circle cx={cx} cy={cy} r={8} fill={h} opacity={0.3}/>
      <text x={cx} y={cy-6} textAnchor="middle" fontSize={9} fill={txt}>{label.split(" ")[0]}</text>
      <text x={cx} y={cy+5} textAnchor="middle" fontSize={9} fill={txt}>{label.split(" ")[1]||""}</text>
    </g>
  );

  return (
    <svg viewBox="0 0 340 210" style={{width:"100%", maxWidth:340}}>
      {/* Body */}
      <path d="M70,45 Q48,45 43,65 L28,148 Q26,172 52,172 L88,172 Q100,180 112,172 L228,172 Q240,180 252,172 L288,172 Q314,172 312,148 L297,65 Q292,45 270,45 Z"
        fill="var(--color-background-secondary)" stroke="var(--color-border-secondary)" strokeWidth={1}/>

      {/* LT / RT */}
      <rect x={42} y={18} width={56} height={24} rx={7} fill={fill} stroke={h} strokeWidth={0.8}/>
      <text x={70} y={34} textAnchor="middle" fontSize={11} fontWeight="500" fill={txt}>LT</text>
      <rect x={242} y={18} width={56} height={24} rx={7} fill={fill} stroke={h} strokeWidth={0.8}/>
      <text x={270} y={34} textAnchor="middle" fontSize={11} fontWeight="500" fill={txt}>RT</text>

      {/* LB / RB */}
      <rect x={48} y={45} width={46} height={18} rx={5} fill={fill} stroke={h} strokeWidth={0.8}/>
      <text x={71} y={57} textAnchor="middle" fontSize={10} fontWeight="500" fill={txt}>LB</text>
      <rect x={246} y={45} width={46} height={18} rx={5} fill={fill} stroke={h} strokeWidth={0.8}/>
      <text x={269} y={57} textAnchor="middle" fontSize={10} fontWeight="500" fill={txt}>RB</text>

      {/* Left stick */}
      <Stick cx={100} cy={97} label="Left Stick" />

      {/* D-pad */}
      <rect x={62} y={128} width={14} height={38} rx={3} fill={fill} stroke={h} strokeWidth={0.8}/>
      <rect x={50} y={140} width={38} height={14} rx={3} fill={fill} stroke={h} strokeWidth={0.8}/>
      <text x={69} y={150} textAnchor="middle" fontSize={9} fill={txt}>DP</text>

      {/* Right stick */}
      <Stick cx={218} cy={128} label="Right Stick" />

      {/* Face buttons */}
      <Btn x={262} y={90}  label="Y" r={13}/>
      <Btn x={278} y={107} label="B" r={13}/>
      <Btn x={246} y={107} label="X" r={13}/>
      <Btn x={262} y={124} label="A" r={13}/>

      {/* Center */}
      <text x={170} y={88} textAnchor="middle" fontSize={9} fill="var(--color-text-tertiary)">menu</text>
      <text x={170} y={102} textAnchor="middle" fontSize={9} fill="var(--color-text-tertiary)">home</text>

      {/* Paddles */}
      <Paddle x={88}  y={190} label="P1"/>
      <Paddle x={130} y={196} label="P2"/>
      <Paddle x={210} y={196} label="P3"/>
      <Paddle x={252} y={190} label="P4"/>
    </svg>
  );
}

export default function App() {
  const [modeIdx, setModeIdx] = useState(0);
  const [openState, setOpenState] = useState(null);
  const mode = MODES[modeIdx];

  return (
    <div style={{padding:"1rem 0", fontFamily:"var(--font-sans)"}}>

      {/* Mode tabs */}
      <div style={{display:"flex", gap:6, marginBottom:14}}>
        {MODES.map((m, i) => (
          <button key={m.id} onClick={() => setModeIdx(i)} style={{
            flex:1, padding:"7px 4px", fontSize:11,
            fontWeight: modeIdx===i ? 500 : 400,
            border:`0.5px solid ${modeIdx===i ? m.border : "var(--color-border-tertiary)"}`,
            borderRadius:"var(--border-radius-md)",
            background: modeIdx===i ? m.bg : "var(--color-background-primary)",
            color: modeIdx===i ? m.text : "var(--color-text-secondary)",
            cursor:"pointer", lineHeight:1.3,
          }}>
            <div style={{fontSize:9, opacity:0.65, marginBottom:1}}>{m.paddle}</div>
            {m.name.replace(" Mode","")}
          </button>
        ))}
      </div>

      {/* Controller diagram + assignments */}
      <div style={{display:"grid", gridTemplateColumns:"minmax(0,1.3fr) minmax(0,1fr)", gap:10, marginBottom:14}}>
        <div style={{background:"var(--color-background-primary)", border:"0.5px solid var(--color-border-tertiary)", borderRadius:"var(--border-radius-lg)", padding:"0.75rem"}}>
          <ControllerSVG mode={mode}/>
        </div>
        <div style={{background:"var(--color-background-primary)", border:"0.5px solid var(--color-border-tertiary)", borderRadius:"var(--border-radius-lg)", padding:"0.75rem"}}>
          <div style={{fontSize:10, fontWeight:500, textTransform:"uppercase", letterSpacing:"0.08em", color:"var(--color-text-tertiary)", marginBottom:8}}>Assignments</div>
          {mode.assignments.map(a => (
            <div key={a.key} style={{display:"flex", gap:6, alignItems:"baseline", padding:"3px 0", borderBottom:"0.5px solid var(--color-border-tertiary)"}}>
              <span style={{fontSize:10, fontWeight:500, minWidth:26, background:mode.bg, color:mode.text, borderRadius:3, padding:"1px 3px", textAlign:"center", flexShrink:0}}>{a.key}</span>
              <span style={{fontSize:11, color:"var(--color-text-secondary)", lineHeight:1.4}}>{a.action}</span>
            </div>
          ))}
        </div>
      </div>

      {/* Haptic state machine */}
      <div style={{fontSize:10, fontWeight:500, textTransform:"uppercase", letterSpacing:"0.08em", color:"var(--color-text-tertiary)", marginBottom:8}}>Haptic state machine — click to expand</div>
      <div style={{display:"flex", flexDirection:"column", gap:4}}>
        {HAPTIC_STATES.map(s => (
          <div key={s.id}
            onClick={() => setOpenState(openState === s.id ? null : s.id)}
            style={{
              background:"var(--color-background-primary)",
              border:`0.5px solid ${openState===s.id ? s.color : "var(--color-border-tertiary)"}`,
              borderLeft:`3px solid ${s.color}`,
              borderRadius:"var(--border-radius-md)",
              padding:"8px 10px",
              cursor:"pointer",
            }}>
            <div style={{display:"flex", alignItems:"center", justifyContent:"space-between", gap:8}}>
              <div style={{minWidth:0}}>
                <span style={{fontSize:12, fontWeight:500, color:"var(--color-text-primary)"}}>{s.label}</span>
                <span style={{fontSize:11, color:"var(--color-text-tertiary)", marginLeft:8}}>{s.desc}</span>
              </div>
              <div style={{display:"flex", gap:10, alignItems:"flex-end", flexShrink:0}}>
                <div style={{display:"flex", flexDirection:"column", alignItems:"center", gap:3}}>
                  <span style={{fontSize:9, color:"var(--color-text-tertiary)"}}>L</span>
                  <MotorBar intensity={s.leftI} color={s.color}/>
                </div>
                <div style={{display:"flex", flexDirection:"column", alignItems:"center", gap:3}}>
                  <span style={{fontSize:9, color:"var(--color-text-tertiary)"}}>R</span>
                  <MotorBar intensity={s.rightI} color={s.color}/>
                </div>
              </div>
            </div>
            {openState === s.id && (
              <div style={{marginTop:10, paddingTop:10, borderTop:"0.5px solid var(--color-border-tertiary)", display:"grid", gridTemplateColumns:"1fr 1fr 1fr", gap:10}}>
                <div>
                  <div style={{fontSize:10, color:"var(--color-text-tertiary)", marginBottom:3}}>Left motor (body)</div>
                  <div style={{fontSize:12, color:"var(--color-text-primary)"}}>{s.leftP}</div>
                </div>
                <div>
                  <div style={{fontSize:10, color:"var(--color-text-tertiary)", marginBottom:3}}>Right motor (fingertip)</div>
                  <div style={{fontSize:12, color:"var(--color-text-primary)"}}>{s.rightP}</div>
                </div>
                <div>
                  <div style={{fontSize:10, color:"var(--color-text-tertiary)", marginBottom:3}}>Trigger feel</div>
                  <div style={{fontSize:12, color:"var(--color-text-primary)"}}>{s.trigger}</div>
                </div>
              </div>
            )}
          </div>
        ))}
      </div>

      {/* HUD corner note */}
      <div style={{marginTop:14, padding:"8px 12px", background:"var(--color-background-secondary)", borderRadius:"var(--border-radius-md)", fontSize:11, color:"var(--color-text-secondary)"}}>
        HUD overlay target: render active mode name + face button assignments as a corner widget in vr.html. Paddles switch layers without thumb-lift.
      </div>
    </div>
  );
}
