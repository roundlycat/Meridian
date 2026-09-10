// Run with: node parse-copilot-turns.js
// Parses Copilot CSV conversations into alternating turn format like Claude conversations

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

// === CONFIG ===
const INPUT_FILE = 'copilotactivityhistory_16.csv';
const OUTPUT_DIR = 'SemanticTwinVault';
const MIN_LENGTH = 800; // Minimum total conversation length to process

// Topic patterns (from your existing parser)
const TOPIC_PATTERNS = {
  'Philosophy & Ethics': {
    keywords: ['wittgenstein', 'gadamer', 'kant', 'hermeneutic', 'ethics', 'resonance', 'phenomenology', 'epistemology', 'metaphysics', 'ontological', 'deontological', 'virtue ethics', 'moral', 'categorical imperative', 'latour', 'ricoeur', 'ihde', 'heidegger', 'husserl', 'merleau-ponty', 'levinas', 'alterity', 'naïveté'],
  },
  'Semantic Systems': {
    keywords: ['semantic twin', 'motif', 'dashboard', 'drift', 'telemetry', 'semantic web', 'linked data', 'knowledge graph', 'triple store', 'sparql', 'semantic layer', 'motif tracking', 'concept drift'],
  },
  'AI Architecture': {
    keywords: ['agent', 'modular', 'neural', 'jetson', 'esp32', 'transformer', 'llm', 'embedding', 'inference', 'fine-tuning', 'rag', 'prompt', 'chain of thought', 'multi-agent', 'agentic', 'claude', 'sonnet', 'opus', 'gpt', 'copilot', 'mcp', 'model context protocol'],
  },
  'Human–Machine Collaboration': {
    keywords: ['apprenticeship', 'co-creation', 'dialogical', 'human-in-the-loop', 'collaborative', 'augmentation', 'centaur', 'hybrid intelligence', 'human-ai', 'dialogue', 'encounter', 'threshold'],
  },
  'Knowledge Representation': {
    keywords: ['ontology', 'rdf', 'vector', 'owl', 'taxonomy', 'schema', 'knowledge base', 'graph database', 'neo4j', 'embeddings', 'semantic search', 'pgvector'],
  },
  'Software Engineering': {
    keywords: ['api', 'database', 'backend', 'frontend', 'devops', 'testing', 'refactoring', 'architecture', 'microservices', 'rest', 'graphql', 'visual studio', 'azure', 'kanban', 'mcp server'],
  },
  'Data & Analytics': {
    keywords: ['data pipeline', 'etl', 'analytics', 'visualization', 'statistics', 'machine learning', 'dataset', 'preprocessing', 'sql', 'postgresql'],
  }
};

// === HELPERS ===

function parseCSV(content) {
  const lines = [];
  let currentLine = [], currentField = '', inQuotes = false;

  for (let i = 0; i < content.length; i++) {
    const char = content[i], nextChar = content[i + 1];
    if (char === '"') {
      if (inQuotes && nextChar === '"') { currentField += '"'; i++; }
      else { inQuotes = !inQuotes; }
    } else if (char === ',' && !inQuotes) {
      currentLine.push(currentField); currentField = '';
    } else if (char === '\n' && !inQuotes) {
      currentLine.push(currentField);
      if (currentLine.some(f => f.trim())) lines.push(currentLine);
      currentLine = []; currentField = '';
    } else if (char !== '\r') {
      currentField += char;
    }
  }
  if (currentField || currentLine.length > 0) {
    currentLine.push(currentField);
    if (currentLine.some(f => f.trim())) lines.push(currentLine);
  }
  return lines;
}

function sanitize(str) {
  return str
    .replace(/[^\w\s-]/g, '')
    .replace(/\s+/g, '_')
    .substring(0, 50);
}

function categorizeContent(content) {
  const text = content.toLowerCase();
  const matches = [];

  for (const [topic, config] of Object.entries(TOPIC_PATTERNS)) {
    const keywords = config.keywords || config;
    const matchedKeywords = keywords.filter(k => text.includes(k));

    if (matchedKeywords.length > 0) {
      let score = matchedKeywords.length;
      matches.push({ topic, score });
    }
  }

  matches.sort((a, b) => b.score - a.score);
  return matches.length > 0 ? matches[0].topic : 'Other';
}

/**
 * Generate a simple summary from conversation turns
 */
function generateSimpleSummary(turns) {
  const summaryParts = [];
  
  // Take first sentence from first 3 turns
  for (let i = 0; i < Math.min(3, turns.length); i++) {
    const text = turns[i].text || '';
    const firstSentence = text.match(/[^.!?]+[.!?]+/)?.[0] || text.substring(0, 150);
    if (firstSentence.trim()) {
      summaryParts.push(firstSentence.trim());
    }
  }
  
  const summary = summaryParts.join(' ');
  return summary.substring(0, 500) + (summary.length > 500 ? '...' : '');
}


// === MAIN PROCESSING ===

console.log('📖 Reading Copilot CSV...');
const rawData = fs.readFileSync(INPUT_FILE, 'utf8');
const rows = parseCSV(rawData);
const headers = rows[0];
const data = rows.slice(1);

console.log(`✓ Found ${data.length} rows\n`);

// Find column indices
const convIdx = headers.findIndex(h => h.toLowerCase() === 'conversation');
const timeIdx = headers.findIndex(h => h.toLowerCase() === 'time');
const authorIdx = headers.findIndex(h => h.toLowerCase() === 'author');
const messageIdx = headers.findIndex(h => h.toLowerCase() === 'message');

console.log(`📋 Column mapping:`);
console.log(`   Conversation: ${convIdx}`);
console.log(`   Time: ${timeIdx}`);
console.log(`   Author: ${authorIdx}`);
console.log(`   Message: ${messageIdx}\n`);

