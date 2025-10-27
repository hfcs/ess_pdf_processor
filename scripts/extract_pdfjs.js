#!/usr/bin/env node
// Minimal PDF.js-based text extractor for local testing.
// Usage: node extract_pdfjs.js <input.pdf>

const fs = require('fs');
const path = require('path');
const pdfjsLib = require('pdfjs-dist/legacy/build/pdf.js');

async function extract(filePath) {
  const data = new Uint8Array(fs.readFileSync(filePath));
  const loadingTask = pdfjsLib.getDocument({data});
  const doc = await loadingTask.promise;
  const outLines = [];
  for (let p = 1; p <= doc.numPages; ++p) {
    const page = await doc.getPage(p);
    const content = await page.getTextContent({disableCombineTextItems: false});
    const items = content.items.map(it => {
      const tx = (it.transform && it.transform.length >= 6) ? it.transform[4] : 0;
      const ty = (it.transform && it.transform.length >= 6) ? it.transform[5] : 0;
      return {str: it.str, x: tx, y: ty};
    });

    // Bucket by rounded y (descending), then sort by x
    const groups = {};
    for (const it of items) {
      const key = Math.round(it.y);
      if (!groups[key]) groups[key] = [];
      groups[key].push(it);
    }
    const keys = Object.keys(groups).map(k => parseInt(k,10)).sort((a,b)=>b-a);
    for (const k of keys) {
      const row = groups[k].sort((a,b)=>a.x-b.x).map(i=>i.str).join(' ').replace(/\s+/g,' ').trim();
      if (row.length) outLines.push(row);
    }
  }
  console.log(outLines.join('\n'));
}

async function main() {
  if (process.argv.length < 3) {
    console.error('Usage: extract_pdfjs.js <input.pdf>');
    process.exit(2);
  }
  const input = process.argv[2];
  try {
    await extract(input);
  } catch (e) {
    console.error('Error extracting PDF:', e);
    process.exit(1);
  }
}

main();
