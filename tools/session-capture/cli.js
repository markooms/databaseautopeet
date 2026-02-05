#!/usr/bin/env node
/**
 * Session Capture - Save browser session for authenticated scraping
 * 
 * Usage:
 *   node cli.js <url> [--stealth]
 * 
 * Example:
 *   node cli.js https://portofrotterdamsso.my.site.com/vmsvisualforce --stealth
 */

import { chromium } from 'playwright-extra';
import StealthPlugin from 'puppeteer-extra-plugin-stealth';
import * as fs from 'fs';
import * as readline from 'readline';

// Parse args
const args = process.argv.slice(2);
let url = null;
let stealth = false;
let outputFile = null;

for (let i = 0; i < args.length; i++) {
  if (args[i] === '--stealth') {
    stealth = true;
  } else if (args[i] === '-o' || args[i] === '--output') {
    outputFile = args[++i];
  } else if (!args[i].startsWith('-')) {
    url = args[i];
  }
}

if (!url) {
  console.log(`
Session Capture - Save browser session for authenticated scraping

Usage:
  node cli.js <url> [options]

Options:
  --stealth        Enable stealth mode (recommended for protected sites)
  -o, --output     Output file name (default: {domain}-session.json)

Example:
  node cli.js https://example.com/login --stealth
  `);
  process.exit(1);
}

// Extract domain for default filename
const domain = new URL(url).hostname;
outputFile = outputFile || `${domain}-session.json`;

console.log(`
╔════════════════════════════════════════════════════════════╗
║              SESSION CAPTURE                               ║
╠════════════════════════════════════════════════════════════╣
║  URL: ${url.substring(0, 50).padEnd(50)}  ║
║  Stealth: ${stealth ? 'ON ' : 'OFF'}                                            ║
║  Output: ${outputFile.substring(0, 45).padEnd(45)}  ║
╚════════════════════════════════════════════════════════════╝
`);

async function main() {
  // Setup stealth if requested
  if (stealth) {
    chromium.use(StealthPlugin());
    console.log('🥷 Stealth mode enabled');
  }

  console.log('🚀 Launching browser...');
  
  const browser = await chromium.launch({
    headless: false,  // Must be visible for manual login
    args: ['--start-maximized']
  });

  const context = await browser.newContext({
    viewport: null,  // Use full window
    userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
  });

  const page = await context.newPage();
  
  console.log(`📍 Navigating to ${url}`);
  await page.goto(url, { waitUntil: 'networkidle' });

  console.log(`
╔════════════════════════════════════════════════════════════╗
║  👆 LOG IN NOW IN THE BROWSER WINDOW                       ║
║                                                            ║
║  Complete your login (including 2FA if needed)             ║
║  Navigate to the page with the data you want               ║
║                                                            ║
║  When done, come back here and press ENTER                 ║
╚════════════════════════════════════════════════════════════╝
`);

  // Wait for user to press Enter
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
  });

  await new Promise(resolve => {
    rl.question('Press ENTER when logged in and ready...', () => {
      rl.close();
      resolve();
    });
  });

  console.log('💾 Saving session...');

  // Get cookies
  const cookies = await context.cookies();
  
  // Get localStorage and sessionStorage from all frames
  const storageData = await page.evaluate(() => {
    const local = {};
    const session = {};
    
    for (let i = 0; i < localStorage.length; i++) {
      const key = localStorage.key(i);
      local[key] = localStorage.getItem(key);
    }
    
    for (let i = 0; i < sessionStorage.length; i++) {
      const key = sessionStorage.key(i);
      session[key] = sessionStorage.getItem(key);
    }
    
    return { localStorage: local, sessionStorage: session };
  });

  // Get current URL (user might have navigated)
  const finalUrl = page.url();

  // Build session object
  const session = {
    url: finalUrl,
    domain: domain,
    capturedAt: new Date().toISOString(),
    cookies: cookies,
    localStorage: storageData.localStorage,
    sessionStorage: storageData.sessionStorage
  };

  // Save to file
  fs.writeFileSync(outputFile, JSON.stringify(session, null, 2));
  
  console.log(`
╔════════════════════════════════════════════════════════════╗
║  ✅ SESSION SAVED SUCCESSFULLY                             ║
╠════════════════════════════════════════════════════════════╣
║  File: ${outputFile.padEnd(50)} ║
║  Cookies: ${String(cookies.length).padEnd(47)} ║
║  LocalStorage keys: ${String(Object.keys(storageData.localStorage).length).padEnd(36)} ║
║  SessionStorage keys: ${String(Object.keys(storageData.sessionStorage).length).padEnd(34)} ║
╚════════════════════════════════════════════════════════════╝
`);

  await browser.close();
  console.log('👋 Done!');
}

main().catch(err => {
  console.error('Error:', err.message);
  process.exit(1);
});
