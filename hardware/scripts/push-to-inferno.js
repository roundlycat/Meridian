// push-to-inferno.js
// Reads all Markdown conversation files from SemanticTwinVault/**/Conversations/
// Parses frontmatter, generates embeddings via Inferno's embedding endpoint,
// and upserts into pgvector on Inferno (192.168.0.28).
//
// Run with: node push-to-inferno.js
// Prerequisites on this machine: npm install pg node-fetch gray-matter
// Prerequisites on Inferno: embedding subprocess running (port 5001),
//                           FastMCP pgvector server running (port 8001)

const fs   = require('fs');
const path = require('path');
const { Client } = require('pg');
const matter = require('gray-matter');

// ── CONFIG ────────────────────────────────────────────────────────────────────
const VAULT_DIR        = 'SemanticTwinVault';
const INFERNO_HOST     = '192.168.0.28';
const INFERNO_PG_PORT  = 5432;
const INFERNO_DB       = 'semantic_kb';          // adjust if different
const INFERNO_USER     = 'sean';                 // adjust if different
const INFERNO_PASSWORD = process.env.INFERNO_PG_PASSWORD || '';
const EMBED_URL        = `http://${INFERNO_HOST}:5001/embed`; // embedding subprocess
const TABLE_NAME       = 'conversation_chunks';
const BATCH_SIZE       = 10;   // embed N docs at a time
const DRY_RUN          = process.argv.includes('--dry-run');

if (DRY_RUN) console.log('🔍 DRY RUN — no writes to Inferno\n');

// ── HELPERS ───────────────────────────────────────────────────────────────────

// Walk vault and collect all .md files inside Conversations/ folders
function collectConversationFiles(vaultDir) {
  const results = [];
  function walk(dir) {
    if (!fs.existsSync(dir)) return;
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      const fullPath = path.join(dir, entry.name);
      if (entry.isDirectory()) {
        walk(fullPath);
      } else if (entry.isFile() && entry.name.endsWith('.md') && dir.endsWith('Conversations')) {
        results.push(fullPath);
      }
    }
  }
  walk(vaultDir);
  return results;
}

// Parse frontmatter + body from a Markdown file
function parseMarkdownFile(filePath) {
  const raw = fs.readFileSync(filePath, 'utf8');
  try {
    const { data: frontmatter, content } = matter(raw);
    return { frontmatter, content, raw };
  } catch {
    // If gray-matter fails, return minimal object
    return { frontmatter: {}, content: raw, raw };
  }
}

// Detect source from frontmatter, filename, or path
function detectSource(frontmatter, filePath) {
  if (frontmatter.source) return frontmatter.source;
  const p = filePath.toLowerCase();
  if (p.includes('copilot')) return 'copilot';
  if (p.includes('gemini'))  return 'gemini';
  return 'claude';
}

// Build a plain-text chunk from the document (used for embedding)
// Strips markdown syntax noise, keeps structure intact
function buildChunkText(frontmatter, content) {
  const parts = [];
  if (frontmatter.title)  parts.push(`Title: ${frontmatter.title}`);
  if (frontmatter.topics) parts.push(`Topics: ${[].concat(frontmatter.topics).join(', ')}`);
  if (frontmatter.tags)   parts.push(`Tags: ${[].concat(frontmatter.tags).join(', ')}`);
  parts.push('');
  // Strip callout blocks and heading markers for cleaner embedding
  const cleaned = content
    .replace(/^>\s*\[!.*?\].*$/gm, '')
    .replace(/^#{1,6}\s+/gm, '')
    .replace(/\*\*(.*?)\*\*/g, '$1')
    .replace(/`{3}[\s\S]*?`{3}/g, '[code block]')
    .trim();
  parts.push(cleaned);
  return parts.join('\n').substring(0, 8000); // stay well within embedding limits
}

// Call Inferno's embedding subprocess (FastAPI, returns {"embedding": [...]})
async function fetchEmbedding(text) {
  const fetch = (await import('node-fetch')).default;
  const res = await fetch(EMBED_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ text }),
    timeout: 30000
  });
  if (!res.ok) throw new Error(`Embedding server returned ${res.status}`);
  const json = await res.json();
  if (!json.embedding) throw new Error('No embedding field in response');
  return json.embedding;
}

