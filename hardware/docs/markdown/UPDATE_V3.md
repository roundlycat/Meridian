# 🚀 v3 Update - Artifacts Support!

## What's New

The server now scans for **BOTH**:
- ✅ **Conversations** directories (original conversations)
- ✅ **Artifacts** directories (Claude & Copilot conversations from the parser)

This means ALL your conversations will now be indexed!

## Quick Update

1. **Extract v3:**
```bash
cd C:/Users/seank/source/repos/SemanticTwinConverter
mv obsidian-vault-mcp-server obsidian-vault-mcp-server-v2-backup
tar -xzf obsidian-vault-mcp-server-v3.tar.gz
```

2. **Config stays the same** - no changes needed!

3. **Restart Claude Desktop**

## What You'll See

When the server starts:
```
Scanning vault for Conversations and Artifacts directories...
Found 30 conversation directories  ← Should be ~2x more now!
Indexed 6000+ markdown files from 30 directories in 1000ms
```

Your full 3080+ conversation archive should now be indexed, including:
- Original Conversations folders
- Claude conversations (in Artifacts)
- Copilot conversations (in Artifacts)

## Test It

After updating, try:
```
Search my vault for conversations about pgvector and semantic systems
```

You should now get results from **both** Conversations and Artifacts folders! 🎉

---

**This should finally give you access to your complete 18-month dialogue archive!**
