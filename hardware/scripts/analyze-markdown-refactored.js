// Run with: node analyze-markdown-refactored.js

const fs = require('fs');
const path = require('path');

// === CONFIG ===
const INPUT_FILE = 'copilotactivityhistory_16.csv';
const OUTPUT_DIR = 'SemanticTwinVault';
const MIN_LENGTH = 800;

// Enhanced topic patterns with weighted keywords and subcategories
const TOPIC_PATTERNS = {
  'Philosophy & Ethics': {
    keywords: ['wittgenstein', 'gadamer', 'kant', 'hermeneutic', 'ethics', 'resonance', 'phenomenology', 'epistemology', 'metaphysics', 'ontological', 'deontological', 'virtue ethics', 'moral', 'categorical imperative'],
    subcategories: {
      'Continental Philosophy': ['gadamer', 'hermeneutic', 'phenomenology', 'heidegger', 'husserl'],
      'Analytic Philosophy': ['wittgenstein', 'logical', 'language game', 'tractatus'],
      'Ethics': ['ethics', 'moral', 'virtue', 'deontological', 'consequentialism']
    }
  },
  'Semantic Systems': {
    keywords: ['semantic twin', 'motif', 'dashboard', 'drift', 'telemetry', 'semantic web', 'linked data', 'knowledge graph', 'triple store', 'sparql', 'semantic layer'],
    subcategories: {
      'Semantic Twin': ['semantic twin', 'digital twin', 'twin architecture'],
      'Data Visualization': ['dashboard', 'telemetry', 'metrics', 'monitoring'],
      'Semantic Web': ['linked data', 'sparql', 'triple store']
    }
  },
  'AI Architecture': {
    keywords: ['agent', 'modular', 'neural', 'jetson', 'esp32', 'transformer', 'llm', 'embedding', 'inference', 'fine-tuning', 'rag', 'prompt', 'chain of thought', 'multi-agent', 'agentic'],
    subcategories: {
      'Edge AI': ['jetson', 'esp32', 'edge computing', 'embedded'],
      'LLM & Transformers': ['transformer', 'llm', 'gpt', 'claude', 'embedding', 'fine-tuning'],
      'Agent Systems': ['agent', 'multi-agent', 'agentic', 'autonomous']
    }
  },
  'Human–Machine Collaboration': {
    keywords: ['apprenticeship', 'co-creation', 'dialogical', 'human-in-the-loop', 'collaborative', 'augmentation', 'centaur', 'hybrid intelligence', 'human-ai'],
    subcategories: {
      'Learning Models': ['apprenticeship', 'scaffolding', 'mentorship'],
      'Collaboration Patterns': ['co-creation', 'dialogical', 'human-in-the-loop']
    }
  },
  'Knowledge Representation': {
    keywords: ['ontology', 'rdf', 'vector', 'owl', 'taxonomy', 'schema', 'knowledge base', 'graph database', 'neo4j', 'embeddings', 'semantic search'],
    subcategories: {
      'Ontologies': ['ontology', 'owl', 'rdf', 'taxonomy', 'schema'],
      'Vector & Embeddings': ['vector', 'embeddings', 'semantic search', 'similarity'],
      'Graph Databases': ['neo4j', 'graph database', 'knowledge graph']
    }
  },
  'Ecological & Multispecies Ethics': {
    keywords: ['multispecies', 'land', 'spirit', 'ecology', 'environmental', 'biodiversity', 'indigenous', 'animism', 'posthuman', 'more-than-human'],
    subcategories: {
      'Environmental Ethics': ['ecology', 'environmental', 'biodiversity', 'sustainability'],
      'Indigenous Knowledge': ['indigenous', 'land', 'spirit', 'animism'],
      'Posthumanism': ['posthuman', 'more-than-human', 'multispecies']
    }
  },
  'Creative & Embodied Interfaces': {
    keywords: ['poetic', 'vr', 'aesthetic', 'ritual', 'embodied', 'haptic', 'immersive', 'artistic', 'generative art', 'interactive'],
    subcategories: {
      'XR & Immersive': ['vr', 'ar', 'xr', 'immersive', 'haptic'],
      'Generative & Artistic': ['generative art', 'artistic', 'poetic', 'aesthetic'],
      'Embodiment': ['embodied', 'ritual', 'somatic', 'kinesthetic']
    }
  },
  'Governance & Society': {
    keywords: ['citizenship', 'clausewitz', 'infrastructure', 'governance', 'policy', 'regulation', 'democracy', 'civic', 'institutional', 'public'],
    subcategories: {
      'AI Governance': ['regulation', 'policy', 'governance', 'ethics board'],
      'Civic Tech': ['citizenship', 'civic', 'democracy', 'public'],
      'Infrastructure': ['infrastructure', 'institutional', 'systems']
    }
  },
  'Software Engineering': {
    keywords: ['api', 'database', 'backend', 'frontend', 'devops', 'testing', 'refactoring', 'architecture', 'microservices', 'rest', 'graphql'],
    subcategories: {
      'Architecture': ['microservices', 'monolith', 'architecture', 'design pattern'],
      'Web Development': ['frontend', 'backend', 'api', 'rest', 'graphql'],
      'DevOps': ['devops', 'ci/cd', 'docker', 'kubernetes', 'deployment']
    }
  },
  'Data & Analytics': {
    keywords: ['data pipeline', 'etl', 'analytics', 'visualization', 'statistics', 'machine learning', 'dataset', 'preprocessing'],
    subcategories: {
      'Data Engineering': ['data pipeline', 'etl', 'preprocessing', 'data lake'],
      'Analytics': ['analytics', 'statistics', 'metrics', 'kpi'],
      'ML & Modeling': ['machine learning', 'model', 'training', 'prediction']
    }
  }
};

