import { useState } from "react";

const SONNET_4 = "claude-sonnet-4-20250514";
const INPUT_COST_PER_MTok = 3.0;
const OUTPUT_COST_PER_MTok = 15.0;

function costUSD(inputTok, outputTok) {
  return (inputTok * INPUT_COST_PER_MTok + outputTok * OUTPUT_COST_PER_MTok) / 1_000_000;
}

function GaugeBar({ tokens, maxRef = 8000 }) {
  const pct = Math.min((tokens / maxRef) * 100, 100);
  const color =
    pct < 25 ? "#1D9E75" : pct < 60 ? "#BA7517" : "#A32D2D";
  return (
    <div>
      <div style={{ display: "flex", justifyContent: "space-between", marginBottom: 5 }}>
        <span style={{ fontSize: 11, color: "var(--color-text-secondary)", fontFamily: "var(--font-mono)" }}>
          request load
        </span>
        <span style={{ fontSize: 11, color: "var(--color-text-secondary)", fontFamily: "var(--font-mono)" }}>
          {tokens.toLocaleString()} / {maxRef.toLocaleString()} tok
        </span>
      </div>
      <div style={{
        height: 6, background: "var(--color-background-secondary)",
        borderRadius: 3, overflow: "hidden",
        border: "0.5px solid var(--color-border-tertiary)"
      }}>
        <div style={{
          width: `${pct.toFixed(1)}%`, height: "100%",
          background: color, borderRadius: 3,
          transition: "width 0.6s ease, background 0.4s"
        }} />
      </div>
      <div style={{ display: "flex", justifyContent: "space-between", marginTop: 4 }}>
        <span style={{ fontSize: 10, color: "var(--color-text-tertiary)" }}>light</span>
        <span style={{ fontSize: 10, color: "var(--color-text-tertiary)" }}>heavy  (8k ref)</span>
      </div>
    </div>
  );
}

function MetricCard({ label, value, accent }) {
  return (
    <div style={{
      background: accent ? "var(--color-background-info)" : "var(--color-background-secondary)",
      borderRadius: "var(--border-radius-md)",
      padding: "10px 14px"
    }}>
      <div style={{ fontSize: 10, color: accent ? "var(--color-text-info)" : "var(--color-text-secondary)", marginBottom: 4, fontFamily: "var(--font-mono)", letterSpacing: "0.04em" }}>
        {label}
      </div>
      <div style={{ fontSize: 18, fontWeight: 500, color: accent ? "var(--color-text-info)" : "var(--color-text-primary)", fontFamily: "var(--font-mono)" }}>
        {value}
      </div>
    </div>
  );
}

