/**
 * convert-claudecode-v2.js
 * Semantic Twin Converter — Claude Code history (history-clean.jsonl)
 *
 * Reads the Claude Code prompt history, groups by project/session,
 * applies sliding-window chunking, and outputs JSONL chunks ready
 * for pgvector ingestion via the standard semantic twin pipeline.
 *
 * Filters applied upstream:
 *   - /rate-limit-options entries removed (history-clean.jsonl)
 *
 * Usage:
 *   node convert-claudecode-v2.js [--full]
 *
 * --full  reprocesses all entries regardless of delta tracking
 */

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

// ── Config ──────────────────────────────────────────────────────────────────

const INPUT_FILE    = path.join(__dirname, 'history-clean.jsonl');
const OUTPUT_FILE   = path.join(__dirname, 'output', 'claudecode-chunks.jsonl');
const DELTA_FILE    = path.join(__dirname, 'output', 'claudecode-delta.json');

const WINDOW_SIZE   = 5;   // messages per sliding window chunk
const WINDOW_STEP   = 2;   // step between windows
const SOURCE_TAG    = 'claude-code';
const MIN_DISPLAY   = 4;   // skip single keystrokes / noise below this length

// ── Helpers ─────────────────────────────────────────────────────────────────

function hash(str) {
  return crypto.createHash('sha256').update(str).digest('hex').slice(0, 16);
}

function projectLabel(fullPath) {
  if (!fullPath) return 'unknown';
  const parts = fullPath.replace(/\\/g, '/').split('/');
  // Return last 2 meaningful segments
  return parts.filter(Boolean).slice(-2).join('/');
}

function isoDate(tsMs) {
  return new Date(tsMs).toISOString();
}

// ── Load & filter ────────────────────────────────────────────────────────────

const isFull = process.argv.includes('--full');

let entries = [];
const raw = fs.readFileSync(INPUT_FILE, 'utf8').trim().split('\n');
for (const line of raw) {
  try {
    const e = JSON.parse(line);
    const display = (e.display || '').trim();
    if (display.length >= MIN_DISPLAY) {
      entries.push(e);
    }
  } catch (_) {}
}

console.log(`📂 Loaded ${entries.length} entries from ${path.basename(INPUT_FILE)}`);

// ── Delta tracking ───────────────────────────────────────────────────────────

let seen = new Set();
if (!isFull && fs.existsSync(DELTA_FILE)) {
  try {
    seen = new Set(JSON.parse(fs.readFileSync(DELTA_FILE, 'utf8')));
    console.log(`🔁 Delta mode: ${seen.size} previously processed chunks`);
  } catch (_) {}
}

// ── Group by session ─────────────────────────────────────────────────────────

const sessions = new Map();
for (const e of entries) {
  const sid = e.sessionId || hash(e.project + String(e.timestamp));
  if (!sessions.has(sid)) {
    sessions.set(sid, { project: e.project, messages: [], earliest: e.timestamp });
  }
  const s = sessions.get(sid);
  s.messages.push(e);
  if (e.timestamp < s.earliest) s.earliest = e.timestamp;
}

console.log(`📦 ${sessions.size} sessions across ${new Set(entries.map(e => e.project)).size} projects`);

// ── Sliding-window chunking ──────────────────────────────────────────────────

fs.mkdirSync(path.dirname(OUTPUT_FILE), { recursive: true });
const out  = fs.createWriteStream(OUTPUT_FILE);
const newSeen = new Set(seen);

let chunkCount = 0;
let skipCount  = 0;

for (const [sid, session] of sessions) {
  const msgs    = session.messages.sort((a, b) => a.timestamp - b.timestamp);
  const project = projectLabel(session.project);
  const date    = isoDate(session.earliest).slice(0, 10);

  for (let i = 0; i < msgs.length; i += WINDOW_STEP) {
    const window = msgs.slice(i, i + WINDOW_SIZE);
    if (window.length === 0) break;

    const text = window
      .map(m => m.display.trim())
      .join('\n\n---\n\n');

    const chunkId = hash(sid + String(i) + text);

    if (seen.has(chunkId)) {
      skipCount++;
      continue;
    }

    const chunk = {
      id:        chunkId,
      source:    SOURCE_TAG,
      project,
      session_id: sid,
      date,
      window_start: i,
      window_size:  window.length,
      timestamp:    isoDate(window[0].timestamp),
      text,
      metadata: {
        projects: [...new Set(window.map(m => projectLabel(m.project)))],
        prompt_count: window.length,
      }
    };

    out.write(JSON.stringify(chunk) + '\n');
    newSeen.add(chunkId);
    chunkCount++;
  }
}

out.end();

// Save delta
fs.writeFileSync(DELTA_FILE, JSON.stringify([...newSeen], null, 2));

console.log(`\n✅ Output: ${OUTPUT_FILE}`);
console.log(`   Chunks written : ${chunkCount}`);
console.log(`   Chunks skipped : ${skipCount} (delta)`);
console.log(`   Delta saved    : ${newSeen.size} total known chunks`);
