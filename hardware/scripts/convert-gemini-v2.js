// convert-gemini-v2.js
// Converts Google Takeout Gemini export → SemanticTwinVault markdown
//
// Google Takeout Gemini format (Takeout/Gemini Apps Activity/):
//   - myactivity.json  (activity log, array of conversation objects)
//   - OR individual JSON files per conversation
//
// Each conversation object looks like:
//   { title, create_time, update_time,
//     conversation: [ { role:"user"|"model", parts:[{text}] }, ... ] }
//   OR the older format:
//   { title, human_turn: [{text}], model_turn: [{text}] }
//
// Handles both formats automatically.
//
// Improvements:
//   - Shared vocabulary with Claude/Copilot converters
//   - Sliding-window chunking
//   - Delta mode via .manifest-gemini.json
//   - source: "gemini" on all frontmatter
//   - Auto-detects single myactivity.json or folder of per-conversation JSONs
//
// Run:  node convert-gemini-v2.js [--full] [--input PATH]
//   --input PATH  path to myactivity.json or folder of JSONs (default: auto-detect)

const fs     = require('fs');
const path   = require('path');
const crypto = require('crypto');

const {
  categorizeMulti, extractTags, detectDocType, extractConcepts,
  sanitize, toWikiLink, formatDate,
  buildFrontmatter, chunkMessages, loadManifest, saveManifest
} = require('./shared-patterns');

// === CONFIG ===
const OUTPUT_DIR    = 'SemanticTwinVault';
const MANIFEST_FILE = 'SemanticTwinVault/.manifest-gemini.json';
const SOURCE        = 'gemini';
const MIN_CHARS     = 50;    // activity log entries are prompt-only (no AI response)
const MIN_TURNS     = 1;    // single-turn prompts are still useful for semantic search
const CHUNK_SIZE    = 40;
const CHUNK_OVERLAP = 6;
const FULL          = process.argv.includes('--full');

// Auto-detect input: --input flag, myactivity.json, or Gemini/ folder
function detectInput() {
  const flagIdx = process.argv.indexOf('--input');
  if (flagIdx >= 0) return process.argv[flagIdx + 1];
  if (fs.existsSync('myactivity.json'))    return 'myactivity.json';
  if (fs.existsSync('Gemini'))             return 'Gemini';
  // Walk up to see if there's a Takeout folder
  const candidates = fs.readdirSync('.').filter(f =>
    f.toLowerCase().includes('gemini') && (f.endsWith('.json') || fs.statSync(f).isDirectory())
  );
  if (candidates.length) return candidates[0];
  console.error('❌ Cannot find Gemini input. Use --input PATH to specify.');
  process.exit(1);
}

const INPUT_PATH = detectInput();

// ─── HTML ENTITY / TAG STRIPPER ─────────────────────────────────────────────
// Used to clean the safeHtmlItem AI response HTML

function stripHtml(html) {
  if (!html) return '';
  return html
    .replace(/<br\s*\/?>/gi, '\n')
    .replace(/<\/p>/gi, '\n\n')
    .replace(/<\/li>/gi, '\n')
    .replace(/<\/h[1-6]>/gi, '\n\n')
    .replace(/<code[^>]*>([\s\S]*?)<\/code>/gi, (_, c) => '`' + c + '`')
    .replace(/<pre[^>]*>([\s\S]*?)<\/pre>/gi, (_, c) => '\n```\n' + c + '\n```\n')
    .replace(/<[^>]+>/g, '')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&#(\d+);/g, (_, n) => String.fromCharCode(Number(n)))
    .replace(/\u00A0/g, ' ')
    .replace(/\n{3,}/g, '\n\n')
    .trim();
}

// ─── FORMAT NORMALIZER ───────────────────────────────────────────────────────
// Returns an ARRAY of interaction objects: { prompt, response, time }
// (one per myactivity.json entry). Caller groups these by day.