// Document type patterns for classification
const DOC_TYPE_PATTERNS = {
  'Tutorial': ['step by step', 'how to', 'guide', 'tutorial', 'walkthrough', 'instructions', 'example:', 'first,', 'then,', 'finally,'],
  'Concept': ['what is', 'definition', 'concept', 'theory', 'principle', 'framework', 'paradigm', 'mental model'],
  'Discussion': ['consider', 'debate', 'perspective', 'argument', 'opinion', 'viewpoint', 'on the other hand', 'however'],
  'Code': ['```', 'function', 'class ', 'const ', 'let ', 'import ', 'export ', 'def ', 'async '],
  'Architecture': ['diagram', 'architecture', 'design', 'system design', 'component', 'module', 'layer'],
  'Reference': ['documentation', 'api reference', 'specification', 'schema', 'interface']
};

// Concept extraction patterns for auto-tagging
const CONCEPT_PATTERNS = [
  // Technical concepts
  /\b(api|rest|graphql|grpc|websocket|oauth|jwt)\b/gi,
  /\b(react|vue|angular|svelte|nextjs|nuxt)\b/gi,
  /\b(node|python|rust|golang|typescript|javascript)\b/gi,
  /\b(docker|kubernetes|terraform|ansible|jenkins)\b/gi,
  /\b(postgresql|mongodb|redis|elasticsearch|neo4j)\b/gi,
  /\b(aws|azure|gcp|cloud|serverless|lambda)\b/gi,
  // AI/ML concepts
  /\b(transformer|attention|embedding|fine-tuning|rag|prompt engineering)\b/gi,
  /\b(gpt|claude|llama|mistral|gemini|copilot)\b/gi,
  /\b(neural network|deep learning|reinforcement learning|supervised|unsupervised)\b/gi,
  // Philosophical concepts
  /\b(hermeneutics|phenomenology|ontology|epistemology|ethics)\b/gi,
  /\b(wittgenstein|gadamer|kant|heidegger|husserl|deleuze)\b/gi,
  // Domain concepts
  /\b(semantic twin|knowledge graph|digital twin|linked data)\b/gi,
  /\b(human-in-the-loop|co-creation|multi-agent|agentic)\b/gi
];

// === HELPERS ===

/**
 * Comprehensive YAML string escaping function
 * Handles all special characters that can break YAML parsing
 */