// Group rows by conversation name
const conversationMap = new Map();

for (const row of data) {
  const convName = row[convIdx] || 'Untitled';
  const time = row[timeIdx] || '';
  const author = row[authorIdx] || 'AI';
  const message = row[messageIdx] || '';
  
  // Skip empty messages
  if (!message.trim()) continue;
  
  if (!conversationMap.has(convName)) {
    conversationMap.set(convName, []);
  }
  
  conversationMap.get(convName).push({
    time,
    author,
    message: message.trim(),
    sender: author.toLowerCase() === 'human' ? 'human' : 'assistant'
  });
}

console.log(`✓ Grouped into ${conversationMap.size} conversations\n`);

// Process each conversation
const conversations = [];
let processed = 0;
let skipped = 0;

for (const [convName, turns] of conversationMap.entries()) {
  // Sort turns by time
  turns.sort((a, b) => new Date(a.time || 0) - new Date(b.time || 0));
  
  // Calculate total length
  const totalLength = turns.reduce((sum, t) => sum + t.message.length, 0);
  
  // Skip very short conversations
  if (totalLength < MIN_LENGTH || turns.length < 2) {
    skipped++;
    continue;
  }
  
  console.log(`\n📝 Processing: "${convName}"`);
  console.log(`   Turns: ${turns.length}`);
  console.log(`   Total length: ${totalLength} chars`);
  
  // Get first and last timestamps
  const created_at = turns[0].time;
  const updated_at = turns[turns.length - 1].time;
  
  // Generate summary from first few messages
  const summaryParts = [];
  for (let i = 0; i < Math.min(3, turns.length); i++) {
    const turn = turns[i];
    const firstSentence = turn.message.match(/[^.!?]+[.!?]+/)?.[0] || turn.message.substring(0, 200);
    summaryParts.push(firstSentence.trim());
  }
  const summary = summaryParts.join(' ');
  
  // Categorize based on full conversation content
  const fullText = turns.map(t => t.message).join(' ');
  const primaryTopic = categorizeContent(fullText);
  
  conversations.push({
    uuid: crypto.randomUUID(),
    name: convName,
    created_at,
    updated_at,
    primary_topic: primaryTopic,
    summary: summary.substring(0, 500) + (summary.length > 500 ? '...' : ''),
    turns: turns.map(t => ({
      sender: t.sender,
      text: t.message,
      created_at: t.time
    })),
    turn_count: turns.length,
    human_turns: turns.filter(t => t.sender === 'human').length,
    ai_turns: turns.filter(t => t.sender === 'assistant').length
  });
  
  processed++;
  console.log(`   ✓ ${turns.filter(t => t.sender === 'human').length} human + ${turns.filter(t => t.sender === 'assistant').length} AI turns`);
}

console.log(`\n📊 Summary: ${processed} conversations processed, ${skipped} skipped\n`);

// === WRITE OUTPUT ===

// Group by topic
const byTopic = {};
for (const conv of conversations) {
  if (!byTopic[conv.primary_topic]) byTopic[conv.primary_topic] = [];
  byTopic[conv.primary_topic].push(conv);
}

// Write each conversation as a markdown file
for (const [topic, convs] of Object.entries(byTopic)) {
  const topicPath = path.join(OUTPUT_DIR, topic, 'Conversations');
  fs.mkdirSync(topicPath, { recursive: true });
  
  for (const conv of convs) {
    const dateStr = conv.created_at ? conv.created_at.split('T')[0] : 'unknown';
    const filename = `${dateStr}_${sanitize(conv.name)}.md`;
    
    // Build frontmatter
    const frontmatter = [
      '---',
      `uuid: ${conv.uuid}`,
      `title: "${conv.name.replace(/"/g, '\\"')}"`,
      `theme: ${topic}`,
      `created: ${conv.created_at}`,
      `updated: ${conv.updated_at}`,
      `turn_count: ${conv.turn_count}`,
      `human_turns: ${conv.human_turns}`,
      `ai_turns: ${conv.ai_turns}`,
      `source: Copilot`,
      '---',
      ''
    ].join('\n');
    
    // Build summary section
    const summarySection = [
      '## Summary',
      '',
      conv.summary,
      '',
      '---',
      ''
    ].join('\n');
    
    // Build conversation section with timestamps
    const conversationLines = ['## Conversation', ''];
    
    for (const turn of conv.turns) {
      const sender = turn.sender === 'human' ? '**Human**' : '**Copilot**';
      const timestamp = turn.created_at ? ` *(${turn.created_at})*` : '';
      
      conversationLines.push(`### ${sender}${timestamp}`);
      conversationLines.push('');
      conversationLines.push(turn.text);
      conversationLines.push('');
      conversationLines.push('---');
      conversationLines.push('');
    }
    
    const conversationSection = conversationLines.join('\n');
    
    // Write file
    const fullContent = frontmatter + summarySection + conversationSection;
    fs.writeFileSync(path.join(topicPath, filename), fullContent);
  }
  
  console.log(`✓ Wrote ${convs.length} conversations to ${topic}/Conversations/`);
}

console.log('\n✅ Complete!\n');
console.log('📊 Statistics:');
console.log(`   Total conversations: ${conversations.length}`);
console.log(`   Total turns: ${conversations.reduce((sum, c) => sum + c.turn_count, 0)}`);
console.log(`   Average turns per conversation: ${(conversations.reduce((sum, c) => sum + c.turn_count, 0) / conversations.length).toFixed(1)}`);
console.log('\n💡 Next steps:');
console.log('   1. Review generated conversations in SemanticTwinVault/');
console.log('   2. Check if summaries are useful or if AI-generated ones would be better');
console.log('   3. Integrate with your Obsidian vault');
