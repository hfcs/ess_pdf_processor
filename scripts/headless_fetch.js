#!/usr/bin/env node
// Headless fetcher using puppeteer. This script prints the fully rendered
// HTML of the given URL to stdout. Requires `npm install puppeteer` in the
// repo or globally available.
const url = process.argv[2];
if (!url) {
  console.error('Usage: node scripts/headless_fetch.js <url>');
  process.exit(2);
}
(async () => {
  try {
    const puppeteer = require('puppeteer');
    const browser = await puppeteer.launch({args: ['--no-sandbox', '--disable-setuid-sandbox']});
    const page = await browser.newPage();
    await page.goto(url, {waitUntil: 'networkidle2', timeout: 30000});
    const html = await page.content();
    console.log(html);
    await browser.close();
  } catch (err) {
    console.error('Headless fetch failed:', err && err.stack ? err.stack : err);
    process.exit(1);
  }
})();
