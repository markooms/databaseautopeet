# Session Capture

Simpele tool om browser sessies op te slaan voor authenticated scraping.

## Installatie

```bash
cd tools/session-capture
npm install
```

## Gebruik

```bash
node cli.js <url> [--stealth]
```

### Voorbeelden

```bash
# Port of Rotterdam (Salesforce)
node cli.js https://portofrotterdamsso.my.site.com/vmsvisualforce --stealth

# Circle8
node cli.js https://www.circle8.nl/opdrachten --stealth

# Generiek
node cli.js https://example.com/login
```

## Wat het doet

1. Opent een Chrome browser (zichtbaar)
2. Je logt handmatig in
3. Druk Enter als je klaar bent
4. Slaat cookies, localStorage en sessionStorage op

## Output

Een `{domain}-session.json` file met:

```json
{
  "url": "https://...",
  "domain": "example.com",
  "capturedAt": "2026-02-05T...",
  "cookies": [...],
  "localStorage": {...},
  "sessionStorage": {...}
}
```

## --stealth mode

Gebruikt voor sites met bot-detectie (Vercel, Cloudflare, etc).
Voegt fingerprint randomization toe.
