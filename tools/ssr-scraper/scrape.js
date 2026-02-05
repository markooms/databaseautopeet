#!/usr/bin/env node
/**
 * SSR/RSC Scraper - For React Server Component sites without APIs
 * Works with: Seven Stars, Circle8, and similar Next.js/React SSR sites
 */

const { chromium } = require('playwright-extra');
const StealthPlugin = require('puppeteer-extra-plugin-stealth');
const fs = require('fs');

chromium.use(StealthPlugin());

// Site configurations
const SITES = {
  sevenstars: {
    name: 'Seven Stars',
    listUrl: 'https://www.sevenstars.nl/opdrachten',
    jobLinkSelector: 'a[href*="/opdracht/"]',
    idPattern: /([A-Z0-9]+-\d+)/,
    getJobDetails: async (page) => {
      return page.evaluate(() => {
        const title = document.querySelector('h1')?.textContent?.trim();
        const description = document.querySelector('article, .description, [class*="content"]')?.textContent?.trim();
        
        // Extract metadata from the page
        const meta = {};
        document.querySelectorAll('dl dt, dl dd').forEach((el, i, arr) => {
          if (el.tagName === 'DT' && arr[i+1]?.tagName === 'DD') {
            meta[el.textContent.trim()] = arr[i+1].textContent.trim();
          }
        });
        
        return { title, description: description?.substring(0, 500), meta };
      });
    }
  },
  circle8: {
    name: 'Circle8',
    listUrl: 'https://www.circle8.nl/opdrachten',
    jobLinkSelector: 'a[href*="/opdracht/"]',
    idPattern: /(VNR-\d+)/,
    getJobDetails: async (page) => {
      return page.evaluate(() => {
        const title = document.querySelector('h1')?.textContent?.trim();
        const description = document.querySelector('article, .description, [class*="content"]')?.textContent?.trim();
        return { title, description: description?.substring(0, 500) };
      });
    }
  }
};

async function scrapeJobList(site, browser) {
  const config = SITES[site];
  if (!config) throw new Error(`Unknown site: ${site}`);
  
  console.log(`\n📋 Scraping job list from ${config.name}...`);
  
  const page = await browser.newPage();
  await page.goto(config.listUrl, { waitUntil: 'networkidle', timeout: 30000 });
  await page.waitForTimeout(2000);
  
  // Scroll to load all jobs
  await autoScroll(page);
  
  const jobs = await page.evaluate(({ selector, pattern }) => {
    const links = Array.from(document.querySelectorAll(selector));
    const regex = new RegExp(pattern);
    
    const jobMap = new Map();
    for (const link of links) {
      const href = link.getAttribute('href');
      const match = href.match(regex);
      if (match && !href.includes('/sollicitatie')) {
        const id = match[1];
        if (!jobMap.has(id)) {
          // Try to get title from link or nearby elements
          let title = link.textContent.trim();
          if (title === 'Solliciteer direct' || title.length < 5) {
            const parent = link.closest('article, div, li');
            const h2 = parent?.querySelector('h2, h3');
            title = h2?.textContent?.trim() || title;
          }
          jobMap.set(id, { id, href, title });
        }
      }
    }
    
    return Array.from(jobMap.values());
  }, { selector: config.jobLinkSelector, pattern: config.idPattern.source });
  
  await page.close();
  console.log(`   Found ${jobs.length} jobs`);
  
  return jobs;
}

async function scrapeJobDetails(site, jobs, browser, limit = 5) {
  const config = SITES[site];
  const baseUrl = new URL(config.listUrl).origin;
  
  console.log(`\n📄 Scraping details for ${Math.min(limit, jobs.length)} jobs...`);
  
  const results = [];
  const page = await browser.newPage();
  
  for (let i = 0; i < Math.min(limit, jobs.length); i++) {
    const job = jobs[i];
    const url = job.href.startsWith('http') ? job.href : baseUrl + job.href;
    
    console.log(`   [${i+1}/${Math.min(limit, jobs.length)}] ${job.id}`);
    
    try {
      await page.goto(url, { waitUntil: 'networkidle', timeout: 20000 });
      await page.waitForTimeout(1000);
      
      const details = await config.getJobDetails(page);
      results.push({ ...job, url, ...details });
    } catch (err) {
      console.log(`      ⚠️ Error: ${err.message}`);
      results.push({ ...job, url, error: err.message });
    }
  }
  
  await page.close();
  return results;
}

async function autoScroll(page) {
  await page.evaluate(async () => {
    await new Promise((resolve) => {
      let totalHeight = 0;
      const distance = 300;
      const timer = setInterval(() => {
        window.scrollBy(0, distance);
        totalHeight += distance;
        if (totalHeight >= document.body.scrollHeight || totalHeight > 10000) {
          clearInterval(timer);
          resolve();
        }
      }, 100);
    });
  });
  await page.waitForTimeout(1000);
}

async function main() {
  const args = process.argv.slice(2);
  const site = args[0] || 'sevenstars';
  const detailLimit = parseInt(args[1]) || 5;
  
  if (!SITES[site]) {
    console.log('Available sites:', Object.keys(SITES).join(', '));
    process.exit(1);
  }
  
  console.log(`\n🕷️  SSR Scraper - ${SITES[site].name}`);
  console.log('━'.repeat(40));
  
  const browser = await chromium.launch({ headless: true });
  
  try {
    // Get job list
    const jobs = await scrapeJobList(site, browser);
    
    // Get details for first N jobs
    const detailed = await scrapeJobDetails(site, jobs, browser, detailLimit);
    
    // Output
    const output = {
      site: SITES[site].name,
      scrapedAt: new Date().toISOString(),
      totalJobs: jobs.length,
      detailedJobs: detailed.length,
      jobs: detailed
    };
    
    const filename = `${site}-jobs.json`;
    fs.writeFileSync(filename, JSON.stringify(output, null, 2));
    
    console.log(`\n✅ Saved to ${filename}`);
    console.log('\nSample job:');
    console.log(JSON.stringify(detailed[0], null, 2));
    
  } finally {
    await browser.close();
  }
}

main().catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
