# AAAS Data Collection Forms

## Adaptive Asset Assembly System - Baseline Data Collection

These three HTML forms are designed for print and manual completion during your baseline data collection phase (Weeks 1-2).

---

## Forms Included

### 1. Assembly Session Log (`assembly_session_log.html`)
**When to use:** Complete during or immediately after assembling equipment kit
**Time required:** 3-5 minutes
**Purpose:** Capture what items were needed, what was found/missing, and any assembly issues

### 2. Mission Outcome Report (`mission_outcome_report.html`)
**When to use:** Complete within 24-48 hours after mission
**Time required:** 10-15 minutes  
**Purpose:** Evaluate how equipment performed in the field, identify surprises and improvements

### 3. Weekly Pattern Analysis (`weekly_pattern_analysis.html`)
**When to use:** Complete at end of week (Friday or Monday morning)
**Time required:** 10-15 minutes
**Purpose:** Reflect on patterns noticed over multiple assemblies

---

## How to Print These Forms

### Method 1: Browser Print (Easiest)
1. Open the HTML file in any web browser (Chrome, Firefox, Edge, Safari)
2. Press `Ctrl+P` (Windows/Linux) or `Cmd+P` (Mac)
3. Select "Save as PDF" as printer destination
4. Click Save

**Recommended settings:**
- Margins: Default (0.75 inches)
- Scale: 100%
- Background graphics: On

### Method 2: Direct PDF Print
If you prefer printing on paper immediately:
1. Open HTML file in browser
2. Press `Ctrl+P` / `Cmd+P`
3. Select your physical printer
4. Print

---

## Usage Workflow

### Week 1-2: Baseline Collection

1. **Before mission:** 
   - Print 2-3 copies of Assembly Session Log
   - Attach to clipboard

2. **During assembly:**
   - Fill out Assembly Session Log
   - Note time, items, issues

3. **After mission (24-48 hours):**
   - Fill out Mission Outcome Report
   - Link to Assembly Log via Session ID

4. **End of week:**
   - Review all your logs from the week
   - Fill out Weekly Pattern Analysis
   - This is your reflective/learning time

### Data Entry

After completing paper forms:
- Scan or photograph completed forms
- Store in `/02_Baseline_Data/week_X/` folder
- Enter key data into spreadsheet for analysis
- Forms serve as backup and reference

---

## Tips for Effective Data Collection

### Assembly Session Log
- Use unique Session IDs (e.g., `20260107-SA-001` = Date-Initials-Number)
- Fill out DURING assembly when memory is fresh
- Be honest about problems - this data drives improvement
- Include small details (they become patterns later)

### Mission Outcome Report
- Wait 24-48 hours to complete (initial impressions + reflection)
- Focus on surprises (positive and negative)
- Specific examples > General statements
- "LED headlamp saved 15 minutes in dark shed" beats "lighting was helpful"

### Weekly Pattern Analysis
- Find quiet time to reflect
- Review your Assembly Logs and Mission Reports first
- Look for patterns YOU noticed, not what you think you should say
- Questions to the system/team are valuable - ask anything!

---

## Customization

These forms are HTML and can be edited:
- Open in any text editor
- Modify fields, add rows, change colors
- Save and print updated version
- Keep original as backup

---

## Azure Cognitive Services Debug

For your MauiApp2 integration issue, check:

1. **Verify Azure credentials:**
   ```csharp
   Debug.WriteLine($"Endpoint: {_endpoint}");
   Debug.WriteLine($"Key exists: {!string.IsNullOrEmpty(_key)}");
   ```

2. **Test with sample image first:**
   - Use embedded test image
   - Verify API call works before connecting to camera

3. **Check network permissions:**
   - Android: `AndroidManifest.xml` needs `INTERNET` permission
   - iOS: `Info.plist` needs network usage description

4. **Common issues:**
   - Wrong endpoint URL (should end with `.cognitiveservices.azure.com/`)
   - Key has spaces/formatting issues (trim the string)
   - Async not properly awaited
   - Network blocked on device

---

## Project Structure Reminder

```
AAAS_Project/
├── 01_Forms_and_Protocols/
│   ├── assembly_session_log.html
│   ├── mission_outcome_report.html
│   └── weekly_pattern_analysis.html
│
├── 02_Baseline_Data/
│   ├── week_1/
│   │   ├── scans/ (scanned paper forms)
│   │   └── data_entry.csv
│   └── week_2/
│       ├── scans/
│       └── data_entry.csv
│
└── README.md (this file)
```

---

## Next Steps

1. Print 5-10 copies of each form
2. Identify 1-2 test agents
3. Choose 2-3 kit types to track
4. Start baseline week 1
5. Reconvene after 2 weeks to analyze patterns

---

## Questions or Issues?

Keep notes on:
- Forms too long/confusing?
- Missing critical fields?
- Workflows unclear?

We'll iterate on v2.0 based on your experience.

---

**Good luck with the baseline collection!**

*Remember: The goal isn't perfect data - it's learning what the system needs to "see" to become intelligent.*