function extractInteractions(items) {
  const interactions = [];

  for (const raw of items) {
    // ── myactivity.json format (Google Takeout) ───────────────────────────
    // { header:"Gemini Apps", title:"user prompt", time:"...",
    //   safeHtmlItem:[{ html:"<p>AI response...</p>" }] }
    if (raw.header && raw.time) {
      const prompt = (raw.title || '').trim();
      if (!prompt) continue;

      let response = '';
      const htmlItems = raw.safeHtmlItem || raw.safehtml || [];
      if (htmlItems.length > 0) {
        response = stripHtml(htmlItems[0].html || '');
      }

      interactions.push({ prompt, response, time: raw.time });
      continue;
    }

    // ── Full conversation format: conversation array ───────────────────────
    if (Array.isArray(raw.conversation)) {
      // Emit as a single grouped interaction for normalisation below
      interactions.push({ _fullConv: raw });
      continue;
    }

    // ── Older human_turn/model_turn format ────────────────────────────────
    if (Array.isArray(raw.human_turn) || Array.isArray(raw.model_turn)) {
      interactions.push({ _fullConv: raw });
      continue;
    }
  }

  return interactions;
}

// Group activity-log interactions by day into conversation-shaped objects
function groupByDay(interactions) {
  const days = new Map();

  for (const item of interactions) {
    // Full conversation objects pass through unchanged
    if (item._fullConv) {
      const raw = item._fullConv;
      const key = (raw.create_time || '').split('T')[0] || 'unknown';
      if (!days.has(key)) days.set(key, { turns: [], time: raw.create_time || '' });
      const entry = days.get(key);

      if (Array.isArray(raw.conversation)) {
        for (const turn of raw.conversation) {
          const text = (turn.parts || []).map(p => p.text || '').join('\n').trim();
          if (text) entry.turns.push({
            sender: (turn.role||'').toLowerCase() === 'model' ? 'assistant' : 'human',
            text, time: turn.create_time || raw.create_time || ''
          });
        }
      } else {
        const human = raw.human_turn || [];
        const model = raw.model_turn || [];
        const maxLen = Math.max(human.length, model.length);
        for (let i = 0; i < maxLen; i++) {
          if (human[i]) {
            const text = human[i].text || (human[i].parts||[]).map(p=>p.text||'').join('\n');
            if (text.trim()) entry.turns.push({ sender:'human', text:text.trim(), time: human[i].timestamp||'' });
          }
          if (model[i]) {
            const text = model[i].text || (model[i].parts||[]).map(p=>p.text||'').join('\n');
            if (text.trim()) entry.turns.push({ sender:'assistant', text:text.trim(), time: model[i].timestamp||'' });
          }
        }
      }
      continue;
    }

    // Activity log pair: human prompt + AI response
    const day = (item.time || '').split('T')[0] || 'unknown';
    if (!days.has(day)) days.set(day, { turns: [], time: item.time || '' });
    const entry = days.get(day);

    if (item.prompt) entry.turns.push({ sender:'human',    text: item.prompt,   time: item.time });
    if (item.response) entry.turns.push({ sender:'assistant', text: item.response, time: item.time });
  }

  // Convert to conversation objects sorted by day
  return Array.from(days.entries())
    .sort(([a],[b]) => a.localeCompare(b))
    .map(([day, entry]) => ({
      title:   `Gemini_Session_${day}`,
      created: entry.time,
      updated: entry.time,
      turns:   entry.turns
    }));
}

// ─── FILE LOADER ────────────────────────────────────────────────────────────

function loadConversations(inputPath) {
  const stat = fs.statSync(inputPath);

  let allItems = [];

  if (stat.isDirectory()) {
    const files = fs.readdirSync(inputPath)
      .filter(f => f.endsWith('.json'))
      .map(f => path.join(inputPath, f));
    for (const f of files) {
      try {
        const raw = JSON.parse(fs.readFileSync(f, 'utf8'));
        allItems = allItems.concat(Array.isArray(raw) ? raw : [raw]);
      } catch(e) { console.warn(`  ⚠️  Skipping ${f}: ${e.message}`); }
    }
  } else {
    const raw = JSON.parse(fs.readFileSync(inputPath, 'utf8'));
    allItems = Array.isArray(raw) ? raw : [raw];
  }

  console.log(`   Loaded ${allItems.length} raw items from export`);

  const interactions = extractInteractions(allItems);
  console.log(`   Extracted ${interactions.length} interactions`);

  const conversations = groupByDay(interactions);
  console.log(`   Grouped into ${conversations.length} daily sessions`);

  return conversations;
}