function escapeYAMLString(str) {
  if (typeof str !== 'string') return 'Untitled';
  
  // Step 1: Remove or escape control characters
  str = str.replace(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/g, '');
  
  // Step 2: Escape backslashes first (before escaping other things)
  str = str.replace(/\\/g, '\\\\');
  
  // Step 3: Escape double quotes
  str = str.replace(/"/g, '\\"');
  
  // Step 4: Remove or escape other problematic characters
  // Newlines and tabs should become spaces
  str = str.replace(/[\n\r\t]/g, ' ');
  
  // Step 5: Collapse multiple spaces
  str = str.replace(/\s+/g, ' ');
  
  // Step 6: Trim
  str = str.trim();
  
  // Step 7: If string is empty after cleaning, return default
  if (!str) return 'Untitled';
  
  return str;
}

/**
 * Escape a string for use in YAML array
 * Wraps in quotes and escapes internal quotes
 */
function escapeYAMLArrayItem(str) {
  const escaped = escapeYAMLString(str);
  return `"${escaped}"`;
}

/**
 * Safely format a YAML array
 */
function formatYAMLArray(items) {
  if (!items || items.length === 0) return '[]';
  return `[${items.map(escapeYAMLArrayItem).join(', ')}]`;
}

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

function isSubstantialMarkdown(message) {
  if (!message || message.length < MIN_LENGTH) return false;
  const hasYAML = /^---\n[\s\S]*?\n---/m.test(message);
  const headers = message.match(/^#{1,6}\s+/gm);
  const hasHeaders = headers && headers.length >= 2;
  const hasCode = message.includes('```');
  return hasYAML || hasHeaders || hasCode;
}

// Multi-category support: returns ALL matching topics with scores
function categorizeMulti(content) {
  const text = content.toLowerCase();
  const matches = [];

  for (const [topic, config] of Object.entries(TOPIC_PATTERNS)) {
    const keywords = config.keywords || config;
    const matchedKeywords = keywords.filter(k => text.includes(k));

    if (matchedKeywords.length > 0) {
      // Calculate score based on keyword matches and frequency
      let score = matchedKeywords.length;
      matchedKeywords.forEach(k => {
        const regex = new RegExp(k.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'gi');
        const occurrences = (text.match(regex) || []).length;
        score += Math.min(occurrences - 1, 3); // Cap bonus at 3
      });

      // Find matching subcategories
      const subcats = [];
      if (config.subcategories) {
        for (const [subcat, subKeywords] of Object.entries(config.subcategories)) {
          if (subKeywords.some(sk => text.includes(sk))) {
            subcats.push(subcat);
          }
        }
      }

      matches.push({ topic, score, matchedKeywords, subcategories: subcats });
    }
  }

  // Sort by score descending
  matches.sort((a, b) => b.score - a.score);
  return matches.length > 0 ? matches : [{ topic: 'Other', score: 0, matchedKeywords: [], subcategories: [] }];
}

// Extract auto-tags from content
function extractTags(content) {
  const tags = new Set();
  const text = content.toLowerCase();

  // Extract from concept patterns
  for (const pattern of CONCEPT_PATTERNS) {
    const matches = content.match(pattern);
    if (matches) {
      matches.forEach(m => tags.add(m.toLowerCase().replace(/\s+/g, '-')));
    }
  }

  // Extract from headers (h1, h2, h3)
  const headers = content.match(/^#{1,3}\s+(.+)$/gm);
  if (headers) {
    headers.forEach(h => {
      const headerText = h.replace(/^#+\s+/, '').trim();
      // Convert to tag format if short enough
      if (headerText.length <= 30) {
        const tag = headerText.toLowerCase()
          .replace(/[^\w\s-]/g, '')
          .replace(/\s+/g, '-')
          .substring(0, 30);
        if (tag.length >= 3) tags.add(tag);
      }
    });
  }

  // Extract code language tags
  const codeBlocks = content.match(/```(\w+)/g);
  if (codeBlocks) {
    codeBlocks.forEach(cb => {
      const lang = cb.replace('```', '').toLowerCase();
      if (lang && lang !== 'text' && lang !== 'plaintext') {
        tags.add(`code/${lang}`);
      }
    });
  }

  return Array.from(tags).slice(0, 15); // Limit to 15 tags
}

// Detect document type
function detectDocType(content) {
  const text = content.toLowerCase();
  const scores = {};

  for (const [docType, patterns] of Object.entries(DOC_TYPE_PATTERNS)) {
    scores[docType] = patterns.filter(p => text.includes(p)).length;
  }

  // Return types with scores > 0, sorted by score
  const detected = Object.entries(scores)
    .filter(([_, score]) => score > 0)
    .sort((a, b) => b[1] - a[1])
    .map(([type]) => type);

  return detected.length > 0 ? detected : ['Note'];
}

// Extract key concepts for wiki-linking
function extractConcepts(content) {
  const concepts = new Set();

  // Extract quoted terms
  const quoted = content.match(/"([^"]{3,40})"/g);
  if (quoted) {
    quoted.forEach(q => concepts.add(q.replace(/"/g, '')));
  }

  // Extract bold terms
  const bold = content.match(/\*\*([^*]{3,40})\*\*/g);
  if (bold) {
    bold.forEach(b => concepts.add(b.replace(/\*\*/g, '')));
  }

  // Extract terms after "called", "named", "known as"
  const named = content.match(/(?:called|named|known as)\s+"?([^".\n]{3,30})"?/gi);
  if (named) {
    named.forEach(n => {
      const term = n.replace(/^(?:called|named|known as)\s+"?/i, '').replace(/"$/, '');
      concepts.add(term);
    });
  }

  return Array.from(concepts);
}

function sanitize(s) {
  if (typeof s !== 'string') return 'Untitled';
  return s.replace(/[^\w\-]/g, '_');
}

// Generate safe wiki-link name
function toWikiLink(text) {
  return text
    .replace(/[^\w\s-]/g, '')
    .replace(/\s+/g, ' ')
    .trim()
    .substring(0, 50);
}

// === MAIN ===
console.log('📊 Starting Enhanced Markdown Analyzer...\n');
// Remove BOM if present
const csvContent = fs.readFileSync(INPUT_FILE, 'utf8').replace(/^\uFEFF/, '');
const rows = parseCSV(csvContent);
const headers = rows[0];
const data = rows.slice(1);

const idx = {
  conversation: headers.indexOf('Conversation'),
  time: headers.indexOf('Time'),
  author: headers.indexOf('Author'),
  message: headers.indexOf('Message')
};

// Process documents with enhanced metadata
const docs = data
  .map(row => {
    const content = row[idx.message];
    if (!isSubstantialMarkdown(content)) return null;

    const categories = categorizeMulti(content);
    const tags = extractTags(content);
    const docTypes = detectDocType(content);
    const concepts = extractConcepts(content);

    return {
      conversation: row[idx.conversation],
      time: row[idx.time],
      author: row[idx.author],
      content,
      // Enhanced metadata
      primaryTopic: categories[0].topic,
      allTopics: categories.map(c => c.topic),
      subcategories: categories.flatMap(c => c.subcategories),
      tags,
      docTypes,
      concepts,
      scores: categories.reduce((acc, c) => { acc[c.topic] = c.score; return acc; }, {})
    };
  })
  .filter(Boolean);

console.log(`✓ Found ${docs.length} substantial markdown documents\n`);

// Build concept index for wiki-linking
const conceptIndex = new Map();
for (const doc of docs) {
  const convName = doc.conversation || 'Untitled';
  const timeStr = doc.time ? doc.time.split('T')[0] : 'unknown';
  const docName = `${timeStr}_${sanitize(convName)}`;
  doc.concepts.forEach(concept => {
    if (!conceptIndex.has(concept.toLowerCase())) {
      conceptIndex.set(concept.toLowerCase(), []);
    }
    conceptIndex.get(concept.toLowerCase()).push({ name: docName, topic: doc.primaryTopic });
  });
  // Also index by conversation name for cross-linking
  if (convName && convName !== 'Untitled') {
    conceptIndex.set(convName.toLowerCase(), [{ name: docName, topic: doc.primaryTopic }]);
  }
}

// Group by primary topic but track all topics
const byTopic = {};
const topicStats = {};
for (const doc of docs) {
  // Add to primary topic
  if (!byTopic[doc.primaryTopic]) byTopic[doc.primaryTopic] = [];
  byTopic[doc.primaryTopic].push(doc);

  // Track stats for all topics
  doc.allTopics.forEach(topic => {
    if (!topicStats[topic]) topicStats[topic] = { count: 0, docs: [] };
    topicStats[topic].count++;
    topicStats[topic].docs.push(doc.conversation || 'Untitled');
  });
}

// === WRITE FILES ===
const allDocLinks = []; // For master index

for (const [topic, entries] of Object.entries(byTopic)) {
  const basePath = path.join(OUTPUT_DIR, topic);
  const artifactPath = path.join(basePath, 'Artifacts');
  fs.mkdirSync(artifactPath, { recursive: true });

  const topicDocs = [];

  // Write each document with enhanced frontmatter
  for (const doc of entries) {
    const convName = doc.conversation || 'Untitled';
    const timeStr = doc.time ? doc.time.split('T')[0] : 'unknown';
    const filename = `${timeStr}_${sanitize(convName)}.md`;
    const wikiName = toWikiLink(convName);

    // Find related documents (same concepts or similar topics)
    const relatedDocs = docs
      .filter(d => d !== doc)
      .filter(d => {
        const sharedConcepts = doc.concepts.filter(c =>
          d.concepts.some(dc => dc.toLowerCase() === c.toLowerCase())
        );
        const sharedTopics = doc.allTopics.filter(t => d.allTopics.includes(t));
        return sharedConcepts.length > 0 || sharedTopics.length > 1;
      })
      .slice(0, 5)
      .map(d => `[[${toWikiLink(d.conversation || 'Untitled')}]]`);

    // Build enhanced frontmatter with comprehensive escaping
    const frontmatter = [
      '---',
      `title: "${escapeYAMLString(convName)}"`,
      `aliases: ["${escapeYAMLString(wikiName)}"]`,
      `theme: "${escapeYAMLString(topic)}"`,
      `topics: ${formatYAMLArray(doc.allTopics)}`,
      `subcategories: ${formatYAMLArray(doc.subcategories)}`,
      `doc_type: ${formatYAMLArray(doc.docTypes)}`,
      `tags: ${formatYAMLArray(doc.tags)}`,
      `concepts: ${formatYAMLArray(doc.concepts.slice(0, 10))}`,
      `related: ${formatYAMLArray(relatedDocs)}`,
      `conversation: "${escapeYAMLString(convName)}"`,
      `timestamp: ${doc.time || 'unknown'}`,
      `author: ${doc.author || 'unknown'}`,
      `created: ${timeStr}`,
      '---',
      ''
    ].join('\n');

    // Add wiki-links section at the end
    const wikiLinksSection = relatedDocs.length > 0
      ? `\n\n---\n## Related Notes\n${relatedDocs.join(' | ')}\n`
      : '';

    // Add topic breadcrumb
    const breadcrumb = `> [!info] Topics: ${doc.allTopics.map(t => `[[${t}]]`).join(' > ')}\n\n`;

    fs.writeFileSync(
      path.join(artifactPath, filename),
      frontmatter + breadcrumb + doc.content + wikiLinksSection
    );

    topicDocs.push({ filename, doc, wikiName });
    allDocLinks.push({ topic, filename, wikiName, doc });
  }

  // Write enhanced Index.md with links
  const indexContent = [
    `# ${topic}`,
    '',
    `> A curated collection of ${entries.length} documents on ${topic}`,
    '',
    '## Statistics',
    `- **Total Documents:** ${entries.length}`,
    `- **Unique Tags:** ${new Set(entries.flatMap(e => e.tags)).size}`,
    `- **Document Types:** ${[...new Set(entries.flatMap(e => e.docTypes))].join(', ')}`,
    '',
    '## Subcategories',
    ...([...new Set(entries.flatMap(e => e.subcategories))].map(s => `- [[${s}]]`)),
    '',
    '## Documents',
    '',
    ...topicDocs.map(({ filename, doc, wikiName }) =>
      `- [[${wikiName}]] - ${doc.docTypes[0]} (${doc.tags.slice(0, 3).join(', ')})`
    ),
    '',
    '## Tag Cloud',
    '',
    [...new Set(entries.flatMap(e => e.tags))].slice(0, 20).map(t => `#${t}`).join(' '),
    ''
  ].join('\n');

  fs.writeFileSync(path.join(basePath, 'Index.md'), indexContent);

  // Write enhanced DriftLog.md
  const driftContent = [
    `# ${topic} - Drift Log`,
    '',
    '> Timeline of document creation and evolution',
    '',
    ...entries
      .sort((a, b) => new Date(b.time || 0) - new Date(a.time || 0))
      .map(d => {
        const ts = d.time ? d.time.split('T')[0] : 'unknown';
        const name = d.conversation || 'Untitled';
        return `- **${ts}** [[${toWikiLink(name)}]] - ${d.docTypes[0]}`;
      })
  ].join('\n');

  fs.writeFileSync(path.join(basePath, 'DriftLog.md'), driftContent);
}

// === WRITE MASTER INDEX ===
const masterIndex = [
  '# Semantic Twin Vault',
  '',
  '> Auto-generated knowledge graph from conversation history',
  '',
  '## Topic Overview',
  '',
  '```dataview',
  'TABLE length(file.inlinks) as "Inlinks", length(file.outlinks) as "Outlinks"',
  'FROM ""',
  'WHERE contains(file.path, "Index")',
  'SORT file.name ASC',
  '```',
  '',
  '## Topics',
  '',
  ...Object.entries(topicStats)
    .sort((a, b) => b[1].count - a[1].count)
    .map(([topic, stats]) => `- [[${topic}]] (${stats.count} documents)`),
  '',
  '## Recent Documents',
  '',
  ...allDocLinks
    .sort((a, b) => new Date(b.doc.time || 0) - new Date(a.doc.time || 0))
    .slice(0, 20)
    .map(({ topic, wikiName, doc }) => {
      const ts = doc.time ? doc.time.split('T')[0] : 'unknown';
      return `- ${ts} - [[${wikiName}]] ([[${topic}]])`;
    }),
  '',
  '## All Tags',
  '',
  [...new Set(docs.flatMap(d => d.tags))].sort().map(t => `#${t}`).join(' '),
  ''
].join('\n');

fs.writeFileSync(path.join(OUTPUT_DIR, 'Index.md'), masterIndex);

// === WRITE CONCEPT MOC (Map of Content) ===
const conceptMOC = [
  '# Concepts Map',
  '',
  '> Key concepts extracted from all documents',
  '',
  ...Array.from(conceptIndex.entries())
    .filter(([_, docs]) => docs.length > 1)
    .sort((a, b) => b[1].length - a[1].length)
    .slice(0, 50)
    .map(([concept, linkedDocs]) =>
      `- **${concept}** - appears in: ${linkedDocs.map(d => `[[${d.name}]]`).join(', ')}`
    ),
  ''
].join('\n');

fs.writeFileSync(path.join(OUTPUT_DIR, 'Concepts.md'), conceptMOC);

// === SUMMARY ===
console.log('✅ Enhanced vault generation complete!\n');
console.log('📊 Summary:');
console.log(`   - ${docs.length} documents processed`);
console.log(`   - ${Object.keys(byTopic).length} primary topics`);
console.log(`   - ${new Set(docs.flatMap(d => d.tags)).size} unique tags extracted`);
console.log(`   - ${conceptIndex.size} concepts indexed for wiki-linking`);
console.log(`\n📁 Output directory: ${path.resolve(OUTPUT_DIR)}`);
console.log('\n🔗 Graph-ready features:');
console.log('   - Multi-topic categorization');
console.log('   - Auto-generated tags');
console.log('   - Wiki-links between related docs');
console.log('   - Concept map for cross-references');
console.log('   - Dataview-compatible frontmatter');