// Upsert a single doc into pgvector
async function upsertDoc(client, doc) {
  const {
    uuid, title, source, topics, tags, filePath,
    created, messageCount, chunkText, embedding
  } = doc;

  // pgvector expects the embedding as a formatted string '[0.1,0.2,...]'
  const embeddingStr = `[${embedding.join(',')}]`;

  await client.query(`
    INSERT INTO ${TABLE_NAME} (
      uuid, title, source, topics, tags, file_path,
      created_date, message_count, content, embedding, updated_at
    ) VALUES (
      $1, $2, $3, $4, $5, $6, $7, $8, $9, $10::vector, NOW()
    )
    ON CONFLICT (uuid) DO UPDATE SET
      title        = EXCLUDED.title,
      source       = EXCLUDED.source,
      topics       = EXCLUDED.topics,
      tags         = EXCLUDED.tags,
      file_path    = EXCLUDED.file_path,
      content      = EXCLUDED.content,
      embedding    = EXCLUDED.embedding,
      updated_at   = NOW()
  `, [
    uuid,
    title       || 'Untitled',
    source,
    topics      || [],
    tags        || [],
    filePath,
    created     || null,
    messageCount || 0,
    chunkText,
    embeddingStr
  ]);
}

// Ensure the table exists (idempotent)
async function ensureTable(client) {
  await client.query(`
    CREATE EXTENSION IF NOT EXISTS vector;

    CREATE TABLE IF NOT EXISTS ${TABLE_NAME} (
      id           SERIAL PRIMARY KEY,
      uuid         TEXT UNIQUE NOT NULL,
      title        TEXT,
      source       TEXT,          -- 'claude' | 'gemini' | 'copilot'
      topics       TEXT[],
      tags         TEXT[],
      file_path    TEXT,
      created_date DATE,
      message_count INTEGER,
      content      TEXT,
      embedding    vector(384),   -- adjust dimension to match your model
      updated_at   TIMESTAMPTZ DEFAULT NOW()
    );

    CREATE INDEX IF NOT EXISTS ${TABLE_NAME}_embedding_idx
      ON ${TABLE_NAME} USING ivfflat (embedding vector_cosine_ops)
      WITH (lists = 100);

    CREATE INDEX IF NOT EXISTS ${TABLE_NAME}_source_idx
      ON ${TABLE_NAME} (source);

    CREATE INDEX IF NOT EXISTS ${TABLE_NAME}_uuid_idx
      ON ${TABLE_NAME} (uuid);
  `);
}

// ── MAIN ──────────────────────────────────────────────────────────────────────

