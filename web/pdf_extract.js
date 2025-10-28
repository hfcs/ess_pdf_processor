// Browser-side PDF.js helper. Include pdfjs-dist via CDN in web/index.html
// before this script. Exposes window.extractPdfArrayBuffer(arrayBuffer) which
// returns a Promise that resolves to an array of lines (strings).

(function (global) {
  if (!global.pdfjsLib) {
    console.warn('pdfjsLib not found on window - ensure pdfjs-dist is loaded');
  }

  // Heuristic extraction that returns structured rows and attaches
  // per-row metadata (division, stage). Returns Promise<Array<Object>> where
  // each object has: { type: 'row', line: string, division: string, stage: string }
  async function extractPdfArrayBuffer(arrayBuffer) {
    const pdfjs = global.pdfjsLib;
    if (!pdfjs) throw new Error('pdfjsLib not available');
    const data = new Uint8Array(arrayBuffer);
    const loadingTask = pdfjs.getDocument({data});
    const doc = await loadingTask.promise;
    const out = [];

    // Regexes for header detection
    const columnHeaderRx = /\bPTS\b|\bTIME\b|\bFACTOR\b|\bPOINTS\b|\bPERCENT\b|\bName\b|\b#\b/i;
    const divisionRx = /^([A-Z\s&-]+)\s+--\s+Overall Stage Results/i;
    const stageRx = /Stage\s*(\d+|[A-Za-z0-9]+)/i;

    let currentDivision = '';
    let currentStage = '';

    for (let p = 1; p <= doc.numPages; ++p) {
      const page = await doc.getPage(p);
      const content = await page.getTextContent({disableCombineTextItems: false});
      const items = content.items.map(it => {
        const tx = (it.transform && it.transform.length >= 6) ? it.transform[4] : 0;
        const ty = (it.transform && it.transform.length >= 6) ? it.transform[5] : 0;
        return {str: it.str, x: tx, y: ty};
      });

      // Group by rounded y coordinate to reconstruct lines
      const groups = {};
      for (const it of items) {
        const key = Math.round(it.y);
        if (!groups[key]) groups[key] = [];
        groups[key].push(it);
      }

      const ys = Object.keys(groups).map(k => parseInt(k, 10)).sort((a,b)=>b-a);
      for (const y of ys) {
        const rowItems = groups[y];
        rowItems.sort((a,b)=>a.x-b.x);
        const line = rowItems.map(i=>i.str).join(' ').replace(/\s+/g,' ').trim();
        if (!line) continue;

        // Detect division header
        const divMatch = line.match(divisionRx);
        if (divMatch) {
          currentDivision = divMatch[1].trim();
          // emit a meta object (optional)
          out.push({ type: 'meta', meta: 'division', division: currentDivision, page: p });
          continue;
        }

        // Detect stage header (e.g., "Stage 1 -- Stage 1" or "Stage 1")
        const sMatch = line.match(stageRx);
        if (sMatch) {
          currentStage = sMatch[0].trim();
          out.push({ type: 'meta', meta: 'stage', stage: currentStage, page: p });
          continue;
        }

        // Skip column headers and legends
        if (columnHeaderRx.test(line)) continue;
        if (/Overall Stage Results/i.test(line)) continue;
        if (/Event|Match|Rank|Ranking/i.test(line) && line.length < 60) {
          // likely a small header/legend line, skip
          continue;
        }

        // Treat line as a data row and attach current metadata
        out.push({ type: 'row', line: line, division: currentDivision, stage: currentStage, page: p });
      }
    }

    return out;
  }

  global.extractPdfArrayBuffer = extractPdfArrayBuffer;
})(window);
