# HAR Parser - API Skill Generator

Extract API endpoints from browser HAR files and generate reusable Python code.

## Quick Start

### Step 1: Capture HAR in Chrome

1. Open Chrome, go to the portal/website
2. Press **F12** to open DevTools
3. Click **Network** tab
4. Make sure the red recording dot 🔴 is active
5. **Log in** to the site (important for capturing auth!)
6. Browse around, trigger the API calls you want to capture
7. Click the **⬇️ download icon** in the Network toolbar
8. Select **"Save all as HAR with content"**
9. Save as `portal_name.har`

```
┌─────────────────────────────────────────────────────┐
│ Chrome DevTools                               _ □ X │
├─────────────────────────────────────────────────────┤
│ Elements  Console  Sources  [Network]  ...          │
├─────────────────────────────────────────────────────┤
│ 🔴 ⃠  🗑️  ⬇️ ← CLICK THIS TO EXPORT HAR            │
└─────────────────────────────────────────────────────┘
```

### Step 2: Parse the HAR

```bash
# Just view the endpoints and generated code
python parse_har.py portal.har

# Save as a reusable skill
python parse_har.py portal.har --output skills/portal_name
```

### Step 3: Use the generated code

```python
from skills.portal_name.client import APIClient

client = APIClient()
result = client.get_api_vacatures()
print(result)
```

## What it captures

| Data | Description |
|------|-------------|
| **Endpoints** | All API URLs (XHR/Fetch requests) |
| **Methods** | GET, POST, PUT, DELETE, etc. |
| **Auth** | Cookies, Bearer tokens, API keys, CSRF tokens |
| **Query params** | URL parameters |
| **Request bodies** | POST/PUT data |
| **Response info** | Status codes, content types |

## Output files

When using `--output`, creates:

```
skills/portal_name/
├── client.py      # Python client with all endpoints
├── auth.json      # Captured authentication (cookies, tokens)
├── endpoints.json # Endpoint metadata
└── SKILL.md       # Human-readable documentation
```

## Tips

### 1. Capture while logged in
The parser captures authentication from your browser session. Make sure you're logged in before exporting the HAR.

### 2. Trigger all endpoints
Browse through the site to make sure all API calls you need are captured. Click on different pages, filters, etc.

### 3. Token expiry
Bearer tokens and session cookies expire. When they stop working:
1. Log in again in your browser
2. Export a new HAR
3. Re-run the parser

### 4. Filter XHR only (optional)
In Chrome DevTools Network tab, click **XHR** filter to see only API calls. This helps identify which calls are important.

## Example

```bash
# Parse a HarveyNash HAR capture
python parse_har.py harveynash.har --output skills/harveynash

# Output:
# 📂 Parsing 156 requests from HAR file...
# ✅ Found 12 API endpoints
# 🔗 Base URL: https://www.harveynash.nl
# 
# 📊 SUMMARY
# Base URL: https://www.harveynash.nl
# Auth Type: Session Cookie
# Total Endpoints: 12
# Methods: {'GET': 8, 'POST': 4}
#
# 💾 Saving skill to: skills/harveynash
# 📄 Saved client: skills/harveynash/client.py
# 🔐 Saved auth: skills/harveynash/auth.json
# 📋 Saved endpoints: skills/harveynash/endpoints.json
# 📖 Saved docs: skills/harveynash/SKILL.md
```

## Troubleshooting

### "No endpoints found"
- Make sure you browsed the site while recording
- Try filtering less strictly (edit `_is_api_request` in parser)
- Some sites use WebSockets instead of REST APIs

### "401 Unauthorized when using client"
- Token has expired
- Capture a new HAR while logged in
- Check if site uses refresh tokens (may need manual handling)

### "CAPTCHA or bot detection"
- Some sites block automated requests
- May need to use browser automation instead
- Consider request delays / rate limiting
