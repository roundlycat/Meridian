import json

with open("C:/Users/seank/.gemini/antigravity/brain/58ed7813-a724-4f5e-a38f-7b966fd44556/.system_generated/steps/141/output.txt", "r", encoding="utf-8") as f:
    text = f.read()

raw = text.partition("Cloud Tasks: ")[2].strip()
tasks = json.loads(raw)

for col in ["working", "waiting", "research"]:
    print(f"\n=== {col.upper()} ===")
    count = 0
    for t in tasks:
        if t.get("columnId") == col:
            count += 1
            prio = t.get("priority", "medium")
            title = t.get("title", "Untitled")
            proj = t.get("projectId", "default")
            desc = (t.get("description") or "").replace("\n", " ").strip()[:140]
            print(f"- [{prio}] {title} (Project: {proj})")
            if desc:
                print(f"    {desc}")
    if count == 0:
        print("  (None)")