// ─── DOCUMENT BUILDER ───────────────────────────────────────────────────────

function stableId(s) {
  const h = crypto.createHash('sha1').update(s).digest('hex');
  return `${h.slice(0,8)}-${h.slice(8,12)}-5${h.slice(13,16)}-${(parseInt(h.slice(16,18),16)&0x3f|0x80).toString(16).padStart(2,'0')}${h.slice(18,20)}-${h.slice(20,32)}`;
}

function buildChunkDoc({ name, uuid, turns, partNumber, totalParts, allTopics, primaryTopic, subcategories, tags, docTypes, concepts, relatedDocs, firstDate }) {
  const titleSuffix = totalParts > 1 ? ` (Part ${partNumber} of ${totalParts})` : '';
  const chunkStart  = (turns[0]?.time?.split('T')[0]) || firstDate;
  const chunkEnd    = (turns[turns.length-1]?.time?.split('T')[0]) || firstDate;

  const fm = buildFrontmatter({
    title:         `${name}${titleSuffix}`,
    conversation:   name,
    source:         SOURCE,
    theme:          primaryTopic,
    topics:         allTopics,
    subcategories: [...new Set(subcategories)],
    doc_type:       docTypes,
    tags,
    concepts:       concepts.slice(0,10),
    related:        relatedDocs,
    uuid,
    part:           partNumber,
    total_parts:    totalParts,
    created:        firstDate,
    chunk_start:    chunkStart,
    chunk_end:      chunkEnd,
    message_count:  turns.length
  });

  const breadcrumb = `> [!info] Topics: ${allTopics.map(t=>`[[${t}]]`).join(' > ')}\n\n`;
  const partNote   = totalParts > 1 ? `> **Part ${partNumber} of ${totalParts}**\n\n` : '';

  const body = turns.map(t => {
    const role = t.sender === 'human' ? '**Human**' : '**Gemini**';
    const ts   = t.time ? ` *(${t.time.split('T')[0]})*` : '';
    return `### ${role}${ts}\n\n${t.text}`;
  }).join('\n\n---\n\n');

  const wikiLinks = relatedDocs.length > 0
    ? `\n\n---\n## Related Notes\n${relatedDocs.join(' | ')}\n`
    : '';

  const filename = totalParts > 1
    ? `${firstDate}_${sanitize(name)}_Part${partNumber}.md`
    : `${firstDate}_${sanitize(name)}.md`;

  return { filename, content: fm + breadcrumb + partNote + `## Conversation\n\n` + body + wikiLinks };
}

// ─── MAIN ───────────────────────────────────────────────────────────────────

console.log('📊 Starting Gemini Converter v2...\n');
if (FULL) console.log('⚠️  --full: reprocessing everything\n');
console.log(`📄 Input: ${INPUT_PATH}\n`);

const rawConvs = loadConversations(INPUT_PATH);
console.log(`✓ Loaded ${rawConvs.length} conversations from export\n`);

// Filter short ones
const conversations = rawConvs.filter(c => {
  const total = c.turns.reduce((s,t) => s + t.text.length, 0);
  return total >= MIN_CHARS && c.turns.length >= MIN_TURNS;
});
console.log(`✓ ${conversations.length} meet minimum length (${MIN_CHARS} chars)\n`);

const manifest    = loadManifest(MANIFEST_FILE, FULL);
const newManifest = { ...manifest };

// Build metadata for all (needed for related-doc linking)
const allDocs = conversations.map(c => {
  const fullText    = c.turns.map(t=>t.text).join('\n\n');
  const fullContent = `${c.title}\n\n${fullText}`;
  const categories  = categorizeMulti(fullContent);
  const id          = stableId(`gemini::${c.title}::${c.created}`);
  const fingerprint = crypto.createHash('sha1').update(fullText).digest('hex').slice(0,16);
  const changed     = !manifest[id] || manifest[id].fp !== fingerprint;
  const firstDate   = formatDate(c.created);

  return {
    uuid: id, name: c.title, turns: c.turns,
    firstDate, changed, fingerprint,
    fullContent,
    primaryTopic:  categories[0].topic,
    allTopics:     categories.map(x=>x.topic),
    subcategories: categories.flatMap(x=>x.subcategories),
    tags:      extractTags(fullContent),
    docTypes:  detectDocType(fullContent),
    concepts:  extractConcepts(fullContent)
  };
});

