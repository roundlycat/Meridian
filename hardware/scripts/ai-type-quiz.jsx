import { useState } from "react";

const questions = [
  {
    id: 1,
    text: "When you start a task with AI, who decides what the task actually is?",
    options: [
      { label: "I do — I know what I need and I direct everything from the start.", scores: { cyborg: 1, centaur: 3, automator: 0 } },
      { label: "It emerges — I have a rough idea and the conversation shapes it.", scores: { cyborg: 3, centaur: 1, automator: 0 } },
      { label: "I hand the brief over and see what comes back.", scores: { cyborg: 0, centaur: 0, automator: 3 } },
    ],
  },
  {
    id: 2,
    text: "How do you handle an AI output you're not sure about?",
    options: [
      { label: "I push back, probe it, expose the contradiction, iterate until I trust it.", scores: { cyborg: 3, centaur: 1, automator: 0 } },
      { label: "I verify it against my own domain knowledge before using it.", scores: { cyborg: 0, centaur: 3, automator: 0 } },
      { label: "Polish it and move on — it's usually fine.", scores: { cyborg: 0, centaur: 0, automator: 3 } },
    ],
  },
  {
    id: 3,
    text: "Which best describes your typical AI session?",
    options: [
      { label: "A conversation — back and forth, personas assigned, ideas extended.", scores: { cyborg: 3, centaur: 0, automator: 0 } },
      { label: "A targeted lookup — specific questions, structured, then I take over.", scores: { cyborg: 0, centaur: 3, automator: 0 } },
      { label: "A delegation — I describe the job, review the output, done.", scores: { cyborg: 0, centaur: 0, automator: 3 } },
    ],
  },
  {
    id: 4,
    text: "After a major AI-assisted project, what have you gained?",
    options: [
      { label: "New AI fluency — I know how to prompt, when to distrust, when to push.", scores: { cyborg: 3, centaur: 0, automator: 0 } },
      { label: "Deeper domain expertise — the questions I asked sharpened my own thinking.", scores: { cyborg: 0, centaur: 3, automator: 0 } },
      { label: "A finished deliverable, mostly.", scores: { cyborg: 0, centaur: 0, automator: 3 } },
    ],
  },
  {
    id: 5,
    text: "The AI gives you a confident, well-written answer that feels slightly off. You:",
    options: [
      { label: "Keep the thread alive — probe where the confidence comes from.", scores: { cyborg: 3, centaur: 1, automator: 0 } },
      { label: "Set the AI output aside and run the analysis myself.", scores: { cyborg: 0, centaur: 3, automator: 0 } },
      { label: "Use it — it reads well and I'm on deadline.", scores: { cyborg: 0, centaur: 0, automator: 3 } },
    ],
  },
  {
    id: 6,
    text: "How would you describe the boundary between your thinking and the AI's?",
    options: [
      { label: "Deliberately blurred — I want to think with it, not just through it.", scores: { cyborg: 3, centaur: 0, automator: 0 } },
      { label: "Clear — I own the logic, the AI handles specific support tasks.", scores: { cyborg: 0, centaur: 3, automator: 0 } },
      { label: "Not really my concern — I care about the output, not the process.", scores: { cyborg: 0, centaur: 0, automator: 3 } },
    ],
  },
];

const results = {
  cyborg: {
    label: "Cyborg",
    icon: "🤖",
    tagline: "Fused Knowledge Co-Creation",
    colour: "#6366f1",
    bg: "#eef2ff",
    description:
      "You and the AI think together. The boundary between your cognition and the machine's is deliberately porous — you assign personas, break tasks into modules, push back on outputs, expose contradictions. You're not using AI as a tool; you're using it as an extension of your own reasoning process. The research shows Cyborgs develop new AI-related expertise — "newskilling" — even as they risk being led astray by confident-but-wrong outputs. The antidote, which you likely already practise: knowing when to distrust the conversation.",
    note: "Highest in persuasiveness. Slightly less accurate than Centaurs — watch for AI overconfidence.",
  },
  centaur: {
    label: "Centaur",
    icon: "🐎",
    tagline: "Directed Knowledge Co-Creation",
    colour: "#059669",
    bg: "#ecfdf5",
    description:
      "You drive. The AI carries specific loads. You know what you need before you open the chat, ask targeted questions, and never hand over the steering wheel. Your domain expertise deepens through this process — the questions you form in order to ask the AI sharpen your own understanding. The research found Centaurs had the highest accuracy of the three types, precisely because they didn't let AI substitute for their own judgment.",
    note: "Highest accuracy. Strong domain upskilling. Trades off some AI fluency.",
  },
  automator: {
    label: "Self-Automator",
    icon: "⚡",
    tagline: "Abdicated Knowledge Co-Creation",
    colour: "#d97706",
    bg: "#fffbeb",
    description:
      "You delegate the whole workflow. The output is polished and arrives fast. The research is fairly direct about the cost: Self-Automators gained neither domain expertise nor AI fluency, and their outputs lagged in accuracy and persuasiveness. That said — context matters. For truly low-stakes, high-volume busywork, full delegation is rational. The question is whether you're doing it selectively or as a default.",
    note: "Fastest output. Lowest accuracy and persuasiveness. No skill accrual.",
  },
};

