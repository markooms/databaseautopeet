#!/usr/bin/env node
/**
 * Test Session - Validate that captured cookies work
 */

import * as fs from 'fs';

const cookiesFile = process.argv[2] || 'cookies.json';

if (!fs.existsSync(cookiesFile)) {
  console.error(`Cookie file not found: ${cookiesFile}`);
  process.exit(1);
}

const cookies = JSON.parse(fs.readFileSync(cookiesFile, 'utf-8'));
console.log(`Loaded ${cookies.length} cookies from ${cookiesFile}`);

// Convert cookies to header format
const cookieHeader = cookies
  .map(c => `${c.name}=${c.value}`)
  .join('; ');

// Test URL - the main portal page
const testUrl = 'https://portofrotterdamsso.my.site.com/vmsvisualforce/s/';

console.log(`\nTesting session against: ${testUrl}\n`);

try {
  const response = await fetch(testUrl, {
    headers: {
      'Cookie': cookieHeader,
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
    },
    redirect: 'manual'  // Don't follow redirects automatically
  });

  console.log(`Status: ${response.status} ${response.statusText}`);
  console.log(`Location: ${response.headers.get('location') || '(none)'}`);

  if (response.status === 200) {
    const html = await response.text();

    // Check for signs of being logged in
    if (html.includes('login') && html.includes('password')) {
      console.log('\n❌ Session INVALID - redirected to login page');
    } else if (html.includes('aura') || html.includes('lightning') || html.includes('Salesforce')) {
      console.log('\n✅ Session VALID - Salesforce content detected');
      console.log(`   Page size: ${html.length} bytes`);

      // Try to find any useful identifiers
      const titleMatch = html.match(/<title>([^<]+)<\/title>/);
      if (titleMatch) {
        console.log(`   Page title: ${titleMatch[1]}`);
      }
    } else {
      console.log('\n⚠️  Session status unclear - check response manually');
      console.log(`   Page size: ${html.length} bytes`);
    }
  } else if (response.status === 302 || response.status === 301) {
    const location = response.headers.get('location');
    if (location?.includes('login')) {
      console.log('\n❌ Session INVALID - redirected to login');
    } else {
      console.log(`\n⚠️  Redirected to: ${location}`);
    }
  } else {
    console.log(`\n⚠️  Unexpected status code: ${response.status}`);
  }

} catch (error) {
  console.error('Error:', error.message);
  process.exit(1);
}