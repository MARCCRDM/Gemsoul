const { chromium } = require('playwright'); const fs = require('fs'), path = require('path'), http = require('http');
const ROOT = __dirname;
const MIME = { '.html': 'text/html', '.js': 'text/javascript', '.json': 'application/json', '.css': 'text/css', '.woff2': 'font/woff2', '.png': 'image/png' };
(async () => {
  const srv = http.createServer((req, rsp) => { const p = path.join(ROOT, decodeURIComponent(req.url.split('?')[0])); fs.readFile(p, (e, d) => { if (e) { rsp.writeHead(404); rsp.end(); return; } rsp.writeHead(200, { 'Content-Type': MIME[path.extname(p)] || 'application/octet-stream' }); rsp.end(d); }); });
  await new Promise(r => srv.listen(0, r));
  const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome', args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
  const page = await b.newPage({ viewport: { width: 400, height: 300 } });
  page.on('pageerror', e => console.error('PAGEERR', e.message));
  await page.goto(`http://localhost:${srv.address().port}/stage.html`); await page.waitForFunction(() => window.ready);
  const ids = process.argv.slice(2);
  await page.evaluate(async (ids) => { for (const id of ids) await window.loadClip(id); }, ids);
  for (const id of ids) {
    const url = await page.evaluate(o => window.portrait(o), { clip: id, w: 1040, h: 800, turn: 0.35 });
    fs.writeFileSync(path.join(ROOT, 'img', id + '.png'), Buffer.from(url.split(',')[1], 'base64')); console.log('wrote', id);
  }
  await b.close(); srv.close();
})().catch(e => { console.error(e); process.exit(1); });