async function main() {
  console.log('🚀 push-to-inferno — Semantic Twin Vault → pgvector\n');

  // 1. Collect files
  const files = collectConversationFiles(VAULT_DIR);
  console.log(`📁 Found ${files.length} conversation files in Conversations/ folders\n`);

  if (files.length === 0) {
    console.log('Nothing to do. Run the parsers first.');
    return;
  }

  // 2. Parse all files
  const parsed = files.map(filePath => {
    const { frontmatter, content } = parseMarkdownFile(filePath);
    const source    = detectSource(frontmatter, filePath);
    const uuid      = frontmatter.uuid || require('crypto')
      .createHash('sha1').update(filePath).digest('hex').substring(0, 36);
    const chunkText = buildChunkText(frontmatter, content);

    return {
      uuid,
      title:        frontmatter.title || path.basename(filePath, '.md'),
      source,
      topics:       [].concat(frontmatter.topics || frontmatter.theme || []),
      tags:         [].concat(frontmatter.tags    || []),
      filePath:     path.relative(process.cwd(), filePath),
      created:      frontmatter.created || frontmatter.timestamp?.split('T')[0] || null,
      messageCount: frontmatter.message_count || 0,
      chunkText
    };
  });

  // Show source breakdown
  const bySource = parsed.reduce((acc, d) => {
    acc[d.source] = (acc[d.source] || 0) + 1; return acc;
  }, {});
  console.log('📊 Source breakdown:');
  for (const [src, count] of Object.entries(bySource)) {
    console.log(`   ${src.padEnd(10)} ${count} files`);
  }
  console.log();

  if (DRY_RUN) {
    console.log('Dry run complete. Re-run without --dry-run to push to Inferno.');
    return;
  }

  // 3. Connect to Inferno PostgreSQL
  const client = new Client({
    host:     INFERNO_HOST,
    port:     INFERNO_PG_PORT,
    database: INFERNO_DB,
    user:     INFERNO_USER,
    password: INFERNO_PASSWORD,
    connectionTimeoutMillis: 10000
  });

  try {
    await client.connect();
    console.log(`✓ Connected to Inferno PostgreSQL (${INFERNO_HOST})\n`);
  } catch (err) {
    console.error(`❌ Cannot connect to Inferno: ${err.message}`);
    console.error('   Check: PostgreSQL running, pg_hba.conf allows this host,');
    console.error('   INFERNO_PG_PASSWORD env var set correctly.');
    process.exit(1);
  }

  // 4. Ensure table
  await ensureTable(client);
  console.log(`✓ Table '${TABLE_NAME}' ready\n`);

  // 5. Check which UUIDs already exist (skip them unless content changed)
  const existingResult = await client.query(`SELECT uuid FROM ${TABLE_NAME}`);
  const existingUUIDs  = new Set(existingResult.rows.map(r => r.uuid));
  const toProcess      = parsed; // upsert handles idempotency via ON CONFLICT

  console.log(`   ${existingUUIDs.size} already in DB — will upsert all (skips re-embedding if unchanged)\n`);

  // 6. Embed + upsert in batches
  let succeeded = 0, failed = 0;

  for (let i = 0; i < toProcess.length; i += BATCH_SIZE) {
    const batch = toProcess.slice(i, i + BATCH_SIZE);
    const batchNum = Math.floor(i / BATCH_SIZE) + 1;
    const totalBatches = Math.ceil(toProcess.length / BATCH_SIZE);
    process.stdout.write(`   Batch ${batchNum}/${totalBatches} — embedding...`);

    for (const doc of batch) {
      try {
        doc.embedding = await fetchEmbedding(doc.chunkText);
        await upsertDoc(client, doc);
        succeeded++;
      } catch (err) {
        console.error(`\n   ⚠️  Failed [${doc.title}]: ${err.message}`);
        failed++;
      }
    }
    console.log(` ✓ (${succeeded} done, ${failed} failed)`);
  }

  await client.end();

  // 7. Summary
  console.log('\n✅ Push complete!');
  console.log(`   ✓ ${succeeded} documents upserted into ${TABLE_NAME}`);
  if (failed > 0) {
    console.log(`   ⚠️  ${failed} failed — check embedding server at ${EMBED_URL}`);
  }
  console.log(`\n💡 Query from Inferno:`);
  console.log(`   SELECT title, source, topics FROM ${TABLE_NAME} ORDER BY updated_at DESC LIMIT 10;`);
  console.log(`\n💡 Semantic search:`);
  console.log(`   SELECT title, source, 1 - (embedding <=> query_vec) AS score`);
  console.log(`   FROM ${TABLE_NAME} ORDER BY embedding <=> query_vec LIMIT 5;`);
  console.log(`\n💡 Filter by source:`);
  console.log(`   SELECT title FROM ${TABLE_NAME} WHERE source = 'copilot' ORDER BY created_date DESC;`);
}

main().catch(err => {
  console.error('Fatal:', err);
  process.exit(1);
});
