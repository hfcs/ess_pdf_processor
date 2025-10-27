// Browser-side PDF.js helper. Include pdfjs-dist via CDN in web/index.html
// before this script. Exposes window.extractPdfArrayBuffer(arrayBuffer) which
// returns a Promise that resolves to an array of lines (strings).

(function (global) {
  if (!global.pdfjsLib) {
    console.warn('pdfjsLib not found on window - ensure pdfjs-dist is loaded');
  }

  async function extractPdfArrayBuffer(arrayBuffer) {
    const pdfjs = global.pdfjsLib;
    if (!pdfjs) throw new Error('pdfjsLib not available');
    const data = new Uint8Array(arrayBuffer);
    const loadingTask = pdfjs.getDocument({data});
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
      const groups = {};
      for (const it of items) {
        const key = Math.round(it.y);
        if (!groups[key]) groups[key] = [];
        groups[key].push(it);
      }
      const keys = Object.keys(groups).map(k => parseInt(k, 10)).sort((a,b)=>b-a);
      for (const k of keys) {
        const row = groups[k].sort((a,b)=>a.x-b.x).map(i=>i.str).join(' ').replace(/\s+/g,' ').trim();
        if (row.length) outLines.push(row);
      }
    }
    return outLines;
  }

  global.extractPdfArrayBuffer = extractPdfArrayBuffer;
})(window);