const toWrite = allDocs.filter(d => d.changed);
console.log(`✓ ${toWrite.length} conversations need writing (${allDocs.length - toWrite.length} unchanged)\n`);

// Group by topic
const byTopic = {};
for (const doc of allDocs) {
  if (!byTopic[doc.primaryTopic]) byTopic[doc.primaryTopic] = [];
  byTopic[doc.primaryTopic].push(doc);
}

let written = 0, totalChunks = 0;

for (const [topic, entries] of Object.entries(byTopic)) {
  const convPath = path.join(OUTPUT_DIR, topic, 'Conversations');
  fs.mkdirSync(convPath, { recursive: true });

  for (const doc of entries) {
    const relatedDocs = allDocs
      .filter(d => d !== doc)
      .filter(d => {
        const shared = doc.concepts.filter(c => d.concepts.some(dc=>dc.toLowerCase()===c.toLowerCase()));
        return shared.length > 0 || doc.allTopics.filter(t=>d.allTopics.includes(t)).length > 1;
      })
      .slice(0,5)
      .map(d => `[[${toWikiLink(d.name)}]]`);

    const chunks = chunkMessages(doc.turns, CHUNK_SIZE, CHUNK_OVERLAP);
    totalChunks += chunks.length;

    if (doc.changed) {
      for (const chunk of chunks) {
        const chunkUuid = chunk.totalParts > 1
          ? stableId(`${doc.uuid}::p${chunk.partNumber}`)
          : doc.uuid;

        const { filename, content } = buildChunkDoc({
          name:        doc.name,
          uuid:        chunkUuid,
          turns:       chunk.messages,
          partNumber:  chunk.partNumber,
          totalParts:  chunk.totalParts,
          allTopics:   doc.allTopics,
          primaryTopic: doc.primaryTopic,
          subcategories: doc.subcategories,
          tags:        doc.tags,
          docTypes:    doc.docTypes,
          concepts:    doc.concepts,
          relatedDocs,
          firstDate:   doc.firstDate
        });
        fs.writeFileSync(path.join(convPath, filename), content);
        written++;
      }
      newManifest[doc.uuid] = { fp: doc.fingerprint, chunks: chunks.length, topic: doc.primaryTopic };
    }
  }

  // Topic index
  const idxPath = path.join(OUTPUT_DIR, topic, 'Index.md');
  let idx = fs.existsSync(idxPath) ? fs.readFileSync(idxPath,'utf8') : '';
  if (!idx.includes('## Conversations')) {
    const section = `\n## Conversations\n\n**Total:** ${entries.length}\n\n` +
      entries.map(d => {
        const c = chunkMessages(d.turns, CHUNK_SIZE, CHUNK_OVERLAP);
        return `- [[${toWikiLink(d.name)}]] — ${d.docTypes[0]} (${d.turns.length} turns)${c.length>1?` [${c.length} parts]`:''}`;
      }).join('\n') + '\n';
    fs.writeFileSync(idxPath, (idx || `# ${topic}\n`) + section);
  }
}

saveManifest(MANIFEST_FILE, newManifest);

console.log('✅ Gemini conversion complete!\n');
console.log('📊 Summary:');
console.log(`   - ${conversations.length} conversations processed`);
console.log(`   - ${toWrite.length} written (${conversations.length - toWrite.length} unchanged)`);
console.log(`   - ${totalChunks} total chunks, ${written} files written`);
console.log(`   - ${Object.keys(byTopic).length} topics`);
console.log(`\n💡 Next run: node convert-gemini-v2.js             (delta)`);
console.log(`              node convert-gemini-v2.js --full      (full reprocess)`);
console.log(`              node convert-gemini-v2.js --input PATH`);