export default function Quiz() {
  const [answers, setAnswers] = useState({});
  const [done, setDone] = useState(false);

  const pick = (qid, scores) => {
    setAnswers((prev) => ({ ...prev, [qid]: scores }));
  };

  const tally = () => {
    const totals = { cyborg: 0, centaur: 0, automator: 0 };
    Object.values(answers).forEach((s) => {
      totals.cyborg += s.cyborg;
      totals.centaur += s.centaur;
      totals.automator += s.automator;
    });
    return totals;
  };

  const winner = () => {
    const t = tally();
    return Object.entries(t).sort((a, b) => b[1] - a[1])[0][0];
  };

  const maxScore = questions.length * 3;

  const answered = Object.keys(answers).length;
  const allDone = answered === questions.length;

  if (done) {
    const type = winner();
    const scores = tally();
    const r = results[type];
    return (
      <div style={{ fontFamily: "system-ui, sans-serif", maxWidth: 600, margin: "0 auto", padding: "2rem 1.5rem" }}>
        <div style={{ background: r.bg, border: `2px solid ${r.colour}`, borderRadius: 16, padding: "2rem", marginBottom: "1.5rem" }}>
          <div style={{ fontSize: 48, marginBottom: 8 }}>{r.icon}</div>
          <div style={{ fontSize: 11, fontWeight: 700, letterSpacing: 2, color: r.colour, textTransform: "uppercase", marginBottom: 4 }}>
            You are a
          </div>
          <div style={{ fontSize: 32, fontWeight: 800, color: "#111", marginBottom: 4 }}>{r.label}</div>
          <div style={{ fontSize: 13, color: r.colour, fontWeight: 600, marginBottom: 16 }}>{r.tagline}</div>
          <p style={{ fontSize: 15, color: "#374151", lineHeight: 1.7, margin: 0 }}>{r.description}</p>
          <div style={{ marginTop: 16, padding: "10px 14px", background: "white", borderRadius: 8, fontSize: 13, color: "#6b7280", fontStyle: "italic" }}>
            {r.note}
          </div>
        </div>

        {/* Score breakdown */}
        <div style={{ background: "#f9fafb", borderRadius: 12, padding: "1.25rem", marginBottom: "1.5rem" }}>
          <div style={{ fontSize: 12, fontWeight: 700, color: "#6b7280", textTransform: "uppercase", letterSpacing: 1, marginBottom: 12 }}>Score breakdown</div>
          {Object.entries(scores).map(([k, v]) => {
            const res = results[k];
            const pct = Math.round((v / maxScore) * 100);
            return (
              <div key={k} style={{ marginBottom: 10 }}>
                <div style={{ display: "flex", justifyContent: "space-between", fontSize: 13, marginBottom: 4 }}>
                  <span style={{ fontWeight: 600, color: res.colour }}>{res.icon} {res.label}</span>
                  <span style={{ color: "#6b7280" }}>{v}/{maxScore}</span>
                </div>
                <div style={{ background: "#e5e7eb", borderRadius: 99, height: 6 }}>
                  <div style={{ background: res.colour, width: `${pct}%`, height: 6, borderRadius: 99, transition: "width 0.5s" }} />
                </div>
              </div>
            );
          })}
        </div>

        <button
          onClick={() => { setAnswers({}); setDone(false); }}
          style={{ background: "#111", color: "white", border: "none", borderRadius: 8, padding: "10px 20px", fontSize: 14, cursor: "pointer" }}
        >
          Retake quiz
        </button>
      </div>
    );
  }

  return (
    <div style={{ fontFamily: "system-ui, sans-serif", maxWidth: 600, margin: "0 auto", padding: "2rem 1.5rem" }}>
      <div style={{ marginBottom: "1.5rem" }}>
        <div style={{ fontSize: 11, fontWeight: 700, letterSpacing: 2, color: "#6b7280", textTransform: "uppercase", marginBottom: 6 }}>MIT Sloan Research</div>
        <div style={{ fontSize: 24, fontWeight: 800, color: "#111", lineHeight: 1.3, marginBottom: 8 }}>
          Cyborg, Centaur, or Self-Automator?
        </div>
        <div style={{ fontSize: 13, color: "#6b7280" }}>{answered} of {questions.length} answered</div>
        <div style={{ background: "#e5e7eb", borderRadius: 99, height: 4, marginTop: 8 }}>
          <div style={{ background: "#6366f1", width: `${(answered / questions.length) * 100}%`, height: 4, borderRadius: 99, transition: "width 0.3s" }} />
        </div>
      </div>

      {questions.map((q) => {
        const selected = answers[q.id];
        return (
          <div key={q.id} style={{ marginBottom: "1.5rem", background: "#f9fafb", borderRadius: 12, padding: "1.25rem" }}>
            <div style={{ fontSize: 14, fontWeight: 700, color: "#111", marginBottom: 12, lineHeight: 1.5 }}>
              <span style={{ color: "#9ca3af", marginRight: 8 }}>{q.id}.</span>{q.text}
            </div>
            {q.options.map((opt, i) => {
              const isSelected = selected === opt.scores;
              return (
                <button
                  key={i}
                  onClick={() => pick(q.id, opt.scores)}
                  style={{
                    display: "block",
                    width: "100%",
                    textAlign: "left",
                    padding: "10px 14px",
                    marginBottom: 8,
                    borderRadius: 8,
                    border: isSelected ? "2px solid #6366f1" : "2px solid #e5e7eb",
                    background: isSelected ? "#eef2ff" : "white",
                    fontSize: 14,
                    color: "#111",
                    cursor: "pointer",
                    lineHeight: 1.5,
                    transition: "all 0.15s",
                  }}
                >
                  {opt.label}
                </button>
              );
            })}
          </div>
        );
      })}

      <button
        disabled={!allDone}
        onClick={() => setDone(true)}
        style={{
          width: "100%",
          padding: "14px",
          borderRadius: 10,
          border: "none",
          background: allDone ? "#111" : "#d1d5db",
          color: "white",
          fontSize: 15,
          fontWeight: 700,
          cursor: allDone ? "pointer" : "default",
          transition: "background 0.2s",
        }}
      >
        {allDone ? "See my result →" : `Answer all ${questions.length} questions to continue`}
      </button>
    </div>
  );
}