export default function ResourcesMeter() {
  const [prompt, setPrompt] = useState("");
  const [loading, setLoading] = useState(false);
  const [last, setLast] = useState(null);
  const [error, setError] = useState(null);
  const [session, setSession] = useState({ input: 0, output: 0, cost: 0, n: 0 });
  const [history, setHistory] = useState([]);

  const measure = async () => {
    if (!prompt.trim() || loading) return;
    setLoading(true);
    setError(null);
    try {
      const res = await fetch("https://api.anthropic.com/v1/messages", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          model: SONNET_4,
          max_tokens: 1000,
          system: "Respond concisely in 1–3 sentences.",
          messages: [{ role: "user", content: prompt }]
        })
      });
      const data = await res.json();
      if (data.error) throw new Error(data.error.message);

      const input = data.usage.input_tokens;
      const output = data.usage.output_tokens;
      const cost = costUSD(input, output);
      const ts = new Date().toLocaleTimeString("en-CA", { hour: "2-digit", minute: "2-digit", second: "2-digit" });
      const entry = { input, output, cost, ts, label: prompt.slice(0, 55) + (prompt.length > 55 ? "…" : "") };

      setLast(entry);
      setSession(s => ({ input: s.input + input, output: s.output + output, cost: s.cost + cost, n: s.n + 1 }));
      setHistory(h => [entry, ...h].slice(0, 12));
    } catch (e) {
      setError(e.message);
    } finally {
      setLoading(false);
    }
  };

  const resetSession = () => {
    setSession({ input: 0, output: 0, cost: 0, n: 0 });
    setHistory([]);
    setLast(null);
  };

  const totalTok = last ? last.input + last.output : 0;

  return (
    <div style={{ padding: "1rem 0" }}>
      <h2 className="sr-only">AI Resources Meter — token usage and cost estimator</h2>

      <div style={{ display: "flex", alignItems: "baseline", justifyContent: "space-between", marginBottom: "1rem" }}>
        <span style={{ fontSize: 13, fontWeight: 500, color: "var(--color-text-primary)", fontFamily: "var(--font-mono)" }}>
          resources meter
        </span>
        <span style={{ fontSize: 11, color: "var(--color-text-tertiary)", fontFamily: "var(--font-mono)" }}>
          sonnet-4 · $3 / $15 per MTok in/out
        </span>
      </div>

      <textarea
        value={prompt}
        onChange={e => setPrompt(e.target.value)}
        onKeyDown={e => { if (e.key === "Enter" && (e.metaKey || e.ctrlKey)) measure(); }}
        placeholder="Paste or type a prompt to measure its token weight and cost…"
        style={{
          width: "100%", boxSizing: "border-box",
          minHeight: 90, resize: "vertical",
          fontFamily: "var(--font-mono)", fontSize: 13,
          padding: "10px 12px",
          background: "var(--color-background-secondary)",
          border: "0.5px solid var(--color-border-secondary)",
          borderRadius: "var(--border-radius-md)",
          color: "var(--color-text-primary)",
          marginBottom: 10
        }}
      />

      <div style={{ display: "flex", gap: 8, marginBottom: "1.5rem" }}>
        <button onClick={measure} disabled={loading || !prompt.trim()}>
          {loading ? "measuring…" : "measure ↗"}
        </button>
        {session.n > 0 && (
          <button onClick={resetSession} style={{ fontSize: 12 }}>
            reset session
          </button>
        )}
      </div>

      {error && (
        <div style={{
          padding: "10px 12px", marginBottom: "1rem",
          background: "var(--color-background-danger)",
          borderRadius: "var(--border-radius-md)",
          color: "var(--color-text-danger)", fontSize: 13,
          fontFamily: "var(--font-mono)"
        }}>
          {error}
        </div>
      )}

      {last && (
        <>
          <div style={{ marginBottom: "1.25rem" }}>
            <GaugeBar tokens={totalTok} />
          </div>

          <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(120px, 1fr))", gap: 10, marginBottom: "1.5rem" }}>
            <MetricCard label="input tok" value={last.input.toLocaleString()} />
            <MetricCard label="output tok" value={last.output.toLocaleString()} />
            <MetricCard label="total tok" value={totalTok.toLocaleString()} />
            <MetricCard label="est. cost" value={`$${last.cost < 0.0001 ? last.cost.toFixed(6) : last.cost.toFixed(5)}`} />
          </div>
        </>
      )}

      {session.n > 0 && (
        <div style={{ borderTop: "0.5px solid var(--color-border-tertiary)", paddingTop: "1rem" }}>
          <div style={{ fontSize: 11, color: "var(--color-text-secondary)", marginBottom: 10, fontFamily: "var(--font-mono)" }}>
            session — {session.n} request{session.n !== 1 ? "s" : ""}
          </div>
          <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(120px, 1fr))", gap: 10, marginBottom: "1.25rem" }}>
            <MetricCard label="session input" value={session.input.toLocaleString()} accent />
            <MetricCard label="session output" value={session.output.toLocaleString()} accent />
            <MetricCard label="session cost" value={`$${session.cost.toFixed(4)}`} accent />
          </div>

          <div style={{ fontSize: 11, color: "var(--color-text-tertiary)", marginBottom: 8, fontFamily: "var(--font-mono)" }}>
            history
          </div>
          {history.map((item, i) => (
            <div key={i} style={{
              display: "grid",
              gridTemplateColumns: "1fr 80px 80px 60px",
              gap: 8,
              padding: "5px 0",
              borderBottom: "0.5px solid var(--color-border-tertiary)",
              fontSize: 11,
              fontFamily: "var(--font-mono)",
              alignItems: "center"
            }}>
              <span style={{ color: "var(--color-text-secondary)", overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
                {item.label}
              </span>
              <span style={{ color: "var(--color-text-tertiary)", textAlign: "right" }}>
                {(item.input + item.output).toLocaleString()} tok
              </span>
              <span style={{ color: "var(--color-text-secondary)", textAlign: "right" }}>
                ${item.cost.toFixed(5)}
              </span>
              <span style={{ color: "var(--color-text-tertiary)", textAlign: "right" }}>
                {item.ts}
              </span>
            </div>
          ))}
        </div>
      )}

      {!last && !loading && (
        <div style={{ textAlign: "center", padding: "2rem 1rem", color: "var(--color-text-tertiary)", fontSize: 12, fontFamily: "var(--font-mono)" }}>
          enter a prompt and press measure — or ⌘↵ / ctrl↵
        </div>
      )}
    </div>
  );
}
